# FPGA UART接收数据可视化调试

这套工具读取的是STM32协议解析器已经接受的数据，不读取FPGA电脑端的数据，也不占用USART1或USART2。

## 一次抓取步骤

1. 在STM32CubeIDE中重新Build，并用Debug方式启动。
2. 在函数 `FPGA_UART_DebugMeasurementReadyHook()` 上设置断点。
3. 点击继续运行，然后在串口屏上按一次时域或频域“启动”。
4. 完整结果通过CRC和格式检查后，STM32先尝试发送ACK，随后停在该断点。
5. 打开CubeIDE的 **Debugger Console**，分别执行：

   ```gdb
   source D:/Users/Desktop/Electronic\ Competition/Tools/fpga_uart_capture.gdb
   fpga-uart-capture
   ```

6. 得到文件：

   ```text
   D:/fpga_uart_snapshot.bin
   ```

7. 用浏览器打开 `Tools/fpga_uart_viewer.html`，选择上面的bin文件。
8. 查看完毕后点击继续运行；下一次测量会生成新的快照。

## 断点处可直接观察的变量

```text
g_fpga_debug_measurement
g_fpga_debug_state
g_fpga_debug_stats
```

`g_fpga_debug_state.last_ack_hal_status == 0` 表示HAL层ACK发送成功。

常用统计量：

```text
valid_frames       CRC正确的完整帧数
crc_errors         CRC错误
length_errors      Payload长度越界
format_errors      N、K、dt、频点间隔或最终长度错误
sequence_errors    返回SEQ与START的SEQ不同
uart_errors        USART2硬件错误
parser_timeouts    帧内字节间隔超过50 ms
```

## 快速判断

- 时域曲线在查看器中已经杂乱：问题位于FPGA装包或STM32-FPGA协议数据，不在串口屏绘图。
- 查看器时域曲线正确、串口屏错误：重点检查STM32到屏幕的绘图命令和坐标映射。
- 原始频谱在查看器中有明显峰值、屏幕频域为空：重点检查STM32频谱特征提取算法。
- `snapshot_counter`不增加：STM32没有接受新的完整结果帧。
- `waiting_for_result`一直为1：STM32发过START，但没有接受到匹配结果。

## 二进制布局

查看器对应当前ARM编译布局，总长度固定为24124字节。固件中使用`_Static_assert`检查关键字段偏移；若以后修改 `FPGA_MeasureResult_t`，编译会提醒同步更新查看器。
