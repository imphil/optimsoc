/**
 * This file is part of LISNoC.
 * 
 * LISNoC is free hardware: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as 
 * published by the Free Software Foundation, either version 3 of 
 * the License, or (at your option) any later version.
 *
 * As the LGPL in general applies to software, the meaning of
 * "linking" is defined as using the LISNoC in your projects at
 * the external interfaces.
 * 
 * LISNoC is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public 
 * License along with LISNoC. If not, see <http://www.gnu.org/licenses/>.
 * 
 * =================================================================
 * 
 * The wishbone slave interface to access the simple message passing.
 * 
 * (c) 2012-2013 by the author(s)
 * 
 * Author(s): 
 *    Stefan Wallentowitz, stefan.wallentowitz@tum.de
 *
 */

module dbgnoc_dma_wb(/*AUTOARG*/
   // Outputs
	noc_in_ready,
	wbm_adr_o, wbm_we_o, wbm_cyc_o, wbm_stb_o, wbm_dat_o, wbm_cti_o, wbm_sel_o,
	irq_na,
	fifo_store_packet, bus_initial_trace_address,
   // Inputs
   clk, rst, 
	address_ack, last_address_read,
	noc_in_flit, noc_in_valid, 
	wbm_dat_i, wbm_ack_i, wbm_err_i, wbm_rty_i
	);

	//Memory range reserved for DMA
	parameter MEM_MIN_ADDR = 32'h000FF058;
	parameter MEM_MAX_ADDR = 32'h000FFFF8;
//	parameter MEM_MAX_ADDR = 32'h000FF114;

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
   input  [NOC_FLIT_WIDTH-1:0] noc_in_flit;
   input                       noc_in_valid;
   output                      noc_in_ready;

	// WB Master interface	
	input [DATA_WIDTH-1:0] 		wbm_dat_i;
	input 							wbm_ack_i;
	input								wbm_rty_i;
	input								wbm_err_i;
	output [ADDRESS_WIDTH-1:0] wbm_adr_o;
	output 						 	wbm_we_o;
	output 							wbm_cyc_o;
	output 							wbm_stb_o;
	output reg[DATA_WIDTH-1:0] wbm_dat_o;
	output [2:0]					wbm_cti_o;
	output [3:0]					wbm_sel_o;
	
	// interrupt lines
	output irq_na; 
	
	// Interface with ready queue
	input address_ack;
	output fifo_store_packet;
	output [ADDRESS_WIDTH-1:0] bus_initial_trace_address;
	input [ADDRESS_WIDTH-1:0] last_address_read;
	
   // NA-DMA interface
   wire [ADDRESS_WIDTH-1:0]   bus_addr;
   wire                       bus_we;
   wire                       bus_en;
   wire [NOC_DATA_WIDTH-1:0]  bus_data_in;
   wire [NOC_DATA_WIDTH-1:0]  bus_data_out;
   wire                       bus_ack;
	
	wire na_cyc_o;
	wire na_stb_o;
   assign bus_en = na_cyc_o & na_stb_o;

   wire packet_received;
	wire full_packet_stored;
	wire shift_left_data_out;
	wire event_id_out;
	wire size_flag;
	
   dbgnoc_na_input
     #(.noc_data_width(NOC_DATA_WIDTH),
       .noc_type_width(NOC_TYPE_WIDTH),
       .fifo_depth(fifo_depth))
   u_dbgnoc_na_input(/*AUTOINST*/
               // Outputs
               .noc_in_ready            (noc_in_ready),
               .bus_data_out            (bus_data_out[NOC_DATA_WIDTH-1:0]),
               .bus_ack                 (bus_ack),
               .irq                     (packet_received),
					.bus_full_packet			 (full_packet_stored),
               // Inputs
               .clk                     (clk),
               .rst                     (rst),
               .noc_in_flit             (noc_in_flit[NOC_FLIT_WIDTH-1:0]),
               .noc_in_valid            (noc_in_valid),
               .bus_addr                (bus_addr[ADDRESS_WIDTH-1:0]),
               .bus_we                  (bus_we),
               .bus_en                  (bus_en));

	dma
	  #(.MEM_MIN_ADDR(MEM_MIN_ADDR),.MEM_MAX_ADDR(MEM_MAX_ADDR),
	    .DATA_WIDTH(DATA_WIDTH),.ADDRESS_WIDTH(ADDRESS_WIDTH))
	u_dma(
			// Inputs
			.clk							(clk),
			.rst							(rst),
			.packet_received			(packet_received),
			.full_packet_stored		(full_packet_stored),
			.wbmem_ack_i				(wbm_ack_i),
			.address_ack				(address_ack),
			.last_address_read		(last_address_read),
			// Outputs 	
			.na_cyc_o					(na_cyc_o),
			.na_stb_o					(na_stb_o),
			.na_we_o						(bus_we),
			.na_adr_o					(bus_addr),
			.wbmem_adr_o				(wbm_adr_o),
			.wbmem_cyc_o				(wbm_cyc_o),
			.wbmem_stb_o				(wbm_stb_o),
			.wbmem_we_o					(wbm_we_o),
			.wbmem_cti_o				(wbm_cti_o),
			.wbmem_sel_o				(wbm_sel_o),
			.shift_left_data_out		(shift_left_data_out),
			.initial_trace_address	(bus_initial_trace_address),
			.fifo_store_packet		(fifo_store_packet),
			.event_id_out				(event_id_out),
			.size_flag					(size_flag));
	

	// mux of output data in Wishbone Master interface to memory
	reg [NOC_DATA_WIDTH-1:0] bus_data_out_reg;
	always @ (posedge clk)
	begin
		if (bus_en) begin
			if (size_flag) begin
				wbm_dat_o <= {16'h0000, bus_data_out};
				bus_data_out_reg <= bus_data_out;
			end else begin
				if (shift_left_data_out) begin
					wbm_dat_o <= {bus_data_out, 16'h0000};
					bus_data_out_reg <= bus_data_out;
				end else begin
					if (event_id_out) begin
						wbm_dat_o <= {26'h0000000, bus_data_out[5:0]};
						bus_data_out_reg <= {10'h000, bus_data_out[5:0]};
					end else begin
						wbm_dat_o <= {16'h0000, bus_data_out};
						bus_data_out_reg <= bus_data_out;
					end
				end
			end
		end else begin
			if (shift_left_data_out) begin
				wbm_dat_o <= {bus_data_out_reg, 16'h0000};
			end else begin
				wbm_dat_o <= {16'h0000, bus_data_out_reg};
			end
		end
	end

	function integer clog2;
      input integer value;
      begin
         value = value-1;
         for (clog2=0; value>0; clog2=clog2+1)
           value = value>>1;
      end
   endfunction

endmodule
