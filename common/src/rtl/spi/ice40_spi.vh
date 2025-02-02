`ifndef ICE40_SPI_VH
`define ICE40_SPI_VH

/************************************************************ 
 *  From Advanced iCE40 I2C and SPI Hardened IP User Guide  *
 ************************************************************/

// registers
`define SPICR0    4'b1000       // SPI Control Register 0
`define SPICR1    4'b1001       // SPI Control Register 1
`define SPICR2    4'b1010       // SPI Control Register 2
`define SPIBR     4'b1011       // SPI Baud Rate Register
`define SPISR     4'b1100       // SPI Status Register
`define SPITXDR   4'b1101       // SPI Transmit Data Register
`define SPICSR    4'b1111       // SPI Chip Select Mask For Master

`endif