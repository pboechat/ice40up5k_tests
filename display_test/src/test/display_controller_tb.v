`include "display_controller.v"

module display_controller_tb;
    wire clk;
    wire reset;
    wire tx_busy;
    wire dis_reset;
    wire dc;
    wire tx_start;
    wire[7:0] tx_data;
    reg clk_val;
    reg reset_val;
    reg tx_busy_val;

    assign clk = clk_val;
    assign reset = reset_val;
    assign tx_busy = tx_busy_val;

    localparam CYCLE_TO_TU = 2;

    always #1 clk_val = ~clk_val;

    localparam DIS_RES_X = 4;
    localparam END_COL = DIS_RES_X - 1;
    localparam DIS_RES_Y = 3;
    localparam END_PAGE = DIS_RES_Y - 1;
    localparam HW_RESET_HOLD_TIMER = 4;
    localparam HW_RESET_RELEASE_TIMER = 100;
    localparam SW_RESET_TIMER = 4;
    localparam SLEEP_OUT_TIMER = 100;
    localparam DISPLAY_ON_TIMER = 8;

    display_controller #(
        .DIS_RES_X(DIS_RES_X),
        .DIS_RES_Y(DIS_RES_Y),
        .HW_RESET_HOLD_TIMER(HW_RESET_HOLD_TIMER),
        .HW_RESET_RELEASE_TIMER(HW_RESET_RELEASE_TIMER),
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
    );
    
    integer cycle_count = 0;

    always @(posedge clk)
    begin
        cycle_count <= cycle_count + 1;
    end

    // master spi controller mock
    
    localparam TX_BUSY_TIMER = 4;
    
    reg[$clog2(TX_BUSY_TIMER)-1:0] tx_busy_timer = 0;

    always @(posedge clk)
    begin
        if (tx_busy)
        begin
            if (tx_busy_timer == 0)
            begin
                tx_busy_val <= 1'b0;
            end
            else
            begin
                tx_busy_timer <= tx_busy_timer - 1;
            end
        end
        else
        begin
            if (tx_start)
            begin
                tx_busy_val <= 1'b1;
                tx_busy_timer <= TX_BUSY_TIMER - 1;
            end
        end
    end

    event dis_reset_hi_evt, dis_reset_lo_evt, tx_start_hi_evt;
    always @(posedge dis_reset) 
    begin
        -> dis_reset_hi_evt;
    end
    always @(negedge dis_reset) 
    begin
        -> dis_reset_lo_evt;
    end
    always @(posedge tx_start) 
    begin
        -> tx_start_hi_evt;
    end

    `include "assertions.vh"

    task asset_command(input reg[7:0] command);
    begin
        assert_eq(dc, `COMMAND_BIT, "dc");
        assert_eq(tx_data, command, "tx_data");
    end
    endtask

    task asset_data(input reg[7:0] data);
    begin
        assert_eq(dc, `DATA_BIT, "dc");
        assert_eq(tx_data, data, "tx_data");
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

    localparam PIXEL_BYTE_COUNT = DIS_RES_X * DIS_RES_Y * 2;

    integer pixel_byte_count = 0;

    initial 
    begin
        $dumpfile("display_controller_tb.vcd");
        $dumpvars(0, display_controller_tb);

        clk_val = 1'b1;                                             // set clk high
        tx_busy_val = 1'b0;                                         // set tx_busy low
        reset_val = 1'b1;                                           // set reset high

        #(CYCLE_TO_TU);                                             // 1 cycle (reset)

        assert_eq(dis_reset, 1, "dis_reset");

        reset_val = 1'b0;                                           // set reset low

        @(dis_reset_lo_evt)

        start_cycle_rec;

        @(dis_reset_hi_evt)

        stop_cycle_rec;

        assert_eq(elapsed_cycles, HW_RESET_HOLD_TIMER, "elapsed_cycles");

        forever 
        begin
            @(tx_start_hi_evt);

            if (step == 0)
            begin
                stop_cycle_rec;
                assert_gt(elapsed_cycles, HW_RESET_RELEASE_TIMER, "elapsed_cycles");
                asset_command(`SW_RESET_CMD);
                start_cycle_rec;
            end
            else if (step == 1)
            begin
                stop_cycle_rec;
                assert_gt(elapsed_cycles, SW_RESET_TIMER, "elapsed_cycles");
                asset_command(`SLEEP_OUT_CMD);
            end
            else if (step == 2)
            begin
                asset_command(`SET_PXL_FMT_CMD);
            end
            else if (step == 4)
            begin
                asset_command(`MEM_ACC_CTR_CMD);
            end
            else if (step == 6)
            begin
                asset_command(`DISPLAY_ON_CMD);
                start_cycle_rec;
            end
            else if (step == 7)
            begin
                stop_cycle_rec;
                assert_gt(elapsed_cycles, DISPLAY_ON_TIMER, "elapsed_cycles");
                asset_command(`SET_COL_ADDR_CMD);
            end
            else if (step == 8 || step == 9)
            begin
                asset_data(8'h00);
            end
            else if (step == 10)
            begin
                asset_data(END_COL[15:8]);
            end
            else if (step == 11)
            begin
                asset_data(END_COL[7:0]);
            end
            else if (step == 12)
            begin
                asset_command(`SET_PAGE_ADDR_CMD);
            end
            else if (step == 13 || step == 14)
            begin
                asset_data(8'h00);
            end
            else if (step == 15)
            begin
                asset_data(END_PAGE[15:8]);
            end
            else if (step == 16)
            begin
                asset_data(END_PAGE[7:0]);
            end
            else if (step == 17)
            begin
                asset_command(`MEM_WRITE_CMD);
            end
            else if (step >= 18)
            begin
                asset_data(pixel_byte_count % 2 == 0 ? 8'hf8 : 8'h00);
                if (pixel_byte_count == PIXEL_BYTE_COUNT - 1)
                begin
                    $display("[display_controller_tb           ] - T(%9t) - success", $time);
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