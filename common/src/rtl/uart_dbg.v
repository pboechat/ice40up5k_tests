`ifndef UART_DBG_V
`define UART_DBG_V

`include "fifo.v"
`include "uart/uart_tx.v"

module uart_dbg #(
    parameter SYS_CLK_FREQ = 48_000_000,
    parameter BAUD_RATE = 9_600,
    parameter MSG_QUEUE_SIZE = 32
) (
    input wire clk,
    input wire reset,
    input wire wr,
    input wire[7:0] msg,
    output wire tx,
    output wire full,
    output wire empty
);
    wire tx_busy;
    reg rd, send;
    wire[7:0] tx_msg;

    fifo #(
        .DATA_WIDTH(8),
        .FIFO_DEPTH(MSG_QUEUE_SIZE)
    ) msg_queue (
        .clk(clk),
        .reset(reset),
        .wr(wr),
        .data_in(msg),
        .rd(rd),
        .data_out(tx_msg),
        .full(full),
        .empty(empty)
    );

    uart_tx #(
        .BAUD_RATE(BAUD_RATE),
        .SYS_CLK_FREQ(SYS_CLK_FREQ)
    ) uart_tx_inst(
        .clk(clk),
        .reset(reset),
        .data_in(tx_msg),
        .send(send),
        .tx(tx),
        .busy(tx_busy)
    );

    always @(posedge clk)
    begin
        if (~tx_busy)
        begin
            if (~empty)
            begin
                if (~rd)
                begin
                    rd <= 1'b1;
                    send <= 1'b1;
                end
                else
                begin
                    rd <= 1'b0;
                end
            end
        end
        else
        begin
            rd <= 1'b0;
            send <= 1'b0;
        end
    end
endmodule

`endif