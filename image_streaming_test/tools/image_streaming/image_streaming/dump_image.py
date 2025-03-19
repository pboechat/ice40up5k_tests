from argparse import ArgumentParser
import sys
from PIL import Image


_IMAGE_WIDTH = 40
_IMAGE_HEIGHT = 30

def _to_str(a: bytes) -> str:
    return '\n'.join(f'{b:08b}' for b in a)


def main():
    parser = ArgumentParser()
    parser.add_argument('-i', '--input', type=str, required=True)
    parser.add_argument('-o', '--output', type=str, required=True)
    args = parser.parse_args()
    
    try:
        img = Image.open(args.input)
        img = img.resize((_IMAGE_WIDTH, _IMAGE_HEIGHT), Image.BILINEAR)
        img = img.convert('RGB')
            
        pixels = img.load()
        r5g6b5_data = bytearray()
        for y in range(_IMAGE_HEIGHT):
            for x in range(_IMAGE_WIDTH):
                r, g, b = pixels[x, y]
                
                r = r * 31 // 255
                g = g * 63 // 255
                b = b * 31 // 255
                
                r5g6b5_data += (r << 11 | g << 5 | b).to_bytes(2, byteorder='big')
            
        open(args.output, 'wt').write(_to_str(r5g6b5_data))

        print('image dumped')
        sys.exit(0)
    except RuntimeError as e:
        print()
        print(e)
        sys.exit(-1)


if __name__ == "__main__":
    main()
