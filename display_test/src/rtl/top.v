module top(
    input wire reset,
    input wire dis_reset,                   // display reset
    input wire dc,                          // data/command
    input wire so,                          // SPI serial output
    output wire sck,                        // SPI SCK
    output wire cs,                         // SPI chip select
    output wire si                          // SPI serial input
`ifdef DEBUG
    , output wire tx,                       // UART TX output
    output wire RGB0,
	output wire RGB1, 
	output wire RGB2
`endif
);
    wire clk;
    wire tx_busy;
    wire tx_start;
    wire[7:0] tx_data;
    wire spi_strobe;
    wire spi_rw;
    wire[7:0] spi_reg_addr;
    wire[7:0] spi_data_in;
    wire[7:0] spi_data_out;
    wire spi_ack;
`ifdef DEBUG
    wire dbg_msg_q_full;
    reg dbg_msg_wr;
    reg[7:0] dbg_msg;
    wire dc_b, dc_g, dc_r;
    wire msc_b, msc_g, msc_r;
    wire b, g, r;
`endif

	SB_HFOSC #(
		.CLKHF_DIV("0b01")                  // 24 MHz
	) high_freq_oscillator(
		.CLKHFPU(1'b1),				        // power-up oscillator
		.CLKHFEN(1'b1),				        // enable clock output
		.CLKHF(clk)					        // clock output
	);

    display_controller #(
        .HW_RESET_TIMER(4_000_000),        // 125 ms
        .SW_RESET_TIMER(120_000),          // 5 ms
        .SLEEP_OUT_TIMER(4_000_000),       // 125 ms
        .DISPLAY_ON_TIMER(240_000),        // 10 ms
        .DIS_RES_X(320),
        .DIS_RES_Y(240),
    ) display_controller_inst (
        .clk(clk),
        .reset(reset),
        .tx_busy(tx_busy),
        .dis_reset(dis_reset),
        .dc(dc),
        .tx_start(tx_start),
        .tx_data(tx_data)
`ifdef DEBUG
        , .b(dc_b),
        .g(dc_g),
        .r(dc_r)
`endif
    );

    SB_SPI #(
        .BUS_ADDR74("0b0000")               // lower left SPI hard IP
    ) SB_SPI_inst(
        .SBCLKI(clk),                       // system clock
        .SBSTBI(spi_strobe),                // strobe signal
        .SBRWI(spi_rw),                     // read/write signal
        .SBADRI0(spi_reg_addr[0]),          // register address bit 0
        .SBADRI1(spi_reg_addr[1]),          // register address bit 1
        .SBADRI2(spi_reg_addr[2]),          // register address bit 2
        .SBADRI3(spi_reg_addr[3]),          // register address bit 3
        .SBADRI4(spi_reg_addr[4]),          // register address bit 4
        .SBADRI5(spi_reg_addr[5]),          // register address bit 5
        .SBADRI6(spi_reg_addr[6]),          // register address bit 6
        .SBADRI7(spi_reg_addr[7]),          // register address bit 7
        .SBDATI0(spi_data_in[0]), 
        .SBDATI1(spi_data_in[1]), 
        .SBDATI2(spi_data_in[2]), 
        .SBDATI3(spi_data_in[3]), 
        .SBDATI4(spi_data_in[4]), 
        .SBDATI5(spi_data_in[5]), 
        .SBDATI6(spi_data_in[6]), 
        .SBDATI7(spi_data_in[7]),
        .SBDATO0(spi_data_out[0]), 
        .SBDATO1(spi_data_out[1]), 
        .SBDATO2(spi_data_out[2]), 
        .SBDATO3(spi_data_out[3]), 
        .SBDATO4(spi_data_out[4]), 
        .SBDATO5(spi_data_out[5]), 
        .SBDATO6(spi_data_out[6]), 
        .SBDATO7(spi_data_out[7]),
        .SBACKO(spi_ack),                   // system acknowledgement
        .MI(so),                            // master-in
        .MO(si),                            // master-out
        .SCKO(sck),                         // sck
        .MCSNO0(cs)                         // chip select (line 0)
    );

    ice40_master_spi_controller #(
        .SPI_CLK_DIVIDER(3)                 // 24 / (3+1) = 6 MHz
    ) spi_controller_inst(
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .spi_data_out(spi_data_out),
        .spi_ack(spi_ack),
        .spi_rw(spi_rw),
        .spi_reg_addr(spi_reg_addr),
        .spi_strobe(spi_strobe),
        .spi_data_in(spi_data_in),
        .tx_busy(tx_busy)
`ifdef DEBUG
        , .b(msc_b),
        .g(msc_g),
        .r(msc_r)
`endif
    );

`ifdef DEBUG
    uart_dbg #(
        .SYS_CLK_FREQ(24_000_000),
        .BAUD_RATE(200_000)
    ) uart_dbg_inst (
        .clk(clk),
        .reset(reset),
        .wr(dbg_msg_wr),
        .msg(spi_data_in),
        .tx(tx),
        .full(dbg_msg_q_full)
    );

    // debug data being transmitted over SPI
    always @(posedge clk)
    begin
        if (!dbg_msg_q_full) // if queue is full, ignore msg
        begin
            if (spi_strobe)
            begin
                dbg_msg_wr <= 1;
            end
            else
            begin
                dbg_msg_wr <= 0;
            end
        end
    end

    assign b = dc_b || msc_b;
    assign g = dc_g || msc_g;
    assign r = dc_r || msc_r;

    SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),		        // half current mode
		.RGB0_CURRENT("0b000111"),          // 12 mA
		.RGB1_CURRENT("0b000111"),          // 12 mA
		.RGB2_CURRENT("0b000111")           // 12 mA
	) rgb_driver(
        .CURREN(1'b1),			            // enable current
        .RGBLEDEN(1'b1),			        // enable LED driver
        .RGB0PWM(b),			            // blue PWM input
        .RGB1PWM(g),			            // green PWM input
        .RGB2PWM(r),			            // red PWM input
        .RGB0(RGB0),				        // blue output
        .RGB1(RGB1),				        // green output
        .RGB2(RGB2)				            // red output
	);
`endif
endmodule