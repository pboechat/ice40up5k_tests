`include "ili9341.vh"

module display_controller #(
    parameter SYS_CLK_FREQ = 1,
    parameter DIS_RES_X = 1,                      // horizontal resolution
    parameter DIS_RES_Y = 1                       // vertical resolution
) (
    input wire clk,
    input wire reset,
    input wire spi_busy,
    input wire[7:0] spi_in,
    input wire[7:0] mem_in,
    input wire mem_ready,
    output reg dis_reset,                          // display reset
    output reg dc,                                 // data/command
    output reg cs,                                 // display cs
    output reg spi_start,
    output reg[7:0] spi_out,
    output reg[31:0] mem_addr,
    output reg mem_req,
    output reg[31:0] display_status
);
    `include "functions.vh"

    localparam HW_RESET_HOLD_TIMER = SYS_CLK_FREQ / 100000;         // 10 us
    localparam HW_RESET_RELEASE_TIMER = SYS_CLK_FREQ / (1000 / 5);  // 5 ms
    localparam SW_RESET_TIMER = SYS_CLK_FREQ / (1000 / 5);          // 5 ms
    localparam SLPOUT_TIMER  = SYS_CLK_FREQ / (1000 / 120);         // 120 ms

    // timers
    localparam LONGEST_TIMER = max(HW_RESET_HOLD_TIMER, max(HW_RESET_RELEASE_TIMER, max(SW_RESET_TIMER, SLPOUT_TIMER)));

    // states
    localparam HW_RESET             = 4'b0000;  // do hardware reset
    localparam SW_RESET             = 4'b0001;  // do software reset
    localparam SLPOUT               = 4'b0010;  // exit sleep mode
    localparam MADCTL               = 4'b0011;  // set memory access pattern
    localparam COLMOD               = 4'b0100;  // set pixel format
    localparam DISPON               = 4'b0101;  // turn the display ON
    localparam READ_DISPLAY_STATUS  = 4'b0110;  // read display status
    localparam CASET                = 4'b0111;  // set column address
    localparam PASET                = 4'b1000;  // set page address
    localparam MEMWRITE             = 4'b1001;  // write memory
    localparam LAST_STATE           = MEMWRITE;

    localparam PIXEL_FORMAT = `RGB565;
    localparam SCREEN_BUF_SIZE = DIS_RES_X * DIS_RES_Y * 2; // two bytes per pixel

    reg[$clog2(LAST_STATE):0] state;
    reg[$clog2(LONGEST_TIMER)-1:0] timer;
    reg[2:0] state_setup_flg;
    reg[31:0] param;

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
            spi_out <= 0;
            spi_start <= 0;
            display_status <= `INVALID_DISPLAY_STATUS;
            mem_addr <= 0;
            mem_req <= 0;
            param <= 0;
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
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `SW_RESET_CMD;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (spi_busy == 0)
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
                            state <= SLPOUT;
                        end
                        else
                        begin
                            timer <= timer - 1;
                        end
                    end
                end
                SLPOUT:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `SLPOUT_CMD;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 1;
                            timer <= SLPOUT_TIMER - 1;
                            state_setup_flg <= 2;
                        end
                    end
                    else
                    begin
                        if (timer == 0)
                        begin
                            state_setup_flg <= 0;
                            state <= MADCTL;
                        end
                        else
                        begin
                            timer <= timer - 1;
                        end
                    end
                end
                MADCTL:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `MADCTL_CMD;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            // 0 - row address order        (0=top to bottom, 1=bottom to top)
                            // 1 - column address order     (0=left to right, 1=right to left)
                            // 2 - row/col exchange         (0=normal, 1=reverse)
                            // 3 - vertical refresh         (0=top to bottom, 1=bottom to top)
                            // 4 - BGR-RGB                  (0=BGR, 1=RGB)
                            // 5 - horizontal refresh       (0=left to right, 0=right to left)
                            // 6 - unused
                            // 7 - unused
                            // enable reverse mode & RGB
                            spi_out <= 8'b0_0_1_0_1_0_0_0;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 1;
                            state_setup_flg <= 0;
                            state <= COLMOD;
                        end
                    end
                end
                COLMOD:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `COLMOD_CMD;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= PIXEL_FORMAT;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 1;
                            state_setup_flg <= 0;
                            state <= DISPON;
                        end
                    end
                end
                DISPON:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `DISPON_CMD;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 1;
                            state_setup_flg <= 0;
                            state <= READ_DISPLAY_STATUS;
                        end
                    end
                end
                READ_DISPLAY_STATUS:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `READ_DISPLAY_STATUS_CMD;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= 0;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else if (state_setup_flg == 2)
                    begin
                        if (spi_busy == 0)
                        begin
                            // ignore parameter 1

                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= 0;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 3;
                        end
                    end
                    else if (state_setup_flg == 3)
                    begin
                        if (spi_busy == 0)
                        begin
                            param[31:24] <= spi_in; // parameter 2

                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= 0;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 4;
                        end
                    end
                    else if (state_setup_flg == 4)
                    begin
                        if (spi_busy == 0)
                        begin
                            param[23:16] <= spi_in; // parameter 3

                            dc <= `DATA_BIT;
                            spi_out <= 0;
                            cs <= 0;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 5;
                        end
                    end
                    else if (state_setup_flg == 5)
                    begin
                        if (spi_busy == 0)
                        begin
                            param[15:8] <= spi_in; // parameter 4

                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= 0;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 6;
                        end
                    end
                    else
                    begin
                        if (spi_busy == 0)
                        begin
                            param[7:0] <= spi_in;
                            display_status <= {param[31:8], spi_in};

                            cs <= 1;
                            state_setup_flg <= 0;
                            state <= CASET;
                        end
                    end
                end
                CASET:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `CASET_CMD;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= 8'h00; // spi_start column MSB
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else if (state_setup_flg == 2)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= 8'h00; // spi_start column MSB
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 3;
                        end
                    end
                    else if (state_setup_flg == 3)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= DIS_RES_X[15:8]; // end column MSB
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 4;
                        end
                    end
                    else if (state_setup_flg == 4)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= DIS_RES_X[7:0]; // end column LSB
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 5;
                        end
                    end
                    else
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 1;
                            state_setup_flg <= 0;
                            state <= PASET;
                        end
                    end
                end
                PASET:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `PASET_CMD;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= 8'h00; // spi_start page MSB
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 2;
                        end
                    end
                    else if (state_setup_flg == 2)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= 8'h00; // spi_start page LSB
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 3;
                        end
                    end
                    else if (state_setup_flg == 3)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= DIS_RES_Y[15:8]; // end page MSB
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 4;
                        end
                    end
                    else if (state_setup_flg == 4)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_out <= DIS_RES_Y[7:0]; // end page LSB
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            state_setup_flg <= 5;
                        end
                    end
                    else
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 1;
                            state_setup_flg <= 0;
                            state <= MEMWRITE;
                        end
                    end
                end
                MEMWRITE:
                begin
                    if (state_setup_flg == 0)
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `MEMWRITE_CMD;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;
                            
                            mem_addr <= 0;
                            mem_req <= 1;

                            state_setup_flg <= 1;
                        end
                    end
                    else if (state_setup_flg == 1)
                    begin
                        if (mem_ready)
                        begin
                            spi_out <= mem_in;
                            mem_req <= 0;

                            state_setup_flg <= 2;
                        end
                    end
                    else
                    begin
                        if (spi_busy == 0)
                        begin
                            cs <= 0;
                            dc <= `DATA_BIT;
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 0;

                            if (mem_addr == (SCREEN_BUF_SIZE - 1))
                            begin
                                state_setup_flg <= 0;
                                state <= MEMWRITE;
                            end
                            else
                            begin
                                mem_addr <= mem_addr + 1;
                                mem_req <= 1;

                                state_setup_flg <= 1;
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