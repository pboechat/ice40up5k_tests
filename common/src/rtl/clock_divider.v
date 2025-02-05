`ifndef CLOCK_DIVIDER_VH
`define CLOCK_DIVIDER_VH

module clock_divider #(
    parameter COUNT = 1
) (
    input wire clk,
    input wire reset,
    output reg out_clk
);
    localparam HALF_COUNT = COUNT / 2;

    reg[$clog2(HALF_COUNT) - 1:0] timer;

    initial
    begin
        out_clk = 0;
        timer <= HALF_COUNT - 1;
    end

    always @(posedge clk)
    begin
        if (reset)
        begin
            out_clk <= clk;
            timer <= HALF_COUNT - 1;
        end
        else
        begin
            if (timer == 0)
            begin
                out_clk <= ~out_clk;
                timer <= HALF_COUNT - 1;
            end
            else
            begin
                timer <= timer - 1;
            end
        end
    end
endmodule

`endif