`include "display_controller.v"

module display_controller_tb;
    wire clk;
    wire reset;
    wire spi_busy;
    wire dis_reset;
    wire dc;
    wire spi_start;
    wire[7:0] spi_out;
    wire[31:0] mem_addr;
    wire mem_req;
    wire[31:0] display_status;
    reg clk_val;
    reg reset_val;
    reg spi_busy_val;
    reg[7:0] spi_in;
    reg[7:0] mem_in;
    reg mem_ready;

    `include "functions.vh"

    assign clk = clk_val;
    assign reset = reset_val;
    assign spi_busy = spi_busy_val;

    always #1 clk_val = ~clk_val;

    localparam SYS_CLK_FREQ = 1;
    localparam DIS_RES_X = 3;
    localparam DIS_RES_Y = 4;
    localparam HW_RESET_HOLD_TIMER = max(4, SYS_CLK_FREQ / 100000);         // 10 us
    localparam HW_RESET_RELEASE_TIMER = max(4, SYS_CLK_FREQ / (1000 / 5));  // 5 ms
    localparam SW_RESET_TIMER = max(4, SYS_CLK_FREQ / (1000 / 5));          // 5 ms
    localparam SLPOUT_TIMER  = max(4, SYS_CLK_FREQ / (1000 / 120));         // 120 ms

    display_controller #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ),
        .DIS_RES_X(DIS_RES_X),
        .DIS_RES_Y(DIS_RES_Y)
    ) display_controller_impl (
        .clk(clk),
        .reset(reset),
        .spi_busy(spi_busy),
        .spi_in(spi_in),
        .mem_in(mem_in),
        .mem_ready(mem_ready),
        .dis_reset(dis_reset),
        .dc(dc),
        .spi_start(spi_start),
        .spi_out(spi_out),
        .mem_addr(mem_addr),
        .mem_req(mem_req),
        .display_status(display_status)
    );
    
    integer cycle_count = 0;

    always @(posedge clk)
    begin
        cycle_count <= cycle_count + 1;
    end

    // master spi controller mock
    
    localparam SPI_BUSY_TIMER = 4;
    
    reg[$clog2(SPI_BUSY_TIMER)-1:0] spi_busy_timer = 0;

    always @(posedge clk)
    begin
        if (spi_busy)
        begin
            if (spi_busy_timer == 0)
            begin
                spi_in <= 8'b10101010;
                spi_busy_val <= 1'b0;
            end
            else
            begin
                spi_busy_timer <= spi_busy_timer - 1;
            end
        end
        else
        begin
            if (spi_start)
            begin
                spi_busy_val <= 1'b1;
                spi_busy_timer <= spi_busy_timer - 1;
            end
        end
    end

    // memory controller mock

    localparam RED = {5'b11111, 6'b000000, 5'b00000};
    localparam GREEN = {5'b00000, 6'b111111, 5'b00000};
    localparam BLUE = {5'b00000, 6'b000000, 5'b11111};

    function integer next_pixel_byte(input integer idx);
        case (idx % 6)
            0:
                next_pixel_byte = RED[15:8];
            1:
                next_pixel_byte = RED[7:0];
            2:
                next_pixel_byte = GREEN[15:8];
            3:
                next_pixel_byte = GREEN[7:0];
            4:
                next_pixel_byte = BLUE[15:8];
            5:
                next_pixel_byte = BLUE[7:0];
        endcase
    endfunction

    always @(posedge clk)
    begin
        mem_ready <= 0;

        if (mem_req)
        begin
            mem_in <= next_pixel_byte(mem_addr);
            mem_ready <= 1;
        end
    end

    event dis_reset_hi_evt, dis_reset_lo_evt, spi_start_hi_evt;
    always @(posedge dis_reset) 
    begin
        -> dis_reset_hi_evt;
    end
    always @(negedge dis_reset) 
    begin
        -> dis_reset_lo_evt;
    end
    always @(posedge spi_start) 
    begin
        -> spi_start_hi_evt;
    end

    `include "assertions.vh"

    task assert_command(input reg[7:0] command);
    begin
        assert_eq(dc, `COMMAND_BIT, "dc");
        assert_eq(spi_out, command, "command");
    end
    endtask

    task assert_data(input reg[7:0] data);
    begin
        assert_eq(dc, `DATA_BIT, "dc");
        assert_eq(spi_out, data, "data");
    end
    endtask

    integer step = 0, cycle_rec = 0, elapsed_cycles = 0;

    task start_cycle_rec;
    begin
        cycle_rec = cycle_count;
    end
    endtask

    task stop_cycle_rec;
    begin
        elapsed_cycles = cycle_count - cycle_rec;
    end
    endtask

    localparam SCREEN_BUF_SIZE = DIS_RES_X * DIS_RES_Y * 2;

    initial 
    begin
        $dumpfile("display_controller_tb.vcd");
        $dumpvars(0, display_controller_tb);

        clk_val = 1'b1;                                             // set clk high
        spi_busy_val = 1'b0;                                        // set spi_busy low
        reset_val = 1'b1;                                           // set reset high

        @(posedge clk);

        assert_eq(dis_reset, 1, "dis_reset");

        reset_val = 1'b0;                                           // set reset low

        @(dis_reset_lo_evt)

        start_cycle_rec;

        @(dis_reset_hi_evt)

        stop_cycle_rec;

        assert_eq(elapsed_cycles, HW_RESET_HOLD_TIMER, "HW_RESET_HOLD_TIMER");

        forever 
        begin
            @(spi_start_hi_evt);

            if (step == 0)
            begin
                stop_cycle_rec;
                assert_gt(elapsed_cycles, HW_RESET_RELEASE_TIMER, "HW_RESET_RELEASE_TIMER");
                assert_command(`SW_RESET_CMD);
                start_cycle_rec;
            end
            else if (step == 1)
            begin
                stop_cycle_rec;
                assert_gt(elapsed_cycles, SW_RESET_TIMER, "SW_RESET_TIMER");
                assert_command(`SLPOUT_CMD);
                start_cycle_rec;
            end
            else if (step == 2)
            begin
                stop_cycle_rec;
                assert_gt(elapsed_cycles, SLPOUT_TIMER, "SLPOUT_TIMER");
                assert_command(`MADCTL_CMD);
            end
            else if (step == 3)
            begin
                assert_data(8'b00000000);
            end
            else if (step == 4)
            begin
                assert_command(`COLMOD_CMD);
            end
            else if (step == 5)
            begin
               assert_data(8'h55);
            end
            else if (step == 6)
            begin
                assert_command(`DISPON_CMD);
            end
            else if (step == 7)
            begin
                assert_command(`READ_DISPLAY_STATUS_CMD);
            end
            else if (step == 13)
            begin
                assert_eq(display_status, 32'b10101010101010101010101010101010, "display_status");
                assert_command(`CASET_CMD);
            end
            else if (step == 14 || step == 15)
            begin
                assert_data(8'h00);
            end
            else if (step == 16)
            begin
                assert_data(DIS_RES_X[15:8]);
            end
            else if (step == 17)
            begin
                assert_data(DIS_RES_X[7:0]);
            end
            else if (step == 18)
            begin
                assert_command(`PASET_CMD);
            end
            else if (step == 19 || step == 20)
            begin
                assert_data(8'h00);
            end
            else if (step == 21)
            begin
                assert_data(DIS_RES_Y[15:8]);
            end
            else if (step == 22)
            begin
                assert_data(DIS_RES_Y[7:0]);
            end
            else if (step == 23)
            begin
                assert_command(`MEMWRITE_CMD);
            end
            else if (step >= 24)
            begin
                assert_data(next_pixel_byte(mem_addr));
                if (mem_addr == (SCREEN_BUF_SIZE - 1))
                begin
                    $display("[display_controller_tb           ] - T(%9t) - success", $time);
                    $finish();
                end
            end

            step = step + 1;
        end
    end
endmodule