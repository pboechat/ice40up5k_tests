`ifndef UART_RX_V
`define UART_RX_V

module uart_rx #(
    parameter BAUD_RATE = 9_600,
    parameter SYS_CLK_FREQ = 48_000_000                     // 48 MHz
) (
    input wire clk,
    input wire reset,
    input wire rx,
    output reg[7:0] data_out,                              // received 8-bit data package
    output reg data_ready                                   // is data ready?
);
    // bit period = number of clock cycles for receiving a bit
    localparam BIT_PERIOD = SYS_CLK_FREQ / BAUD_RATE;

    // states
    localparam IDLE           = 2'b00;
    localparam RCV_START_BIT  = 2'b01;
    localparam RCV_DATA_BITS  = 2'b10;
    localparam RCV_STOP_BIT   = 2'b11;

    reg[1:0] state = IDLE;
    reg[$clog2(BIT_PERIOD)-1:0] timer = 0;
    reg[3:0] bit_index = 0;                                // tracks which data bit is being received
    reg[7:0] shift_reg = 0;                                // data being received

    always @(posedge clk) 
    begin
        if (reset)
        begin
            state <= IDLE;
            timer <= 0;
            bit_index <= 0;
            shift_reg <= 0;
            data_ready <= 0;
            data_out <= 0;
        end
        else
        begin
            case (state)
                IDLE: 
                begin
                    data_ready <= 1'b0;                     // announce data is not ready
                    if (rx == 0)                            // rx is low, wait for the start bit 
                    begin
                        state <= RCV_START_BIT;             // prepare for receiving the start bit
                        timer <= BIT_PERIOD / 2;            // sample rx in the middle of a frame
                    end
                end
                RCV_START_BIT: 
                begin
                    if (timer == 0)
                    begin
                        if (rx == 0)                        // rx is still low, start bit received
                        begin
                            state <= RCV_DATA_BITS;         // prepare for receiving the data bits
                            bit_index <= 0; 
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
                    if (timer == 0)
                    begin
                        shift_reg[bit_index] <= rx;         // receive current data bit
                        bit_index <= bit_index + 1;
                        if (bit_index == 7)                 // received all 8 bits
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
                    if (timer == 0) 
                    begin
                        if (rx == 1)                        // rx is high, stop bit received
                        begin
                            data_out <= shift_reg;
                            data_ready <= 1'b1;             // announce that data is ready!
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