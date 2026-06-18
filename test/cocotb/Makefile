# =============================================================
#  Makefile — cocotb testbench for TIME_REPORTER
#
#  Usage:
#      make            # run with default sim (icarus)
#      make SIM=icarus # explicit
#      make clean
# =============================================================

SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES = $(PWD)/../../time.v

TOPLEVEL = TIME_REPORTER
MODULE   = test_time_reporter

include $(shell cocotb-config --makefiles)/Makefile.sim
