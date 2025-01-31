`include "ili9341.vh"

module display_controller #(
    parameter HW_RESET_TIMER = 0,                   // hardware reset timer     (suggested: 120 ms)
    parameter SW_RESET_TIMER = 0,                   // software reset timer     (suggested 5ms)
    parameter SLEEP_OUT_TIMER = 0,                  // sleep out timer          (suggested 120ms)
    parameter DISPLAY_ON_TIMER = 0,                 // display ON timer         (suggested 10ms)
    parameter DIS_RES_X = 320,                      // horizontal resolution    (default: 320 pixels)
    parameter DIS_RES_Y = 240                       // vertical resolution      (default: 240 pixels)
) (
    input wire clk,
    input wire reset,
    input wire tx_busy,
    output reg dis_reset,                          // display reset
    output reg dc,                                 // data/command
    output reg tx_start,
    output reg[7:0] tx_data
`ifdef DEBUG
    , output reg b,
    output reg g,
    output reg r
`endif
);
    `include "functions.vh"

    // timers
    localparam LONGEST_TIMER = max(HW_RESET_TIMER, max(SW_RESET_TIMER, max(SLEEP_OUT_TIMER, DISPLAY_ON_TIMER)));

    // states
    localparam HW_RESET             = 4'b0000;                                              // do hardware reset
    localparam SW_RESET             = 4'b0001;                                              // do software reset
    localparam EXIT_SLEEP_MODE      = 4'b0010;                                              // exit sleep mode
    localparam SET_PXL_FMT          = 4'b0011;                                              // set pixel format
    localparam SET_MEM_ACC_CTL      = 4'b0100;                                              // set memory access pattern
    localparam TURN_DISPLAY_ON      = 4'b0101;                                              // turn the display ON
    localparam SET_COL_ADDR         = 4'b0110;                                              // set column address
    localparam SET_PAGE_ADDR        = 4'b0111;                                              // set page address
    localparam WRITE_PIXELS         = 4'b1010;                                              // write pixels
    localparam LAST_STATE           = WRITE_PIXELS;

    localparam PIXEL_FORMAT = `RGB565;
    localparam PIXEL_BYTE_COUNT = DIS_RES_X * DIS_RES_Y * 2;                                // two bytes per pixel
    localparam COLOR = 16'hf800;

    reg[$clog2(LAST_STATE):0] state = HW_RESET;
    reg[$clog2(LONGEST_TIMER)-1:0] timer = 0;
    reg[2:0] state_setup_flg = 0;
    reg[$clog2(PIXEL_BYTE_COUNT)-1:0] pixel_byte_counter = 0;

    // simulation-only
    integer frame_counter = 0;

    task send_command(input reg[7:0] command);
    begin
`ifdef SIMULATION
        if (tx_data != command)
            $display("[display_controller              ] - T(%9t) - sending command (h%h)", $time, command);
`endif
        dc <= `COMMAND_BIT;
        tx_data <= command;
        tx_start <= 1'b1;
`ifdef DEBUG
        b <= 0;
        g <= 0;
        r <= 1;
`endif
    end
    endtask

    task send_data(input reg[7:0] data);
    begin
`ifdef SIMULATION
        if (tx_data != data)
            $display("[display_controller              ] - T(%9t) - sending data (h%h)", $time, data);
`endif
        dc <= `DATA_BIT;
        tx_data <= data;
        tx_start <= 1'b1;
`ifdef DEBUG
        b <= 0;
        g <= 0;
        r <= 1;
`endif
    end
    endtask

    always @(posedge clk)
    begin
        if (reset)
        begin
`ifdef SIMULATION
            $display("[display_controller              ] - T(%9t) - reset", $time);
`endif
            state_setup_flg <= 0;
            state <= HW_RESET;
            dc <= 0;
            dis_reset <= 0;
            timer <= 0;
            tx_data <= 0;
            tx_start <= 0;
            frame_counter <= 0;
`ifdef DEBUG
            b <= 0;
            g <= 0;
            r <= 1;
`endif
        end
        else
        begin
            case (state)
                HW_RESET:
                begin
                    if (state_setup_flg == 0)
                    begin
`ifdef SIMULATION
                        $display("[display_controller              ] - T(%9t) - HW_RESET", $time); 
`endif
                        dis_reset <= 1;
                        state_setup_flg <= 1;
                        timer <= HW_RESET_TIMER - 1;
`ifdef DEBUG
                        b <= 1;
                        g <= 0;
                        r <= 1;
