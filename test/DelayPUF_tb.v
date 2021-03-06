/* Minimal testbech to sanity-check the implementation. There are many
   oportunities for improvement. */

/* verilator lint_off STMTDLY */

`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`define SIM_MODE

module DelayPUF_tb;
	
	// Signature for hard-coded delays: #2,#1,#3,#4,#5,#4,#5,#5,#3,#6,#5,#6,#4,#3,#5,#6,#3,#3
	localparam EXPECTED_SIGNATURE = 256'heffeffff1001effe000000004bb4ffff10010000effe1001ffffffffb44b;
   localparam HALF_PERIOD = 5;  // duration for each cycle = 10 * 1 ns  = 10ns
	localparam PUF_LENGTH = 8;

    wire result;
    reg clk, run, reset;
    reg [PUF_LENGTH-1:0] challenge;
    reg [255:0] signature;
    reg stopSig;
    integer i;

    DelayPUF DUT (clk, reset, challenge, run, result);

	initial begin
		signature = 0;
		stopSig = 1'b0;
		reset = 1'b0;
	   run = 1'b0;

	   $display("Testing the full challenge range...");
		
		for (i = 0; i < 256; i = i + 1) begin
		    run = 1'b0;
		    challenge = i[7:0];
		    #100; // arbitrary, for now
		    run = 1'b1;
		    #100;
		    // Create a sort of signature by logging the results of each
		    // challenge in an N-bit vector, where N is 2^PUF_LENGTH
		    signature = {result, signature[255: 1]};
		end

		$display("PUF signature: 0x%0h", signature);
		// Pass/fail condition
		if (signature == EXPECTED_SIGNATURE) begin
			$display("Test passed");
		end else begin
			$display("Test failed");
		end

		stopSig = 1'b1;

	end

	// Debug. Monitor changes
	always @(result)
	begin
	//	$strobe("result changed - time=%0t challenge=0x%0h result=%0h", $time, challenge, result);
	end

	// The clock is only used to drive the double synchronizers
	always // indefinitely
	begin
	    clk = 1'b1; 
	    #HALF_PERIOD; 
	    clk = 1'b0;
	    #HALF_PERIOD;
	end
    
	always @(posedge clk)
	begin
		if (stopSig == 1'b1)
	    	$finish;
	end
    
endmodule
