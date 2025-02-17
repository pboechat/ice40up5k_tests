# display_test

Displays the rainbow colors in a ILI9341 TFT display connected to the board via SPI.

## initialization sequence

TODO

## display status

After the initialization sequence, the design sends the display status via the UART debug interface (MSB-first).

The display status is 32-bit long. Here is how you interpret it:

| bit(s) | description            | value(s)                              |
|--------|------------------------|---------------------------------------|
| 31     | voltage boost status   | 0 = OFF, 1 = ON                       |
| 30     | row address order      | 0 = top to bottom, 1 = bottom to top  |
| 29     | column address order   | 0 = left to right, 1 = right to left  |
| 28     | row/column exchange    | 0 = normal, 1 = reverse               |
| 27     | vertical refresh       | 0 = top to bottom, 1 = bottom to top  |
| 26     | BGR/RGB                | 0 = BGR, 1 = RGB                      |
| 25     | horizontal refresh     | 0 = left to right, 1 = right to left  |
| 24     | unused                 | -                                     |
| 23     | unused                 | -                                     |
| 22-20  | color depth            | 101 = 16-bit, 110 = 18-bit            |
| 19     | idle mode              | 0 = OFF, 1 = ON                       |
| 18     | partial mode           | 0 = OFF, 1 = ON                       |
| 17     | sleep mode             | 0 = OFF, 1 = ON                       |
| 16     | normal mode            | 0 = OFF, 1 = ON                       |
| 15     | vertical scrolling     | 0 = OFF, 1 = ON                       |
| 14     | unused                 | -                                     |
| 13     | inversion              | 0                                     |
| 12     | all pixels ON          | 0                                     |
| 11     | all pixels OFF         | 0                                     |
| 10     | display ON/OFF         | 0 = OFF, 1 = ON                       |
| 9      | tearing effect ON/OFF  | 0 = OFF, 1 = ON                       |
| 8-6    | gamma curve            | 000 = GC0,...                         |
| 5      | tearing effect mode    | 0 = v-blank, 1 = h-and-b-blank        |
| 4      | unused                 | -                                     |
| 3      | unused                 | -                                     |
| 2      | unused                 | -                                     |
| 1      | unused                 | -                                     |
| 0      | unused                 | -                                     |

