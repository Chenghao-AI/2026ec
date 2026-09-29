# Spectrum 数组可视化调试

这套工具直接通过 ST-Link/GDB 读取 `g_spectrum_points`，不占用连接陶晶驰屏幕的 USART1。

## 第一次使用

1. 在 STM32CubeIDE 中以 Debug 方式启动工程。
2. 在 `main.c` 的 `Spectrum_ConvertRawVoltageToAmplitude()` 调用之后设置断点，推荐断在当前第 156 行。
3. 继续运行，等一次扫频完成并停在断点。
4. 打开 **Debugger Console**，注意不是普通 Console。
5. 在 Debugger Console 输入下面这一条命令（整行粘贴后按一次回车）：

   ```gdb
   dump binary memory D:/spectrum_snapshot.bin &g_spectrum_points[0] &g_spectrum_points[1201]
   ```

6. `D:` 盘根目录会生成 `D:/spectrum_snapshot.bin`。这里刻意使用不含空格的路径，避免CubeIDE Debugger Console把文件名拆成多个表达式。
7. 用浏览器打开 `Tools/spectrum_viewer.html`，把这个 bin 文件拖进去或通过文件选择框打开。

以后每次重新测量，只需要停在断点后再次执行这条 `dump binary memory` 命令，然后在页面中重新选择快照。

也可以选择加载预设的GDB命令。注意工具位于桌面工程副本，而当前CubeIDE打开的是 `D:/STM32HALProject/Electronic Competition`，因此必须使用绝对路径，并且两条命令要分别执行：

```gdb
source D:/Users/Desktop/Electronic\ Competition/Tools/spectrum_dump.gdb
spectrum-dump
```

## 页面显示内容

- 第一张图：ADC原始值和AD8307输出电压。
- 第二张图：固件当前换算得到的幅值。
- 鼠标移动到曲线上可查看任意频点的本振、输入频率、ADC、电压和幅值。
- 红色圆点：按照固件当前规则找到的候选峰。
- 菱形点：按照固件当前规则选出的基波和谐波。
- 阈值、峰最小距离和谐波容差可以在电脑端实时调整，不需要重新烧写固件。
- “导出 CSV”可把完整1201点数据交给 Excel、Origin、MATLAB 或 Python继续分析。

## 二进制结构约定

工具按 STM32F407 当前编译布局解析，每点20字节：

```text
uint32_t lo_frequency_hz
uint32_t input_frequency_hz
uint16_t adc_raw
uint16_t padding
float    detector_voltage_v
float    amplitude_mv
```

如果以后修改 `SpectrumPoint_t` 字段或编译布局，需要同步修改页面中的 `RECORD_BYTES` 和解析逻辑。
