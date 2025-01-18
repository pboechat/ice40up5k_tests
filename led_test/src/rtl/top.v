module top(reset, RGB0, RGB1, RGB2);
	input wire reset;
	output wire RGB0;
	output wire RGB1; 
	output wire RGB2;
	wire clk;

	SB_HFOSC #(
		.CLKHF_DIV("0b11")		// 6 MHz
	) high_freq_oscillator(
		.CLKHFPU(1'b1),			// Power-up oscillator
		.CLKHFEN(1'b1),			// Enable clock output
		.CLKHF(clk)				// Clock output
	);

	reg [31:0] counter;
	reg pwm_r, pwm_g, pwm_b;

	always@(posedge clk)
	begin
		if (reset)
		begin
			counter <= 0;
			pwm_r <= 1'b0;
			pwm_g <= 1'b0;
			pwm_b <= 1'b0;
		end
		else
		begin
			counter <= counter + 1;
			if (counter == 1)
			begin
				pwm_r <= 1'b1;
				pwm_g <= 1'b0;
				pwm_b <= 1'b0;
			end
			else if (counter == 6000000)
			begin
				pwm_r <= 1'b0;
				pwm_g <= 1'b1;
				pwm_b <= 1'b0;
			end
			else if (counter == 12000000)
			begin
				pwm_r <= 1'b0;
				pwm_g <= 1'b0;
				pwm_b <= 1'b1;
			end
			else if (counter == 18000000)
			begin
				counter <= 0;
			end
		end
	end

	SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),		// Half current mode
		.RGB0_CURRENT("0b000111"),  // 12 mA
		.RGB1_CURRENT("0b000111"),  // 12 mA
		.RGB2_CURRENT("0b000111")   // 12 mA
	) rgb_driver(
	  .CURREN(1'b1),			// Enable current
	  .RGBLEDEN(1'b1),			// Enable LED driver
	  .RGB0PWM(pwm_b),			// Blue PWM input
	  .RGB1PWM(pwm_g),			// Green PWM input
	  .RGB2PWM(pwm_r),			// Red PWM input
	  .RGB0(RGB0),				// Blue output
	  .RGB1(RGB1),				// Green output
	  .RGB2(RGB2)				// Red output
	);
endmodule
