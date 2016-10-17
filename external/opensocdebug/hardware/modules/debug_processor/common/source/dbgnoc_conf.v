
module dbgnoc_conf(
			// Inputs
	      clk, rst, dbgnoc_conf_in_flit, dbgnoc_conf_in_valid, dbgnoc_conf_out_ready,
			// Outputs
			dbgnoc_conf_in_ready, dbgnoc_conf_out_flit, dbgnoc_conf_out_valid);


	parameter DBG_NOC_FLIT_DATA_WIDTH = 16;
   parameter DBG_NOC_FLIT_TYPE_WIDTH = 2;
   localparam DBG_NOC_FLIT_WIDTH = DBG_NOC_FLIT_DATA_WIDTH + DBG_NOC_FLIT_TYPE_WIDTH;

	parameter DATA_WIDTH = 32;
	parameter ADDRESS_WIDTH = 32;

	// module description
   localparam MODULE_TYPE_DP = 8'h06;
   localparam MODULE_VERSION_DP = 8'h00;

	localparam CONF_MEM_SIZE = 8;

	input clk;
   input rst;

   // NoC interface
   output [DBG_NOC_FLIT_WIDTH-1:0]  dbgnoc_conf_out_flit;
   output                      		dbgnoc_conf_out_valid;
   input                       		dbgnoc_conf_out_ready;
	
	input [DBG_NOC_FLIT_WIDTH-1:0]	dbgnoc_conf_in_flit;
	input                      		dbgnoc_conf_in_valid;
   output                     		dbgnoc_conf_in_ready;
			 
			 
   // configuration memory
   wire [CONF_MEM_SIZE*16-1:0] conf_mem_flat_in;
   reg [CONF_MEM_SIZE-1:0] conf_mem_flat_in_valid;

   // un-flatten conf_mem_in to conf_mem_flat_in
   reg [15:0] conf_mem_in [CONF_MEM_SIZE-1:0];
   genvar i;
   generate
      for (i = 0; i < CONF_MEM_SIZE; i = i + 1) begin : gen_conf_mem_in
         assign conf_mem_flat_in[((i+1)*16)-1:i*16] = conf_mem_in[i];
      end
   endgenerate
	
   // initialize configuration memory
   always @ (posedge clk) begin
      if (rst) begin
         conf_mem_in[0] <= {MODULE_TYPE_DP, MODULE_VERSION_DP};
         conf_mem_flat_in_valid <= {CONF_MEM_SIZE{1'b1}};
      end else begin
         conf_mem_flat_in_valid <= {CONF_MEM_SIZE{1'b0}};
      end
   end
	
   /* dbgnoc_conf_if AUTO_TEMPLATE(
      .conf_mem_flat_out(),
      .conf_mem_flat_in_ack(),
      .\(.*\)(\1), // suppress explict port widths
    ); */
   dbgnoc_conf_if
      #(.MEM_SIZE(CONF_MEM_SIZE),
        .MEM_INIT_ZERO(0))
      u_dbgnoc_conf_if(.dbgnoc_out_ready(dbgnoc_conf_out_ready),
                       .dbgnoc_out_rts  (dbgnoc_out_rts),
                       .dbgnoc_out_valid(dbgnoc_conf_out_valid),
                       .dbgnoc_out_flit (dbgnoc_conf_out_flit),
                       .dbgnoc_in_ready (dbgnoc_conf_in_ready),
                       .dbgnoc_in_valid (dbgnoc_conf_in_valid),
                       .dbgnoc_in_flit  (dbgnoc_conf_in_flit),
                       /*AUTOINST*/
                       // Outputs
                       .conf_mem_flat_out(),    					  // Templated
                       .conf_mem_flat_in_ack(),                  // Templated
                       // Inputs
                       .clk             (clk),                   // Templated
                       .rst             (rst),                   // Templated
                       .conf_mem_flat_in(conf_mem_flat_in),      // Templated
                       .conf_mem_flat_in_valid(conf_mem_flat_in_valid)); // Templated

		

endmodule