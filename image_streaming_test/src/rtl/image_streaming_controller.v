`define ACK 8'b10101010

module image_streaming_controller #(
    parameter IMAGE_BUF_X = 1,
    parameter IMAGE_BUF_Y = 1
) (
    input wire clk,
    input wire reset,
    input wire[7:0] rx_data,
    input wire rx_ready,
    input wire tx_busy,
    input wire mem_ready,
    output reg[7:0] tx_data,
    output reg tx_ready,
    output reg mem_req,
    output reg[7:0] mem_in,
    output reg[31:0] mem_addr,
    output reg streaming_ended
`ifdef DEBUG
    , output reg r,
    output reg g,
    output reg b
`endif
);
    localparam IMAGE_BUF_SIZE = IMAGE_BUF_X * IMAGE_BUF_Y * 2;

    // states
    localparam IDLE             = 3'b000;
    localparam RECEIVING_PIXEL  = 3'b001;
    localparam STORING_PIXEL    = 3'b010;
    localparam SENDING_ACK      = 3'b011;
    localparam ENDING           = 3'b100;
    localparam LAST_STATE       = ENDING;

    reg[$clog2(LAST_STATE):0] state;

    always @(posedge clk)
    begin
        if (reset)
        begin
            state <= IDLE;
            mem_req <= 0;
            mem_in <= 0;
            mem_addr <= 0;
            tx_ready <= 0;
            streaming_ended <= 0;
`ifdef DEBUG
            r <= 0;
            g <= 0;
            b <= 0;
`endif
        end
        else
        begin
            case (state)
            IDLE:
            begin
                streaming_ended <= 0;

                if (rx_ready)
                begin
                    if (rx_data == `ACK)
                    begin
                        mem_addr <= 0;
                        state <= RECEIVING_PIXEL;
`ifdef DEBUG
                        r <= 0;
                        g <= 1;
                        b <= 0;
`endif
                    end
`ifdef DEBUG
                    else
                    begin
                        r <= 1;
                        g <= 0;
                        b <= 1;
                    end
`endif
                end
            end
            RECEIVING_PIXEL:
            begin
                if (rx_ready)
                begin
                    mem_in <= rx_data;
                    state <= STORING_PIXEL;
`ifdef DEBUG
                    r <= 0;
                    g <= 1;
                    b <= 0;
`endif
                end
`ifdef DEBUG
                else
                begin
                    r <= 0;
                    g <= 0;
                    b <= 0;
                end
`endif
            end
            STORING_PIXEL:
            begin
                if (mem_ready == 0)
                begin
                    mem_req <= 1;
                end
                else if (mem_req)
                begin
                    mem_req <= 0;
                    state <= SENDING_ACK;
                end
            end
            SENDING_ACK:
            begin
                if (tx_busy == 0)
                begin
                    tx_data <= `ACK;
                    tx_ready <= 1;
`ifdef DEBUG
                    r <= 0;
                    g <= 1;
                    b <= 1;
`endif
                end
                else if (tx_ready)
                begin
                    tx_ready <= 0;

                    if (mem_addr == (IMAGE_BUF_SIZE - 1))
                    begin
                        state <= ENDING;
                    end
                    else
                    begin
                        mem_addr <= mem_addr + 1;
                        state <= RECEIVING_PIXEL;
                    end
                end
            end
            ENDING:
            begin
                streaming_ended <= 1;
                state <= IDLE;
`ifdef DEBUG
                r <= 0;
                g <= 0;
                b <= 0;
`endif
            end
            default:
            begin
                state <= IDLE;
            end
            endcase
        end
    end
endmodule