import serial
import time
from argparse import ArgumentParser
import sys
from enum import Enum
from typing import List
from dataclasses import dataclass


_DEFAULT_PORT = 'COM3' if sys.platform.startswith('win') else '/dev/ttyUSB0'    # windows: 'COM3', linux/mac: '/dev/ttyUSB0'
_DEFAULT_BAUD_RATE = 9600                                                       # match the baud of the UART receiver


def _to_bytes(a: str | List[int]) -> bytes:
    if isinstance(a, str):
        if not a.startswith('b') or len(a) != 9:
            raise ValueError('string must be in the form \'bxxxxxxxx')
        return bytes([int(a[1:], 2)])
    elif isinstance(a, list):
        return sum(e << (len(a) - c - 1) for c, e in enumerate(a)).to_bytes()
    else:
        raise ValueError('invalid argument')


def _to_str(a: bytes) -> str:
    return ' '.join(f'b{b:08b}' for b in a)


def _or_bytes(a: bytes, b: bytes) -> bytes:
    return bytes(ax | bx for ax, bx in zip(a, b))


def _and_bytes(a: bytes, b: bytes) -> bytes:
    return bytes(ax & bx for ax, bx in zip(a, b))


class Op(Enum):
    SET = ('SET', 3, _to_bytes('b10000000'))
    TOGGLE = ('TOGGLE', 3, _to_bytes('b01000000'))
    NOP = ('NOP', 0, _to_bytes('b00100000'))
    DEBUG = ('DEBUG', 8, _to_bytes('b00000000'))

    @property
    def mask(self) -> bytes:
        return self.value[2]

    @property
    def arg_count(self) -> int:
        return self.value[1]

    def __str__(self):
        return self.value[0]


@dataclass
class Command:
    op: Op
    args: List[int]

    def encode(self):
        return _or_bytes(self.op.mask, _to_bytes(self.args))

    @staticmethod
    def parse(command_str: str) -> 'Command':
        tokens = [token.strip() for token in command_str.split(',')]
    
        op = Op.__members__.get(tokens[0], None)

        if op is None:
            raise RuntimeError(f'unknown command: {command_str}')

        args = [int(arg.strip() != '0') for arg in tokens[1:]]

        if len(args) != op.arg_count:
            raise RuntimeError(f'invalid argument count for {op} (expected: {op.arg_count}, got: {len(args)})')

        return Command(op=op, args=args)
    
    def __repr__(self):
        return f'{{op={self.op}, args={",".join(str(arg) for arg in self.args)}}}'


def _send_data(port: str, baud_rate: int, data: bytes) -> bytes:
    try:
        # open the serial port
        with serial.Serial(port, baud_rate, timeout=1) as serial_port:
            # send the data
            serial_port.write(data)
            
            time.sleep(0.1)

            if serial_port.in_waiting > 0:                       # check if data is available
                return serial_port.read(serial_port.in_waiting)  # read all available data
            else:
                return bytes()
    except serial.SerialException as e:
        raise RuntimeError('error with the serial port while sending data', e)
    except Exception as e:
        raise RuntimeError('unexpected error while sending data', e)


def main():
    parser = ArgumentParser()
    parser.add_argument('-p', '--port', type=str, required=False, default=_DEFAULT_PORT)
    parser.add_argument('-b', '--baud-rate', type=int, required=False, default=_DEFAULT_BAUD_RATE)
    parser.add_argument('-c', '--command', type=str, required=True)
    parser.add_argument('-v', '--verbose', action='store_true', required=False)
    args = parser.parse_args()
    
    try:
        command = Command.parse(args.command)
        if args.verbose:
            print(f'parsed command: {command}')
        data = command.encode()
        if args.verbose:
            print(f'encoded command: {_to_str(data)}')
        response =_send_data(args.port, args.baud_rate, data)
        if args.verbose:
            print(f'response: {_to_str(response)}')
        if _and_bytes(response, _to_bytes('b11111000')) != b'\x00':
            if args.verbose:
                print(f'failed to run command (error code: {_to_str(_and_bytes(response, _to_bytes("b00000111")))})')
            sys.exit(1)
        else:
            if args.verbose:
                print('command ran successfully')
            sys.exit(0)
    except RuntimeError as e:
        print(e)
        sys.exit(-1)


if __name__ == "__main__":
    main()
