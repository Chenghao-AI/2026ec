/* Rabi 备用模块：MSPM0 硬件 SPI 阻塞事务实现。 */
#include "rabi_spi.h"
#include "ti_msp_dl_config.h"

static bool is_cs_valid(const rabi_spi_cs_t *cs);
static bool has_manual_cs(const rabi_spi_t *spi);
static void set_cs_active(const rabi_spi_t *spi, bool active);
static rabi_err_t wait_tx_space(const rabi_spi_t *spi);
static rabi_err_t wait_rx_data(const rabi_spi_t *spi);
static rabi_err_t wait_not_busy(const rabi_spi_t *spi);
static void drain_stale_rx(const rabi_spi_t *spi);
static rabi_err_t transfer_selected(
    const rabi_spi_t *spi,
    const uint8_t *tx,
    uint8_t *rx,
    size_t length);
static void delay_if_needed(uint32_t cycles);

rabi_err_t rabi_spi_init(const rabi_spi_t *spi)
{
    if (spi == NULL || spi->instance == NULL || spi->poll_limit == 0 ||
        !is_cs_valid(&spi->cs))
    {
        return RABI_ERR_INVALID_ARG;
    }

    /*
     * SPI 的时钟、IOMUX、Controller 模式等必须先由 SYSCFG_DL_init() 配置。
     * 在这里检查关键假设，可把“忘记配置/配置成 16 bit”尽早变成错误码。
     */
    if (!DL_SPI_isPowerEnabled(spi->instance) ||
        !DL_SPI_isEnabled(spi->instance))
    {
        return RABI_ERR_INVALID_STATE;
    }
    if (DL_SPI_getMode(spi->instance) != DL_SPI_MODE_CONTROLLER ||
        DL_SPI_getDataSize(spi->instance) != DL_SPI_DATA_SIZE_8 ||
        DL_SPI_isPackingEnabled(spi->instance))
    {
        return RABI_ERR_NOT_SUPPORTED;
    }

    if (has_manual_cs(spi)) set_cs_active(spi, false);
    drain_stale_rx(spi);
    return RABI_ERR_OK;
}

rabi_err_t rabi_spi_transfer(
    const rabi_spi_t *spi,
    const uint8_t *tx,
    uint8_t *rx,
    size_t length)
{
    if (spi == NULL || length == 0 || (tx == NULL && rx == NULL))
    {
        return RABI_ERR_INVALID_ARG;
    }

    rabi_err_t err = rabi_spi_init(spi);
    if (err != RABI_ERR_OK) return err;

    set_cs_active(spi, true);
    delay_if_needed(spi->cs_setup_cycles);

    err = transfer_selected(spi, tx, rx, length);

    /*
     * 即使事务中途超时，也要释放手动 CS，避免目标芯片一直把 MISO 驱动在总线上。
     * 正常路径先等 SPI Busy 清零，确保最后一位已经真正移出移位寄存器。
     */
    if (err == RABI_ERR_OK) err = wait_not_busy(spi);
    delay_if_needed(spi->cs_hold_cycles);
    set_cs_active(spi, false);
    return err;
}

rabi_err_t rabi_spi_write(
    const rabi_spi_t *spi, const uint8_t *data, size_t length)
{
    if (data == NULL) return RABI_ERR_INVALID_ARG;
    return rabi_spi_transfer(spi, data, NULL, length);
}

rabi_err_t rabi_spi_read(
    const rabi_spi_t *spi, uint8_t *data, size_t length)
{
    if (data == NULL) return RABI_ERR_INVALID_ARG;
    return rabi_spi_transfer(spi, NULL, data, length);
}

