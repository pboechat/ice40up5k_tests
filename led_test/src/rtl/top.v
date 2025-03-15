module top(
    input wire reset, 
    output wire RGB0, 
    output wire RGB1, 
    output wire RGB2
);
    wire clk;
    reg[31:0] counter;
    reg r, g, b;

    SB_HFOSC #(
        .CLKHF_DIV("0b11")              // 6 MHz
    ) high_freq_osc(
        .CLKHFPU(1'b1),                 // power-up oscillator
        .CLKHFEN(1'b1),                 // enable clock output
        .CLKHF(clk)                     // clock output
    );

    always @(posedge clk)
    begin
        if (reset)
        begin
            counter <= 32'h00000000;
            r <= 1'b0;
            g <= 1'b0;
            b <= 1'b0;
        end
        else
        begin
            counter <= counter + 1;
            if (counter == 'd1)
            begin
                r <= 1'b1;
                g <= 1'b0;
                b <= 1'b0;
            end
            else if (counter == 'd6000000)
            begin
                r <= 1'b0;
                g <= 1'b1;
                b <= 1'b0;
            end
            else if (counter == 'd12000000)
            begin
                r <= 1'b0;
                g <= 1'b0;
                b <= 1'b1;
            end
            else if (counter == 'd18000000)
            begin
                counter <= 'd0;
            end
        end
    end

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),           // half current mode
        .RGB0_CURRENT("0b000111"),      // 12 mA
        .RGB1_CURRENT("0b000111"),      // 12 mA
        .RGB2_CURRENT("0b000111")       // 12 mA
    ) rgb_driver(
      .CURREN(1'b1),                    // enable current
      .RGBLEDEN(1'b1),                  // enable LED driver
      .RGB0PWM(b),                      // blue PWM input
      .RGB1PWM(g),                      // green PWM input
      .RGB2PWM(r),                      // red PWM input
      .RGB0(RGB0),                      // blue output
      .RGB1(RGB1),                      // green output
      .RGB2(RGB2)                       // red output
    );
endmodule
