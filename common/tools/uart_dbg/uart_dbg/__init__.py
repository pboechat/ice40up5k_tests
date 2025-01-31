import serial
from argparse import ArgumentParser
import sys


_DEFAULT_PORT = 'COM3' if sys.platform.startswith('win') else '/dev/ttyUSB0'    # windows: 'COM3', linux/mac: '/dev/ttyUSB0'
_DEFAULT_BAUD_RATE = 9600                                                       # match the baud of the UART receiver

def main():
    parser = ArgumentParser()
    parser.add_argument('-p', '--port', type=str, required=False, default=_DEFAULT_PORT)
    parser.add_argument('-b', '--baud-rate', type=int, required=False, default=_DEFAULT_BAUD_RATE)
    args = parser.parse_args()
    
    try:
        with serial.Serial(args.port, args.baud_rate, timeout=1) as ser:
            print(f"Listening on {args.port} at {args.baud_rate} baud... (Press Ctrl+C to exit)")
            while True:
                data = ser.read(1)
                if data:
                    binary_data = ' '.join(f'{byte:08b}' for byte in data)
                    print(binary_data, flush=True)
    except serial.SerialException as e:
        print(f"Serial error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nInterrupted by user. Exiting...", file=sys.stderr)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
