`include "ili9341.vh"

module display_controller #(
    parameter HW_RESET_HOLD_TIMER = 0,              // hardware reset hold timer    (suggested: 10 ms)
    parameter HW_RESET_RELEASE_TIMER = 0,           // hardware reset release timer (suggested: 120 ms)
    parameter SW_RESET_TIMER = 0,                   // software reset timer         (suggested 5ms)
    parameter SLEEP_OUT_TIMER = 0,                  // sleep out timer              (suggested 120ms)
    parameter DISPLAY_ON_TIMER = 0,                 // display ON timer             (suggested 10ms)
    parameter DIS_RES_X = 320,                      // horizontal resolution        (default: 320 pixels)
    parameter DIS_RES_Y = 240                       // vertical resolution          (default: 240 pixels)
) (
    input wire clk,
    input wire reset,
    input wire tx_busy,
    output wire dis_reset,                          // display reset
    output wire dc,                                 // data/command
    output wire cs,                                 // display cs
    output reg tx_start,
    output reg[7:0] tx_data
);
    `include "functions.vh"

    // timers
    localparam LONGEST_TIMER = max(HW_RESET_HOLD_TIMER, max(HW_RESET_RELEASE_TIMER, max(SW_RESET_TIMER, max(SLEEP_OUT_TIMER, DISPLAY_ON_TIMER))));

    // states
    localparam HW_RESET             = 4'b0000;                                              // do hardware reset
    localparam SW_RESET             = 4'b0001;                                              // do software reset
    localparam EXIT_SLEEP_MODE      = 4'b0010;                                              // exit sleep mode
    localparam SET_PXL_FMT          = 4'b0011;                                              // set pixel format
    localparam SET_MEM_ACC_CTL      = 4'b0100;                                              // set memory access pattern
    localparam TURN_DISPLAY_ON      = 4'b0101;                                              // turn the display ON
    localparam SET_COL_ADDR         = 4'b0110;                                              // set column address
    localparam SET_PAGE_ADDR        = 4'b0111;                                              // set page address
    localparam WRITE_PIXELS         = 4'b1000;                                              // write pixels
    localparam LAST_STATE           = WRITE_PIXELS;

    localparam END_COLUMN = DIS_RES_X - 1;
    localparam END_PAGE = DIS_RES_Y - 1;
    localparam PIXEL_FORMAT = `RGB565;
    localparam PIXEL_BYTE_COUNT = DIS_RES_X * DIS_RES_Y * 2;                                // two bytes per pixel
    localparam COLOR = 16'hf800;

    reg[$clog2(LAST_STATE):0] state = HW_RESET;
    reg[$clog2(LONGEST_TIMER)-1:0] timer = 0;
    reg[2:0] state_setup_flg = 0;
    reg[$clog2(PIXEL_BYTE_COUNT)-1:0] pixel_byte_counter = 0;
    reg cs_val;
    reg dc_val;
    reg dis_reset_val;

    // simulation-only
    integer frame_counter = 0;

    assign cs = cs_val;
    assign dc = dc_val;
    assign dis_reset = dis_reset_val;

    always @(posedge clk)
    begin
        if (reset)
        begin
`ifdef SIMULATION
            $display("[display_controller              ] - T(%9t) - reset", $time);
`endif
            state_setup_flg <= 0;
            state <= HW_RESET;
            dc_val <= `COMMAND_BIT;
            cs_val <= 1;
            dis_reset_val <= 1;
            timer <= 0;
            tx_data <= 0;
            tx_start <= 0;
            frame_counter <= 0;
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
                        dis_reset_val <= 0;
                        cs_val <= 0;
                        state_setup_flg <= 1;
                        timer <= HW_RESET_HOLD_TIMER - 1;
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (timer == 0)
                        begin
                            dis_reset_val <= 1;
                            cs_val <= 1;
                            state_setup_flg <= 2;
                            timer <= HW_RESET_RELEASE_TIMER - 1;
                        end
                        else
                        begin
                            timer <= timer - 1;
                        end
                    end
                    else
                    begin
                        if (timer == 0)
                        begin
                            cs_val <= 0;
                            state_setup_flg <= 0;
                            state <= SW_RESET;
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
`ifdef SIMULATION
                            if (tx_data != command)
                                $display("[display_controller              ] - T(%9t) - sending command (h%h)", $time, command);
`endif
                            dc_val <= `COMMAND_BIT;
                            tx_data <= `SW_RESET_CMD;
                            tx_start <= 1;
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
                            cs_val <= 1;
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
`ifdef SIMULATION
                            if (tx_data != command)
                                $display("[display_controller              ] - T(%9t) - sending command (h%h)", $time, command);
`endif
                            cs_val <= 0;
                            dc_val <= `COMMAND_BIT;
                            tx_data <= `SLEEP_OUT_CMD;
                            tx_start <= 1;
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
                            cs_val <= 1;
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
`ifdef SIMULATION
                            if (tx_data != command)
                                $display("[display_controller              ] - T(%9t) - sending command (h%h)", $time, command);
`endif
                            cs_val <= 0;
                            dc_val <= `COMMAND_BIT;
                            tx_data <= `SET_PXL_FMT_CMD;
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != data)
                                $display("[display_controller              ] - T(%9t) - sending data (h%h)", $time, data);
