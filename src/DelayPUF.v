/*
 * Delay-based physically-unclonable function (PUF)
 *
 * Copyright (c) 2021 Pedro Rivera
 * Licence: Apache-2.0
 *
 *  TODO:
 *   - Need constraints for:
 *     - False path through the mux chain, so it doesn't try to meet timing
 *     - Setting the propagation delays of both lanes as equal as possible
 *     - Having a valid bit to notify the result is valid 
 *       (instead of waiting an arbitrary # of clock cycles)
 */


`define SIM
`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps

module DelayPUF #(parameter LENGTH = 8) ( 
   input clk,
   input reset,                    // sync (diven by LA)
   input [LENGTH-1:0] a_challenge, // async (if src is GPIO)
   input a_run,                    // async (if src is GPIO)
   output result
);

   wire run;
   wire [LENGTH-1:0] a_in, a_out, b_in, b_out;
   wire a_final, b_final;
   wire latch_d, latch_en;
   reg latch_q;

   d_sync run_ds(clk, reset, a_run, run); // In case run is async

   // Instantiate LENGTH number of MUX pairs
   // TODO: parametrize instantiation
   mux_pair stage0(a_in[0], b_in[0], a_challenge[0], a_out[0], b_out[0]);
   mux_pair stage1(a_in[1], b_in[1], a_challenge[1], a_out[1], b_out[1]);
   mux_pair stage2(a_in[2], b_in[2], a_challenge[2], a_out[2], b_out[2]);
   mux_pair stage3(a_in[3], b_in[3], a_challenge[3], a_out[3], b_out[3]);
   mux_pair stage4(a_in[4], b_in[4], a_challenge[4], a_out[4], b_out[4]);
   mux_pair stage5(a_in[5], b_in[5], a_challenge[5], a_out[5], b_out[5]);
   mux_pair stage6(a_in[6], b_in[6], a_challenge[6], a_out[6], b_out[6]);
   mux_pair stage7(a_in[7], b_in[7], a_challenge[7], a_out[7], b_out[7]);

   // Explicitly assign outputs of each stage to inputs. It's done this way to
   // enable simulating different delays between each stage via '#delay'
   assign {a_in[0], b_in[0]} = run;
   assign #3 a_in[1] = a_out[0];
   assign #4 b_in[1] = b_out[0];
   assign #5 a_in[2] = a_out[1];
   assign #4 b_in[2] = b_out[1];
   assign #5 a_in[3] = a_out[2];
   assign #5 b_in[3] = b_out[2];
   assign #3 a_in[4] = a_out[3];
   assign #6 b_in[4] = b_out[3];
   assign #5 a_in[5] = a_out[4];
   assign #6 b_in[5] = b_out[4];
   assign #4 a_in[6] = a_out[5];
   assign #3 b_in[6] = b_out[5];
   assign #5 a_in[7] = a_out[6];
   assign #6 b_in[7] = b_out[6];
   assign #3 a_final = a_out[7];
   assign #3 b_final = b_out[7];

   // Assign the final bit of the mux chain to the arbiter latch
   assign latch_d  = a_final;
   assign latch_en = b_final;
   
   `ifdef SIM
      always @* begin // Obtained from 'yosys> help $_DLATCH_P_+'
        if (latch_en == 1)
            latch_q <= latch_d;
      end
   `else
      $_DLATCH_P_ arbiter_latch(.E(latch_en), .D(latch_d), .Q(latch_q)); 
   `endif

   // The latch might predictably glitch
   d_sync result_ds(clk, reset, latch_q, result); 

endmodule

module mux_pair(
   input a, 
   input b, 
   input sel, 
   output reg out1,
   output reg out2
);
   `ifdef SIM

      //(* via_celltype = "$_MUX_ Y" *)
      //(* via_celltype_defparam_WIDTH = 1 *)
      function Fmux2_1;
         input A, B, S;
         begin
            Fmux2_1 = S ? A : B;
         end
      endfunction

      always @(*)
      begin
         out1 = Fmux2_1(a, b, sel);
         out2 = Fmux2_1(b, a, sel);
      end 

   `else

      // Explicit cell instantiation: (must call read_verilog with -icells)
      $_MUX_ mux_a(.A(b), .B(a), .S(sel), .Y(out1)); // 
      $_MUX_ mux_b(.A(a), .B(b), .S(sel), .Y(out2));

   `endif
   
   /* The attribute via_celltype can be used to implement a Verilog task or
    * function by instantiating the specified cell type. The value is the name of
    * the cell type to use. For functions the name of the output port can be
    * specified by appending it to the cell type separated by a whitespace. The
    * body of the task or function is unused in this case and can be used to
    * specify a behavioral model of the cell type for simulation. 
    * 
    * However, I was not able to use the attributes due to this error:
    * "ERROR: Failed to detect width for
    *  identifier \Fmux2_1$func$/openLANE_flow/designs/DelayPUF/src/DelayPUF.v:77$1.$result!"
    */

endmodule

module d_sync (
   input clk,
   input reset,
   input in_async,
   output reg out
);
   reg in_ms;

   always @(posedge clk)
   begin
      if (reset) begin
         in_ms <= 1'b0;      
         out   <= 1'b0;      
      end else begin
         in_ms <= in_async;
         out   <= in_ms;
      end
   end
endmodule
   

