"""
test_time_reporter.py
cocotb testbench for TIME_REPORTER (time.v)

Run with:
    make SIM=icarus

Mirrors the same test plan as the plain-Verilog tb_TIME_REPORTER.v:
  1. async reset
  2. free-running seconds counter
  3. second -> minute rollover
  4. invalid write rejected (error_tick)
  5. full rollover chain at year boundary
  6. leap-year Feb 28 -> Feb 29
  7. alarm match
  8. timer countdown to zero
  9. day-of-week (Zeller) sanity check
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

# ---------------------------------------------------------------
# Register address map (mirrors localparams in time.v)
# ---------------------------------------------------------------
RTC_Y_ADDR, RTC_M_ADDR, RTC_D_ADDR  = 0x0, 0x1, 0x2
RTC_H_ADDR, RTC_MIN_ADDR, RTC_SEC_ADDR = 0x3, 0x4, 0x5
ALM_Y_ADDR, ALM_M_ADDR, ALM_D_ADDR  = 0x6, 0x7, 0x8
ALM_H_ADDR, ALM_MIN_ADDR, ALM_SEC_ADDR = 0x9, 0xA, 0xB
TMR_H_ADDR, TMR_MIN_ADDR, TMR_SEC_ADDR = 0xC, 0xD, 0xE


async def tick(dut):
    """Advance exactly one clk_1hz rising edge."""
    await RisingEdge(dut.clk_1hz)
    # tiny settle delay so reg outputs (NBA updates) are visible
    await Timer(1, unit="ns")


async def write_reg(dut, addr, value):
    """Drive addr/data, hold wr_en for exactly one clk_1hz edge."""
    dut.addr.value = addr
    dut.data_in.value = value
    dut.wr_en.value = 1
    await tick(dut)
    dut.wr_en.value = 0


async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.wr_en.value = 0
    dut.alarm_en.value = 0
    dut.timer_en.value = 0
    dut.data_in.value = 0
    dut.addr.value = 0

    # The clk_1hz Clock() runs continuously in the background, so we
    # must not release rst_n exactly on top of a rising edge (that
    # creates a simulator race between the posedge and negedge
    # sensitivity in the DUT's always block). Wait for a couple of
    # falling edges first, then deassert reset safely mid-low-phase,
    # well clear of the next rising edge.
    await FallingEdge(dut.clk_1hz)
    await FallingEdge(dut.clk_1hz)
    dut.rst_n.value = 1
    await Timer(1, unit="ns")


def check(dut, name, got, exp):
    got_i = int(got)
    if got_i != exp:
        dut._log.error(f"[FAIL] {name}: expected={exp} got={got_i}")
        raise AssertionError(f"{name}: expected={exp} got={got_i}")
    dut._log.info(f"[PASS] {name} = {got_i}")


@cocotb.test()
async def test_time_reporter(dut):
    """Full functional test of TIME_REPORTER"""

    # clk_1hz is driven directly by this testbench (no 50MHz divider
    # needed here -- that only matters on real hardware / the
    # DE10_LITE_TOP wrapper). Use a fast sim period; only edges matter.
    clock = Clock(dut.clk_1hz, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # -------------------------------------------------------
    # Test 1: async reset
    # -------------------------------------------------------
    dut._log.info("-- Test 1: async reset --")
    await reset_dut(dut)

    check(dut, "rtc_year after reset",  dut.rtc_year.value,  1990)
    check(dut, "rtc_month after reset", dut.rtc_month.value, 1)
    check(dut, "rtc_day after reset",   dut.rtc_day.value,   1)
    check(dut, "rtc_hour after reset",  dut.rtc_hour.value,  0)
    check(dut, "rtc_minute after reset", dut.rtc_minute.value, 0)
    check(dut, "rtc_second after reset", dut.rtc_second.value, 0)

    # -------------------------------------------------------
    # Test 2: free-running seconds counter
    # -------------------------------------------------------
    dut._log.info("-- Test 2: seconds increment each tick --")
    await tick(dut)
    check(dut, "rtc_second after 1 tick", dut.rtc_second.value, 1)
    await tick(dut)
    await tick(dut)
    check(dut, "rtc_second after 3 ticks", dut.rtc_second.value, 3)

    # -------------------------------------------------------
    # Test 3: second -> minute rollover
    # -------------------------------------------------------
    dut._log.info("-- Test 3: second->minute rollover --")
    await write_reg(dut, RTC_SEC_ADDR, 59)
    check(dut, "rtc_second after write 59", dut.rtc_second.value, 59)
    check(dut, "error_tick on valid write", dut.error_tick.value, 0)

    await tick(dut)  # 59 -> 0, minute increments
    check(dut, "rtc_second after rollover", dut.rtc_second.value, 0)
    check(dut, "rtc_minute after rollover", dut.rtc_minute.value, 1)

    # -------------------------------------------------------
    # Test 4: invalid write rejected
    # -------------------------------------------------------
    dut._log.info("-- Test 4: out-of-range write rejected --")
    await write_reg(dut, RTC_SEC_ADDR, 70)  # invalid (>59)
    check(dut, "error_tick on invalid sec write", dut.error_tick.value, 1)
    check(dut, "rtc_second unchanged on bad write", dut.rtc_second.value, 0)

    # -------------------------------------------------------
    # Test 5: full rollover chain at year boundary
    # -------------------------------------------------------
    dut._log.info("-- Test 5: full rollover chain (year boundary) --")
    await write_reg(dut, RTC_Y_ADDR,   2024)
    await write_reg(dut, RTC_M_ADDR,   12)
    await write_reg(dut, RTC_D_ADDR,   31)
    await write_reg(dut, RTC_H_ADDR,   23)
    await write_reg(dut, RTC_MIN_ADDR, 59)
    await write_reg(dut, RTC_SEC_ADDR, 59)

    check(dut, "year before rollover",  dut.rtc_year.value,  2024)
    check(dut, "month before rollover", dut.rtc_month.value, 12)
    check(dut, "day before rollover",   dut.rtc_day.value,   31)

    await tick(dut)  # 23:59:59 -> 00:00:00, day/month/year all roll

    check(dut, "rtc_second after full rollover", dut.rtc_second.value, 0)
    check(dut, "rtc_minute after full rollover", dut.rtc_minute.value, 0)
    check(dut, "rtc_hour after full rollover",   dut.rtc_hour.value,   0)
    check(dut, "rtc_day after full rollover",    dut.rtc_day.value,    1)
    check(dut, "rtc_month after full rollover",  dut.rtc_month.value,  1)
    check(dut, "rtc_year after full rollover",   dut.rtc_year.value,   2025)

    # -------------------------------------------------------
    # Test 6: leap year Feb 28 -> Feb 29
    # -------------------------------------------------------
    dut._log.info("-- Test 6: leap year Feb 28 -> Feb 29 --")
    await write_reg(dut, RTC_Y_ADDR,   2024)
    await write_reg(dut, RTC_M_ADDR,   2)
    await write_reg(dut, RTC_D_ADDR,   28)
    await write_reg(dut, RTC_H_ADDR,   23)
    await write_reg(dut, RTC_MIN_ADDR, 59)
    await write_reg(dut, RTC_SEC_ADDR, 59)

    await tick(dut)  # should roll to Feb 29, not Mar 1 (2024 is leap)

    check(dut, "leap year day rolls to 29", dut.rtc_day.value,   29)
    check(dut, "leap year month stays Feb", dut.rtc_month.value, 2)

    # -------------------------------------------------------
    # Test 7: alarm match
    # -------------------------------------------------------
    dut._log.info("-- Test 7: alarm fires on exact match --")
    await write_reg(dut, RTC_Y_ADDR,   2025)
    await write_reg(dut, RTC_M_ADDR,   6)
    await write_reg(dut, RTC_D_ADDR,   15)
    await write_reg(dut, RTC_H_ADDR,   10)
    await write_reg(dut, RTC_MIN_ADDR, 30)
    await write_reg(dut, RTC_SEC_ADDR, 0)

    await write_reg(dut, ALM_Y_ADDR,   2025)
    await write_reg(dut, ALM_M_ADDR,   6)
    await write_reg(dut, ALM_D_ADDR,   15)
    await write_reg(dut, ALM_H_ADDR,   10)
    await write_reg(dut, ALM_MIN_ADDR, 30)
    await write_reg(dut, ALM_SEC_ADDR, 0)

    dut.alarm_en.value = 1
    await Timer(1, unit="ns")
    check(dut, "alarm_out on exact match", dut.alarm_out.value, 1)

    await tick(dut)  # second advances, match broken
    check(dut, "alarm_out clears after tick", dut.alarm_out.value, 0)
    dut.alarm_en.value = 0

    # -------------------------------------------------------
    # Test 8: countdown timer reaches zero
    # -------------------------------------------------------
    dut._log.info("-- Test 8: timer counts down to zero --")
    await write_reg(dut, TMR_H_ADDR,   0)
    await write_reg(dut, TMR_MIN_ADDR, 0)
    await write_reg(dut, TMR_SEC_ADDR, 2)

    dut.timer_en.value = 1
    check(dut, "timer_out before expiry", dut.timer_out.value, 0)

    await tick(dut)  # 2 -> 1
    check(dut, "timer_out at 1s remaining", dut.timer_out.value, 0)

    await tick(dut)  # 1 -> 0
    check(dut, "timer_out at 0s remaining", dut.timer_out.value, 1)
    dut.timer_en.value = 0

    # -------------------------------------------------------
    # Test 9: day-of-week sanity check
    #   2025-06-15 is a Sunday (dow = 0)
    # -------------------------------------------------------
    dut._log.info("-- Test 9: day_of_week (Zeller) sanity check --")
    await write_reg(dut, RTC_Y_ADDR, 2025)
    await write_reg(dut, RTC_M_ADDR, 6)
    await write_reg(dut, RTC_D_ADDR, 15)
    await Timer(1, unit="ns")
    check(dut, "2025-06-15 is Sunday (dow=0)", dut.rtc_dow.value, 0)

    dut._log.info("ALL TESTS PASSED")
