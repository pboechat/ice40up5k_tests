`include "spi/ice40_master_spi_controller.v"

module ice40_master_spi_controller_tb;
    wire clk;
    wire reset;
    wire tx_busy;
    wire tx_start;
    wire spi_strobe;
    wire spi_rw;
    wire[7:0] spi_reg_addr;
    wire[7:0] spi_data_in;
    wire spi_ack;
    reg[7:0] tx_data;
    reg[7:0] spi_data_out;
    reg clk_val;
    reg reset_val;
    reg spi_ack_val;
    reg tx_start_val;
`ifdef DEBUG
    wire b, g, r;
`endif

    assign clk = clk_val;
    assign reset = reset_val;
    assign spi_ack = spi_ack_val;
    assign tx_start = tx_start_val;

    localparam CYCLE_TO_TU = 2;

    always #1 clk_val = ~clk_val;

    localparam SPI_CLK_DIVIDER = 1;

    ice40_master_spi_controller #(
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

    event spi_strobe_hi_evt;
    always @(posedge spi_strobe) 
    begin
        -> spi_strobe_hi_evt;
    end

    `include "assertions.vh"

    task assert_reg_write(input reg[4:0] reg_addr, input reg[7:0] reg_value);
    begin
        assert_eq(spi_rw, 1, "spi_rw");
        assert_eq(spi_reg_addr, reg_addr, "spi_reg_addr");
        assert_eq(spi_data_in, reg_value, "spi_data_in");
    end
    endtask

    task assert_reg_read(input reg[4:0] reg_addr);
    begin
        assert_eq(spi_rw, 0, "spi_rw");
        assert_eq(spi_reg_addr, reg_addr, "spi_reg_addr");
    end
    endtask

    localparam TX_DATA = 8'b10101010;

    integer step = 0;

    initial
    begin
        $dumpfile("ice40_master_spi_controller_tb.vcd");
        $dumpvars(0, ice40_master_spi_controller_tb);

        clk_val = 1'b1;                                             // set clk high
        reset_val = 1'b1;                                           // set reset high

        #(CYCLE_TO_TU);                                             // 1 cycle (reset)

        assert_eq(tx_busy, 1, "tx_busy");

        reset_val = 1'b0;                                           // set reset low

        forever
        begin
            @(spi_strobe_hi_evt);

            if (step == 0)
            begin
                assert_reg_write(`SPICR0, 8'b00000000);
            end
            else if (step == 1)
            begin
                assert_reg_write(`SPICR1, 8'b10000000);
            end
            else if (step == 2)
            begin
                assert_reg_write(`SPICR2, 8'b10000001);
            end
            else if (step == 3)
            begin
                assert_reg_write(`SPIBR, {2'b00, SPI_CLK_DIVIDER[5:0]});
            end
            else if (step == 4)
            begin
                assert_reg_write(`SPICSR, 8'b00000000);

                tx_data <= TX_DATA;
                tx_start_val <= 1;
            end
            else if (step == 5)
            begin
                assert_reg_read(`SPISR);
            end
            else if (step == 6)
            begin
                assert_eq(tx_busy, 1, "tx_busy");
                assert_reg_write(`SPITXDR, TX_DATA);
            end
            else
            begin
                $display("[ice40_master_spi_controller_tb  ] - T(%9t) - success", $time);
                $finish();
            end

            step = step + 1;
        end
    end
endmodule