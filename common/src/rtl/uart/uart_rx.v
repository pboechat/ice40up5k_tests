`ifndef UART_RX_V
`define UART_RX_V

module uart_rx #(
    parameter BAUD_RATE = 9_600,
    parameter SYS_CLK_FREQ = 48_000_000                     // 48 MHz
) (
    input wire clk,
    input wire reset,
    input wire rx,
    output reg[7:0] data_out,                               // received 8-bit data package
    output reg ready                                        // is data ready?
);
    // bit period = number of clock cycles for receiving a bit
    localparam BIT_PERIOD = SYS_CLK_FREQ / BAUD_RATE;

    // states
    localparam IDLE           = 2'b00;
    localparam RCV_START_BIT  = 2'b01;
    localparam RCV_DATA_BITS  = 2'b10;
    localparam RCV_STOP_BIT   = 2'b11;

    reg[1:0] state;
    reg[$clog2(BIT_PERIOD)-1:0] timer;
    reg[3:0] bit_index;                                     // tracks which data bit is being received
    reg[7:0] rx_data;                                       // data being received

    always @(posedge clk) 
    begin
        if (reset)
        begin
            state <= IDLE;
            timer <= '0;
            bit_index <= 3'd0;
            rx_data <= 8'h00;
            ready <= 1'b0;
            data_out <= 8'h00;
        end
        else
        begin
            case (state)
                IDLE: 
                begin
                    ready <= 1'b0;                          // announce data is not ready
                    if (~|rx)                               // rx is low, wait for the start bit 
                    begin
                        state <= RCV_START_BIT;             // prepare for receiving the start bit
                        timer <= BIT_PERIOD / 2;            // sample rx in the middle of a frame
                    end
                end
                RCV_START_BIT: 
                begin
                    if (~|timer)
                    begin
                        if (~|rx)                           // rx is still low, start bit received
                        begin
                            state <= RCV_DATA_BITS;         // prepare for receiving the data bits
                            bit_index <= 3'd0; 
                            timer <= BIT_PERIOD - 1;
                        end 
                        else                                // false start
                        begin
                            state <= IDLE;                  // go back to IDLE
                        end
                    end 
                    else 
                    begin
                        timer <= timer - 1;
                    end
                end
                RCV_DATA_BITS: 
                begin
                    if (~|timer)
                    begin
                        rx_data[bit_index] <= rx;           // receive current data bit
                        bit_index <= bit_index + 1;
                        if (bit_index == 3'd7)              // received all 8 bits
                        begin
                            state <= RCV_STOP_BIT;          // prepare for receiving the stop bit
                        end
                        timer <= BIT_PERIOD - 1;
                    end
                    else 
                    begin
                        timer <= timer - 1;
                    end
                end
                RCV_STOP_BIT: 
                begin
                    if (~|timer) 
                    begin
                        if (|rx)                            // rx is high, stop bit received
                        begin
                            data_out <= rx_data;
                            ready <= 1'b1;                  // announce that data is ready!
                        end
                        state <= IDLE;                      // go back to IDLE
                    end 
                    else 
                    begin
                        timer <= timer - 1;
                    end
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