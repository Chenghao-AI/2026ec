## Example Summary

Led working between 3 Status: Off/On/Flashing while Pressed once Key.

## Peripherals & Pin Assignments

| Peripheral | Pin | Function |
| --- | --- | --- |
| GPIOA | PA0 | Standard Output-LED On Core Board|
| GPIOA | PA14 | Connect to One Key By Dupont Line |
| TIMG0 | Periodic Down Counting | Generate Interrupt per 500ms |
| SYSCTL | --- | --- |
| EVENT | --- | --- |

## Example Usage
Compile, load and run the example.
LED will change status in Three Type: Off/On/Flashing due to Key Pressed.
