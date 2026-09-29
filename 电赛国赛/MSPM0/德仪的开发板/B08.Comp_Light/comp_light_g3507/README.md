## Example Summary

NTC Temperature Sampling Example with ADC0 Ch2.

## Peripherals & Pin Assignments

| Peripheral | Pin | Function |
| --- | --- | --- |
| GPIOA | PA0 | Standard Output-LED |
| U0RX | PA11 | UART RX on CoreBoard |
| U0TX | PA10 | UART TX on CoreBoard |
| COMP0 IN- | PA27 | Connect to the Signal Input |
| COMP0 OUT | PA7 | Connect to the Signal Output |
| SYSCTL | --- | --- |
| EVENT | --- | --- |

## Example Usage
Compile, load and run the example.  
LED on CoreBoard will toggle, and The Signal In/Out through Analog Comparator.  
