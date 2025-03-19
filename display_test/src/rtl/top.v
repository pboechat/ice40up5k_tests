`include "ili9341/ili9341_spi_controller.v"
`include "spi/spi_master_controller.v"
`include "uart_dbg.v"
`include "single_port_ram.v"

// procedural image (rainbow)
//`define PROC_IMAGE

module top(
    input wire clk,                         // 12 MHz external clock oscillator
    input wire reset,                       // reset
    input wire so,                          // SPI serial output
    output wire dc,                         // data/command
    output wire dis_reset,                  // display reset
    output wire sck,                        // SPI SCK
    output wire cs,                         // SPI chip select
    output wire si                          // SPI serial input
`ifdef DEBUG
    , output wire tx                        // UART TX output
    , output wire RGB0,
    output wire RGB1, 
    output wire RGB2
`endif
);
    localparam SYS_CLK_FREQ = 12_000_000;
    localparam SPI_CLK_DIVIDER = 6;

    localparam DISPLAY_X = 320;
    localparam DISPLAY_Y = 240;
    localparam DOWNSCALE_SHIFT = 3;

    localparam IMAGE_BUF_X = DISPLAY_X >> DOWNSCALE_SHIFT;
    localparam IMAGE_BUF_Y = DISPLAY_Y >> DOWNSCALE_SHIFT;
    localparam IMAGE_BUF_SIZE = IMAGE_BUF_X * IMAGE_BUF_Y * 2;

    // rainbow colors

    localparam NUM_COLORS = 12;
    
    localparam RED = {5'b11111, 6'b000000, 5'b00000};
    localparam ORANGE = {5'b11111, 6'b011111, 5'b00000};
    localparam YELLOW = {5'b11111, 6'b111111, 5'b00000};
    localparam LIME_GREEN = {5'b01111, 6'b111111, 5'b00000};
    localparam GREEN = {5'b00000, 6'b111111, 5'b00000};
    localparam TURQUOISE = {5'b00000, 6'b111111, 5'b01111};
    localparam CYAN = {5'b00000, 6'b111111, 5'b11111};
    localparam AZURE = {5'b00000, 6'b011111, 5'b11111};
    localparam BLUE = {5'b00000, 6'b000000, 5'b11111};
    localparam VIOLET = {5'b01111, 6'b000000, 5'b11111};
    localparam MAGENTA = {5'b11111, 6'b000000, 5'b11111};
    localparam RASPBERRY = {5'b11111, 6'b000000, 5'b01111};

    localparam BYTES_PER_ROW = IMAGE_BUF_X * 2;
    localparam ROWS_PER_COLOR = IMAGE_BUF_Y / NUM_COLORS;
    localparam COLOR_BOUNDARY = BYTES_PER_ROW * ROWS_PER_COLOR;

    wire clk;
    wire spi_busy;
    wire spi_start;
    wire[7:0] spi_in;
    wire[7:0] spi_out;
    wire[31:0] mem_addr;
    wire cs0;
    wire cs1;
    wire raw_tx;
    wire raw_sck;
    reg[7:0] mem_out;
`ifdef DEBUG
    wire[31:0] display_status;
    reg dbg_wr;
    reg[7:0] dbg_msg;
    reg[2:0] display_status_tx_step;
    reg[31:0] last_seen_display_status;
    reg b, g, r;
`endif

    assign cs = cs0 | cs1; // cs is shared between SPI and display controllers

    SB_IO #(
        .PIN_TYPE(6'b0110_01), // simple output
    ) tx_buf (
        .PACKAGE_PIN(tx),
        .D_OUT_0(raw_tx)
    );

    SB_IO #(
        .PIN_TYPE(6'b0101_01), // registered output
    ) sck_buf (
        .PACKAGE_PIN(sck),
        .CLOCK_ENABLE(1'b1),
        .OUTPUT_CLK(clk),
        .D_OUT_0(raw_sck)
    );

`ifdef PROC_IMAGE
    always @(posedge clk)
    begin
        if (mem_addr < COLOR_BOUNDARY)
        begin
            mem_out <= mem_addr[0] ? RED[7:0] : RED[15:8];
        end
        else if (mem_addr < (2 * COLOR_BOUNDARY))
        begin
            mem_out <= mem_addr[0] ? ORANGE[7:0] : ORANGE[15:8];
        end
        else if (mem_addr < (3 * COLOR_BOUNDARY))
        begin
            mem_out <= mem_addr[0] ? YELLOW[7:0] : YELLOW[15:8];
        end
        else if (mem_addr < (4 * COLOR_BOUNDARY))
        begin
            mem_out <= mem_addr[0] ? LIME_GREEN[7:0] : LIME_GREEN[15:8];
        end
        else if (mem_addr < (5 * COLOR_BOUNDARY))
        begin
            mem_out <= mem_addr[0] ? GREEN[7:0] : GREEN[15:8];
        end
        else if (mem_addr < (6 * COLOR_BOUNDARY))
        begin
            mem_out <= mem_addr[0] ? TURQUOISE[7:0] : TURQUOISE[15:8];
        end
        else if (mem_addr < (7 * COLOR_BOUNDARY))
        begin
            mem_out <= mem_addr[0] ? CYAN[7:0] : CYAN[15:8];
        end
        else if (mem_addr < (8 * COLOR_BOUNDARY))
        begin
            mem_out <= mem_addr[0] ? AZURE[7:0] : AZURE[15:8];
        end
        else if (mem_addr < (9 * COLOR_BOUNDARY))
        begin
            mem_out <= mem_addr[0] ? BLUE[7:0] : BLUE[15:8];
        end
        else if (mem_addr < (10 * COLOR_BOUNDARY))
        begin
            mem_out <= mem_addr[0] ? VIOLET[7:0] : VIOLET[15:8];
        end
        else if (mem_addr < (11 * COLOR_BOUNDARY))
        begin
            mem_out <= mem_addr[0] ? MAGENTA[7:0] : MAGENTA[15:8];
        end
        else
        begin
            mem_out <= mem_addr[0] ? RASPBERRY[7:0] : RASPBERRY[15:8];
        end
    end
`else
    single_port_ram #(
        .WIDTH(8),
        .DEPTH(IMAGE_BUF_SIZE),
        .ADDR_WIDTH(32),
        .INIT_FILE("display_test/data/tv_card.r5g6b5")
    ) imagebuf_0_inst (
        .clk(clk),
        .we(1'b0),
        .addr(mem_addr),
        .data_in(),
        .data_out(mem_out)
    );
`endif

    ili9341_spi_controller #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ),
        .DISPLAY_X(DISPLAY_X),
        .DISPLAY_Y(DISPLAY_Y),
        .DOWNSCALE_SHIFT(DOWNSCALE_SHIFT)
    ) ili9341_spi_controller_inst (
        .clk(clk),
        .reset(reset),
        .spi_busy(spi_busy),
        .spi_in(spi_out),
        .mem_in(mem_out),
        .dis_reset(dis_reset),
        .dc(dc),
        .cs(cs0),
        .spi_start(spi_start),
        .spi_out(spi_in),
        .mem_addr(mem_addr)
`ifdef DEBUG
        , .display_status(display_status)
`endif
    );

    spi_master_controller #(
        .CLK_DIVIDER(SPI_CLK_DIVIDER)
    ) spi_master_controller_inst (
        .clk(clk),
        .reset(reset),
        .start(spi_start),
        .data_in(spi_in),
        .data_out(spi_out),
        .busy(spi_busy),
        .cs(cs1),
        .sck(raw_sck),
        .mosi(si),
        .miso(so)
    );

`ifdef DEBUG
    uart_dbg #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ),
        .BAUD_RATE(115_200),
        .MSG_QUEUE_SIZE(8)
    ) uart_dbg_inst (
        .clk(clk),
        .reset(reset),
        .wr(dbg_wr),
        .msg(dbg_msg),
        .tx(raw_tx)
    );

    always @(posedge clk)
    begin
        if (reset)
        begin
            b <= 1'b0;
            g <= 1'b0;
            r <= 1'b1;
            dbg_wr <= 1'b0;
            dbg_msg <= 8'h00;
            display_status_tx_step <= 'b0;
            last_seen_display_status <= `INVALID_DISPLAY_STATUS;
        end
        else
        begin
            b <= 1'b0;
            g <= 1'b1;
            r <= 1'b0;
            if (last_seen_display_status != display_status)
            begin
                if (~dbg_wr)
                begin
                    if (display_status_tx_step == 'd0)
                    begin
                        dbg_msg <= display_status[31:24];
                        display_status_tx_step <= 'd1;
                        dbg_wr <= 1'b1;
                    end
                    else if (display_status_tx_step == 'd1)
                    begin
                        dbg_msg <= display_status[23:16];
                        display_status_tx_step <= 'd2;
                        dbg_wr <= 1'b1;
                    end
                    else if (display_status_tx_step == 'd2)
                    begin
                        dbg_msg <= display_status[15:8];
                        display_status_tx_step <= 'd3;
                        dbg_wr <= 1'b1;
                    end
                    else if (display_status_tx_step == 'd3)
                    begin
                        dbg_msg <= display_status[7:0];
                        display_status_tx_step <= 'd4;
                        dbg_wr <= 1'b1;
                    end
                end
                else
                begin
                    if (display_status_tx_step == 'd4)
                    begin
                        display_status_tx_step <= 'd0;
                        last_seen_display_status <= display_status;
                    end
                    dbg_wr <= 1'b0;
                end
            end
        end
    end

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),               // half current mode
        .RGB0_CURRENT("0b000111"),          // 12 mA
        .RGB1_CURRENT("0b000111"),          // 12 mA
        .RGB2_CURRENT("0b000111")           // 12 mA
    ) rgb_driver(
        .CURREN(1'b1),                      // enable current
        .RGBLEDEN(1'b1),                    // enable LED driver
        .RGB0PWM(b),                        // blue PWM input
        .RGB1PWM(g),                        // green PWM input
        .RGB2PWM(r),                        // red PWM input
        .RGB0(RGB0),                        // blue output
        .RGB1(RGB1),                        // green output
        .RGB2(RGB2)                         // red output
    );
`endif
endmodule