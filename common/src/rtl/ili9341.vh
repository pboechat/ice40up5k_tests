`ifndef ILI9341_VH
`define ILI9341_VH

/****************************
 *  From ILI9341 datasheet  *
 ****************************/

// d/c bits
`define COMMAND_BIT             1'b0
`define DATA_BIT                1'b1

// commands
`define SW_RESET_CMD            8'h01
`define READ_DISPLAY_STATUS_CMD 8'h09
`define SLPOUT_CMD              8'h11
`define DISPON_CMD              8'h29
`define CASET_CMD               8'h2a
`define PASET_CMD               8'h2b
`define MEMWRITE_CMD            8'h2c
`define MADCTL_CMD              8'h36
`define COLMOD_CMD              8'h3a

// pixel formats
`define RGB565                  8'h55 // 16-bit RGB565

// display status mask with all reserved bits flipped
`define INVALID_DISPLAY_STATUS  {8'b0000001, 8'b10000000, 8'b11111000, 8'b00011111}

`endif