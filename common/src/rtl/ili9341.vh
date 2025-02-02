`ifndef ILI9341_VH
`define ILI9341_VH

/****************************
 *  From ILI9341 datasheet  *
 ****************************/

// d/c bits
`define DATA_BIT                1'b0
`define COMMAND_BIT             1'b1

// commands
`define SW_RESET_CMD            8'h01
`define SLEEP_OUT_CMD           8'h11
`define SET_PXL_FMT_CMD         8'h3a
`define MEM_ACC_CTR_CMD         8'h36
`define DISPLAY_ON_CMD          8'h29
`define SET_COL_ADDR_CMD        8'h2a
`define SET_PAGE_ADDR_CMD       8'h2b
`define MEM_WRITE_CMD           8'h2c
`define READ_DISPLAY_ID_CMD     8'h04

// pixel formats
`define RGB565                  8'h55 // 16-bit RGB565

`endif