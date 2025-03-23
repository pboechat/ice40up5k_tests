# iCE40UP5K-B-EVN tests

Multiple test designs for the iCE40UP5K-B-EVN board. 

Designs written in Verilog and built with [yosys](https://github.com/YosysHQ/yosys) and [nextprn](https://github.com/YosysHQ/nextpnr).

## Pre-requisites

For building the designs:
```
make
yosys
nextpnr-ice40
fpga-icestorm
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

Cycles through RGB on the LED.

### [uart_test](uart_test)

Controls the LED via commands sent over UART.

### [display_test](display_test)

Displays the rainbow colors on an ILI9341 TFT display connected to the board via SPI.

### [image_streaming_test](image_streaming_test)

Displays an image streamed over UART on an ILI9341 TFT display.


*note*: All designs are in reset mode until right-most switch (49A) is ON.
