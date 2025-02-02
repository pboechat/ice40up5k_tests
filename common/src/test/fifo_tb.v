`include "fifo.v"

module fifo_tb;
    wire clk;
    wire reset;
    wire empty, full;
    wire[7:0] data_out;
    reg wr, rd;
    reg[7:0] data_in;
    reg clk_val, reset_val;

    assign clk = clk_val;
    assign reset = reset_val;

    localparam CYCLE_TO_TU = 2;
    localparam HALF_CYCLE_TO_TU = (CYCLE_TO_TU / 2);

    always #1 clk_val = ~clk_val;

    fifo #(
        .DATA_WIDTH(8),
        .FIFO_DEPTH(4)
    ) fifo_inst (
        .clk(clk),
        .reset(reset),
        .wr(wr),
        .rd(rd),
        .data_in(data_in),
        .data_out(data_out),
        .empty(empty),
        .full(full)
    );

    `include "assertions.vh"

    integer i = 0;

    initial
    begin
        $dumpfile("fifo_tb.vcd");
        $dumpvars(0, fifo_tb);

        clk_val = 1;                                                // set clk high
        reset_val = 1;                                              // set reset high
        rd <= 0;
        wr <= 0;

        #(CYCLE_TO_TU);                                             // 1 cycle (reset)

        reset_val <= 0;

        assert_eq(empty, 1, "empty");

        // fill up fifo

        rd <= 0;
        wr <= 1;
        for (i = 0; i < 4; ++i)
        begin
            data_in <= i;
            #(CYCLE_TO_TU);
        end

        #(HALF_CYCLE_TO_TU);

        assert_eq(empty, 0, "empty");
        assert_eq(full, 1, "full");

        #(HALF_CYCLE_TO_TU);
        
        // read up fifo

        wr <= 0;
        rd <= 1;
        #(HALF_CYCLE_TO_TU);
        for (i = 0; i < 4; ++i)
        begin
            #(CYCLE_TO_TU);

            assert_eq(data_out, i, "data_out");
        end

        #(HALF_CYCLE_TO_TU);

        assert_eq(empty, 1, "empty");
        assert_eq(full, 0, "full");

        #(HALF_CYCLE_TO_TU);

        // fill fifo again

        rd <= 0;
        wr <= 1;
        for (i = 0; i < 4; ++i)
        begin
            data_in <= i;
            #(CYCLE_TO_TU);
        end

        #(HALF_CYCLE_TO_TU);

        assert_eq(empty, 0, "empty");
        assert_eq(full, 1, "full");

        // try to overflow

        rd <= 0;
        wr <= 1;
        data_in <= 4;
        #(CYCLE_TO_TU);

        // check that overflow was ignored

        wr <= 0;
        rd <= 1;
        #(HALF_CYCLE_TO_TU);
        for (i = 0; i < 3; ++i)
        begin
            #(CYCLE_TO_TU);

            assert_eq(empty, 0, "empty");
            assert_eq(data_out, i, "data_out");
        end

        #(CYCLE_TO_TU);
        assert_eq(data_out, 3, "data_out");
        assert_eq(empty, 1, "empty");

        #(HALF_CYCLE_TO_TU);

        // try to underflow

        assert_eq(data_out, 3, "data_out");
        assert_eq(empty, 1, "empty");

        $finish();
    end
endmodule