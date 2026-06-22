# TIME_REPORTER — FPGA Real-Time Clock Module

A synthesisable Verilog RTC module with alarm and countdown timer, designed for 50 MHz FPGA operation.

---

## Features

- **Full Gregorian calendar** — year range 1990–9999 with correct leap-year handling
- **Day-of-week** — computed each cycle via Zeller's congruence (0 = Sunday … 6 = Saturday)
- **Address-mapped register interface** — 15 registers across a 4-bit address bus; invalid writes pulse `error_tick` for one clock cycle and are silently discarded
- **Alarm** — `alarm_out` asserts when the RTC matches a programmed datetime (enabled by `alarm_en`)
- **Countdown timer** — counts down from a programmed HH:MM:SS with correct borrow propagation; `timer_out` asserts at zero when `timer_en` is high

---

## Repository Layout

```
RTC/
├── time.v              # RTL source — pll stub, TIME_REPORTER, day_of_week
├── time_constraint.sdc # Timing constraints (50 MHz target clock)
├── doc/                # Design documents and register map
├── test/               # Python-based test utilities
│   └── Makefile        # Build, simulate, view waveforms (iverilog + GTKWave)
└── README.md
```

---

## Port Reference

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk_1hz` | in | 1 | 1 Hz tick (derive from 50 MHz PLL on board) |
| `rst_n` | in | 1 | Asynchronous active-low reset |
| `wr_en` | in | 1 | Assert for one cycle to write a register |
| `alarm_en` | in | 1 | Enable alarm comparison |
| `timer_en` | in | 1 | Enable and run countdown timer |
| `addr` | in | 4 | Register address (see table below) |
| `data_in` | in | 14 | Write data |
| `rtc_year` | out | 14 | Current year (1990–9999) |
| `rtc_month` | out | 4 | Current month (1–12) |
| `rtc_day` | out | 5 | Current day (1–maxday) |
| `rtc_hour` | out | 5 | Current hour (0–23) |
| `rtc_dow` | out | 3 | Day of week (0=Sun … 6=Sat) |
| `rtc_minute` | out | 6 | Current minute (0–59) |
| `rtc_second` | out | 6 | Current second (0–59) |
| `alarm_out` | out | 1 | High when RTC == alarm time and `alarm_en` |
| `timer_out` | out | 1 | High when timer reaches 00:00:00 and `timer_en` |
| `error_tick` | out | 1 | Pulses high for one cycle on invalid write |

---

## Register Map

| Addr | Register | Valid Range |
|------|----------|-------------|
| `0x0` | `rtc_year` | 1990 – 9999 |
| `0x1` | `rtc_month` | 1 – 12 |
| `0x2` | `rtc_day` | 1 – maxday |
| `0x3` | `rtc_hour` | 0 – 23 |
| `0x4` | `rtc_minute` | 0 – 59 |
| `0x5` | `rtc_second` | 0 – 59 |
| `0x6` | `alarm_year` | 1990 – 9999 |
| `0x7` | `alarm_month` | 1 – 12 |
| `0x8` | `alarm_day` | 1 – maxday |
| `0x9` | `alarm_hour` | 0 – 23 |
| `0xA` | `alarm_minute` | 0 – 59 |
| `0xB` | `alarm_second` | 0 – 59 |
| `0xC` | `timer_hour` | 0 – 23 |
| `0xD` | `timer_minute` | 0 – 59 |
| `0xE` | `timer_second` | 0 – 59 |

**Write protocol:** assert `wr_en = 1` for exactly one `clk_1hz` cycle with `addr` and `data_in` set. Out-of-range values are rejected and `error_tick` pulses high.

---

## Quick Start

### 1 — Install Tools

**Ubuntu / Debian**
```bash
sudo apt update && sudo apt install -y iverilog make gtkwave
```

**Fedora / RHEL**
```bash
sudo dnf install -y iverilog make gtkwave
```

**macOS** (requires [Homebrew](https://brew.sh))
```bash
brew install icarus-verilog make
brew install --cask gtkwave
```

**Windows — WSL (recommended)**
```powershell
# In PowerShell (admin)
wsl --install
# Then open the Ubuntu terminal and follow the Ubuntu steps above
```

**Windows — native**
1. Icarus Verilog installer → https://bleyer.org/icarus
2. GNU Make → https://gnuwin32.sourceforge.net/packages/make.htm
3. GTKWave → https://gtkwave.sourceforge.net
4. Add all three `bin/` directories to your system `PATH`

### 2 — Verify Installation
```bash
iverilog -V    # Icarus Verilog version 12.x
make --version # GNU Make 4.x
gtkwave --version
```

### 3 — Simulate
```bash
cd test/
make           # compile + run testbench
make wave      # open GTKWave with saved signals
```

---

## Instantiation Example

```verilog
TIME_REPORTER u_rtc (
    .clk_1hz   (clk_1hz),
    .rst_n     (rst_n),
    .wr_en     (wr_en),
    .alarm_en  (alarm_en),
    .timer_en  (timer_en),
    .addr      (addr),
    .data_in   (data_in),
    .rtc_year  (rtc_year),
    .rtc_month (rtc_month),
    .rtc_day   (rtc_day),
    .rtc_hour  (rtc_hour),
    .rtc_dow   (rtc_dow),
    .rtc_minute(rtc_minute),
    .rtc_second(rtc_second),
    .alarm_out (alarm_out),
    .timer_out (timer_out),
    .error_tick(error_tick)
);
```

The `clk_1hz` input expects a 1 Hz strobe. On a 50 MHz FPGA, use the on-chip PLL to generate this or divide the system clock with a counter.

---

## Timing Constraints

The included `time_constraint.sdc` targets a 50 MHz system clock. All `TIME_REPORTER` logic is clocked by the derived 1 Hz signal, so the critical path is entirely combinational (Zeller's congruence and the `maxday` decoder).

