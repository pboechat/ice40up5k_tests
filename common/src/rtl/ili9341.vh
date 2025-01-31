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

// command parameter count
`define SW_RESET_CMD_PCNT       0
`define SLEEP_OUT_CMD_PCNT      0
`define SET_PXL_FMT_CMD_PCNT    1
`define MEM_ACC_CTR_CMD_PCNT    1
`define DISPLAY_ON_CMD_PCNT     0
`define SET_COL_ADDR_CMD_PCNT   4
`define SET_PAGE_ADDR_CMD_PCNT  4

// pixel formats
`define RGB565                  8'h55 // 16-bit RGB565