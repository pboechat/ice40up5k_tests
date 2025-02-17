# iCE40UP5K-B-EVN tests

Multiple test designs for the iCE40UP5K-B-EVN board. 

Designs written in Verilog and built with [yosys](https://github.com/YosysHQ/yosys) and [nextprn](https://github.com/YosysHQ/nextpnr).

## Pre-requisites

For building the designs:
```
make
yosys
nextpnr
iverilog (simulation-only)
```

For building the tools:
```
python3.10
python3.10-venv
python-is-python3
```

## Designs

### [led_test](led_test)

Blinks the LED in RGB at every 3 seconds.

### [uart_test](uart_test)

Implements a very simple command decoder over UART.

### [display_test](display_test)

Displays the rainbow colors in a ILI9341 TFT display connected to the board via SPI.


*note*: All designs are in reset mode until right-most switch (49A) is ON.