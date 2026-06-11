# TIME_REPORTER

A synthesisable Verilog RTC module with alarm and countdown timer, targeting 50 MHz FPGA operation.

## Features

- Full Gregorian calendar (year 1990–9999) with leap year support
- Day-of-week output via Zeller's congruence
- Address-mapped register interface with input validation
- Alarm: fires when RTC matches a programmed datetime
- Countdown timer with hour/minute/second borrow propagation

## Files

```
time.v       — RTL source (pll, TIME_REPORTER, day_of_week)
tb.v         — Original testbench
Makefile     — Build, simulate, view waveforms
```

---

## Installing Tools

### Linux (Ubuntu / Debian)

```bash
sudo apt update
sudo apt install -y iverilog make gtkwave
```

### Linux (Fedora / RHEL)

```bash
sudo dnf install -y iverilog make gtkwave
```

### macOS

Install [Homebrew](https://brew.sh) first, then:

```bash
brew install icarus-verilog make
brew install --cask gtkwave
```

### Windows

Two options:

**Option A — WSL (recommended)**
1. Install [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install): open PowerShell as admin and run `wsl --install`
2. Open the Ubuntu terminal it creates, then follow the Linux instructions above

**Option B — Native**
1. Download the Icarus Verilog Windows installer from https://bleyer.org/icarus
2. Install [GNU Make for Windows](https://gnuwin32.sourceforge.net/packages/make.htm)
3. Download [GTKWave for Windows](https://gtkwave.sourceforge.net) and extract it
4. Add all three `bin/` folders to your system PATH

---

## Verify Installation

```bash
iverilog -V   # should print: Icarus Verilog version 12.x
make --version # should print: GNU Make 4.x
gtkwave --version
```

---

## Register Map (quick reference)

| Addr | Register      | Valid Range          |
|------|---------------|----------------------|
| 0x0  | rtc_year      | 1990 – 9999          |
| 0x1  | rtc_month     | 1 – 12               |
| 0x2  | rtc_day       | 1 – maxday           |
| 0x3  | rtc_hour      | 0 – 23               |
| 0x4  | rtc_minute    | 0 – 59               |
| 0x5  | rtc_second    | 0 – 59               |
| 0x6  | alarm_year    | 1990 – 9999          |
| 0x7  | alarm_month   | 1 – 12               |
| 0x8  | alarm_day     | 1 – maxday           |
| 0x9  | alarm_hour    | 0 – 23               |
| 0xA  | alarm_minute  | 0 – 59               |
| 0xB  | alarm_second  | 0 – 59               |
| 0xC  | timer_hour    | 0 – 23               |
| 0xD  | timer_minute  | 0 – 59               |
| 0xE  | timer_second  | 0 – 59               |

Write: assert `wr_en=1` for one clock cycle with `addr` and `data_in` set.  
Invalid values are silently rejected and `error` pulses high for one cycle.
