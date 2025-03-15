`ifndef FIFO_V
`define FIFO_V

module fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16
)(
    input wire clk,
    input wire reset,
    input wire wr,
    input wire rd,
    input wire[DATA_WIDTH-1:0] data_in,
    output reg[DATA_WIDTH-1:0] data_out,
    output wire full,
    output wire empty
);
    localparam SLOT_COUNT = FIFO_DEPTH + 1;

    reg[DATA_WIDTH-1:0] mem[FIFO_DEPTH:0]; // one-slot reserve approach
    reg[$clog2(FIFO_DEPTH):0] wr_ptr, rd_ptr;

    assign full = ((wr_ptr + 1) % SLOT_COUNT) == rd_ptr;
    assign empty = (wr_ptr == rd_ptr);

    always @(posedge clk) 
    begin
        if (reset) 
        begin
            wr_ptr <= 'b0;
            rd_ptr <= 'b0;
            data_out <= 'b0;
        end 
        else 
        begin
            if (wr && ~full) 
            begin
                mem[wr_ptr] <= data_in;
                wr_ptr <= (wr_ptr + 1) % SLOT_COUNT;
            end
            if (rd && ~empty) 
            begin
                data_out <= mem[rd_ptr];
                rd_ptr <= (rd_ptr + 1) % SLOT_COUNT;
            end
        end
    end
endmodule

`endif