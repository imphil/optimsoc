
module networkadapter_wb(
    //Inputs
	 clk, rst, dbgnoc_out_ready, dbgnoc_in_flit, dbgnoc_in_valid, 
	 wbm_dat_i, wbm_ack_i, wbm_err_i, wbm_rty_i,
	 wbs_adr_i, wbs_we_i, wbs_cyc_i, wbs_stb_i, wbs_dat_i,
	 address_ack, last_address_read,
	 //Outputs
	 dbgnoc_out_flit, dbgnoc_out_valid, dbgnoc_in_ready,
	 wbm_adr_o, wbm_we_o, wbm_cyc_o, wbm_stb_o, wbm_dat_o, wbm_cti_o, wbm_sel_o,
	 irq_na, bus_initial_trace_address, fifo_store_packet,
	 wbs_dat_o, wbs_ack_o, wbs_err_o, wbs_rty_o);


	//Memory range reserved for DMA
	parameter MEM_MIN_ADDR = 32'h000FF058;
	parameter MEM_MAX_ADDR = 32'h000FFFF8;
//	parameter MEM_MAX_ADDR = 32'h000FF114;

	parameter DBG_NOC_FLIT_DATA_WIDTH = 16;
   parameter DBG_NOC_FLIT_TYPE_WIDTH = 2;
   localparam DBG_NOC_FLIT_WIDTH = DBG_NOC_FLIT_DATA_WIDTH + DBG_NOC_FLIT_TYPE_WIDTH;

	parameter DATA_WIDTH = 32;
	parameter ADDRESS_WIDTH = 32;
	
	//virtual channels definition
	parameter DBG_NOC_VCHANNELS = 2;
	parameter DBG_NOC_CONF_VCHANNEL = 0;
	parameter DBG_NOC_TRACE_VCHANNEL = 1;


	input clk;
	input rst; 
	
	//
	input	 [DBG_NOC_FLIT_WIDTH-1:0] 	dbgnoc_in_flit;
   input  [DBG_NOC_VCHANNELS-1:0] 	dbgnoc_in_valid;
   output [DBG_NOC_VCHANNELS-1:0] 	dbgnoc_in_ready;
	
   output [DBG_NOC_FLIT_WIDTH-1:0] 	dbgnoc_out_flit;
   output [DBG_NOC_VCHANNELS-1:0]	dbgnoc_out_valid;
   input  [DBG_NOC_VCHANNELS-1:0] 	dbgnoc_out_ready;
	
	// WB Master interface	
	input [DATA_WIDTH-1:0] 		wbm_dat_i;
	input 							wbm_ack_i;
	input								wbm_rty_i;
	input								wbm_err_i;
	output [ADDRESS_WIDTH-1:0] wbm_adr_o;
	output 						 	wbm_we_o;
	output 							wbm_cyc_o;
	output 							wbm_stb_o;
	output [DATA_WIDTH-1:0] 	wbm_dat_o;
	output [2:0]					wbm_cti_o;
	output [3:0]					wbm_sel_o;
	
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
	
	//
	input address_ack;
	input [ADDRESS_WIDTH-1:0] last_address_read;
	output irq_na; 
	output [ADDRESS_WIDTH-1:0] bus_initial_trace_address; 
	output fifo_store_packet;
	

	dbgnoc_dma_wb
     #(.MEM_MIN_ADDR(MEM_MIN_ADDR),.MEM_MAX_ADDR(MEM_MAX_ADDR),
	    .NOC_DATA_WIDTH(DBG_NOC_FLIT_DATA_WIDTH),.NOC_TYPE_WIDTH(DBG_NOC_FLIT_TYPE_WIDTH),.fifo_depth(32),
		 .DATA_WIDTH(DATA_WIDTH),.ADDRESS_WIDTH(ADDRESS_WIDTH))
   u_dbgnoc_dma_wb(
	       // Inputs
	       .clk									(clk),
	       .rst									(rst),
	       .noc_in_flit						(dbgnoc_in_flit),
	       .noc_in_valid						(dbgnoc_in_valid[DBG_NOC_TRACE_VCHANNEL]),
			 .wbm_dat_i							(wbm_dat_i[DATA_WIDTH-1:0]),
	       .wbm_ack_i							(wbm_ack_i),
			 .wbm_err_i							(wbm_err_i),
			 .wbm_rty_i							(wbm_rty_i),
			 .address_ack						(address_ack),
			 .last_address_read				(last_address_read),
	       // Outputs
	       .noc_in_ready						(dbgnoc_in_ready[DBG_NOC_TRACE_VCHANNEL]),
	       .wbm_adr_o							(wbm_adr_o),
	       .wbm_we_o							(wbm_we_o),
	       .wbm_cyc_o							(wbm_cyc_o),
	       .wbm_stb_o							(wbm_stb_o),
	       .wbm_dat_o							(wbm_dat_o),
			 .wbm_cti_o							(wbm_cti_o),
			 .wbm_sel_o							(wbm_sel_o),
			 .irq_na								(irq_na), // interrupt lines not used
			 .bus_initial_trace_address 	(bus_initial_trace_address),
 			 .fifo_store_packet				(fifo_store_packet)); 



	//multiplex dbgnoc configuration flits output
	wire [DBG_NOC_FLIT_WIDTH-1:0] dbgnoc_out_flit_na;
	wire  [DBG_NOC_FLIT_WIDTH-1:0] dbgnoc_out_flit_conf;
	reg  [DBG_NOC_FLIT_WIDTH-1:0] dbgnoc_out_flit_temp;
	
	wire dbgnoc_out_valid_na;
	wire dbgnoc_out_valid_conf;
	reg  dbgnoc_out_valid_temp;


	dbgnoc_na_output_wb
     #(.NOC_DATA_WIDTH(DBG_NOC_FLIT_DATA_WIDTH),.NOC_TYPE_WIDTH(DBG_NOC_FLIT_TYPE_WIDTH),.fifo_depth(32),
		 .DATA_WIDTH(DATA_WIDTH),.ADDRESS_WIDTH(ADDRESS_WIDTH))
   u_dbgnoc_na_output_wb(
			 // Inputs
	       .clk						(clk),
	       .rst						(rst),
			 .noc_out_ready		(dbgnoc_out_ready[DBG_NOC_CONF_VCHANNEL]),
			 .wbs_adr_i          (wbs_adr_i[ADDRESS_WIDTH-1:0]),
          .wbs_dat_i          (wbs_dat_i[DATA_WIDTH-1:0]),
          .wbs_cyc_i          (wbs_cyc_i),
          .wbs_stb_i          (wbs_stb_i),
          .wbs_we_i           (wbs_we_i),
			 // Outputs
			 .noc_out_flit			(dbgnoc_out_flit_na),
	       .noc_out_valid		(dbgnoc_out_valid_na),
			 .wbs_dat_o          (wbs_dat_o),
          .wbs_ack_o          (wbs_ack_o),
          .wbs_err_o          (wbs_err_o),
          .wbs_rty_o          (wbs_rty_o));


	dbgnoc_conf
		#(.DBG_NOC_FLIT_DATA_WIDTH(DBG_NOC_FLIT_DATA_WIDTH),.DBG_NOC_FLIT_TYPE_WIDTH(DBG_NOC_FLIT_TYPE_WIDTH),
		 .DATA_WIDTH(DATA_WIDTH),.ADDRESS_WIDTH(ADDRESS_WIDTH))
	u_dbgnoc_conf(
			 // Inputs
	       .clk								(clk),
	       .rst								(rst),
			 .dbgnoc_conf_in_flit		(dbgnoc_in_flit),
	       .dbgnoc_conf_in_valid		(dbgnoc_in_valid[DBG_NOC_CONF_VCHANNEL]),
			 .dbgnoc_conf_out_ready		(dbgnoc_out_ready[DBG_NOC_CONF_VCHANNEL]),
			 // Outputs
			 .dbgnoc_conf_in_ready		(dbgnoc_in_ready[DBG_NOC_CONF_VCHANNEL]),
			 .dbgnoc_conf_out_flit		(dbgnoc_out_flit_conf),
	       .dbgnoc_conf_out_valid		(dbgnoc_out_valid_conf));



	// Mux dbgnoc conf vchannel outputs
	always @ (*) 
	begin
		if (dbgnoc_out_ready[DBG_NOC_CONF_VCHANNEL] && dbgnoc_out_valid_conf) begin
			dbgnoc_out_flit_temp = dbgnoc_out_flit_conf;
			dbgnoc_out_valid_temp = dbgnoc_out_valid_conf;
		end else if (dbgnoc_out_ready[DBG_NOC_CONF_VCHANNEL] && dbgnoc_out_valid_na) begin
			dbgnoc_out_flit_temp = dbgnoc_out_flit_na;
			dbgnoc_out_valid_temp = dbgnoc_out_valid_na;
		end else begin
			dbgnoc_out_flit_temp = 18'h00000;
			dbgnoc_out_valid_temp = 1'b0;
		end
	end
	assign dbgnoc_out_flit = dbgnoc_out_flit_temp;
	assign dbgnoc_out_valid [DBG_NOC_CONF_VCHANNEL] = dbgnoc_out_valid_temp;

endmodule
