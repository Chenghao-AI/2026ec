## Example Summary

NTC Temperature Sampling Example with ADC0 Ch2.

## Peripherals & Pin Assignments

| Peripheral | Pin | Function |
| --- | --- | --- |
| GPIOA | PA0 | Standard Output-LED |
| U0RX | PA22 | UART RX on CoreBoard |
| U0TX | PA23 | UART TX on CoreBoard |
| ADC0 CH2 | PA25 | ADC0 CH2 Connect to NTC Circuit |
| SYSCTL | --- | --- |
| EVENT | --- | --- |

## Example Usage
Compile, load and run the example.  
LED on CoreBoard will toggle, and ADC Result print to UART terminal.  
