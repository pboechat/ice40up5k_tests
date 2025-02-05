`include "ili9341.vh"

module display_controller #(
    parameter SYS_CLK_FREQ = 0,
    parameter DIS_RES_X = 1,                      // horizontal resolution
    parameter DIS_RES_Y = 1                       // vertical resolution
) (
    input wire clk,
    input wire reset,
    input wire busy,
    input wire[7:0] data_in,
    output reg dis_reset,                          // display reset
    output reg dc,                                 // data/command
    output reg cs,                                 // display cs
    output reg start,
    output reg[7:0] data_out
);
    `include "functions.vh"

    localparam HW_RESET_HOLD_TIMER = SYS_CLK_FREQ / 100000; // 10 us
    localparam HW_RESET_RELEASE_TIMER = SYS_CLK_FREQ / (1000 / 5); // 5 ms
    localparam SW_RESET_TIMER = SYS_CLK_FREQ / (1000 / 5); // 5 ms
    localparam SLEEP_OUT_TIMER  = SYS_CLK_FREQ / (1000 / 120); // 120 ms

    // timers
    localparam LONGEST_TIMER = max(HW_RESET_HOLD_TIMER, max(HW_RESET_RELEASE_TIMER, max(SW_RESET_TIMER, SLEEP_OUT_TIMER)));

    // states
    localparam HW_RESET             = 4'b0000;                                              // do hardware reset
    localparam SW_RESET             = 4'b0001;                                              // do software reset
    localparam EXIT_SLEEP_MODE      = 4'b0010;                                              // exit sleep mode
    localparam READ_DISPLAY_STATUS  = 4'b0011;                                              // read display status
    localparam SET_PXL_FMT          = 4'b0100;                                              // set pixel format
    localparam SET_MEM_ACC_CTL      = 4'b0101;                                              // set memory access pattern
    localparam TURN_DISPLAY_ON      = 4'b0110;                                              // turn the display ON
    localparam SET_COL_ADDR         = 4'b0111;                                              // set column address
    localparam SET_PAGE_ADDR        = 4'b1000;                                              // set page address
    localparam WRITE_PIXELS         = 4'b1001;                                              // write pixels
    localparam LAST_STATE           = WRITE_PIXELS;

    localparam PIXEL_FORMAT = `RGB565;
    localparam PIXEL_BYTE_COUNT = DIS_RES_X * DIS_RES_Y * 2;                                // two bytes per pixel
    localparam COLOR = {5'b11111, 6'b000000, 5'b00000};

    reg[$clog2(LAST_STATE):0] state;
    reg[$clog2(LONGEST_TIMER)-1:0] timer;
    reg[2:0] state_setup_flg;
    reg[$clog2(PIXEL_BYTE_COUNT)-1:0] pixel_byte_counter;
    reg[31:0] display_status;

    always @(posedge clk)
    begin
        if (reset)
        begin
            state_setup_flg <= 0;
            state <= HW_RESET;
            dc <= `COMMAND_BIT;
            cs <= 1;
            dis_reset <= 1;
            timer <= 0;
            data_out <= 0;
            start <= 0;
        end
        else
        begin
            case (state)
                HW_RESET:
                begin
                    if (state_setup_flg == 0)
                    begin
                        dis_reset <= 0;
                        cs <= 1;
                        state_setup_flg <= 1;
                        timer <= HW_RESET_HOLD_TIMER - 1;
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (timer == 0)
                        begin
                            dis_reset <= 1;
                            cs <= 1;
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
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            data_out <= `SW_RESET_CMD;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 1;
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
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            data_out <= `SLEEP_OUT_CMD;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 1;
                            timer <= SLEEP_OUT_TIMER - 1;
                            state_setup_flg <= 2;
                        end
                    end
                    else
                    begin
                        if (timer == 0)
                        begin
                            state_setup_flg <= 0;
                            state <= READ_DISPLAY_STATUS;
                        end
                        else
                        begin
                            timer <= timer - 1;
                        end
                    end
                end
                READ_DISPLAY_STATUS:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            data_out <= `READ_DISPLAY_STATUS_CMD;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (busy == 0)
                        begin
                            dc <= `DATA_BIT;
                            data_out <= 0;
                            cs <= 0;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else if (state_setup_flg == 2)
                    begin
                        if (busy == 0)
                        begin
                            // ignore parameter 1

                            dc <= `DATA_BIT;
                            data_out <= 0;
                            cs <= 0;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 3;
                        end
                    end
                    else if (state_setup_flg == 3)
                    begin
                        if (busy == 0)
                        begin
                            display_status[31:25] <= data_in[7:1]; // parameter 2

                            dc <= `DATA_BIT;
                            data_out <= 0;
                            cs <= 0;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 4;
                        end
                    end
                    else if (state_setup_flg == 4)
                    begin
                        if (busy == 0)
                        begin
                            display_status[22:16] <= data_in[6:0]; // parameter 3

                            dc <= `DATA_BIT;
                            data_out <= 0;
                            cs <= 0;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 5;
                        end
                    end
                    else if (state_setup_flg == 5)
                    begin
                        if (busy == 0)
                        begin
                            display_status[10:8] <= data_in[2:0]; // parameter 4

                            dc <= `DATA_BIT;
                            data_out <= 0;
                            cs <= 0;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 6;
                        end
                    end
                    else
                    begin
                        if (busy == 0)
                        begin
                            display_status[7:5] <= data_in[7:5]; // parameter 5

                            cs <= 1;
                            state_setup_flg <= 0;
                            state <= SET_PXL_FMT;
                        end
                    end
                end
                SET_PXL_FMT:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            data_out <= `SET_PXL_FMT_CMD;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            data_out <= PIXEL_FORMAT;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else
                    begin
                        if (busy == 0)
                        begin
                            cs <= 1;
                            state_setup_flg <= 0;
                            state <= SET_MEM_ACC_CTL;
                        end
                    end
                end
                SET_MEM_ACC_CTL:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            data_out <= `MEM_ACC_CTR_CMD;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            // row address order
                            // column address order 
                            // row/col exchange
                            // vertical refresh
                            // RGB-BGR
                            // horizontal refresh
                            data_out <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0}; // RGB
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else
                    begin
                        if (busy == 0)
                        begin
                            cs <= 1;
                            state_setup_flg <= 0;
                            state <= TURN_DISPLAY_ON;
                        end
                    end
                end
                TURN_DISPLAY_ON:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            data_out <= `DISPLAY_ON_CMD;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else
                    begin
                        if (busy == 0)
                        begin
                            cs <= 1;
                            state_setup_flg <= 0;
                            state <= SET_COL_ADDR;
                        end
                    end
                end
                SET_COL_ADDR:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            data_out <= `SET_COL_ADDR_CMD;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            data_out <= 8'h00; // start column MSB
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else if (state_setup_flg == 2)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            data_out <= 8'h00; // start column MSB
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 3;
                        end
                    end
                    else if (state_setup_flg == 3)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            data_out <= DIS_RES_X[15:8]; // end column MSB
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 4;
                        end
                    end
                    else if (state_setup_flg == 4)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            data_out <= DIS_RES_X[7:0]; // end column LSB
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 5;
                        end
                    end
                    else
                    begin
                        if (busy == 0)
                        begin
                            cs <= 1;
                            state_setup_flg <= 0;
                            state <= SET_PAGE_ADDR;
                        end
                    end
                end
                SET_PAGE_ADDR:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            data_out <= `SET_PAGE_ADDR_CMD;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            data_out <= 8'h00; // start page MSB
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else if (state_setup_flg == 2)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            data_out <= 8'h00; // start page LSB
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 3;
                        end
                    end
                    else if (state_setup_flg == 3)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            data_out <= DIS_RES_Y[15:8]; // end page MSB
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 4;
                        end
                    end
                    else if (state_setup_flg == 4)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            data_out <= DIS_RES_Y[7:0]; // end page LSB
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 5;
                        end
                    end
                    else
                    begin
                        if (busy == 0)
                        begin
                            cs <= 1;
                            state_setup_flg <= 0;
                            state <= WRITE_PIXELS;
                        end
                    end
                end
                WRITE_PIXELS:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            data_out <= `MEM_WRITE_CMD;
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            state_setup_flg <= 1;
                            pixel_byte_counter <= PIXEL_BYTE_COUNT - 1;
                        end
                    end
                    else if (pixel_byte_counter == 0)
                    begin
                        if (busy == 0)
                        begin
                            state_setup_flg <= 0;
                            state <= SET_COL_ADDR;
                        end
                    end
                    else
                    begin
                        if (busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            data_out <= pixel_byte_counter % 2 == 0 ? COLOR[7:0] : COLOR[15:8]; // even = LSB, odd = MSB
                            start <= 1;
                        end
                        else if (start)
                        begin
                            start <= 0;
                            pixel_byte_counter <= pixel_byte_counter - 1;
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