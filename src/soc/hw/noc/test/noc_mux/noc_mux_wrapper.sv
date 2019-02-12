module noc_mux_wrapper
  #(parameter FLIT_WIDTH = 34
    )
   (
    input 		    clk, rst,

    input [FLIT_WIDTH-1:0]  in0_flit,
    input 		    in0_valid,
    output 		    in0_ready,

    input [FLIT_WIDTH-1:0]  in1_flit,
    input 		    in1_valid,
    output 		    in1_ready,

    input [FLIT_WIDTH-1:0]  in2_flit,
    input 		    in2_valid,
    output 		    in2_ready,

    output [FLIT_WIDTH-1:0] out_flit,
    output 		    out_valid,
    input 		    out_ready
    );

   noc_mux
     #(.FLIT_WIDTH(FLIT_WIDTH), .CHANNELS(3))
   u_mux
     (.*,
      .in_flit ({in2_flit,in1_flit,in0_flit}),
      .in_valid ({in2_valid,in1_valid,in0_valid}),
      .in_ready ({in2_ready,in1_ready,in0_ready}));


`ifdef COCOTB_SIM
   initial begin
      $dumpfile ("waveform.vcd");
      $dumpvars (0,noc_mux_wrapper);
      #1;
   end
`endif
   
endmodule // noc_mux
