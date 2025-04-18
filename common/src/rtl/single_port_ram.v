`ifndef SINGLE_PORT_RAM_V
`define SINGLE_PORT_RAM_V

module single_port_ram #(
    parameter WIDTH = 8,
    parameter DEPTH = 256,
    parameter ADDR_WIDTH = $clog2(DEPTH),
    parameter INIT_FILE = ""
) (
    input wire clk,
    input wire we,
    input wire[ADDR_WIDTH-1:0] addr,
    input wire[WIDTH-1:0] data_in,
    output reg[WIDTH-1:0] data_out
);
    localparam ADDR_MSB = $clog2(DEPTH)-1;

    reg[WIDTH-1:0] ram[0:DEPTH-1];

    generate
        if (INIT_FILE != "") begin
            initial $readmemb(INIT_FILE, ram);
        end
    endgenerate

    always @(posedge clk) 
    begin
        if (we) 
        begin
            ram[addr[ADDR_MSB:0]] <= data_in;
        end
        data_out <= ram[addr[ADDR_MSB:0]];
    end
endmodule

`endif