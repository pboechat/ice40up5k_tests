import serial
import time
from argparse import ArgumentParser
import sys
from PIL import Image


_DEFAULT_PORT = 'COM3' if sys.platform.startswith('win') else '/dev/ttyUSB0'    # windows: 'COM3', linux/mac: '/dev/ttyUSB0'
_DEFAULT_BAUD_RATE = 115_200                                                      # match the baud of the UART receiver
_IMAGE_WIDTH = 40
_IMAGE_HEIGHT = 30
_ACK = 0b10101010.to_bytes(1, byteorder='big')


def _to_str(a: bytes) -> str:
    return ' '.join(f'b{b:08b}' for b in a)


def main():
    parser = ArgumentParser()
    parser.add_argument('-p', '--port', type=str, required=False, default=_DEFAULT_PORT)
    parser.add_argument('-b', '--baud-rate', type=int, required=False, default=_DEFAULT_BAUD_RATE)
    parser.add_argument('-f', '--filename', type=str, required=True)
    parser.add_argument('-v', '--verbose', action='store_true', required=False)
    args = parser.parse_args()
    
    try:
        img = Image.open(args.filename)
        img = img.resize((_IMAGE_WIDTH, _IMAGE_HEIGHT), Image.BILINEAR)
        img = img.convert('RGB')

        with serial.Serial(args.port, args.baud_rate, timeout=1) as serial_port:
            def _wait_for_ack():
                response_data = serial_port.read()
                if response_data != _ACK:
                    raise RuntimeError(f'response is not an ACK (input={_to_str(response_data)})')
            
            serial_port.write(_ACK)  # start transaction by sending an ACK
            serial_port.flush()
            
            pixels = img.load()
            for y in range(_IMAGE_HEIGHT):
                for x in range(_IMAGE_WIDTH):
                    r, g, b = pixels[x, y]
                    
                    r = r * 31 // 255
                    g = g * 63 // 255
                    b = b * 31 // 255
                    
                    r5g6b5_data = (r << 11 | g << 5 | b).to_bytes(2, byteorder='big')
                    
                    if args.verbose:
                        print(f'pixel {x},{y}', end='')
                    
                    serial_port.write(r5g6b5_data[:1])
                    serial_port.flush()
                    _wait_for_ack()
                    if args.verbose:
                        print('.', end='')
                        
                    serial_port.write(r5g6b5_data[1:])
                    serial_port.flush()
                    _wait_for_ack()
                    if args.verbose:
                        print('.')
            
        print('image sent successfully')
        sys.exit(0)
    except RuntimeError as e:
        print()
        print(e)
        sys.exit(-1)


if __name__ == "__main__":
    main()
