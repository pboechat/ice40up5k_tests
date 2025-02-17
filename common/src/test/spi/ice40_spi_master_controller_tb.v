`include "spi/ice40_spi_master_controller.v"

module ice40_spi_master_controller_tb;
    wire clk;
    wire reset;
    wire busy;
    wire start;
    wire spi_strobe;
    wire spi_rw;
    wire[7:0] spi_reg_addr;
    wire[7:0] spi_data_in;
    wire spi_ack;
    reg[7:0] data_out;
    reg[7:0] spi_data_out;
    reg clk_val;
    reg reset_val;
    reg spi_ack_val;
    reg start_val;
`ifdef DEBUG
    wire b, g, r;
`endif

    assign clk = clk_val;
    assign reset = reset_val;
    assign spi_ack = spi_ack_val;
    assign start = start_val;

    localparam CYCLE_TO_TU = 2;

    always #1 clk_val = ~clk_val;

    localparam SPI_CLK_DIVIDER = 1;

    ice40_spi_master_controller #(
        .CLK_DIVIDER(SPI_CLK_DIVIDER)
    ) spi_controller_inst(
        .clk(clk),
        .reset(reset),
        .start(start),
        .data_out(data_out),
        .spi_data_out(spi_data_out),
        .spi_ack(spi_ack),
        .spi_rw(spi_rw),
        .spi_reg_addr(spi_reg_addr),
        .spi_strobe(spi_strobe),
        .spi_data_in(spi_data_in),
        .busy(busy)
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

    task assert_reg_write(input reg[4:0] reg_addr, input reg[7:0] reg_value, input reg[16*8:1] reg_name);
    begin
        assert_eq(spi_rw, 1, "spi_rw");
        assert_eq(spi_reg_addr, reg_addr, "spi_reg_addr");
        assert_eq(spi_data_in, reg_value, reg_name);
    end
    endtask

    task assert_reg_read(input reg[4:0] reg_addr);
    begin
        assert_eq(spi_rw, 0, "spi_rw");
        assert_eq(spi_reg_addr, reg_addr, "spi_reg_addr");
    end
    endtask

    localparam DATA_OUT = 8'b10101010;

    integer step = 0;

    initial
    begin
        $dumpfile("ice40_spi_master_controller_tb.vcd");
        $dumpvars(0, ice40_spi_master_controller_tb);

        clk_val = 1'b1;                                             // set clk high
        reset_val = 1'b1;                                           // set reset high

        #(CYCLE_TO_TU);                                             // 1 cycle (reset)

        assert_eq(busy, 1, "busy");

        reset_val = 1'b0;                                           // set reset low

        forever
        begin
            @(spi_strobe_hi_evt);

            if (step == 0)
            begin
                assert_reg_write(`SPICR0, 8'b00000000, "SPICR0");
            end
            else if (step == 1)
            begin
                assert_reg_write(`SPICR1, 8'b10000000, "SPICR1");
            end
            else if (step == 2)
            begin
                assert_reg_write(`SPICR2, 8'b10000000, "SPICR2");
            end
            else if (step == 3)
            begin
                assert_reg_write(`SPIBR, {2'b00, SPI_CLK_DIVIDER[5:0]}, "SPIBR");
            end
            else if (step == 4)
            begin
                assert_reg_write(`SPICSR, 8'b00000000, "SPICSR");

                data_out <= DATA_OUT;
                start_val <= 1;
            end
            else if (step == 5)
            begin
                assert_reg_read(`SPISR);
            end
            else if (step == 6)
            begin
                assert_eq(busy, 1, "busy");
                assert_reg_write(`SPITXDR, DATA_OUT, "SPITXDR");
            end
            else
            begin
                $display("[ice40_spi_master_controller_tb  ] - T(%9t) - success", $time);
                $finish();
            end

            step = step + 1;
        end
    end
endmodule