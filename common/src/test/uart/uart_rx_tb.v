`include "uart/uart_rx.v"

module uart_rx_tb;
    localparam TEST_DATA = 8'b10101010;

    wire clk;
    wire reset;
    wire rx;
    reg clk_val;
    reg reset_val;
    reg rx_val;
    reg[7:0] test_data = TEST_DATA;
    wire[7:0] data_out;
    wire data_ready;

    assign clk = clk_val;
    assign reset = reset_val;
    assign rx = rx_val;

    always #1 clk_val = ~clk_val;           // 1 (clock) cycle at every 2 time units

    uart_rx #(
		.BAUD_RATE(1),
    	.SYS_CLK_FREQ(4)                    // 1 bit period at every 4 clock cycles (or 8 time units)
	) uart_rx_inst(
		.clk(clk),
		.reset(reset),
		.rx(rx),
		.data_out(data_out),
		.data_ready(data_ready)
	);

    integer i;
    integer j = 0;

    initial 
    begin
        $dumpfile("uart_rx_tb.vcd");
        $dumpvars(0, uart_rx_tb);

        clk_val = 1'b0;                     // set clock low

        reset_val = 1'b1;                   // set reset high

        #2;                                 // run for 1 cycle (reset)

        reset_val = 1'b0;                   // set reset low
        
        rx_val = 1'b0;                      // set rx low

        #2;                                 // run for 1 cycle (prepare to sample start bit)

        #4;                                 // run for 2 cycles / 0.5 bit period (sample start bit)

        #2;                                 // run for 1 cycle (prepare to read data bits)

        for (i = 0; i < 8; i++) 
        begin
            rx_val = test_data[j++];
            #8;                             // run for 4 cycles / 1 bit period (read data bit)
        end

        rx_val = 1'b1;                      // set stop bit

        #8;                                 // run for 4 cycles / 1 bit period (read stop bit)

        if (data_ready != 1'b1)
        begin
            $display("[uart_rx_tb                      ] - T(%t) - data_ready(b0), expected(b1)", $time);
            $stop();
        end

        if (data_out != TEST_DATA)
        begin
            $display("[uart_rx_tb                      ] - T(%t) - data_out(b%b), expected(b%b)", $time, data_out, TEST_DATA);
            $stop();
        end

        $display("[uart_rx_tb                      ] - T(%t) - success", $time);
        $finish();
    end
endmodule