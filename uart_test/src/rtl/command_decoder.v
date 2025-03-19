// instructions
`define SET     8'b10000???
`define TOGGLE  8'b01000???
`define NOP     8'b00100000

module command_decoder(
    input wire clk,
    input wire reset,
    input wire[7:0] rcv_data,
    input wire rcv_ready,
    input wire snd_busy,
    output reg[7:0] snd_data,
    output reg snd_ready,
    output reg r,
    output reg g,
    output reg b
);
    // states
    localparam DECODE_WAIT    = 2'b00;
    localparam DECODE         = 2'b01;
    localparam NOTIFY         = 2'b10;
    localparam NOTIFY_WAIT    = 2'b11;

    reg[7:0] instr;
    reg[1:0] state;
    reg[2:0] decode_error;

    integer i;

    always @(posedge clk)
    begin
        if (reset)
        begin
            state <= DECODE_WAIT;                   // wait to decode
            instr <= 8'h00;                         // reset current instruction
            decode_error <= 3'b0;                   // reset decode error (debugging)
            // display RED
            r <= 1'b1;
            g <= 1'b0;
            b <= 1'b0;
        end
        else
        begin
            case (state)
                DECODE_WAIT:
                begin
                    if (rcv_ready)                  // rcv_data is ready!
                    begin
                        instr <= rcv_data;          // decode rcv_data
                        state <= DECODE;
                    end
                    else if (~|instr)
                    begin
                        // display YELLOW
                        r <= 1'b1;
                        g <= 1'b1;
                        b <= 1'b0;
                    end
                end
                DECODE:
                begin
                    casez (instr)
                        `SET:
                        begin
                            // display received color
                            b <= instr[2];
                            g <= instr[1];
                            r <= instr[0];
                        end
                        `TOGGLE:
                        begin
                            // toggle bits of currently displayed color
                            if (instr[2])
                            begin
                                b <= ~b;
                            end
                            if (instr[1])
                            begin
                                g <= ~g;
                            end
                            if (instr[0])
                            begin
                                r <= ~r;
                            end
                        end
                        `NOP:
                        begin
                            // don't do anything
                        end
                        default:
                        begin
                            // decode error: invalid instruction bit count (debugging)
                            decode_error = 3'b0;
                            for (i = 0; i < 8; i++) 
                            begin
                                decode_error = decode_error + instr[i];
                            end
                            // display decode error as BGR
                            b = decode_error[2];
                            g = decode_error[1];
                            r = decode_error[0];
                        end 
                    endcase
                    state <= NOTIFY;                    // notify decode result
                end
                NOTIFY:
                begin
                    if (~snd_busy)                      // wait for an opportunity to send the decode result
                    begin
                        if (decode_error)               // send decode error
                        begin
                            snd_data <= {5'b11111, decode_error};
                        end
                        else
                        begin                           // send current color
                            snd_data <= {5'b00000, b, g, r};
                        end
                        snd_ready <= 1'b1;
                        state <= NOTIFY_WAIT;           // wait for the decode result to be sent
                    end
                end
                NOTIFY_WAIT:
                begin
                    if (~snd_busy)
                    begin
                        snd_data <= 8'h00;
                        snd_ready <= 1'b0;
                        decode_error <= 3'b0;
                        state <= DECODE_WAIT;
                    end
                end
                default:
                begin
                    state <= DECODE_WAIT;
                end
            endcase
        end
    end
endmodule