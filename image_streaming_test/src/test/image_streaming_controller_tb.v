`include "image_streaming_controller.v"

module image_streaming_controller_tb;
    wire clk;
    wire reset;
    wire tx_ready;
    wire swap;
    wire[7:0] tx_data;
    wire[7:0] mem_in;
    wire[31:0] mem_addr;
    reg clk_val;
    reg reset_val;
    reg tx_busy;
    reg rx_ready;
    reg[7:0] rx_data;

    assign clk = clk_val;
    assign reset = reset_val;

    always #1 clk_val = ~clk_val;

    localparam IMAGE_BUF_X = 4;
    localparam IMAGE_BUF_Y = 3;
    localparam IMAGE_BUF_SIZE = IMAGE_BUF_X * IMAGE_BUF_Y * 2;

    image_streaming_controller #(
        .IMAGE_BUF_X(IMAGE_BUF_X),
        .IMAGE_BUF_Y(IMAGE_BUF_Y)
    ) image_streaming_controller_inst(
        .clk(clk),
        .reset(reset),
        .rx_data(rx_data),
        .rx_ready(rx_ready),
        .tx_busy(tx_busy),
        .tx_data(tx_data),
        .tx_ready(tx_ready),
        .mem_addr(mem_addr),
        .mem_in(mem_in),
        .streaming_ended(swap)
    );

    event tx_ready_hi_evt, tx_ready_lo_evt;
    always @(posedge tx_ready) 
    begin
        -> tx_ready_hi_evt;
    end
    always @(negedge tx_ready) 
    begin
        -> tx_ready_lo_evt;
    end

    `include "asserts.vh"

    integer step = 0;

    initial 
    begin
        $dumpfile("image_streaming_controller_tb.vcd");
        $dumpvars(0, image_streaming_controller_tb);

        clk_val <= 1'b1;                                            // set clk high
        reset_val <= 1'b1;                                          // set reset high

        @(posedge clk);

        reset_val <= 0;                                             // set reset low

        // start the streaming
        rx_data <= `ACK;
        rx_ready <= 1;

        @(posedge clk);

        rx_data <= step;
        rx_ready <= 1;
        tx_busy <= 0;

        forever
        begin
            @(tx_ready_hi_evt);

            rx_ready <= 0;
            tx_busy <= 1;

            assert_eq(mem_addr, step, "mem_addr");
            assert_eq(mem_in, step, "mem_in");
            assert_eq(tx_data, `ACK, "tx_data");

            @(tx_ready_lo_evt);


            if (step == (IMAGE_BUF_SIZE - 1))
            begin
                @(posedge swap);

                $display("[image_streaming_controller_tb   ] - T(%9t) - success", $time);
                $finish();
            end

            step = step + 1;

            rx_data <= step;
            rx_ready <= 1;
            tx_busy <= 0;
        end
    end
endmodule