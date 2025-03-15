`ifndef SPI_MASTER_CONTROLLER_V
`define SPI_MASTER_CONTROLLER_V

module spi_master_controller #(
    parameter CLK_DIVIDER = 1
) (
    input wire clk,
    input wire reset,
    input wire start,
    input wire[7:0] data_in,
    input wire miso,
    output reg[7:0] data_out,
    output reg busy,
    output reg cs,
    output reg sck,
    output reg mosi
);
    reg[$clog2(CLK_DIVIDER)-1:0] timer;
    reg clk_phase; // 0 = falling edge, 1 = rising edge
    reg sck_tick; // pulse on every SCK edge

    always @(posedge clk) 
    begin
        if (reset) 
        begin
            timer <= '0;
            sck <= 1'b0;
            clk_phase <= 1'b0;
            sck_tick <= 1'b0;
        end 
        else 
        begin
            if (timer == (CLK_DIVIDER - 1)) 
            begin
                timer <= 1'b0;
                sck <= ~sck;
                clk_phase <= ~clk_phase;
                sck_tick <= 1'b1;
            end 
            else 
            begin
                timer <= timer + 1;
                sck_tick <= 1'b0;
            end
        end
    end

    // states
    localparam IDLE             = 3'b000;
    localparam TRANSACTIONING   = 3'b001;
    localparam RECEIVING        = 3'b010;
    localparam DONE             = 3'b011;
    localparam LAST_STATE       = DONE;

    reg[$clog2(LAST_STATE):0] state;
    reg[7:0] spi_data;
    reg[2:0] bit_index;

    always @(posedge clk) 
    begin
        if (reset) 
        begin
            state <= IDLE;
            busy <= 1'b0;
            cs <= 1'b1;
            data_out <= 1'b0;
            bit_index <= 3'd0;
            spi_data <= 8'h00;
            mosi <= 1'b1;
        end 
        else if (sck_tick) 
        begin
            case (state)
                IDLE: 
                begin
                    if (start) 
                    begin
                        busy <= 1'b1;
                        cs <= 1'b0;
                        spi_data <= data_in;
                        bit_index <= 3'd7;
                        mosi <= data_in[7];
                        state <= TRANSACTIONING;
                    end
                    else
                    begin
                        busy <= 1'b0;
                        cs <= 1'b1;
                    end
                end
                TRANSACTIONING:
                begin
                    if (clk_phase)
                    begin
                        // rising edge: sample MISO and store the bit.
                        spi_data[bit_index] <= miso;
                    end 
                    else
                    begin
                        // falling edge: if not done, update MOSI with the next bit.
                        if (~|bit_index) 
                        begin
                            state <= DONE;
                        end 
                        else 
                        begin
                            mosi <= spi_data[bit_index - 1];
                            bit_index <= bit_index - 1;
                        end
                    end
                end
                DONE: 
                begin
                    cs <= 1'b1;
                    busy <= 1'b0;
                    data_out <= spi_data;
                    state <= IDLE;
                end
                default: 
                begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

`endif