`endif
                            cs_val <= 0;
                            dc_val <= `DATA_BIT;
                            tx_data <= PIXEL_FORMAT;
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != command)
                                $display("[display_controller              ] - T(%9t) - sending command (h%h)", $time, command);
`endif
                            cs_val <= 0;
                            dc_val <= `COMMAND_BIT;
                            tx_data <= `MEM_ACC_CTR_CMD;
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != data)
                                $display("[display_controller              ] - T(%9t) - sending data (h%h)", $time, data);
`endif
                            cs_val <= 0;
                            dc_val <= `DATA_BIT;
                            // row address order, column address order, row/col exchange, vertical refresh, RGB-BGR, horizontal refresh
                            tx_data <= {1'b0, 1, 1'b0, 1'b0, 1, 1'b0, 1'b0, 1'b0}; // column, RGB
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != command)
                                $display("[display_controller              ] - T(%9t) - sending command (h%h)", $time, command);
`endif
                            cs_val <= 0;
                            dc_val <= `COMMAND_BIT;
                            tx_data <= `DISPLAY_ON_CMD;
                            tx_start <= 1;
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
                            cs_val <= 1;
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
`ifdef SIMULATION
                            if (tx_data != command)
                                $display("[display_controller              ] - T(%9t) - sending command (h%h)", $time, command);
`endif
                            cs_val <= 0;
                            dc_val <= `COMMAND_BIT;
                            tx_data <= `SET_COL_ADDR_CMD;
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != data)
                                $display("[display_controller              ] - T(%9t) - sending data (h%h)", $time, data);
`endif
                            cs_val <= 0;
                            dc_val <= `DATA_BIT;
                            tx_data <= 8'h00; // start column MSB
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != data)
                                $display("[display_controller              ] - T(%9t) - sending data (h%h)", $time, data);
`endif
                            cs_val <= 0;
                            dc_val <= `DATA_BIT;
                            tx_data <= 8'h00; // start column MSB
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != data)
                                $display("[display_controller              ] - T(%9t) - sending data (h%h)", $time, data);
`endif
                            cs_val <= 0;
                            dc_val <= `DATA_BIT;
                            tx_data <= END_COLUMN[15:8]; // end column MSB
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != data)
                                $display("[display_controller              ] - T(%9t) - sending data (h%h)", $time, data);
`endif
                            cs_val <= 0;
                            dc_val <= `DATA_BIT;
                            tx_data <= END_COLUMN[7:0]; // end column LSB
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != command)
                                $display("[display_controller              ] - T(%9t) - sending command (h%h)", $time, command);
`endif
                            cs_val <= 0;
                            dc_val <= `COMMAND_BIT;
                            tx_data <= `SET_PAGE_ADDR_CMD;
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != data)
                                $display("[display_controller              ] - T(%9t) - sending data (h%h)", $time, data);
`endif
                            cs_val <= 0;
                            dc_val <= `DATA_BIT;
                            tx_data <= 8'h00; // start page MSB
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != data)
                                $display("[display_controller              ] - T(%9t) - sending data (h%h)", $time, data);
`endif
                            cs_val <= 0;
                            dc_val <= `DATA_BIT;
                            tx_data <= 8'h00; // start page LSB
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != data)
                                $display("[display_controller              ] - T(%9t) - sending data (h%h)", $time, data);
`endif
                            cs_val <= 0;
                            dc_val <= `DATA_BIT;
                            tx_data <= END_PAGE[15:8]; // end page MSB
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != data)
                                $display("[display_controller              ] - T(%9t) - sending data (h%h)", $time, data);
`endif
                            cs_val <= 0;
                            dc_val <= `DATA_BIT;
                            tx_data <= END_PAGE[7:0]; // end page LSB
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != command)
                                $display("[display_controller              ] - T(%9t) - sending command (h%h)", $time, command);
`endif
                            cs_val <= 0;
                            dc_val <= `COMMAND_BIT;
                            tx_data <= `MEM_WRITE_CMD;
                            tx_start <= 1;
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
`ifdef SIMULATION
                            if (tx_data != data)
                                $display("[display_controller              ] - T(%9t) - sending data (h%h)", $time, data);
`endif
                            cs_val <= 0;
                            dc_val <= `DATA_BIT;
                            tx_data <= pixel_byte_counter % 2 == 0 ? COLOR[15:8] : COLOR[7:0]; // even = MSB, odd = LSB
                            tx_start <= 1;
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