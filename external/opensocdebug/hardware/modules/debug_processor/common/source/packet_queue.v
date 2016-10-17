
module packet_queue(/*AUTOARG*/
   // Outputs
	wbs_dat_o, wbs_ack_o, wbs_err_o, wbs_rty_o, address_ack,
	discard_queue,
   // Inputs
   clk, rst, fifo_store_packet, bus_initial_trace_address,
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

	// WB Slave interface
	output reg[DATA_WIDTH-1:0] wbs_dat_o;
	output reg						wbs_ack_o;
	output 							wbs_err_o;
	output 							wbs_rty_o;
	input [ADDRESS_WIDTH-1:0] 	wbs_adr_i;
	input 							wbs_we_i;
	input 							wbs_cyc_i;
	input 							wbs_stb_i;
	input [DATA_WIDTH-1:0] 		wbs_dat_i;
	
	// Interface with DMA
	input fifo_store_packet;
	input [ADDRESS_WIDTH-1:0] bus_initial_trace_address;
	output address_ack;
	
	output reg [ADDRESS_WIDTH-1:0] discard_queue;
	
	
	wire [ADDRESS_WIDTH-1:0] queue_in_flit;
	reg queue_in_valid;
	wire queue_in_ready;
	
	wire [ADDRESS_WIDTH-1:0] queue_out_flit;
	wire queue_out_valid;
	reg queue_out_ready;
	
	assign queue_in_flit = bus_initial_trace_address; 


	
	// FIFO for ready queue
	lisnoc16_fifo
		#(.LENGTH(31),.WIDTH(ADDRESS_WIDTH))
	u_ready_queue(
			// Inputs
			.clk				(clk),
			.rst				(rst),
			.in_flit			(queue_in_flit),
			.in_valid		(queue_in_valid),
			.out_ready		(queue_out_ready),
			// Outputs
			.in_ready		(queue_in_ready),
			.out_flit		(queue_out_flit),
			.out_valid		(queue_out_valid));
	
	
	// push addresses of trace packets in ready queue
	always @ (*)
	begin
		if (fifo_store_packet) begin
			queue_in_valid = 1'b1;
		end else begin
			queue_in_valid = 1'b0;
		end
	end
	
	always @ (*)
	begin
		queue_out_ready = 1'b0;
		wbs_dat_o = 32'h00000000;
		wbs_ack_o = 1'b0;
				
		if (wbs_stb_i & wbs_cyc_i) begin
			if (!wbs_we_i) begin	
				if (wbs_adr_i[31:20] == 12'hFE8) begin
					wbs_ack_o = wbs_cyc_i && wbs_stb_i;
					if (!queue_out_valid) begin
						wbs_dat_o = 32'hFFFFFFFF;
					end else begin
						queue_out_ready = 1'b1;
						wbs_dat_o = queue_out_flit;
					end
				end	
			end else begin
				if (wbs_adr_i[31:20] == 12'hFE8) begin
					discard_queue = wbs_dat_i;
					wbs_ack_o = wbs_cyc_i && wbs_stb_i;
				end	
			end
		end
	end	
	
	assign address_ack = queue_in_valid & queue_in_ready;
	
	assign wbs_err_o = 1'b0;
	assign wbs_rty_o = 1'b0;	
	
	function integer clog2;
      input integer value;
      begin
         value = value-1;
         for (clog2=0; value>0; clog2=clog2+1)
           value = value>>1;
      end
   endfunction
	
endmodule
	
