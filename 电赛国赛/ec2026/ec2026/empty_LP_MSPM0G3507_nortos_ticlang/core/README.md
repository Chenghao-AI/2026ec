# core：比赛工程的常驻核心模块

这个目录存放当前 UI 工程每次都会使用、并应保持稳定的基础能力。`empty.c`
只负责组合这些模块，具体驱动和通用逻辑留在这里，避免入口文件越写越大。

## 模块清单

- `rabi_system.*`：系统初始化和主循环入口；
- `rabi_event.*`：固定容量事件队列；
- `rabi_tick.*`：基于 SysTick 的软件定时器；
- `rabi_oled.*`、`rabi_font.*`：OLED 驱动和字库；
- `rabi_ui.*`：菜单与参数编辑 UI；
- `rabi_keypad.*`：4x4 矩阵键盘扫描与消抖；
- `rabi_err.h`、`rabi_utils.h`：公共错误码和工具宏。

## 依赖方向

建议始终保持下面的单向关系，避免比赛现场出现循环依赖：

```text
empty.c / 业务代码
        |
        +-- UI -------- OLED -------- Font
        +-- Keypad
        +-- Event
        +-- Tick
        `-- System
```

根目录文件引用核心头文件时写成 `#include "core/rabi_xxx.h"`；`core` 目录内部
模块互相引用时继续使用 `#include "rabi_xxx.h"`，这样同目录依赖最直观。

新增一个确定会长期使用的输入、显示或调度模块时放在这里。某个具体比赛器件的
驱动先放 `optional/`，确认成为工程固定组成部分后再迁入，减少核心层变动。
