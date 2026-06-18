// =============================================================
//  tb_TIME_REPORTER.v
//  Simple self-checking testbench for TIME_REPORTER
//
//  Strategy: clk_1hz is driven directly by the testbench
//  (no need for the 50 MHz divider here — that's only needed
//  on real hardware). Each "tick" task pulses clk_1hz once.
// =============================================================

`timescale 1ns / 1ps

module tb_TIME_REPORTER;

    // ---------------------------------------------------------
    //  DUT signals
    // ---------------------------------------------------------
    reg         clk_1hz;
    reg         rst_n;
    reg         wr_en;
    reg         alarm_en;
    reg         timer_en;
    reg  [13:0] data_in;
    reg  [3:0]  addr;

    wire [13:0] rtc_year;
    wire [3:0]  rtc_month;
    wire [4:0]  rtc_day;
    wire [4:0]  rtc_hour;
    wire [2:0]  rtc_dow;
    wire [5:0]  rtc_minute;
    wire [5:0]  rtc_second;
    wire        alarm_out;
    wire        timer_out;
    wire        error_tick;

    integer errors = 0;

    // ---------------------------------------------------------
    //  DUT instantiation
    // ---------------------------------------------------------
    TIME_REPORTER dut (
        .clk_1hz    (clk_1hz),
        .rst_n      (rst_n),
        .wr_en      (wr_en),
        .alarm_en   (alarm_en),
        .timer_en   (timer_en),
        .data_in    (data_in),
        .addr       (addr),

        .rtc_year   (rtc_year),
        .rtc_month  (rtc_month),
        .rtc_day    (rtc_day),
        .rtc_hour   (rtc_hour),
        .rtc_dow    (rtc_dow),
        .rtc_minute (rtc_minute),
        .rtc_second (rtc_second),

        .alarm_out  (alarm_out),
        .timer_out  (timer_out),
        .error_tick (error_tick)
    );

    // ---------------------------------------------------------
    //  Register address localparams (mirrors DUT)
    // ---------------------------------------------------------
    localparam RTC_Y_ADDR   = 4'h0,
               RTC_M_ADDR   = 4'h1,
               RTC_D_ADDR   = 4'h2,
               RTC_H_ADDR   = 4'h3,
               RTC_MIN_ADDR = 4'h4,
               RTC_SEC_ADDR = 4'h5,
               ALM_Y_ADDR   = 4'h6,
               ALM_M_ADDR   = 4'h7,
               ALM_D_ADDR   = 4'h8,
               ALM_H_ADDR   = 4'h9,
               ALM_MIN_ADDR = 4'hA,
               ALM_SEC_ADDR = 4'hB,
               TMR_H_ADDR   = 4'hC,
               TMR_MIN_ADDR = 4'hD,
               TMR_SEC_ADDR = 4'hE;

    // ---------------------------------------------------------
    //  Helper tasks
    // ---------------------------------------------------------

    // Pulse clk_1hz for one rising edge (10ns period, plenty for sim)
    task tick;
        begin
            clk_1hz = 1'b0;
            #5;
            clk_1hz = 1'b1;
            #5;
        end
    endtask

    // Write one register: drive addr/data, assert wr_en for exactly
    // one tick (matches how the DUT samples wr_en on posedge clk_1hz)
    task write_reg(input [3:0] a, input [13:0] d);
        begin
            addr    = a;
            data_in = d;
            wr_en   = 1'b1;
            tick;
            wr_en   = 1'b0;
        end
    endtask

    task check_equal(input [255:0] name, input [31:0] got, input [31:0] exp);
        begin
            if (got !== exp) begin
                $display("  [FAIL] %0s : expected=%0d got=%0d  (time=%0t)",
                          name, exp, got, $time);
                errors = errors + 1;
            end else begin
                $display("  [PASS] %0s = %0d", name, got);
            end
        end
    endtask

    // ---------------------------------------------------------
    //  Test sequence
    // ---------------------------------------------------------
    initial begin
        $display("=========================================");
        $display(" TIME_REPORTER testbench starting");
        $display("=========================================");

        // Initial values
        clk_1hz  = 0;
        rst_n    = 1;
        wr_en    = 0;
        alarm_en = 0;
        timer_en = 0;
        data_in  = 0;
        addr     = 0;

        // ----------------------------------------------------
        // Test 1: Reset behaviour
        // ----------------------------------------------------
        $display("\n-- Test 1: async reset --");
        rst_n = 0;
        #20;                 // hold reset
        rst_n = 1;
        #1;

        check_equal("rtc_year  after reset", rtc_year,   1990);
        check_equal("rtc_month after reset", rtc_month,  1);
        check_equal("rtc_day   after reset", rtc_day,    1);
        check_equal("rtc_hour  after reset", rtc_hour,   0);
        check_equal("rtc_minute after reset", rtc_minute, 0);
        check_equal("rtc_second after reset", rtc_second, 0);

        // ----------------------------------------------------
        // Test 2: free-running seconds counter
        // ----------------------------------------------------
        $display("\n-- Test 2: seconds increment each tick --");
        tick;
        check_equal("rtc_second after 1 tick", rtc_second, 1);
        tick;
        tick;
        check_equal("rtc_second after 3 ticks", rtc_second, 3);

        // ----------------------------------------------------
        // Test 3: minute rollover (drive seconds to 59 then tick)
        // ----------------------------------------------------
        $display("\n-- Test 3: second->minute rollover --");
        write_reg(RTC_SEC_ADDR, 59);
        check_equal("rtc_second after write 59", rtc_second, 59);
        check_equal("error_tick on valid write", error_tick, 0);

        tick;  // 59 -> 0, minute should increment
        check_equal("rtc_second after rollover", rtc_second, 0);
        check_equal("rtc_minute after rollover", rtc_minute, 1);

        // ----------------------------------------------------
        // Test 4: invalid write rejected (error_tick asserted)
        // ----------------------------------------------------
        $display("\n-- Test 4: out-of-range write rejected --");
        write_reg(RTC_SEC_ADDR, 70);   // invalid (>59)
        check_equal("error_tick on invalid sec write", error_tick, 1);
        check_equal("rtc_second unchanged on bad write", rtc_second, 0);

        // ----------------------------------------------------
        // Test 5: hour/day/month/year rollover chain
        //   Set time to 23:59:59 on Dec 31 and tick once
        // ----------------------------------------------------
        $display("\n-- Test 5: full rollover chain (year boundary) --");
        write_reg(RTC_Y_ADDR,   2024);
        write_reg(RTC_M_ADDR,   12);
        write_reg(RTC_D_ADDR,   31);
        write_reg(RTC_H_ADDR,   23);
        write_reg(RTC_MIN_ADDR, 59);
        write_reg(RTC_SEC_ADDR, 59);

        check_equal("year before rollover",  rtc_year,  2024);
        check_equal("month before rollover", rtc_month, 12);
        check_equal("day before rollover",   rtc_day,   31);

        tick;  // the big rollover: 23:59:59 -> 00:00:00, day/month/year roll

        check_equal("rtc_second after full rollover", rtc_second, 0);
        check_equal("rtc_minute after full rollover", rtc_minute, 0);
        check_equal("rtc_hour   after full rollover", rtc_hour,   0);
        check_equal("rtc_day    after full rollover", rtc_day,    1);
        check_equal("rtc_month  after full rollover", rtc_month,  1);
        check_equal("rtc_year   after full rollover", rtc_year,   2025);

        // ----------------------------------------------------
        // Test 6: leap year Feb 29 (2024 is a leap year)
        // ----------------------------------------------------
        $display("\n-- Test 6: leap year Feb 28 -> Feb 29 --");
        write_reg(RTC_Y_ADDR,   2024);
        write_reg(RTC_M_ADDR,   2);
        write_reg(RTC_D_ADDR,   28);
        write_reg(RTC_H_ADDR,   23);
        write_reg(RTC_MIN_ADDR, 59);
        write_reg(RTC_SEC_ADDR, 59);

        tick;  // should roll to Feb 29 (leap year), not Mar 1

        check_equal("leap year day rolls to 29", rtc_day,   29);
        check_equal("leap year month stays Feb",  rtc_month, 2);

        // ----------------------------------------------------
        // Test 7: alarm match
        // ----------------------------------------------------
        $display("\n-- Test 7: alarm fires on exact match --");
        write_reg(RTC_Y_ADDR,   2025);
        write_reg(RTC_M_ADDR,   6);
        write_reg(RTC_D_ADDR,   15);
        write_reg(RTC_H_ADDR,   10);
        write_reg(RTC_MIN_ADDR, 30);
        write_reg(RTC_SEC_ADDR, 0);

        write_reg(ALM_Y_ADDR,   2025);
        write_reg(ALM_M_ADDR,   6);
        write_reg(ALM_D_ADDR,   15);
        write_reg(ALM_H_ADDR,   10);
        write_reg(ALM_MIN_ADDR, 30);
        write_reg(ALM_SEC_ADDR, 0);

        alarm_en = 1;
        #1;
        check_equal("alarm_out on exact match", alarm_out, 1);

        tick; // second advances, match broken
        check_equal("alarm_out clears after tick", alarm_out, 0);
        alarm_en = 0;

        // ----------------------------------------------------
        // Test 8: countdown timer reaches zero
        // ----------------------------------------------------
        $display("\n-- Test 8: timer counts down to zero --");
        write_reg(TMR_H_ADDR,   0);
        write_reg(TMR_MIN_ADDR, 0);
        write_reg(TMR_SEC_ADDR, 2);

        timer_en = 1;
        check_equal("timer_out before expiry", timer_out, 0);

        tick;  // 2 -> 1
        check_equal("timer_out at 1s remaining", timer_out, 0);

        tick;  // 1 -> 0
        check_equal("timer_out at 0s remaining", timer_out, 1);
        timer_en = 0;

        // ----------------------------------------------------
        // Test 9: day-of-week sanity check
        //   2025-06-15 is a Sunday (dow = 0)
        // ----------------------------------------------------
        $display("\n-- Test 9: day_of_week (Zeller) sanity check --");
        write_reg(RTC_Y_ADDR, 2025);
        write_reg(RTC_M_ADDR, 6);
        write_reg(RTC_D_ADDR, 15);
        #1;
        check_equal("2025-06-15 is Sunday (dow=0)", rtc_dow, 0);

        // ----------------------------------------------------
        // Wrap up
        // ----------------------------------------------------
        $display("\n=========================================");
        if (errors == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" %0d TEST(S) FAILED", errors);
        $display("=========================================");

        $finish;
    end

    // Safety timeout in case of hang
    initial begin
        #100000;
        $display("[TIMEOUT] testbench did not finish in time");
        $finish;
    end

endmodule
