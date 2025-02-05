`include "spi/master_spi_controller.v"
`include "uart_dbg.v"

module top(
    input wire reset,
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
    wire clk;
    wire tx_busy;
    wire tx_start;
    wire[7:0] tx_data;
    wire[7:0] rx_data;
    wire dis_cs;
    wire spi_cs;
`ifdef DEBUG
    reg dbg_wr;
    reg[7:0] dbg_msg;
    reg tx_busy_seen;
    reg b, g, r;
`endif

    assign cs = dis_cs || spi_cs;

    initial 
    begin
        tx_busy_seen <= 0;    
    end

    localparam SYS_CLK_FREQ = 12_000_000;

    SB_HFOSC #(
        .CLKHF_DIV("0b10")
    ) high_freq_oscillator(
        .CLKHFPU(1'b1),                         // power-up oscillator
        .CLKHFEN(1'b1),                         // enable clock output
        .CLKHF(clk)                             // clock output
    );

    localparam HW_RESET_HOLD_TIMER = SYS_CLK_FREQ / (1000 / 10);            // 10 ms
    localparam HW_RESET_RELEASE_TIMER = SYS_CLK_FREQ / (1000 / 120);        // 120 ms
    localparam SW_RESET_TIMER = SYS_CLK_FREQ / (1000 / 10);                 // 10 ms
    localparam SLEEP_OUT_TIMER = SYS_CLK_FREQ / (1000 / 120);               // 120 ms
    localparam DISPLAY_ON_TIMER = SYS_CLK_FREQ / (1000 / 10);               // 10 ms

    display_controller #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ),
        .DIS_RES_X(240),
        .DIS_RES_Y(320),
    ) display_controller_inst (
        .clk(clk),
        .reset(reset),
        .busy(tx_busy),
        .dis_reset(dis_reset),
        .dc(dc),
        .cs(dis_cs),
        .start(tx_start),
        .data_out(tx_data),
        .data_in(rx_data)
    );

    master_spi_controller #(
        .CLK_DIVIDER(3)
    ) master_spi_controller_inst (
        .clk(clk),
        .reset(reset),
        .start(tx_start),
        .data_in(tx_data),
        .data_out(rx_data),
        .busy(tx_busy),
        .cs(spi_cs),
        .sck(sck),
        .mosi(si),
        .miso(so)
    );

`ifdef DEBUG
    uart_dbg #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ),
        .BAUD_RATE(115_200),
        .MSG_QUEUE_SIZE(32)
    ) uart_dbg_inst (
        .clk(clk),
        .reset(reset),
        .wr(dbg_wr),
        .msg(dbg_msg),
        .tx(tx)
    );

    // debug data being transmitted over SPI
    always @(posedge clk)
    begin
        if (reset)
        begin
            b <= 0;
            g <= 0;
            r <= 1;
        end
        else
        begin
            b <= 0;
            g <= 1;
            r <= 0;
            if (tx_busy)
            begin
                tx_busy_seen <= 1;
            end
            else if (tx_busy_seen)
            begin
                if (dbg_msg != rx_data)
                begin
                    dbg_msg <= rx_data;
                    dbg_wr <= 1;
                end
                tx_busy_seen <= 0;
            end
            else if (dbg_wr)
            begin
                dbg_wr <= 0;
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