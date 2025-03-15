`include "uart/uart_rx.v"
`include "uart/uart_tx.v"

module top(
    input wire reset,               // reset
    input wire rx,                  // UART RX input
    output wire tx,                 // UART TX output
    output wire RGB0,
    output wire RGB1,
    output wire RGB2
);
    localparam SYS_CLK_FREQ = 48_000_000;
    localparam BAUD_RATE = 9_600;

    wire clk;
    wire raw_rx;
    wire raw_tx;
    wire rcv_ready, snd_ready, snd_busy;
    reg b, g, r;
    reg[7:0] rcv_data;
    reg[7:0] snd_data;

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

    // use internal high-frequency oscillator
    // since there are no precision/stability requirements 
    SB_HFOSC #(
        .CLKHF_DIV("0b00")              // 48 MHz
    ) high_freq_osc(
        .CLKHFPU(1'b1),                 // power-up oscillator
        .CLKHFEN(1'b1),                 // enable clock output
        .CLKHF(clk)                     // clock output
    );

    uart_rx #(
        .BAUD_RATE(BAUD_RATE),
        .SYS_CLK_FREQ(SYS_CLK_FREQ)
    ) uart_rx_inst(
        .clk(clk),
        .reset(reset),
        .rx(raw_rx),
        .data_out(rcv_data),
        .data_ready(rcv_ready)
    );

    uart_tx #(
        .BAUD_RATE(BAUD_RATE),
        .SYS_CLK_FREQ(SYS_CLK_FREQ)
    ) uart_tx_inst(
        .clk(clk),
        .reset(reset),
        .data_in(snd_data),
        .send(snd_ready),
        .tx(raw_tx),
        .busy(snd_busy)
    );

    command_decoder command_decoder_inst(
        .clk(clk),
        .reset(reset),
        .rcv_data(rcv_data),
        .rcv_ready(rcv_ready),
        .snd_busy(snd_busy),
        .snd_data(snd_data),
        .snd_ready(snd_ready),
        .b(b),
        .g(g),
        .r(r)
    );

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),           // half current mode
        .RGB0_CURRENT("0b000111"),      // 12 mA
        .RGB1_CURRENT("0b000111"),      // 12 mA
        .RGB2_CURRENT("0b000111")       // 12 mA
    ) rgb_driver(
        .CURREN(1'b1),                  // enable current
        .RGBLEDEN(1'b1),                // enable LED driver
        .RGB0PWM(b),                    // blue PWM input
        .RGB1PWM(g),                    // green PWM input
        .RGB2PWM(r),                    // red PWM input
        .RGB0(RGB0),                    // blue output
        .RGB1(RGB1),                    // green output
        .RGB2(RGB2)                     // red output
    );
endmodule