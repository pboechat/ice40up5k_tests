`ifndef ILI9341_SPI_CONTROLLER_V
`define ILI9341_SPI_CONTROLLER_V

`include "ili9341/ili9341.vh"

module pixel_mem_addr_translator #(
    parameter DISPLAY_X = 1,                      // horizontal resolution
    parameter DISPLAY_Y = 1,                      // vertical resolution
    parameter DOWNSCALE_SHIFT = 0
) (
    input wire clk,
    input wire reset,
    input wire[$clog2(DISPLAY_X)-1:0] x,
    input wire[$clog2(DISPLAY_Y)-1:0] y,
    input wire byte_idx,
    input wire mem_addr_req,
    output reg[31:0] mem_addr,
    output reg mem_addr_ready
);
    localparam Y_STRIDE = (DISPLAY_X >> DOWNSCALE_SHIFT) * 2;

    // states
    localparam IDLE                 = 3'b000;
    localparam DOWNSCALE            = 3'b001;
    localparam ADDR_COMP_0          = 3'b010;
    localparam ADDR_COMP_1          = 3'b011;
    localparam RETURN_ADDR          = 3'b100;
    localparam LAST_STATE           = RETURN_ADDR;

    reg[$clog2(LAST_STATE):0] state;
    reg[$clog2(DISPLAY_X)-DOWNSCALE_SHIFT-1:0] d_x;
    reg[$clog2(DISPLAY_Y)-DOWNSCALE_SHIFT-1:0] d_y;

    always @(posedge clk)
    begin
        if (reset)
        begin
            state <= IDLE;
            mem_addr <= 32'h00000000;
            mem_addr_ready <= 1'b0;
        end
        else
        begin
            case (state)
                IDLE:
                begin
                    mem_addr_ready <= 1'b0;

                    if (mem_addr_req)
                    begin
                        state <= DOWNSCALE;
                    end
                end
                DOWNSCALE:
                begin
                    if (mem_addr_req)
                    begin
                        d_x <= x >> DOWNSCALE_SHIFT;
                        d_y <= y >> DOWNSCALE_SHIFT;
                        state <= ADDR_COMP_0;
                    end
                    else
                    begin
                        state <= IDLE;
                    end
                end
                ADDR_COMP_0: 
                begin
                    if (mem_addr_req)
                    begin
                        mem_addr <= byte_idx + d_x * 2;
                        state <= ADDR_COMP_1;
                    end
                    else
                    begin
                        state <= IDLE;
                    end
                end
                ADDR_COMP_1:
                begin 
                    if (mem_addr_req)
                    begin
                        mem_addr <= mem_addr + d_y * Y_STRIDE;
                        state <= RETURN_ADDR;
                    end
                    else
                    begin
                        state <= IDLE;
                    end
                end
                RETURN_ADDR: 
                begin
                    if (mem_addr_req)
                    begin
                        mem_addr_ready <= 1'b1;
                    end

                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

module ili9341_spi_controller #(
    parameter SYS_CLK_FREQ = 1,
    parameter DISPLAY_X = 1,                      // horizontal resolution
    parameter DISPLAY_Y = 1,                      // vertical resolution
    parameter DOWNSCALE_SHIFT = 0
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
    output wire[31:0] mem_addr,
    output reg mem_req,
    output reg[31:0] display_status,
    output reg frame_ended
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
    localparam SCREEN_BUF_SIZE = DISPLAY_X * DISPLAY_Y * 2; // two bytes per pixel

    reg[$clog2(LAST_STATE):0] state;
    reg[$clog2(LONGEST_TIMER)-1:0] timer;
    reg[2:0] state_setup_flg;
    reg[31:0] param;
    reg[$clog2(DISPLAY_X)-1:0] pixel_x;
    reg[$clog2(DISPLAY_Y)-1:0] pixel_y;
    reg pixel_byte_idx;
    reg pixel_mem_addr_req;
    wire pixel_addr_ready;

    pixel_mem_addr_translator #(
        .DISPLAY_X(DISPLAY_X),
        .DISPLAY_Y(DISPLAY_Y),
        .DOWNSCALE_SHIFT(DOWNSCALE_SHIFT)
    ) pixel_mem_addr_translator_inst (
        .clk(clk),
        .reset(reset),
        .x(pixel_x),
        .y(pixel_y),
        .byte_idx(pixel_byte_idx),
        .mem_addr_req(pixel_mem_addr_req),
        .mem_addr(mem_addr),
        .mem_addr_ready(pixel_addr_ready)
    );

    always @(posedge clk)
    begin
        if (reset)
        begin
            state_setup_flg <= 'd0;
            state <= HW_RESET;
            dc <= `COMMAND_BIT;
            cs <= 1'b1;
            dis_reset <= 1'b1;
            timer <= 1'b0;
            spi_out <= 8'h00;
            spi_start <= 1'b0;
            display_status <= `INVALID_DISPLAY_STATUS;
            mem_req <= 1'b0;
            param <= 32'h00000000;
            frame_ended <= 1'b0;
        end
        else
        begin
            case (state)
                HW_RESET:
                begin
                    if (state_setup_flg == 'd0)
                    begin
                        dis_reset <= 1'b0;
                        cs <= 1'b1;
                        state_setup_flg <= 'd1;
                        timer <= HW_RESET_HOLD_TIMER - 1;
                    end
                    else if (state_setup_flg == 'd1)
                    begin
                        if (~|timer)
                        begin
                            dis_reset <= 1'b1;
                            cs <= 1'b1;
                            state_setup_flg <= 'd2;
                            timer <= HW_RESET_RELEASE_TIMER - 1;
                        end
                        else
                        begin
                            timer <= timer - 1;
                        end
                    end
                    else
                    begin
                        if (~|timer)
                        begin
                            state_setup_flg <= 'd0;
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
                    if (state_setup_flg == 'd0)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `SW_RESET_CMD;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd1;
                        end
                    end
                    else if (state_setup_flg == 'd1)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b1;
                            timer <= SW_RESET_TIMER - 1;
                            state_setup_flg <= 'd2;
                        end
                    end
                    else
                    begin
                        if (~|timer)
                        begin
                            state_setup_flg <= 'd0;
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
                    if (state_setup_flg == 'd0)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `SLPOUT_CMD;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd1;
                        end
                    end
                    else if (state_setup_flg == 'd1)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b1;
                            timer <= SLPOUT_TIMER - 1;
                            state_setup_flg <= 'd2;
                        end
                    end
                    else
                    begin
                        if (~|timer)
                        begin
                            state_setup_flg <= 'd0;
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
                    if (state_setup_flg == 'd0)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `MADCTL_CMD;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd1;
                        end
                    end
                    else if (state_setup_flg == 'd1)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
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
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd2;
                        end
                    end
                    else
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b1;
                            state_setup_flg <= 'd0;
                            state <= COLMOD;
                        end
                    end
                end
                COLMOD:
                begin
                    if (state_setup_flg == 'd0)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `COLMOD_CMD;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd1;
                        end
                    end
                    else if (state_setup_flg == 'd1)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= PIXEL_FORMAT;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd2;
                        end
                    end
                    else
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b1;
                            state_setup_flg <= 'd0;
                            state <= DISPON;
                        end
                    end
                end
                DISPON:
                begin
                    if (state_setup_flg == 'd0)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `DISPON_CMD;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd1;
                        end
                    end
                    else
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b1;
                            state_setup_flg <= 'd0;
                            state <= READ_DISPLAY_STATUS;
                        end
                    end
                end
                READ_DISPLAY_STATUS:
                begin
                    if (state_setup_flg == 'd0)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `READ_DISPLAY_STATUS_CMD;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd1;
                        end
                    end
                    else if (state_setup_flg == 'd1)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= 1'b0;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd2;
                        end
                    end
                    else if (state_setup_flg == 'd2)
                    begin
                        if (~|spi_busy)
                        begin
                            // ignore parameter 1

                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= 8'h00;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd3;
                        end
                    end
                    else if (state_setup_flg == 'd3)
                    begin
                        if (~|spi_busy)
                        begin
                            param[31:24] <= spi_in; // parameter 2

                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= 8'h00;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd4;
                        end
                    end
                    else if (state_setup_flg == 'd4)
                    begin
                        if (~|spi_busy)
                        begin
                            param[23:16] <= spi_in; // parameter 3

                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= 8'h00;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd5;
                        end
                    end
                    else if (state_setup_flg == 'd5)
                    begin
                        if (~|spi_busy)
                        begin
                            param[15:8] <= spi_in; // parameter 4

                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= 8'h00;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd6;
                        end
                    end
                    else
                    begin
                        if (~|spi_busy)
                        begin
                            param[7:0] <= spi_in;
                            display_status <= {param[31:8], spi_in};

                            cs <= 1'b1;
                            state_setup_flg <= 'd0;
                            state <= CASET;
                        end
                    end
                end
                CASET:
                begin
                    if (state_setup_flg == 'd0)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `CASET_CMD;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd1;
                        end
                    end
                    else if (state_setup_flg == 'd1)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= 8'h00; // start column MSB
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd2;
                        end
                    end
                    else if (state_setup_flg == 'd2)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= 8'h00; // start column MSB
                            spi_start <= 1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd3;
                        end
                    end
                    else if (state_setup_flg == 'd3)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= DISPLAY_X[15:8]; // end column MSB
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd4;
                        end
                    end
                    else if (state_setup_flg == 'd4)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= DISPLAY_X[7:0]; // end column LSB
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd5;
                        end
                    end
                    else
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b1;
                            state_setup_flg <= 'd0;
                            state <= PASET;
                        end
                    end
                end
                PASET:
                begin
                    if (state_setup_flg == 'd0)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `PASET_CMD;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd1;
                        end
                    end
                    else if (state_setup_flg == 'd1)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= 8'h00; // start page MSB
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd2;
                        end
                    end
                    else if (state_setup_flg == 'd2)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= 8'h00; // start page LSB
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd3;
                        end
                    end
                    else if (state_setup_flg == 'd3)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= DISPLAY_Y[15:8]; // end page MSB
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd4;
                        end
                    end
                    else if (state_setup_flg == 'd4)
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_out <= DISPLAY_Y[7:0]; // end page LSB
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            state_setup_flg <= 'd5;
                        end
                    end
                    else
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b1;
                            state_setup_flg <= 'd0;
                            state <= MEMWRITE;
                        end
                    end
                end
                MEMWRITE:
                begin
                    if (state_setup_flg == 'd0)
                    begin
                        frame_ended <= 1'b0;

                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `COMMAND_BIT;
                            spi_out <= `MEMWRITE_CMD;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;
                            
                            pixel_x <= 'b0;
                            pixel_y <= 'b0;
                            pixel_byte_idx <= 1'b0;
                            pixel_mem_addr_req <= 1'b1;

                            state_setup_flg <= 'd1;
                        end
                    end
                    else if (state_setup_flg == 'd1)
                    begin
                        if (pixel_addr_ready)
                        begin
                            pixel_mem_addr_req <= 1'b0;
                            mem_req <= 1'b1;

                            state_setup_flg <= 'd2;
                        end
                    end
                    else if (state_setup_flg == 'd2)
                    begin
                        if (mem_ready)
                        begin
                            spi_out <= mem_in;
                            mem_req <= 1'b0;

                            state_setup_flg <= 'd3;
                        end
                    end
                    else
                    begin
                        if (~|spi_busy)
                        begin
                            cs <= 1'b0;
                            dc <= `DATA_BIT;
                            spi_start <= 1'b1;
                        end
                        else if (spi_start)
                        begin
                            spi_start <= 1'b0;

                            if (~|pixel_byte_idx)
                            begin
                                pixel_byte_idx <= 1'b1;
                                pixel_mem_addr_req <= 1'b1;

                                state_setup_flg <= 'd1;
                            end
                            else
                            begin
                                if (pixel_x < (DISPLAY_X - 1))
                                begin
                                    pixel_x <= pixel_x + 1;
                                    pixel_byte_idx <= 1'b0;
                                    pixel_mem_addr_req <= 1'b1;

                                    state_setup_flg <= 'd1;
                                end
                                else if (pixel_y < (DISPLAY_Y - 1))
                                begin
                                    pixel_x <= 'b0;
                                    pixel_y <= pixel_y + 1;
                                    pixel_byte_idx <= 1'b0;
                                    pixel_mem_addr_req <= 1'b1;

                                    state_setup_flg <= 'd1;
                                end
                                else
                                begin
                                    frame_ended <= 1'b1;
                                    state_setup_flg <= 'd0;
                                end
                            end
                        end
                    end
                end
                default:
                begin
                    state_setup_flg <= 'd0;
                    state <= HW_RESET;
                end
            endcase
        end
    end
endmodule

`endif