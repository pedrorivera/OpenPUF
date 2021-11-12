all: lint test_fixed_signature

test_fixed_signature:
	rm -rf sim_build/
	mkdir sim_build
	iverilog -o sim_build/test src/DelayPUF.v test/DelayPUF_tb.v
	sim_build/test

lint:
	verilator --lint-only src/DelayPUF.v

clean:
	rm -rf sim_build

.PHONY: clean