rabi_err_t rabi_spi_write_then_read(
    const rabi_spi_t *spi,
    const uint8_t *command,
    size_t command_length,
    uint8_t *data,
    size_t data_length)
{
    if (spi == NULL || command == NULL || command_length == 0 ||
        data == NULL || data_length == 0)
    {
        return RABI_ERR_INVALID_ARG;
    }

    rabi_err_t err = rabi_spi_init(spi);
    if (err != RABI_ERR_OK) return err;

    set_cs_active(spi, true);
    delay_if_needed(spi->cs_setup_cycles);

    /* 命令阶段收到的字节没有意义，但仍由 transfer_selected() 读出并丢弃。 */
    err = transfer_selected(spi, command, NULL, command_length);
    if (err == RABI_ERR_OK)
    {
        /* CS 保持有效；发送 dummy_tx，为真正的读数据阶段继续产生时钟。 */
        err = transfer_selected(spi, NULL, data, data_length);
    }
    if (err == RABI_ERR_OK) err = wait_not_busy(spi);

    delay_if_needed(spi->cs_hold_cycles);
    set_cs_active(spi, false);
    return err;
}

static bool is_cs_valid(const rabi_spi_cs_t *cs)
{
    if (cs == NULL) return false;

    /* port=NULL 且 pin=0 是明确支持的“无手动 CS”配置。 */
    if (cs->port == NULL && cs->pin == 0) return true;
    if (cs->port == NULL || cs->pin == 0) return false;

    /* 只允许一个 GPIO bit，避免一个 CS 操作误翻转同端口的其他输出。 */
    return (cs->pin & (cs->pin - 1U)) == 0;
}

static bool has_manual_cs(const rabi_spi_t *spi)
{
    return spi->cs.port != NULL && spi->cs.pin != 0;
}

static void set_cs_active(const rabi_spi_t *spi, bool active)
{
    if (!has_manual_cs(spi)) return;

    bool high = active ? !spi->cs_active_low : spi->cs_active_low;
    if (high)
    {
        DL_GPIO_setPins(spi->cs.port, spi->cs.pin);
    }
    else
    {
        DL_GPIO_clearPins(spi->cs.port, spi->cs.pin);
    }
}

static rabi_err_t wait_tx_space(const rabi_spi_t *spi)
{
    uint32_t remaining = spi->poll_limit;
    while (DL_SPI_isTXFIFOFull(spi->instance))
    {
        if (--remaining == 0) return RABI_ERR_TIMEOUT;
    }
    return RABI_ERR_OK;
}

static rabi_err_t wait_rx_data(const rabi_spi_t *spi)
{
    uint32_t remaining = spi->poll_limit;
    while (DL_SPI_isRXFIFOEmpty(spi->instance))
    {
        if (--remaining == 0) return RABI_ERR_TIMEOUT;
    }
    return RABI_ERR_OK;
}

static rabi_err_t wait_not_busy(const rabi_spi_t *spi)
{
    uint32_t remaining = spi->poll_limit;
    while (DL_SPI_isBusy(spi->instance))
    {
        if (--remaining == 0) return RABI_ERR_TIMEOUT;
    }
    return RABI_ERR_OK;
}

static void drain_stale_rx(const rabi_spi_t *spi)
{
    /* 上一次异常中断的事务可能留下 RX 数据；新 CS 帧开始前全部丢弃。 */
    while (!DL_SPI_isRXFIFOEmpty(spi->instance))
    {
        (void)DL_SPI_receiveData8(spi->instance);
    }
}

static rabi_err_t transfer_selected(
    const rabi_spi_t *spi,
    const uint8_t *tx,
    uint8_t *rx,
    size_t length)
{
    for (size_t i = 0; i < length; i++)
    {
        /* tx/rx 可以是同一缓冲区，所以必须在覆盖 rx[i] 之前先保存待发字节。 */
        uint8_t tx_byte = tx != NULL ? tx[i] : spi->dummy_tx;

        rabi_err_t err = wait_tx_space(spi);
        if (err != RABI_ERR_OK) return err;
        DL_SPI_transmitData8(spi->instance, tx_byte);

        /* 每发一字节立即收一字节，速度不如 DMA，但绝不会把 RX FIFO 撑满。 */
        err = wait_rx_data(spi);
        if (err != RABI_ERR_OK) return err;
        uint8_t rx_byte = DL_SPI_receiveData8(spi->instance);
        if (rx != NULL) rx[i] = rx_byte;
    }

    return RABI_ERR_OK;
}

static void delay_if_needed(uint32_t cycles)
{
    if (cycles != 0) delay_cycles(cycles);
}
