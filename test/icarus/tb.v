`timescale 1ns/1ps


// ============================================================
//  Testbench for TIME_REPORTER
//  Tool:  iverilog time_tb.v time.v -o sim.out && vvp sim.out
//  View:  gtkwave dump.vcd
// ============================================================

module time_tb;

	localparam CLK_DIV = 100;

    // ----------------------------------------------------------
    // DUT signals
    // ----------------------------------------------------------
    wire [13:0] rtc_year;
    wire [3:0]  rtc_month;
    wire [4:0]  rtc_day, rtc_hour;
    wire [2:0]  rtc_dow;
    wire [5:0]  rtc_minute, rtc_second;
    wire        alarm_out, timer_out, invalid_data_flag;

    reg         clk_50Mhz, rst_n, wr_en, alarm_en, timer_en;
    reg [13:0]  data_in;
    reg [3:0]   addr;

    // ----------------------------------------------------------
    // Instantiate DUT with tiny DIV so 1 "second" = 4 clocks
    // (override the pll parameter through defparam on the
    //  internal instance — works in iverilog)
    // ----------------------------------------------------------
    TIME_REPORTER dut (
        .rtc_year(rtc_year), .rtc_month(rtc_month),
        .rtc_day(rtc_day),   .rtc_hour(rtc_hour),
        .rtc_dow(rtc_dow),
        .rtc_minute(rtc_minute), .rtc_second(rtc_second),
        .alarm_out(alarm_out),   .timer_out(timer_out),
        .error(invalid_data_flag),
        .clk_50Mhz(clk_50Mhz),  .rst_n(rst_n),
        .wr_en(wr_en),           .alarm_en(alarm_en),
        .timer_en(timer_en),
        .data_in(data_in),       .addr(addr)
    );

    // Override PLL divisor so 1 tick = 4 clock edges (fast sim)
    defparam dut.pll_inst.DIV = CLK_DIV;

    // ----------------------------------------------------------
    // Clock: 10ns period = 100 MHz (period doesn't matter,
    //         only DIV count matters for tick generation)
    // ----------------------------------------------------------
    initial clk_50Mhz = 0;
    always #5 clk_50Mhz = ~clk_50Mhz;

    // ----------------------------------------------------------
    // VCD dump for GTKWave
    // ----------------------------------------------------------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, time_tb);
    end

    // ----------------------------------------------------------
    // Helper task: write one register
    // ----------------------------------------------------------
    task write_reg;
        input [3:0]  a;
        input [13:0] d;
        begin
            @(negedge clk_50Mhz);
            addr    = a;
            data_in = d;
            wr_en   = 1;
            @(negedge clk_50Mhz);
            wr_en   = 0;
        end
    endtask

    // ----------------------------------------------------------
    // Helper task: wait N seconds (N * DIV clock cycles)
    // ----------------------------------------------------------
    task wait_seconds;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                repeat(CLK_DIV) @(posedge clk_50Mhz);
        end
    endtask

    // ----------------------------------------------------------
    // Helper task: check and print pass/fail
    // ----------------------------------------------------------
    task check;
        input [127:0] test_name; // string passed as bits
        input         condition;
        begin
            if (condition)
                $display("  PASS  %s", test_name);
            else
                $display("  FAIL  %s", test_name);
        end
    endtask

    // ----------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------
    integer errors;

    initial begin
        // ---- init ----
        rst_n   = 1; wr_en = 0; alarm_en = 0; timer_en = 0;
        data_in = 0; addr  = 0;
        errors  = 0;

        // ======================================================
        // TEST 1: Reset
        // ======================================================
        $display("\n=== TEST 1: Reset state ===");
        rst_n = 0;
        repeat(4) @(negedge clk_50Mhz);
        rst_n = 1;
        @(negedge clk_50Mhz);

        check("year  resets to 1990", rtc_year   == 14'd1990);
        check("month resets to 1",    rtc_month  == 4'd1);
        check("day   resets to 1",    rtc_day    == 5'd1);
        check("hour  resets to 0",    rtc_hour   == 5'd0);
        check("min   resets to 0",    rtc_minute == 6'd0);
        check("sec   resets to 0",    rtc_second == 6'd0);

        // ======================================================
        // TEST 2: Register writes — set RTC to 2025-06-11 13:45:00
        // ======================================================
        $display("\n=== TEST 2: Register writes ===");

        write_reg(4'h0, 14'd2025);  // year
        write_reg(4'h1, 4'd6);      // month = June
        write_reg(4'h2, 5'd11);     // day = 11
        write_reg(4'h3, 5'd13);     // hour = 13
        write_reg(4'h4, 6'd45);     // minute = 45
        write_reg(4'h5, 6'd0);      // second = 0

        @(negedge clk_50Mhz);
        check("year  = 2025", rtc_year   == 14'd2025);
        check("month = 6",    rtc_month  == 4'd6);
        check("day   = 11",   rtc_day    == 5'd11);
        check("hour  = 13",   rtc_hour   == 5'd13);
        check("min   = 45",   rtc_minute == 6'd45);
        check("sec   = 0",    rtc_second == 6'd0);

        // Check day-of-week: 2025-06-11 is a Wednesday (dow=3)
        check("dow   = 3 (Wed)", rtc_dow == 3'd3);
	$display(" rtc_dow = %d", rtc_dow);

        // ======================================================
        // TEST 3: Invalid data rejection
        // ======================================================
        $display("\n=== TEST 3: Invalid data ===");

        // Bad year (< 1990)
        write_reg(4'h0, 14'd1985);
        check("invalid year rejected",  invalid_data_flag == 1);
        check("year unchanged",         rtc_year == 14'd2025);
        @(negedge clk_50Mhz);

        // Bad month (= 0)
        write_reg(4'h1, 4'd0);
        check("invalid month rejected", invalid_data_flag == 1);
        check("month unchanged",        rtc_month == 4'd6);
        @(negedge clk_50Mhz);

        // Bad hour (>= 24)
        write_reg(4'h3, 14'd24);
        check("invalid hour rejected",  invalid_data_flag == 1);
        check("hour unchanged",         rtc_hour == 5'd13);
        @(negedge clk_50Mhz);

        // Bad minute (>= 60)
        write_reg(4'h4, 14'd60);
        check("invalid minute rejected",invalid_data_flag == 1);
        @(negedge clk_50Mhz);

        // ======================================================
        // TEST 4: Tick / rollover
        // Set time to 23:59:58, wait 3 seconds,
        // expect rollover to next day 00:00:01
        // ======================================================
        $display("\n=== TEST 4: Rollover 23:59:58 -> 00:00:01 ===");

        write_reg(4'h3, 5'd23);
        write_reg(4'h4, 6'd59);
        write_reg(4'h5, 6'd58);

        wait_seconds(3);
        @(negedge clk_50Mhz);

        check("hour  rolled to 0",  rtc_hour   == 5'd0);
        check("min   rolled to 0",  rtc_minute == 6'd0);
        check("sec   = 1",          rtc_second == 6'd1);
        check("day   incremented",  rtc_day    == 5'd12);
	$display("hour: %d, minute=%d, second=%d, day=%d", rtc_hour, rtc_minute, rtc_second, rtc_day);

        // ======================================================
        // TEST 5: Alarm trigger
        // Set RTC to 2025-06-15 08:00:00
        // Set alarm to same time, enable it
        // ======================================================
        $display("\n=== TEST 5: Alarm trigger ===");

        // Set RTC
        write_reg(4'h0, 14'd2025);
        write_reg(4'h1, 4'd6);
        write_reg(4'h2, 5'd15);
        write_reg(4'h3, 5'd8);
        write_reg(4'h4, 6'd0);
        write_reg(4'h5, 6'd0);

        // Set alarm to same datetime
        write_reg(4'h6, 14'd2025);  // alarm year
        write_reg(4'h7, 4'd6);      // alarm month
        write_reg(4'h8, 5'd15);     // alarm day
        write_reg(4'h9, 5'd8);      // alarm hour
        write_reg(4'ha, 6'd0);      // alarm minute
        write_reg(4'hb, 6'd0);      // alarm second

        alarm_en = 1;
        @(negedge clk_50Mhz);
        check("alarm fires at exact match", alarm_out == 1);

        // Advance one second — alarm should be silent
        wait_seconds(1);
        @(negedge clk_50Mhz);
        check("alarm silent after tick", alarm_out == 0);
        alarm_en = 0;

        // ======================================================
        // TEST 6: Timer countdown
        // Load timer = 0h 0m 3s, enable, wait 4 seconds,
        // timer_out should fire at 0
        // ======================================================
        $display("\n=== TEST 6: Timer countdown ===");

        write_reg(4'hc, 5'd0);   // timer_hour  = 0
        write_reg(4'hd, 6'd0);   // timer_minute = 0
        write_reg(4'he, 6'd3);   // timer_second = 3

        timer_en = 1;
        @(negedge clk_50Mhz);
        check("timer not expired yet", timer_out == 0);

        wait_seconds(3);
        @(negedge clk_50Mhz);
        check("timer expired (timer_out=1)", timer_out == 1);

        timer_en = 0;

        // ======================================================
        // DONE
        // ======================================================
        $display("\n=== Simulation complete ===\n");
        #100 $finish;
    end

    // ----------------------------------------------------------
    // Timeout watchdog — kill sim if it hangs
    // ----------------------------------------------------------
    initial begin
        #500_000;
        $display("TIMEOUT — simulation hung");
        $finish;
    end

    // ----------------------------------------------------------
    // Live monitor — prints every second tick
    // ----------------------------------------------------------
    always @(posedge dut.second_tick) begin
        $display("[tick] %04d-%02d-%02d (dow=%0d) %02d:%02d:%02d  | timer=%02d:%02d:%02d",
            rtc_year, rtc_month, rtc_day, rtc_dow,
            rtc_hour, rtc_minute, rtc_second,
            dut.timer_hour, dut.timer_minute, dut.timer_second);
    end

endmodule
