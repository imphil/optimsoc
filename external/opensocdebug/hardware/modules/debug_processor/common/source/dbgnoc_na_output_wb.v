
module dbgnoc_na_output_wb(
    // Outputs
   noc_out_flit, noc_out_valid, wbs_dat_o, wbs_ack_o, wbs_err_o, wbs_rty_o,
   // Inputs
   clk, rst, noc_out_ready,
	wbs_adr_i, wbs_we_i, wbs_cyc_i, wbs_stb_i, wbs_dat_i);


   parameter NOC_DATA_WIDTH = 16;
   parameter NOC_TYPE_WIDTH = 2;
   localparam NOC_FLIT_WIDTH = NOC_DATA_WIDTH + NOC_TYPE_WIDTH;

	parameter DATA_WIDTH = 32;
	parameter ADDRESS_WIDTH = 32;

   parameter  fifo_depth = 16;
   localparam size_width = clog2(fifo_depth+1);
   
   input clk;
   input rst;

   // NoC interface
   output [NOC_FLIT_WIDTH-1:0] noc_out_flit;
   output                      noc_out_valid;
   input                       noc_out_ready;

	// WB Slave interface
	output [DATA_WIDTH-1:0] 	wbs_dat_o;
	output 							wbs_ack_o;
	output 							wbs_err_o;
	output 							wbs_rty_o;
	input [ADDRESS_WIDTH-1:0] 	wbs_adr_i;
	input 							wbs_we_i;
	input 							wbs_cyc_i;
	input 							wbs_stb_i;
	input [DATA_WIDTH-1:0] 		wbs_dat_i;

   // Bus side (generic)
   wire [ADDRESS_WIDTH-1:0]    bus_addr;
   wire                        bus_we;
   wire                        bus_en;
   wire [NOC_DATA_WIDTH-1:0]   bus_data_in;
   wire [NOC_DATA_WIDTH-1:0]   bus_data_out;
   wire                        bus_ack;

   assign bus_addr    = wbs_adr_i;
   assign bus_we      = wbs_we_i;
   assign bus_en      = wbs_cyc_i & wbs_stb_i;
   assign bus_data_in = wbs_dat_i[NOC_DATA_WIDTH-1:0];
   assign wbs_dat_o [NOC_DATA_WIDTH-1:0] = bus_data_out;
	assign wbs_dat_o [ADDRESS_WIDTH-1:NOC_DATA_WIDTH] = 16'h0000;
	
   assign wbs_ack_o   = bus_ack;
	
	assign wbs_err_o = 1'b0;
	assign wbs_rty_o = 1'b0;
	
   dbgnoc_na_output
     #(.NOC_DATA_WIDTH(NOC_DATA_WIDTH),
       .NOC_TYPE_WIDTH(NOC_TYPE_WIDTH),
       .fifo_depth(fifo_depth))
   u_dbgnoc_na_output(/*AUTOINST*/
               // Outputs
               .noc_out_flit            (noc_out_flit[NOC_FLIT_WIDTH-1:0]),
               .noc_out_valid           (noc_out_valid),
               .bus_data_out            (bus_data_out[NOC_DATA_WIDTH-1:0]),
               .bus_ack                 (bus_ack),
               // Inputs
               .clk                     (clk),
               .rst                     (rst),
               .noc_out_ready           (noc_out_ready),
               .bus_addr                (bus_addr[ADDRESS_WIDTH-1:0]),
               .bus_we                  (bus_we),
               .bus_en                  (bus_en),
               .bus_data_in             (bus_data_in[NOC_DATA_WIDTH-1:0]));

	
	function integer clog2;
      input integer value;
      begin
         value = value-1;
         for (clog2=0; value>0; clog2=clog2+1)
           value = value>>1;
      end
   endfunction

endmodule
