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
    output reg pwm_b,
    output reg pwm_g,
    output reg pwm_r
);
    localparam DECODE_WAIT    = 2'b00;
    localparam DECODE         = 2'b01;
    localparam NOTIFY         = 2'b10;
    localparam NOTIFY_WAIT    = 2'b11;

    reg[7:0] instr = 0;
    reg[1:0] state = DECODE_WAIT;
    reg[2:0] decode_error = 0;

    integer i;

    always@(posedge clk)
    begin
        if (reset)
        begin
            state <= DECODE_WAIT;                   // wait to decode
            instr <= 0;                             // reset current instruction
            decode_error <= 0;                      // reset decode error (debugging)
            // display RED
            pwm_b <= 1'b0;
            pwm_g <= 1'b0;
            pwm_r <= 1'b1;
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
                    else if (instr == 0)
                    begin
                        // display YELLOW
                        pwm_b <= 1'b0;
                        pwm_g <= 1'b1;
                        pwm_r <= 1'b1;
                    end
                end
                DECODE:
                begin
                    casez (instr)
                        `SET:
                        begin
                            // display received color
                            pwm_b <= instr[2];
                            pwm_g <= instr[1];
                            pwm_r <= instr[0];
                        end
                        `TOGGLE:
                        begin
                            // toggle bits of currently displayed color
                            if (instr[2])
                            begin
                                pwm_b <= ~pwm_b;
                            end
                            if (instr[1])
                            begin
                                pwm_g <= ~pwm_g;
                            end
                            if (instr[0])
                            begin
                                pwm_r <= ~pwm_r;
                            end
                        end
                        `NOP:
                        begin
                            // don't do anything
                        end
                        default:
                        begin
                            // decode error: invalid instruction bit count (debugging)
                            decode_error = 0;
                            for (i = 0; i < 8; i++) 
                            begin
                                decode_error = decode_error + instr[i];
                            end
                            // display decode error as BGR
                            pwm_b = decode_error[2];
                            pwm_g = decode_error[1];
                            pwm_r = decode_error[0];
                        end 
                    endcase
                    state <= NOTIFY;                    // notify decode result
                end
                NOTIFY:
                begin
                    if (snd_busy == 0)                  // wait for an opportunity to send the decode result
                    begin
                        if (decode_error != 0)          // send decode error
                        begin
                            snd_data <= {5'b11111, decode_error};
                        end
                        else
                        begin                           // send current color
                            snd_data <= {5'b00000, pwm_b, pwm_g, pwm_r};
                        end
                        snd_ready <= 1'b1;
                        state <= NOTIFY_WAIT;           // wait for the decode result to be sent
                    end
                end
                NOTIFY_WAIT:
                begin
                    if (snd_busy == 0)
                    begin
                        snd_data <= 0;
                        snd_ready <= 1'b0;
                        decode_error <= 0;
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