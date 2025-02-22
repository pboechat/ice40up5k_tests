# uart_test

Controls the LED via commands sent over UART.

# How to send commands

1. Run `uart_test_tools`' install script

  eg, 
  ```
  > <ice40up5k_tests>/uart_test/tools/uart_test_tools/install.sh
  ```

2. Activate the virtual environment created by the install script

  eg,
  ```
  > source <ice40up5k_tests>/uart_test/tools/uart_test_tools/.venv/activate
  ```

3. Run the `send_command` console app
  
  eg,
  ```
  (.venv) > send_command -c '<command>'
  ```

## Commands

### SET

Sets the color of the LED. You must specify 0 or 1 for each color channel (R, G, and B).

eg, set the color of the LED to red
```
(.venv) > send_command -c 'SET,1,0,0'
``` 

### TOGGLE

Toggles the channels of the color currently set in the LED.

eg, toggle the green channel
```
(.venv) > send_command -c 'TOGGLE,0,1,0'
``` 

### NOP
No-op.


### DEBUG 

Sends a byte to be interpreted as a command by the decoder.

eg, send zero (no-op)
```
(.venv) > send_command -c 'DEBUG,0,0,0,0,0,0,0,0'
```
