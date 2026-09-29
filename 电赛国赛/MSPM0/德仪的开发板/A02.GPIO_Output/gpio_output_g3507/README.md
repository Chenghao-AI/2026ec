## Example Summary

Flashing LED, LED-RGB on Base Board while using GPIO as OUTPUTs.

## Peripherals & Pin Assignments(Need Dupont Line Connecting)

| Peripheral | Pin | Function |
| --- | --- | --- |
| GPIOA | PA0 | LED on CoreBoard |
| GPIOA | PA10 | NEED Connect PA10(J6) to LED on Base Board (J10)|
| GPIOA | PA11 | NEED Connect PA11(J6) to LED-R on Base Board (J10) |
| GPIOA | PA12 | NEED Connect PA12(J6) to LED-G on Base Board (J10) |
| GPIOA | PA13 | NEED Connect PA13(J6) to LED-B on Base Board (J10) |

## Example Usage
Compile, load and run the example.
RGB LEDs and LED on Base Board will toggle per Seconds.
Green LED toggle per 0.5 Seconds.
