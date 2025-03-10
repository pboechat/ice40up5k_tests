`include "ili9341/ili9341_spi_controller.v"
`include "spi/spi_master_controller.v"
`include "uart/uart_receiver.v"
`include "uart/uart_transmitter.v"
`include "single_port_ram.v"

module top(
    input wire reset,
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
    wire clk;
    wire spi_busy;
    wire spi_start;
    wire[7:0] spi_in;
    wire[7:0] spi_out;
    wire cs_dis;
    wire cs_spi;
    wire[7:0] rx_data;
    wire rx_ready;
    wire[7:0] tx_data;
    wire tx_busy;
    wire tx_ready;
    wire streaming_ended;
    wire frame_ended;
    wire frontbuf_req;
    wire backbuf_req;
    wire frontbuf_ready;
    wire backbuf_ready;
    wire[7:0] frontbuf_out;
    wire[7:0] backbuf_in;
    wire[31:0] frontbuf_addr;
    wire[31:0] backbuf_addr;
    wire imagebuf_0_req;
    wire imagebuf_1_req;
    wire imagebuf_0_ready;
    wire imagebuf_1_ready;
    wire imagebuf_0_we;
    wire imagebuf_1_we;
    wire[7:0] imagebuf_0_out;
    wire[7:0] imagebuf_1_out;
    wire[7:0] imagebuf_0_in;
    wire[7:0] imagebuf_1_in;
    wire[31:0] imagebuf_0_addr;
    wire[31:0] imagebuf_1_addr;
    reg frontbuf = 0;
    reg swap_req = 0;
`ifdef DEBUG
    wire r, g, b;
    reg b0, g0, r0;
    reg b1, g1, r1;
`endif

    localparam SYS_CLK_FREQ = 12_000_000;
    localparam SPI_CLK_DIVIDER = 6;
    localparam BAUD_RATE = 115_200;

    localparam DISPLAY_X = 320;
    localparam DISPLAY_Y = 240;
    localparam DOWNSCALE_SHIFT = 3;
    
    localparam IMAGE_BUF_X = DISPLAY_X >> DOWNSCALE_SHIFT;
    localparam IMAGE_BUF_Y = DISPLAY_Y >> DOWNSCALE_SHIFT;
    localparam IMAGE_BUF_SIZE = IMAGE_BUF_X * IMAGE_BUF_Y * 2;

    assign cs = cs_dis | cs_spi; // cs is shared between SPI and display controllers

`ifdef DEBUG
    assign r = r0 | r1;
    assign g = g0 | g1;
    assign b = b0 | b1;
`endif

    assign imagebuf_0_req   = frontbuf == 0 ? frontbuf_req : backbuf_req;
    assign imagebuf_1_req   = frontbuf == 0 ? backbuf_req : frontbuf_req;
    assign frontbuf_ready   = frontbuf == 0 ? imagebuf_0_ready : imagebuf_1_ready;
    assign backbuf_ready    = frontbuf == 0 ? imagebuf_1_ready : imagebuf_0_ready;
    assign imagebuf_0_we    = frontbuf == 1; // frontbuf is read-only
    assign imagebuf_1_we    = frontbuf == 0; // frontbuf is read-only
    assign frontbuf_out     = frontbuf == 0 ? imagebuf_0_out : imagebuf_1_out;
    assign imagebuf_0_in    = frontbuf == 0 ? 0 : backbuf_in; // frontbuf is read-only
    assign imagebuf_1_in    = frontbuf == 0 ? backbuf_in : 0; // frontbuf is read-only
    assign imagebuf_0_addr  = frontbuf == 0 ? frontbuf_addr : backbuf_addr;
    assign imagebuf_1_addr  = frontbuf == 0 ? backbuf_addr : frontbuf_addr;

    task swap();
    begin
        frontbuf = ~frontbuf;
    end
    endtask

    // imagebuf signal redirection
    always @(posedge clk)
    begin
        if (reset)
        begin
            frontbuf <= 0;
            swap_req <= 0;
        end
        else if (streaming_ended)
        begin
            if (frame_ended)
            begin
                swap();
            end
            else
            begin
                swap_req <= 1;
            end
        end
        else if (swap_req)
        begin
            if (frame_ended)
            begin
                swap();
                swap_req <= 0;
            end
        end
    end

    SB_HFOSC #(
        .CLKHF_DIV("0b10")
    ) high_freq_oscillator(
        .CLKHFPU(1'b1), // power-up oscillator
        .CLKHFEN(1'b1), // enable clock output
        .CLKHF(clk)     // clock output
    );

    uart_receiver #(
        .BAUD_RATE(BAUD_RATE),
        .SYS_CLK_FREQ(SYS_CLK_FREQ)
    ) uart_receiver_inst(
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .data_out(rx_data),
        .data_ready(rx_ready)
    );

    uart_transmitter #(
        .BAUD_RATE(BAUD_RATE),
        .SYS_CLK_FREQ(SYS_CLK_FREQ)
    ) uart_transmitter_inst(
        .clk(clk),
        .reset(reset),
        .data_in(tx_data),
        .send(tx_ready),
        .tx(tx),
        .busy(tx_busy)
    );

    single_port_ram #(
        .WIDTH(8),
        .DEPTH(IMAGE_BUF_SIZE),
        .ADDR_WIDTH(32)
    ) imagebuf_0_inst (
        .clk(clk),
        .reset(reset),
        .request(imagebuf_0_req),
        .write_enable(imagebuf_0_we),
        .addr(imagebuf_0_addr),
        .write_data(imagebuf_0_in),
        .read_data(imagebuf_0_out),
        .ready(imagebuf_0_ready)
    );

    single_port_ram #(
        .WIDTH(8),
        .DEPTH(IMAGE_BUF_SIZE),
        .ADDR_WIDTH(32)
    ) imagebuf_1_inst (
        .clk(clk),
        .reset(reset),
        .request(imagebuf_1_req),
        .write_enable(imagebuf_1_we),
        .addr(imagebuf_1_addr),
        .write_data(imagebuf_1_in),
        .read_data(imagebuf_1_out),
        .ready(imagebuf_1_ready)
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
        .mem_ready(backbuf_ready),
        .tx_data(tx_data),
        .tx_ready(tx_ready),
        .mem_req(backbuf_req),
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
        .mem_ready(frontbuf_ready),
        .dis_reset(dis_reset),
        .dc(dc),
        .cs(cs_dis),
        .spi_start(spi_start),
        .spi_out(spi_in),
        .mem_req(frontbuf_req),
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
        .cs(cs_spi),
        .sck(sck),
        .mosi(si),
        .miso(so)
    );

`ifdef DEBUG
    always @(posedge clk)
    begin
        if (reset)
        begin
            r0 <= 1;
            g0 <= 0;
            b0 <= 0;
        end
        else if (swap_req)
        begin
            r0 <= 1;
            g0 <= 1;
            b0 <= 0;
        end
        else
        begin
            r0 <= 0;
            g0 <= 0;
            b0 <= 0;
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