`endif
                    end
                    else
                    begin
                        if (timer == 0)
                        begin
                            dis_reset <= 0;
                            state_setup_flg <= 0;
                            state <= SW_RESET;
`ifdef DEBUG
                            b <= 0;
                            g <= 0;
                            r <= 0;
`endif
                        end
                        else
                        begin
                            timer <= timer - 1;
                        end
                    end
                end
                SW_RESET:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_command(`SW_RESET_CMD);
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (tx_busy == 0)
                        begin
                            timer <= SW_RESET_TIMER - 1;
                            state_setup_flg <= 2;
                        end
                    end
                    else
                    begin
                        if (timer == 0)
                        begin
                            state_setup_flg <= 0;
                            state <= EXIT_SLEEP_MODE;
                        end
                        else
                        begin
                            timer <= timer - 1;
                        end
                    end
                end
                EXIT_SLEEP_MODE:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_command(`SLEEP_OUT_CMD);
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (tx_busy == 0)
                        begin
                            timer <= SLEEP_OUT_TIMER - 1;
                            state_setup_flg <= 2;
                        end
                    end
                    else
                    begin
                        if (timer == 0)
                        begin
                            state_setup_flg <= 0;
                            state <= SET_PXL_FMT;
                        end
                        else
                        begin
                            timer <= timer - 1;
                        end
                    end
                end
                SET_PXL_FMT:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_command(`SET_PXL_FMT_CMD);
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_data(PIXEL_FORMAT);
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else
                    begin
                        if (tx_busy == 0)
                        begin
                            state_setup_flg <= 0;
                            state <= SET_MEM_ACC_CTL;
                        end
                    end
                end
                SET_MEM_ACC_CTL:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_command(`MEM_ACC_CTR_CMD);
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (tx_busy == 0)
                        begin
                            // row address order, column address order, row/col exchange, vertical refresh, RGB-BGR, horizontal refresh
                            send_data({1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0}); // column, RGB
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else
                    begin
                        if (tx_busy == 0)
                        begin
                            state_setup_flg <= 0;
                            state <= TURN_DISPLAY_ON;
                        end
                    end
                end
                TURN_DISPLAY_ON:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_command(`DISPLAY_ON_CMD);
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (tx_busy == 0)
                        begin
                            state_setup_flg <= 2;
                            timer <= DISPLAY_ON_TIMER - 1;
                        end
                    end
                    else
                    begin
                        if (timer == 0)
                        begin
                            state_setup_flg <= 0;
                            state <= SET_COL_ADDR;
                        end
                        else
                        begin
                            timer <= timer - 1;
                        end
                    end
                end
                SET_COL_ADDR:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_command(`SET_COL_ADDR_CMD);
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_data(8'h00); // start column MSB
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else if (state_setup_flg == 2)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_data(8'h00); // start column LSB
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 3;
                        end
                    end
                    else if (state_setup_flg == 3)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_data(DIS_RES_X[15:8]); // end column MSB
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 4;
                        end
                    end
                    else if (state_setup_flg == 4)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_data(DIS_RES_X[7:0]); // end column LSB
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 0;
                            state <= SET_PAGE_ADDR;
                        end
                    end
                end
                SET_PAGE_ADDR:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_command(`SET_PAGE_ADDR_CMD);
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_data(8'h00); // tx_start page MSB
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else if (state_setup_flg == 2)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_data(8'h00); // tx_start page LSB
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 3;
                        end
                    end
                    else if (state_setup_flg == 3)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_data(DIS_RES_Y[15:8]); // end page MSB
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 4;
                        end
                    end
                    else if (state_setup_flg == 4)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_data(DIS_RES_Y[7:0]); // end page LSB
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 0;
                            state <= WRITE_PIXELS;
                        end
                    end
                end
                WRITE_PIXELS:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (tx_busy == 0)
                        begin
                            send_command(`MEM_WRITE_CMD);
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            state_setup_flg <= 1;
                            pixel_byte_counter <= 0;
                        end
                    end
                    else
                    begin
                        if (tx_busy == 0)
                        begin
                            send_data(pixel_byte_counter % 2 == 0 ? COLOR[15:8] : COLOR[7:0]); // even = MSB, odd = LSB
                        end
                        else if (tx_start)
                        begin
                            tx_start <= 0;
                            if (pixel_byte_counter == PIXEL_BYTE_COUNT - 1)
                            begin
                                state_setup_flg <= 0;
                                state <= SET_COL_ADDR;
                            end
                            else
                            begin
                                pixel_byte_counter <= pixel_byte_counter + 1;
                            end
                        end
                    end
                end
                default:
                begin
                    state_setup_flg <= 0;
                    state <= HW_RESET;
                end
            endcase
        end
    end
endmodule