// tb_top.v — thin wrapper so cocotb sees all DUT signals,
// but the PLL uses DIV=2 (not 50_000_000) so tests run fast.

// Override the PLL parameter inside TIME_REPORTER.
// In Icarus Verilog you can do this with defparam:
module tb_top (
    output [13:0] rtc_year,
    output [3:0]  rtc_month,
    output [4:0]  rtc_day, rtc_hour,
    output [2:0]  rtc_dow,
    output [5:0]  rtc_minute, rtc_second,
    output        alarm_out, timer_out, error,
    input         clk_50Mhz, rst_n, wr_en, alarm_en, timer_en,
    input  [13:0] data_in,
    input  [3:0]  addr
);

    TIME_REPORTER dut (
        .rtc_year(rtc_year), .rtc_month(rtc_month),
        .rtc_day(rtc_day),   .rtc_hour(rtc_hour),
        .rtc_dow(rtc_dow),
        .rtc_minute(rtc_minute), .rtc_second(rtc_second),
        .alarm_out(alarm_out), .timer_out(timer_out), .error(error),
        .clk_50Mhz(clk_50Mhz), .rst_n(rst_n),
        .wr_en(wr_en), .alarm_en(alarm_en), .timer_en(timer_en),
        .data_in(data_in), .addr(addr)
    );

    // Override PLL divisor to 2 so 1 "second" = 2 clock cycles
    defparam dut.pll_inst.DIV = 2;

endmodule
