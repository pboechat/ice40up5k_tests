`include "clock_divider.v"

module clock_divider_tb;
    wire clk;
    wire reset;
    wire out_clk;
    reg clk_val, reset_val;

    assign clk = clk_val;
    assign reset = reset_val;

    localparam CYCLE_TO_TU = 2;

    always #1 clk_val = ~clk_val;

    localparam CLK_DIV_COUNT = 10;

    clock_divider #(
        .COUNT(CLK_DIV_COUNT)
    ) clock_divider_inst (
        .clk(clk),
        .reset(reset),
        .out_clk(out_clk)
    );

    `include "assertions.vh"

    initial
    begin
        $dumpfile("clock_divider_tb.vcd");
        $dumpvars(0, clock_divider_tb);

        clk_val = 1;                        // set clock high
        reset_val = 1;                      // set reset high

        #(CYCLE_TO_TU);

        reset_val = 0;

        assert_eq(out_clk, 1, "out_clk");

        #((CLK_DIV_COUNT / 2) * CYCLE_TO_TU);

        assert_eq(out_clk, 0, "out_clk");

        #((CLK_DIV_COUNT / 2) * CYCLE_TO_TU);

        assert_eq(out_clk, 1, "out_clk");

        $finish();
    end
endmodule