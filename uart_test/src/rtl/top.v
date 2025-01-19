module top(
	input wire reset,				// reset
	input wire rx,					// UART RX input
	output wire tx,					// UART TX output
	output wire RGB0,				// blue output
	output wire RGB1,				// green output
	output wire RGB2				// red output
);
    wire clk;
	reg pwm_b, pwm_g, pwm_r;
	reg[7:0] rcv_data;
	reg[7:0] snd_data;
	reg rcv_ready, snd_ready, snd_busy;

    SB_HFOSC #(
		.CLKHF_DIV("0b00")			// 48 MHz
	) high_freq_oscillator(
		.CLKHFPU(1'b1),				// power-up oscillator
		.CLKHFEN(1'b1),				// enable clock output
		.CLKHF(clk)					// clock output
	);

	uart_receiver #(
		.BAUD_RATE(9_600),			// 9.6 KHz
    	.CLOCK_FREQ(48_000_000)		// 48 MHz
	) uart_receiver_inst(
		.clk(clk),
		.reset(reset),
		.rx(rx),
		.data_out(rcv_data),
		.data_ready(rcv_ready)
	);

	uart_transmitter #(
		.BAUD_RATE(9_600),			// 9.6 KHz
    	.CLOCK_FREQ(48_000_000)		// 48 MHz
	) uart_transmitter_inst(
		.clk(clk),
		.reset(reset),
		.data_in(snd_data),
		.send(snd_ready),
		.tx(tx),
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
		.pwm_b(pwm_b),
		.pwm_g(pwm_g),
		.pwm_r(pwm_r)
	);

	SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),		// half current mode
		.RGB0_CURRENT("0b000111"),  // 12 mA
		.RGB1_CURRENT("0b000111"),  // 12 mA
		.RGB2_CURRENT("0b000111")   // 12 mA
	) rgb_driver(
		.CURREN(1'b1),				// enable current
		.RGBLEDEN(1'b1),			// enable LED driver
		.RGB0PWM(pwm_b),			// blue PWM input
		.RGB1PWM(pwm_g),			// green PWM input
		.RGB2PWM(pwm_r),			// red PWM input
		.RGB0(RGB0),				// blue output
		.RGB1(RGB1),				// green output
		.RGB2(RGB2)					// red output
	);
endmodule