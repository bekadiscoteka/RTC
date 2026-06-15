import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles


# ── helpers ────────────────────────────────────────────────────────────────────

async def reset(dut):
    dut.rst_n.value    = 0
    dut.wr_en.value    = 0
    dut.alarm_en.value = 0
    dut.timer_en.value = 0
    dut.data_in.value  = 0
    dut.addr.value     = 0
    await ClockCycles(dut.clk_50Mhz, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk_50Mhz, 2)


async def write_reg(dut, addr, value):
    """Write one register via the bus."""
    dut.addr.value    = addr
    dut.data_in.value = value
    dut.wr_en.value   = 1
    await RisingEdge(dut.clk_50Mhz)
    dut.wr_en.value = 0
    await RisingEdge(dut.clk_50Mhz)   # let it settle


async def set_time(dut, year, month, day, hour, minute, second):
    """Write all RTC fields at once."""
    await write_reg(dut, 0x0, year)
    await write_reg(dut, 0x1, month)
    await write_reg(dut, 0x2, day)
    await write_reg(dut, 0x3, hour)
    await write_reg(dut, 0x4, minute)
    await write_reg(dut, 0x5, second)


async def set_alarm(dut, year, month, day, hour, minute, second):
    await write_reg(dut, 0x6, year)
    await write_reg(dut, 0x7, month)
    await write_reg(dut, 0x8, day)
    await write_reg(dut, 0x9, hour)
    await write_reg(dut, 0xA, minute)
    await write_reg(dut, 0xB, second)


async def wait_ticks(dut, n):
    """Wait for n second_ticks (PLL is set to DIV=2, so 2 clocks = 1 tick).
    tb_top wraps TIME_REPORTER as 'dut', so hierarchy is dut.dut.pll_inst.tick
    """
    for _ in range(n):
        await RisingEdge(dut.dut.pll_inst.tick)
        await RisingEdge(dut.clk_50Mhz)


# ── tests ──────────────────────────────────────────────────────────────────────

@cocotb.test()
async def test_reset_values(dut):
    """After reset, RTC should be 1990-01-01 00:00:00."""
    cocotb.start_soon(Clock(dut.clk_50Mhz, 10, units="ns").start())
    await reset(dut)

    assert dut.rtc_year.value   == 1990, f"year={dut.rtc_year.value}"
    assert dut.rtc_month.value  == 1
    assert dut.rtc_day.value    == 1
    assert dut.rtc_hour.value   == 0
    assert dut.rtc_minute.value == 0
    assert dut.rtc_second.value == 0
    assert dut.error.value      == 0
    cocotb.log.info("PASS: reset values correct")


@cocotb.test()
async def test_write_read_rtc(dut):
    """Write a date/time and read it back immediately."""
    cocotb.start_soon(Clock(dut.clk_50Mhz, 10, units="ns").start())
    await reset(dut)

    await set_time(dut, year=2025, month=6, day=15, hour=9, minute=30, second=45)

    assert dut.rtc_year.value   == 2025
    assert dut.rtc_month.value  == 6
    assert dut.rtc_day.value    == 15
    assert dut.rtc_hour.value   == 9
    assert dut.rtc_minute.value == 30
    assert dut.rtc_second.value == 45
    assert dut.error.value      == 0
    cocotb.log.info("PASS: write/read RTC")


@cocotb.test()
async def test_invalid_write(dut):
    """Writing out-of-range values must set error flag."""
    cocotb.start_soon(Clock(dut.clk_50Mhz, 10, units="ns").start())
    await reset(dut)

    # month = 13  (invalid)
    await write_reg(dut, 0x1, 13)
    assert dut.error.value == 1, "expected error for month=13"
    cocotb.log.info("PASS: error on invalid month")

    # hour = 24  (invalid)
    await write_reg(dut, 0x3, 24)
    assert dut.error.value == 1, "expected error for hour=24"
    cocotb.log.info("PASS: error on invalid hour")


@cocotb.test()
async def test_second_increment(dut):
    """
    With DIV=2 the PLL fires every 2 clock edges.
    Set time to 00:00:58 and wait 2 ticks → should reach 00:01:00.
    """
    cocotb.start_soon(Clock(dut.clk_50Mhz, 10, units="ns").start())
    await reset(dut)

    await set_time(dut, 2025, 1, 1, 0, 0, 58)
    await wait_ticks(dut, 3)

    assert dut.rtc_second.value == 0,  f"sec={dut.rtc_second.value}"
    assert dut.rtc_minute.value == 1,  f"min={dut.rtc_minute.value}"
    cocotb.log.info("PASS: second and minute rollover")


@cocotb.test()
async def test_alarm_trigger(dut):
    """Alarm fires when RTC matches alarm registers."""
    cocotb.start_soon(Clock(dut.clk_50Mhz, 10, units="ns").start())
    await reset(dut)

    # Set RTC and alarm to the SAME time
    await set_time (dut, 2025, 6, 15, 10, 0, 0)
    await set_alarm(dut, 2025, 6, 15, 10, 0, 0)

    dut.alarm_en.value = 1
    await ClockCycles(dut.clk_50Mhz, 1)

    assert dut.alarm_out.value == 1, "alarm should be HIGH"
    cocotb.log.info("PASS: alarm fires")

    # Disable alarm
    dut.alarm_en.value = 0
    await ClockCycles(dut.clk_50Mhz, 2)
    assert dut.alarm_out.value == 0
    cocotb.log.info("PASS: alarm clears when disabled")


@cocotb.test()
async def test_timer_countdown(dut):
    """Timer counts down; timer_out goes high when it reaches 00:00:00."""
    cocotb.start_soon(Clock(dut.clk_50Mhz, 10, units="ns").start())
    await reset(dut)

    # Load timer with 0h 0m 2s
    await write_reg(dut, 0xC, 0)   # timer_hour
    await write_reg(dut, 0xD, 0)   # timer_minute
    await write_reg(dut, 0xE, 2)   # timer_second

    dut.timer_en.value = 1

    # After 2 ticks it should hit 0 and raise timer_out
    await wait_ticks(dut, 3)

    assert dut.timer_out.value == 1, f"timer_out expected 1"
    cocotb.log.info("PASS: timer countdown to zero")
