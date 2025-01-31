module uart_dbg #(
    parameter SYS_CLK_FREQ = 48_000_000,
    parameter BAUD_RATE = 9_000_000,
    parameter FIFO_DEPTH = 32
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
        .FIFO_DEPTH(FIFO_DEPTH)
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

    uart_transmitter #(
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
        if (!tx_busy)
        begin
            if (!empty)
            begin
                if (!rd)
                begin
                    rd <= 1;
                end
                else
                begin
                    send <= 1;
                end
            end
        end
        else
        begin
            rd <= 0;
            send <= 0;
        end
    end
endmodule