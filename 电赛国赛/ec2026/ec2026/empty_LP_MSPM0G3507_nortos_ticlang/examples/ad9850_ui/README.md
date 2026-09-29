# AD9850 UI 独立入口

本目录的 `main.c` 是 AD9850 示波器联调入口，不替换工程根目录的通用 `empty.c`。

使用时：

1. 在 CCS 中把根目录 `empty.c` 设为 **Exclude from Build**；
2. 把本目录 `main.c`、`optional/rabi_gpio_serial.c`、`optional/rabi_ad9850.c`
   加入当前 Build；
3. 按 `optional/AD9850_UI_QUICKSTART.md` 配置 GPIO、接线和电平转换；
4. 结束测试后重新包含根目录 `empty.c`，并排除本文件即可恢复模板入口。

