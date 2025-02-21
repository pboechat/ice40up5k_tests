`include "uart_dbg.v"
`include "uart/uart_receiver.v"

module uart_dbg_tb;
    wire clk;
    wire reset;
    wire tx;
    wire full, rx_ready;
    wire[7:0] rx_msg;
    reg wr;
    reg[7:0] msg;
    reg clk_val, reset_val;

    assign clk = clk_val;
    assign reset = reset_val;

    always #1 clk_val = ~clk_val;

    localparam MAX_SIM_CYCLES = 1000;

    localparam BAUD_RATE = 4;
    localparam MSG_QUEUE_SIZE = 8;

    uart_dbg #(
        .SYS_CLK_FREQ(1),
        .BAUD_RATE(BAUD_RATE),
        .MSG_QUEUE_SIZE(MSG_QUEUE_SIZE)
    ) uart_dbg_inst (
        .clk(clk),
        .reset(reset),
        .wr(wr),
        .msg(msg),
        .tx(tx),
        .full(full)
    );

    uart_receiver #(
        .SYS_CLK_FREQ(1),
        .BAUD_RATE(BAUD_RATE)
    ) uart_receiver_inst(
        .clk(clk),
        .reset(reset),
        .rx(tx),
        .data_out(rx_msg),
        .data_ready(rx_ready)
    );

    `include "assertions.vh"

    integer prod_step = 0;
    integer cons_step = 0;

    initial
    begin
        $dumpfile("uart_dbg_tb.vcd");
        $dumpvars(0, uart_dbg_tb);

        clk_val = 1;                        // set clock high
        reset_val = 1;                      // set reset high
        wr <= 0;                            // set write to low
        msg <= 0;                           // set msg to 0

        @(posedge clk);                     // run for 1 cycle (reset)

        reset_val = 0;                      // set reset low

        forever
        begin
            wr <= 1;
            msg <= prod_step;
        
            @(posedge clk);

            if (prod_step == MAX_SIM_CYCLES)
            begin
                $display("[uart_dbg_tb                     ] - T(%9t) - success", $time);
                $finish();
            end

            prod_step = prod_step + 1;
        end

        forever
        begin
            @(posedge rx_ready);

            assert_eq(rx_msg, cons_step, "rx_msg");

            if (prod_step == MAX_SIM_CYCLES)
            begin
                $display("[uart_dbg_tb                     ] - T(%9t) - success", $time);
                $finish();
            end

            cons_step = cons_step + 1;
        end
    end
endmodule