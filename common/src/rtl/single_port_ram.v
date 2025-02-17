`ifndef SINGLE_PORT_RAM_V
`define SINGLE_PORT_RAM_V

module single_port_ram #(
    parameter WIDTH = 8,
    parameter DEPTH = 256
)(
    input wire clk,
    input wire reset,
    input wire request,
    input wire write_enable,
    input wire [$clog2(DEPTH)-1:0] addr,
    input wire [WIDTH-1:0] write_data,
    output reg [WIDTH-1:0] read_data,
    output reg ready
);
    reg[WIDTH-1:0] ram [0:DEPTH-1];

    always @(posedge clk) 
    begin
        if (reset) 
        begin
            ready <= 1'b0;
        end 
        else 
        begin
            ready <= 1'b0;

            if (request) 
            begin
                if (write_enable) 
                begin
                    ram[addr] <= write_data;
                end
                else
                begin
                    read_data <= ram[addr];
                end
                
                ready <= 1'b1;
            end
        end
    end
endmodule

`endif