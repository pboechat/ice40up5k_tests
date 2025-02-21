# image_streaming_test

Displays an image streamed over UART on an ILI9341 TFT display.

# How to stream an image

1. Run `image_streaming`' install script

  eg, 
  ```
  > <ice40up5k_tests>/image_streaming_test/tools/image_streaming/install.sh
  ```

2. Activate the virtual environment created by the install script

  eg,
  ```
  > source <ice40up5k_tests>/image_streaming_test/tools/image_streaming/.venv/activate
  ```

3. Run the `send_image` console app
  
  eg,
  ```
  (.venv) > send_image -f '<filename>'