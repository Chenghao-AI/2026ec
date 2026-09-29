/* Rabi 备用模块：MSPM0 硬件 I2C Controller 阻塞事务实现。 */
#include "rabi_i2c.h"
#include "ti_msp_dl_config.h"

#define RABI_I2C_MAX_TRANSFER_LENGTH 4095U

static rabi_err_t prepare_transfer(const rabi_i2c_t *i2c);
static rabi_err_t flush_tx_fifo(const rabi_i2c_t *i2c);
static rabi_err_t flush_rx_fifo(const rabi_i2c_t *i2c);
static rabi_err_t wait_controller_idle(const rabi_i2c_t *i2c);
static rabi_err_t wait_transfer_complete(const rabi_i2c_t *i2c);
static rabi_err_t check_controller_error(const rabi_i2c_t *i2c);
static rabi_err_t write_phase(
    const rabi_i2c_t *i2c,
    uint8_t target_address,
    const uint8_t *data,
    size_t length,
    bool send_stop);
static rabi_err_t read_phase(
    const rabi_i2c_t *i2c,
    uint8_t target_address,
    uint8_t *data,
    size_t length);

rabi_err_t rabi_i2c_init(const rabi_i2c_t *i2c)
{
    if (i2c == NULL || i2c->instance == NULL || i2c->poll_limit == 0 ||
        i2c->start_delay_cycles == 0)
    {
        return RABI_ERR_INVALID_ARG;
    }

    /* IOMUX、开漏、电源、时钟和 SCL 速率均应由 SYSCFG_DL_init() 完成。 */
    if (!DL_I2C_isPowerEnabled(i2c->instance) ||
        !DL_I2C_isControllerEnabled(i2c->instance))
    {
        return RABI_ERR_INVALID_STATE;
    }

    return RABI_ERR_OK;
}

rabi_err_t rabi_i2c_write(
    const rabi_i2c_t *i2c,
    uint8_t target_address,
    const uint8_t *data,
    size_t length)
{
    rabi_err_t err = rabi_i2c_init(i2c);
    if (err != RABI_ERR_OK) return err;

    return write_phase(i2c, target_address, data, length, true);
}

rabi_err_t rabi_i2c_read(
    const rabi_i2c_t *i2c,
    uint8_t target_address,
    uint8_t *data,
    size_t length)
{
    rabi_err_t err = rabi_i2c_init(i2c);
    if (err != RABI_ERR_OK) return err;

    return read_phase(i2c, target_address, data, length);
}

rabi_err_t rabi_i2c_write_read(
    const rabi_i2c_t *i2c,
    uint8_t target_address,
    const uint8_t *tx,
    size_t tx_length,
    uint8_t *rx,
    size_t rx_length)
{
    rabi_err_t err = rabi_i2c_init(i2c);
    if (err != RABI_ERR_OK) return err;
    if (tx == NULL || rx == NULL || tx_length == 0 || rx_length == 0)
    {
        return RABI_ERR_INVALID_ARG;
    }

    /* 第一阶段禁止 STOP，所以第二阶段的 START 会成为 repeated START。 */
    err = write_phase(i2c, target_address, tx, tx_length, false);
    if (err != RABI_ERR_OK) return err;

    return read_phase(i2c, target_address, rx, rx_length);
}

static rabi_err_t prepare_transfer(const rabi_i2c_t *i2c)
{
    /*
     * IDLE 表示本 Controller 当前没有执行传输。repeated-start 的两阶段之间，
     * Controller 可为 IDLE，但 BUSY_BUS 仍为 1；这里故意不等待 BUSY_BUS 清零。
     */
    rabi_err_t err = wait_controller_idle(i2c);
    if (err != RABI_ERR_OK) return err;

    err = flush_tx_fifo(i2c);
    if (err != RABI_ERR_OK) return err;
    return flush_rx_fifo(i2c);
}

static rabi_err_t flush_tx_fifo(const rabi_i2c_t *i2c)
{
    uint32_t remaining = i2c->poll_limit;

    DL_I2C_startFlushControllerTXFIFO(i2c->instance);
    while (!DL_I2C_isControllerTXFIFOEmpty(i2c->instance))
    {
        if (--remaining == 0)
        {
            DL_I2C_stopFlushControllerTXFIFO(i2c->instance);
            return RABI_ERR_TIMEOUT;
        }
    }
    DL_I2C_stopFlushControllerTXFIFO(i2c->instance);
    return RABI_ERR_OK;
}

static rabi_err_t flush_rx_fifo(const rabi_i2c_t *i2c)
{
    uint32_t remaining = i2c->poll_limit;

    DL_I2C_startFlushControllerRXFIFO(i2c->instance);
    while (!DL_I2C_isControllerRXFIFOEmpty(i2c->instance))
    {
        if (--remaining == 0)
        {
            DL_I2C_stopFlushControllerRXFIFO(i2c->instance);
            return RABI_ERR_TIMEOUT;
        }
    }
    DL_I2C_stopFlushControllerRXFIFO(i2c->instance);
    return RABI_ERR_OK;
}

