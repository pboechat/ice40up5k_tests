`include "display_controller.v"
`include "master_spi_controller.v"

module top_tb;
    wire clk;
    wire reset;
    wire tx_busy;
    wire dis_reset;
    wire dc;
    wire tx_start;
    wire spi_strobe;
    wire spi_rw;
    wire[7:0] spi_reg_addr;
    wire[7:0] spi_data_in;
    wire spi_ack;
    wire[7:0] tx_data;
    reg[7:0] spi_data_out;
    reg clk_val;
    reg reset_val;
    reg spi_ack_val;
    reg tx_start_val;
`ifdef DEBUG
    wire dc_b, dc_g, dc_r;
    wire msc_b, msc_g, msc_r;
`endif

    assign clk = clk_val;
    assign reset = reset_val;
    assign spi_ack = spi_ack_val;

    localparam CYCLE_TO_TU = 2;

    always #1 clk_val = ~clk_val;

    localparam DIS_RES_X = 4;
    localparam DIS_RES_Y = 3;
    localparam HW_RESET_TIMER = 100;
    localparam SW_RESET_TIMER = 4;
    localparam SLEEP_OUT_TIMER = 100;
    localparam DISPLAY_ON_TIMER = 8;

    display_controller #(
        .DIS_RES_X(DIS_RES_X),
        .DIS_RES_Y(DIS_RES_Y),
        .HW_RESET_TIMER(HW_RESET_TIMER),
        .SW_RESET_TIMER(SW_RESET_TIMER),
        .SLEEP_OUT_TIMER(SLEEP_OUT_TIMER),
        .DISPLAY_ON_TIMER(DISPLAY_ON_TIMER)
    ) display_controller_impl (
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

    localparam SPI_CLK_DIVIDER = 1;

    master_spi_controller #(
        .SPI_CLK_DIVIDER(SPI_CLK_DIVIDER)
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
        , .b(b),
        .g(g),
        .r(r)
`endif
    );

    localparam SPI_ACK_TIMER = 2;

    reg[$clog2(SPI_ACK_TIMER)-1:0] spi_ack_timer = 0;
    reg spi_ack_timer_flg = 0;

    // spi soft block mock
    always @(posedge clk)
    begin
        if (spi_strobe)
        begin
            if (spi_ack_timer_flg)
            begin
                if (spi_ack_timer == 0)
                begin
                    if (spi_rw == 0)
                    begin
                        spi_data_out <= 8'b0010000; // TRDY ON
                    end
                    spi_ack_val <= 1;
                    spi_ack_timer_flg <= 0;
                end
                else
                begin
                    spi_ack_timer <= spi_ack_timer - 1;
                end
            end
            else
            begin
                spi_ack_timer_flg <= 1;
                spi_ack_timer <= SPI_ACK_TIMER - 1;
            end
        end
    end

    always @(negedge spi_strobe)
    begin
        spi_ack_val <= 0;
    end

    event tx_data_req_evt, tx_data_sent_evt;
    always @(posedge spi_strobe) 
    begin
        if (spi_reg_addr == `SPITXDR)
            -> tx_data_req_evt;
    end

    `include "assertions.vh"

    task assert_tx_data(input reg[8:0] expected_tx_data);
    begin
        assert_eq(spi_data_in, expected_tx_data, "spi_data_in");
    end
    endtask

    localparam PIXEL_BYTE_COUNT = DIS_RES_X * DIS_RES_Y * 2;

    integer pixel_byte_count = 0;

    integer step = 0;

    initial 
    begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);

        clk_val = 1'b1;                                             // set clk high
        reset_val = 1'b1;                                           // set reset high

        #(CYCLE_TO_TU);                                             // 1 cycle (reset)

        assert_eq(dis_reset, 0, "dis_reset");
        assert_eq(tx_busy, 1, "tx_busy");

        reset_val = 1'b0;                                           // set reset low

        forever 
        begin
            @(tx_data_req_evt);

            if (step == 0)
            begin
                assert_eq(dc, `COMMAND_BIT, "dc");
                assert_tx_data(`SW_RESET_CMD);
            end
            else if (step == 1)
            begin
                assert_eq(dc, `COMMAND_BIT, "dc");
                assert_tx_data(`SLEEP_OUT_CMD);
            end
            else if (step == 2)
            begin
                assert_eq(dc, `COMMAND_BIT, "dc");
                assert_tx_data(`SET_PXL_FMT_CMD);
            end
            else if (step == 3)
            begin
                assert_eq(dc, `DATA_BIT, "dc");
                assert_tx_data(`RGB565);
            end
            else if (step == 4)
            begin
                assert_eq(dc, `COMMAND_BIT, "dc");
                assert_tx_data(`MEM_ACC_CTR_CMD);
            end
            else if (step == 5)
            begin
                assert_eq(dc, `DATA_BIT, "dc");
                assert_tx_data(8'b01001000);
            end
            else if (step == 6)
            begin
                assert_eq(dc, `COMMAND_BIT, "dc");
                assert_tx_data(`DISPLAY_ON_CMD);
            end
            else if (step == 7)
            begin
                assert_eq(dc, `COMMAND_BIT, "dc");
                assert_tx_data(`SET_COL_ADDR_CMD);
            end
            else if (step == 8 || step == 9)
            begin
                assert_eq(dc, `DATA_BIT, "dc");
                assert_tx_data(8'h00);
            end
            else if (step == 10)
            begin
                assert_eq(dc, `DATA_BIT, "dc");
                assert_tx_data(DIS_RES_X[15:8]);
            end
            else if (step == 11)
            begin
                assert_eq(dc, `DATA_BIT, "dc");
                assert_tx_data(DIS_RES_X[7:0]);
            end
            else if (step == 12)
            begin
                assert_eq(dc, `COMMAND_BIT, "dc");
                assert_tx_data(`SET_PAGE_ADDR_CMD);
            end
            else if (step == 13 || step == 14)
            begin
                assert_eq(dc, `DATA_BIT, "dc");
                assert_tx_data(8'h00);
            end
            else if (step == 15)
            begin
                assert_eq(dc, `DATA_BIT, "dc");
                assert_tx_data(DIS_RES_Y[15:8]);
            end
            else if (step == 16)
            begin
                assert_eq(dc, `DATA_BIT, "dc");
                assert_tx_data(DIS_RES_Y[7:0]);
            end
            else if (step == 17)
            begin
                assert_eq(dc, `COMMAND_BIT, "dc");
                assert_tx_data(`MEM_WRITE_CMD);
            end
            else if (step >= 18)
            begin
                assert_eq(dc, `DATA_BIT, "dc");
                assert_tx_data(pixel_byte_count % 2 == 0 ? 8'hf8 : 8'h00);
                if (pixel_byte_count == PIXEL_BYTE_COUNT - 1)
                begin
                    $display("[top_tb                          ] - T(%9t) - success", $time);
                    $finish();
                end
                else
                begin
                    pixel_byte_count = pixel_byte_count + 1;
                end
            end

            step = step + 1;
        end
    end
endmodule