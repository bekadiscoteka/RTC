DESIGN = ../../time.v
sim.out: tb.v $(DESIGN) 
	iverilog -o sim.out tb.v $(DESIGN) 
	vvp sim.out > output.txt
	@echo "detected fails:"
	@grep "FAIL" output.txt | wc -l 

clean: 
	rm sim.out output.txt dump.vcd

wave:
	gtkwave dump.vcd 
