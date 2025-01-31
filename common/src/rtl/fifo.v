module fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16
)(
    input  wire clk,
    input  wire reset,
    input  wire wr,
    input  wire rd,
    input  wire [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg full,
    output reg empty
);
    localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);

    reg [DATA_WIDTH-1:0] mem[FIFO_DEPTH-1:0]; 
    reg [ADDR_WIDTH:0] wr_ptr, rd_ptr;

    always @(posedge clk) 
    begin
        if (reset) 
        begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            full <= 0;
            empty <= 1;
        end 
        else 
        begin
            if (wr && !full) 
            begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= data_in;
                wr_ptr <= wr_ptr + 1;
            end
            if (rd && !empty) begin
                data_out <= mem[rd_ptr[ADDR_WIDTH-1:0]];
                rd_ptr <= rd_ptr + 1;
            end

            full <= (wr_ptr - rd_ptr == FIFO_DEPTH);
            empty <= (wr_ptr == rd_ptr);
        end
    end
endmodule
