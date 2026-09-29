## Example Summary

CA-TUBE-4 whll Display from 0x1234, and Add ONE while once key pressed.

## Peripherals & Pin Assignments

| Peripheral | Pin | Function |
| --- | --- | --- |
| GPIOA | PA0 | Standard Output-LED On Core Board|
| GPIOA | PA8 | Connect to One Key By Dupont Line |
| GPIOA | PA22 | Connect between PA2 and CA-Tube Digit DP Input |
| GPIOA | PA21 | Connect between PA2 and CA-Tube Digit G Input |
| GPIOA | PA18 | Connect between PA2 and CA-Tube Digit F Input |
| GPIOA | PA17 | Connect between PA2 and CA-Tube Digit E Input |
| GPIOA | PA16 | Connect between PA2 and CA-Tube Digit D Input |
| GPIOA | PA15 | Connect between PA2 and CA-Tube Digit C Input |
| GPIOA | PA14 | Connect between PA2 and CA-Tube Digit B Input |
| GPIOA | PA13 | Connect between PA2 and CA-Tube Digit A Input |
| GPIOA | PB6 | Connect between PA2 and CA-Tube Digit 0 Input |
| GPIOA | PB7 | Connect between PA2 and CA-Tube Digit 1 Input |
| GPIOA | PB8 | Connect between PA2 and CA-Tube Digit 2 Input |
| GPIOA | PB9 | Connect between PA2 and CA-Tube Digit 3 Input |
| TIMG0 | Periodic Down Counting | Generate Interrupt per 5ms |
| SYSCTL | --- | --- |
| EVENT | --- | --- |

## Example Usage
Compile, load and run the example.
CA-TUBE will display 0x1234, and add 1 due to One Key Pressed.
