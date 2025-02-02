`ifndef UART_TRANSMITTER_V
`define UART_TRANSMITTER_V

module uart_transmitter #(
    parameter BAUD_RATE = 9_600,
    parameter SYS_CLK_FREQ = 48_000_000                             // 48 MHz
) (
    input wire clk,
    input wire reset,
    input wire [7:0] data_in,                                       // 8-bit data package to transmit
    input wire send,                                                // start transmission when high
    output reg tx,                                                  // UART TX
    output reg busy                                                 // is transmitting?
);
    // bit period = number of clock cycles for transmitting a bit
    localparam BIT_PERIOD = SYS_CLK_FREQ / BAUD_RATE;

    // states
    localparam IDLE          = 2'b00;
    localparam TMT_START_BIT = 2'b01;
    localparam TMT_DATA_BITS = 2'b10;
    localparam TMT_STOP_BIT  = 2'b11;

    reg [1:0] state = IDLE;
    reg [7:0] shift_reg = 0; // data being transmitted
    reg [$clog2(BIT_PERIOD)-1:0] timer = 0;
    reg [2:0] bit_index = 0; // tracks which data bit is being transmitted

    always @(posedge clk) 
    begin
        if (reset) 
        begin
            tx <= 1'b1;                                             // tx line high (idle)
            busy <= 1'b0;                                           // announce we're idle
            state <= IDLE;
            shift_reg <= 0;
            timer <= 0;
            bit_index <= 0;
        end 
        else 
        begin
            case (state)
                IDLE: 
                begin
                    tx <= 1'b1;                                     // tx line high (idle)
                    busy <= 1'b0;                                   // announce we're idle
                    if (send)                                       // send signal received
                    begin
                        busy <= 1'b1;                               // announce we're busy
                        shift_reg <= data_in;                       // copy data to transmit
                        state <= TMT_START_BIT;                     // prepare for transmitting the start bit
                        timer <= BIT_PERIOD - 1;
                    end
                end
                TMT_START_BIT: 
                begin
                    tx <= 1'b0;                                     // transmit the start bit (tx line low) for the duration of a frame
                    if (timer == 0) 
                    begin
                        bit_index <= 0;
                        state <= TMT_DATA_BITS;                     // prepare for transmitting the data bits
                        timer <= BIT_PERIOD - 1;
                    end 
                    else 
                    begin
                        timer <= timer - 1;
                    end
                end
                TMT_DATA_BITS: 
                begin
                    tx <= shift_reg[bit_index];                     // transmit the current data bit for the duration of a frame
                    if (timer == 0) 
                    begin
                        if (bit_index == 7)                         // all data bits transmitted
                        begin
                            state <= TMT_STOP_BIT;                  // prepare for transmitting the stop bit
                        end 
                        else 
                        begin
                            bit_index <= bit_index + 1;
                        end
                        timer <= BIT_PERIOD - 1;
                    end 
                    else 
                    begin
                        timer <= timer - 1;
                    end
                end
                TMT_STOP_BIT: 
                begin
                    tx <= 1'b1;                                     // transmit the stop bit (tx line high) for the duration of a frame
                    if (timer == 0) 
                    begin
                        busy <= 1'b0;                               // announce we're idle again (ie, transmission completed)
                        state <= IDLE;                              // return to idle
                    end 
                    else 
                    begin
                        timer <= timer - 1;
                    end
                end
            endcase
        end
    end
endmodule

`endif