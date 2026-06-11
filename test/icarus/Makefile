DESIGN = ../../time.v
sim.out: tb.v $(DESIGN) 
	iverilog -o sim.out tb.v $(DESIGN) 
	vvp sim.out > output.txt
	gtkwave dump.vcd