static rabi_err_t wait_controller_idle(const rabi_i2c_t *i2c)
{
    uint32_t remaining = i2c->poll_limit;
    while ((DL_I2C_getControllerStatus(i2c->instance) &
            DL_I2C_CONTROLLER_STATUS_IDLE) == 0)
    {
        if (--remaining == 0) return RABI_ERR_TIMEOUT;
    }
    return RABI_ERR_OK;
}

static rabi_err_t wait_transfer_complete(const rabi_i2c_t *i2c)
{
    uint32_t remaining = i2c->poll_limit;
    while ((DL_I2C_getControllerStatus(i2c->instance) &
            DL_I2C_CONTROLLER_STATUS_BUSY) != 0)
    {
        rabi_err_t err = check_controller_error(i2c);
        if (err != RABI_ERR_OK) return err;
        if (--remaining == 0) return RABI_ERR_TIMEOUT;
    }

    return check_controller_error(i2c);
}

static rabi_err_t check_controller_error(const rabi_i2c_t *i2c)
{
    uint32_t status = DL_I2C_getControllerStatus(i2c->instance);
    if ((status & DL_I2C_CONTROLLER_STATUS_ARBITRATION_LOST) != 0)
    {
        return RABI_ERR_BUSY;
    }
    if ((status & DL_I2C_CONTROLLER_STATUS_ERROR) != 0)
    {
        /* 包含目标地址 NACK、数据 NACK 等；MSR 没有在此层细分成稳定错误码。 */
        return RABI_ERR_FAIL;
    }
    return RABI_ERR_OK;
}

static rabi_err_t write_phase(
    const rabi_i2c_t *i2c,
    uint8_t target_address,
    const uint8_t *data,
    size_t length,
    bool send_stop)
{
    if (target_address > 0x7fU || data == NULL || length == 0 ||
        length > RABI_I2C_MAX_TRANSFER_LENGTH)
    {
        return RABI_ERR_INVALID_ARG;
    }

    rabi_err_t err = prepare_transfer(i2c);
    if (err != RABI_ERR_OK) return err;

    /* 启动前先尽量填满 FIFO，剩余字节在硬件移出数据时继续轮询补入。 */
    size_t sent = DL_I2C_fillControllerTXFIFO(
        i2c->instance, data, (uint16_t)length);

    DL_I2C_startControllerTransferAdvanced(i2c->instance,
        target_address,
        DL_I2C_CONTROLLER_DIRECTION_TX,
        (uint16_t)length,
        DL_I2C_CONTROLLER_START_ENABLE,
        send_stop ? DL_I2C_CONTROLLER_STOP_ENABLE :
                    DL_I2C_CONTROLLER_STOP_DISABLE,
        DL_I2C_CONTROLLER_ACK_DISABLE);

    /* MSPM0 官方轮询示例同样在启动事务后保留这段延时。 */
    delay_cycles(i2c->start_delay_cycles);

    uint32_t remaining = i2c->poll_limit;
    while (sent < length)
    {
        err = check_controller_error(i2c);
        if (err != RABI_ERR_OK) return err;

        if (!DL_I2C_isControllerTXFIFOFull(i2c->instance))
        {
            DL_I2C_transmitControllerData(i2c->instance, data[sent++]);
            remaining = i2c->poll_limit; /* 有进展就重新给下一个字节完整预算。 */
        }
        else if (--remaining == 0)
        {
            return RABI_ERR_TIMEOUT;
        }
    }

    /* BUSY 清零表示本阶段长度已经完成；无 STOP 时 BUSY_BUS 可以继续保持。 */
    return wait_transfer_complete(i2c);
}

static rabi_err_t read_phase(
    const rabi_i2c_t *i2c,
    uint8_t target_address,
    uint8_t *data,
    size_t length)
{
    if (target_address > 0x7fU || data == NULL || length == 0 ||
        length > RABI_I2C_MAX_TRANSFER_LENGTH)
    {
        return RABI_ERR_INVALID_ARG;
    }

    rabi_err_t err = prepare_transfer(i2c);
    if (err != RABI_ERR_OK) return err;

    DL_I2C_startControllerTransferAdvanced(i2c->instance,
        target_address,
        DL_I2C_CONTROLLER_DIRECTION_RX,
        (uint16_t)length,
        DL_I2C_CONTROLLER_START_ENABLE,
        DL_I2C_CONTROLLER_STOP_ENABLE,
        DL_I2C_CONTROLLER_ACK_DISABLE);
    delay_cycles(i2c->start_delay_cycles);

    size_t received = 0;
    uint32_t remaining = i2c->poll_limit;
    while (received < length)
    {
        err = check_controller_error(i2c);
        if (err != RABI_ERR_OK) return err;

        if (!DL_I2C_isControllerRXFIFOEmpty(i2c->instance))
        {
            data[received++] = DL_I2C_receiveControllerData(i2c->instance);
            remaining = i2c->poll_limit;
        }
        else if (--remaining == 0)
        {
            return RABI_ERR_TIMEOUT;
        }
    }

    return wait_transfer_complete(i2c);
}
