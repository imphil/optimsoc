module noc_demux_wrapper
  #(parameter FLIT_WIDTH = 32
    )
   (
    input                   clk, rst,

    input [FLIT_WIDTH-1:0]  in_flit,
    input                   in_valid,
    input                   in_last,
    output                  in_ready,

    output [FLIT_WIDTH-1:0] out0_flit,
    output                  out0_valid,
    output                  out0_last,
    input                   out0_ready,

    output [FLIT_WIDTH-1:0] out1_flit,
    output                  out1_valid,
    output                  out1_last,
    input                   out1_ready,

    output [FLIT_WIDTH-1:0] out2_flit,
    output                  out2_valid,
    output                  out2_last,
    input                   out2_ready
    );

   noc_demux
     #(.CHANNELS(3),
       .MAPPING(64'h0))
   u_demux
     (.*,
      .out_flit ({out2_flit,out1_flit,out0_flit}),
      .out_valid ({out2_valid,out1_valid,out0_valid}),
      .out_ready ({out2_ready,out1_ready,out0_ready}),
      .out_last ({out2_last, out1_last, out0_last}));
   
endmodule
