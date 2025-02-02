`ifndef ICE40_MASTER_SPI_CONTROLLER_V
`define ICE40_MASTER_SPI_CONTROLLER_V

`include "spi/ice40_spi.vh"

module ice40_master_spi_controller #(
    parameter SPI_CLK_DIVIDER = 0
) (
    input wire clk,
    input wire reset,
    input wire tx_start,
    input wire[7:0] tx_data,
    input wire[7:0] spi_data_out,
    input wire spi_ack,
    output reg spi_rw,
    output reg[7:0] spi_reg_addr,
    output reg spi_strobe,
    output reg[7:0] spi_data_in,
    output reg tx_busy
);
    `include "functions.vh"

    // states
    localparam SET_CR0_REG          = 3'b000;
    localparam SET_CR1_REG          = 3'b001;
    localparam SET_CR2_REG          = 3'b010;
    localparam SET_BR_REG           = 3'b011;
    localparam SET_CSR_REG          = 3'b100;
    localparam IDLE                 = 3'b101;
    localparam WAITING_TO_TRANSMIT  = 3'b110;
    localparam TRANSMITTING         = 3'b111;
    localparam LAST_STATE           = TRANSMITTING;

    reg[$clog2(LAST_STATE):0] state = SET_CR0_REG;
    reg[7:0] tx_data_cpy = 0;

    always @(posedge clk)
    begin
        if (reset)
        begin
            state <= SET_CR0_REG;
            tx_busy <= 1;
            spi_rw <= 0;
            spi_reg_addr <= 0;
            spi_strobe <= 0;
            spi_data_in <= 0;
        end
        else
        begin
            case (state)
                SET_CR0_REG:
                begin
                    spi_reg_addr <= `SPICR0;
                    // idle delay count, trail delay count, lead delay count
                    spi_data_in <= {2'b00, 3'b000, 3'b000};
                    spi_strobe <= 1;
                    spi_rw <= 1;
                    if (spi_ack)
                    begin
                        spi_strobe <= 0;
                        state <= SET_CR1_REG;
                    end
                end
                SET_CR1_REG:
                begin
                    spi_reg_addr <= `SPICR1;
                    // SPI enable, wake-up enable, 0, data transm. sel. bit, 0000 
                    spi_data_in <= {1'b1, 1'b0, 1'b0, 1'b0, 4'b0000 }; 
                    spi_strobe <= 1;
                    spi_rw <= 1;
                    if (spi_ack)
                    begin
                        spi_strobe <= 0;
                        state <= SET_CR2_REG;
                    end
                end
                SET_CR2_REG:
                begin
                    spi_reg_addr <= `SPICR2;
                    // master-slave mode, master CCSPIN hold, slave dummy byte, 00, CPOL, CPHA, LSB
                    spi_data_in <= {1'b1, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 1'b0 }; 
                    spi_strobe <= 1;
                    spi_rw <= 1;
                    if (spi_ack)
                    begin
                        spi_strobe <= 0;
                        state <= SET_BR_REG;
                    end
                end
                SET_BR_REG:
                begin
                    spi_reg_addr <= `SPIBR;
                    // 00, divider
                    spi_data_in <= {2'b00, SPI_CLK_DIVIDER[5:0]}; 
                    spi_strobe <= 1;
                    spi_rw <= 1;
                    if (spi_ack)
                    begin
                        spi_strobe <= 0;
                        state <= SET_CSR_REG;
                    end
                end
                SET_CSR_REG:
                begin
                    spi_reg_addr <= `SPICSR;
                    // 0000, CS
                    spi_data_in <= {4'b0000, 4'b0001}; 
                    spi_strobe <= 1;
                    spi_rw <= 1;
                    if (spi_ack)
                    begin
                        spi_strobe <= 0;
                        tx_busy <= 0;
                        state <= IDLE;
                    end
                end
                IDLE:
                begin
                    if (tx_start)
                    begin
                        tx_data_cpy <= tx_data;
                        tx_busy <= 1;
                        state <= WAITING_TO_TRANSMIT;
                    end
                end
                WAITING_TO_TRANSMIT:
                begin
                    spi_reg_addr <= `SPISR;
                    spi_strobe <= 1;
                    spi_rw <= 0;
                    if (spi_ack) 
                    begin
                        spi_strobe <= 0;
                        // bit 4 = TRDY (transmit ready)
                        if (spi_data_out[4] == 1) 
                        begin
                            tx_busy <= 1;
                            state <= TRANSMITTING;
                        end
                    end
                end
                TRANSMITTING:
                begin
                    spi_reg_addr <= `SPITXDR;
                    spi_data_in <= tx_data_cpy;
                    spi_strobe <= 1;
                    spi_rw <= 1;
                    if(spi_ack == 1) 
                    begin
                        spi_strobe <= 0;
                        tx_busy <= 0;
                        state <= IDLE;
                    end
                end
                default:
                begin
                    state <= SET_CR0_REG;
                end
            endcase
        end
    end
endmodule

`endif