TOPLEVEL_LANG   = verilog
# Wrapper instantiates TIME_REPORTER with PLL DIV overridden to 2
VERILOG_SOURCES = $(PWD)/../../time.v $(PWD)/tb_top.v

TOPLEVEL = tb_top
MODULE   = test_rtc
SIM     ?= icarus

include $(shell cocotb-config --makefiles)/Makefile.sim
