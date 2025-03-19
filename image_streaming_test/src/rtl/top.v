`include "ili9341/ili9341_spi_controller.v"
`include "spi/spi_master_controller.v"
`include "uart/uart_rx.v"
`include "uart/uart_tx.v"
`include "single_port_ram.v"

module top(
    input wire clk,                         // 12 MHz external clock oscillator
    input wire reset,                       // reset
    input wire so,                          // SPI serial output
    input wire rx,                          // UART RX output
    output wire dc,                         // data/command
    output wire dis_reset,                  // display reset
    output wire sck,                        // SPI SCK
    output wire cs,                         // SPI chip select
    output wire si,                         // SPI serial input
    output wire tx                          // UART TX output
`ifdef DEBUG
    , output wire RGB0,
    output wire RGB1, 
    output wire RGB2
`endif
);
    localparam SYS_CLK_FREQ = 12_000_000;
    localparam SPI_CLK_DIVIDER = 6;
    localparam BAUD_RATE = 115_200;

    localparam DISPLAY_X = 320;
    localparam DISPLAY_Y = 240;
    localparam DOWNSCALE_SHIFT = 3;
    
    localparam IMAGE_BUF_X = DISPLAY_X >> DOWNSCALE_SHIFT;
    localparam IMAGE_BUF_Y = DISPLAY_Y >> DOWNSCALE_SHIFT;
    localparam IMAGE_BUF_SIZE = IMAGE_BUF_X * IMAGE_BUF_Y * 2;

    wire spi_busy;
    wire spi_start;
    wire[7:0] spi_in;
    wire[7:0] spi_out;
    wire cs0;
    wire cs1;
    wire raw_sck;
    wire raw_rx;
    wire[7:0] rx_data;
    wire rx_ready;
    wire raw_tx;
    wire[7:0] tx_data;
    wire tx_busy;
    wire tx_ready;
    wire streaming_ended;
    wire frame_ended;
    wire[7:0] frontbuf_out;
    wire[7:0] backbuf_in;
    wire[31:0] frontbuf_addr;
    wire[31:0] backbuf_addr;
    wire imagebuf_0_we;
    wire imagebuf_1_we;
    wire[7:0] imagebuf_0_out;
    wire[7:0] imagebuf_1_out;
    wire[7:0] imagebuf_0_in;
    wire[7:0] imagebuf_1_in;
    wire[31:0] imagebuf_0_addr;
    wire[31:0] imagebuf_1_addr;
    reg frontbuf;
    reg swap_req;
`ifdef DEBUG
    wire r, g, b;
    reg b0, g0, r0;
    reg b1, g1, r1;
`endif

    assign cs = cs0 | cs1; // cs is shared between SPI and display controllers

`ifdef DEBUG
    assign r = r0 | r1;
    assign g = g0 | g1;
    assign b = b0 | b1;
`endif

    assign imagebuf_0_we    = frontbuf == 1'b1; // frontbuf is read-only
    assign imagebuf_1_we    = frontbuf == 1'b0; // frontbuf is read-only
    assign frontbuf_out     = frontbuf == 1'b0 ? imagebuf_0_out : imagebuf_1_out;
    assign imagebuf_0_in    = frontbuf == 1'b0 ? 1'b0 : backbuf_in; // frontbuf is read-only
    assign imagebuf_1_in    = frontbuf == 1'b0 ? backbuf_in : 1'b0; // frontbuf is read-only
    assign imagebuf_0_addr  = frontbuf == 1'b0 ? frontbuf_addr : backbuf_addr;
    assign imagebuf_1_addr  = frontbuf == 1'b0 ? backbuf_addr : frontbuf_addr;

    SB_IO #(
        .PIN_TYPE(6'b0000_01), // simple input
        .PULLUP(1'b1)
    ) rx_buf (
        .PACKAGE_PIN(rx),
        .D_IN_0(raw_rx),
    );

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

    // imagebuf signal redirection
    always @(posedge clk)
    begin
        if (reset)
        begin
            frontbuf <= 1'b0;
            swap_req <= 1'b0;
        end
        else if (streaming_ended)
        begin
            if (frame_ended)
            begin
                frontbuf = ~frontbuf;
            end
            else
            begin
                swap_req <= 1'b1;
            end
        end
        else if (swap_req)
        begin
            if (frame_ended)
            begin
                frontbuf = ~frontbuf;
                swap_req <= 1'b0;
            end
        end
    end

    uart_rx #(
        .BAUD_RATE(BAUD_RATE),
        .SYS_CLK_FREQ(SYS_CLK_FREQ)
    ) uart_rx_inst(
        .clk(clk),
        .reset(reset),
        .rx(raw_rx),
        .data_out(rx_data),
        .ready(rx_ready)
    );

    uart_tx #(
        .BAUD_RATE(BAUD_RATE),
        .SYS_CLK_FREQ(SYS_CLK_FREQ)
    ) uart_tx_inst(
        .clk(clk),
        .reset(reset),
        .data_in(tx_data),
        .send(tx_ready),
        .tx(raw_tx),
        .busy(tx_busy)
    );

    single_port_ram #(
        .WIDTH(8),
        .DEPTH(IMAGE_BUF_SIZE),
        .ADDR_WIDTH(32),
        .INIT_FILE("image_streaming_test/data/frontbuf.r5g6b5")
    ) imagebuf_0_inst (
        .clk(clk),
        .we(imagebuf_0_we),
        .addr(imagebuf_0_addr),
        .data_in(imagebuf_0_in),
        .data_out(imagebuf_0_out)
    );

    single_port_ram #(
        .WIDTH(8),
        .DEPTH(IMAGE_BUF_SIZE),
        .ADDR_WIDTH(32)
    ) imagebuf_1_inst (
        .clk(clk),
        .we(imagebuf_1_we),
        .addr(imagebuf_1_addr),
        .data_in(imagebuf_1_in),
        .data_out(imagebuf_1_out)
    );

    image_streaming_controller #(
        .IMAGE_BUF_X(IMAGE_BUF_X),
        .IMAGE_BUF_Y(IMAGE_BUF_Y)
    ) image_streaming_controller_inst(
        .clk(clk),
        .reset(reset),
        .rx_data(rx_data),
        .rx_ready(rx_ready),
        .tx_busy(tx_busy),
        .tx_data(tx_data),
        .tx_ready(tx_ready),
        .mem_addr(backbuf_addr),
        .mem_in(backbuf_in),
        .streaming_ended(streaming_ended)
`ifdef DEBUG
        , .r(r1),
        .g(g1),
        .b(b1)
`endif
    );

    ili9341_spi_controller #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ),
        .DISPLAY_X(DISPLAY_X),
        .DISPLAY_Y(DISPLAY_Y),
        .DOWNSCALE_SHIFT(DOWNSCALE_SHIFT)
    ) image_display_inst (
        .clk(clk),
        .reset(reset),
        .spi_busy(spi_busy),
        .spi_in(spi_out),
        .mem_in(frontbuf_out),
        .dis_reset(dis_reset),
        .dc(dc),
        .cs(cs0),
        .spi_start(spi_start),
        .spi_out(spi_in),
        .mem_addr(frontbuf_addr),
        .frame_ended(frame_ended)
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
    always @(posedge clk)
    begin
        if (reset)
        begin
            r0 <= 1'b1;
            g0 <= 1'b0;
            b0 <= 1'b0;
        end
        else if (swap_req)
        begin
            r0 <= 1'b1;
            g0 <= 1'b1;
            b0 <= 1'b0;
        end
        else
        begin
            r0 <= 1'b0;
            g0 <= 1'b0;
            b0 <= 1'b0;
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