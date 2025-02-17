`include "spi/master_spi_controller.v"
`include "uart_dbg.v"
`include "single_port_ram.v"
`include "ili9341.vh"

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
    wire spi_busy;
    wire spi_start;
    wire[7:0] spi_in;
    wire[7:0] spi_out;
    wire[31:0] mem_addr;
    wire mem_req;
    wire cs_dis;
    wire cs_spi;
    reg mem_ready;
    reg[7:0] mem_out;
`ifdef DEBUG
    wire[31:0] display_status;
    reg dbg_wr;
    reg[7:0] dbg_msg;
    reg[31:0] last_seen_display_status;
    reg[2:0] display_status_tx_step;
    reg b, g, r;
`endif

    assign cs = cs_dis | cs_spi;

    initial 
    begin
`ifdef DEBUG
        last_seen_display_status <= `INVALID_DISPLAY_STATUS;
        display_status_tx_step <= 0;
`endif    
    end

    localparam SYS_CLK_FREQ = 12_000_000;

    localparam DIS_RES_X = 320;
    localparam DIS_RES_Y = 240;

    SB_HFOSC #(
        .CLKHF_DIV("0b10")
    ) high_freq_oscillator(
        .CLKHFPU(1'b1), // power-up oscillator
        .CLKHFEN(1'b1), // enable clock output
        .CLKHF(clk)     // clock output
    );

    // memory controller mock

    localparam RED = {5'b11111, 6'b000000, 5'b00000};
    localparam GREEN = {5'b00000, 6'b111111, 5'b00000};
    localparam BLUE = {5'b00000, 6'b000000, 5'b11111};
    localparam YELLOW = {5'b11111, 6'b111111, 5'b00000};
    localparam CYAN = {5'b00000, 6'b111111, 5'b11111};

    always @(posedge clk)
    begin
        mem_ready <= 0;

        if (mem_req)
        begin
            if (mem_addr[17])
            begin
                mem_out <= mem_addr[0] ? CYAN[7:0] : CYAN[15:8];
            end
            else if (mem_addr[16])
            begin
                if (mem_addr[15])
                begin
                    mem_out <= mem_addr[0] ? BLUE[7:0] : BLUE[15:8];
                end
                else
                begin
                    mem_out <= mem_addr[0] ? YELLOW[7:0] : YELLOW[15:8];
                end
            end
            else if (mem_addr[15])
            begin
                mem_out <= mem_addr[0] ? GREEN[7:0] : GREEN[15:8];
            end
            else
            begin
                mem_out <= mem_addr[0] ? RED[7:0] : RED[15:8];
            end
            mem_ready <= 1;
        end
    end

    display_controller #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ),
        .DIS_RES_X(DIS_RES_X),
        .DIS_RES_Y(DIS_RES_Y),
    ) display_controller_inst (
        .clk(clk),
        .reset(reset),
        .spi_busy(spi_busy),
        .spi_in(spi_out),
        .mem_in(mem_out),
        .mem_ready(mem_ready),
        .dis_reset(dis_reset),
        .dc(dc),
        .cs(cs_dis),
        .spi_start(spi_start),
        .spi_out(spi_in),
        .mem_req(mem_req),
        .mem_addr(mem_addr)
`ifdef DEBUG
        , .display_status(display_status)
`endif
    );

    master_spi_controller #(
        .CLK_DIVIDER(3)
    ) master_spi_controller_inst (
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
    uart_dbg #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ),
        .BAUD_RATE(115_200),
        .MSG_QUEUE_SIZE(8)
    ) uart_dbg_inst (
        .clk(clk),
        .reset(reset),
        .wr(dbg_wr),
        .msg(dbg_msg),
        .tx(tx)
    );

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
            if (last_seen_display_status != display_status)
            begin
                if (dbg_wr == 0)
                begin
                    if (display_status_tx_step == 0)
                    begin
                        dbg_msg <= display_status[31:24];
                        display_status_tx_step <= 1;
                        dbg_wr <= 1;
                    end
                    else if (display_status_tx_step == 1)
                    begin
                        dbg_msg <= display_status[23:16];
                        display_status_tx_step <= 2;
                        dbg_wr <= 1;
                    end
                    else if (display_status_tx_step == 2)
                    begin
                        dbg_msg <= display_status[15:8];
                        display_status_tx_step <= 3;
                        dbg_wr <= 1;
                    end
                    else if (display_status_tx_step == 3)
                    begin
                        dbg_msg <= display_status[7:0];
                        display_status_tx_step <= 4;
                        dbg_wr <= 1;
                    end
                end
                else
                begin
                    if (display_status_tx_step == 4)
                    begin
                        display_status_tx_step <= 0;
                        last_seen_display_status <= display_status;
                    end
                    dbg_wr <= 0;
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