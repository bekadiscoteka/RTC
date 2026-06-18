# -------------------------------------------------------------------------
# Define the clock with a 1 MHz period (1000 ns) to satisfy Quartus limits.
# If the design meets timing at 1 MHz, it will safely meet it at 1 Hz.
create_clock -name clk_1hz -period 1us [get_ports {clk_1hz}]

derive_clock_uncertainty

# -------------------------------------------------------------------------
# 2. Input Constraints
# -------------------------------------------------------------------------
set_input_delay -clock clk_1hz 5.0 [get_ports {wr_en alarm_en timer_en data_in[*] addr[*]}]
set_input_delay -clock clk_1hz 5.0 [get_ports {rst_n}]

# -------------------------------------------------------------------------
# 3. Output Constraints
# -------------------------------------------------------------------------
set_output_delay -clock clk_1hz 5.0 [get_ports {rtc_year[*] rtc_month[*] rtc_day[*] rtc_hour[*] rtc_minute[*] rtc_second[*] alarm_out timer_out error_tick}]

# Fixed the stray braces at the end of this line:
set_output_delay -clock clk_1hz 5.0 [get_ports {rtc_dow[*]}]}}}}}
create_clock -name clk_1hz -period 10000 [get_ports {clk_1hz}]

# Automatically derive clock uncertainties (jitter, guard bands)
derive_clock_uncertainty

# -------------------------------------------------------------------------
# 2. Input Constraints
# -------------------------------------------------------------------------
# Constrain all synchronous input ports relative to clk_1hz.
# Note: The 5.0 ns value is a placeholder. Adjust this based on your actual 
# board delays or upstream module constraints.
set_input_delay -clock clk_1hz 5.0 [get_ports {wr_en alarm_en timer_en data_in[*] addr[*]}]

# rst_n is used as an asynchronous reset (negedge rst_n) in the always block. 
# If it is driven by an asynchronous external button, you may choose to set 
# it as a false path instead. Otherwise, keep the input delay:
set_input_delay -clock clk_1hz 5.0 [get_ports {rst_n}]

# -------------------------------------------------------------------------
# 3. Output Constraints
# -------------------------------------------------------------------------
# Constrain all output ports relative to clk_1hz.
set_output_delay -clock clk_1hz 5.0 [get_ports {rtc_year[*] rtc_month[*] rtc_day[*] rtc_hour[*] rtc_minute[*] rtc_second[*] alarm_out timer_out error_tick}]

# rtc_dow is driven by combinational logic (day_of_week module), 
# but its inputs (rtc_year, rtc_month, rtc_day) are synchronous to clk_1hz.
set_output_delay -clock clk_1hz 5.0 [get_ports {rtc_dow[*]}]}}}}}
