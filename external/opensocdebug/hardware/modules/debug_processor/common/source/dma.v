`timescale 1ns / 1ps

/**
 * This file is part of OpTiMSoC.
 * 
 *  
 * The direct memory access of the debug co-processor for 
 * receiving/sending messages through the network adapter
 *
 * (c) 2015 by the author(s)
 * 
 * Author(s): 
 *    Ignacio Alonso Blanco <ga26pay@mytum.de>
 *
 */
 
module dma(
	//outputs
	na_adr_o, na_cyc_o, na_stb_o, na_we_o, 
	wbmem_adr_o, wbmem_cyc_o, wbmem_stb_o, wbmem_we_o, wbmem_cti_o, wbmem_sel_o,
	shift_left_data_out, initial_trace_address,
	fifo_store_packet, event_id_out, size_flag,
	// Inputs
   clk, rst, packet_received, full_packet_stored,
	wbmem_ack_i, address_ack, last_address_read);

	parameter DATA_WIDTH = 32;
	parameter ADDRESS_WIDTH = 32;

	input	clk;
	input	rst;
	
	//interface with packet queue
	input address_ack;
	input [ADDRESS_WIDTH-1:0] last_address_read;
	output reg [ADDRESS_WIDTH-1:0] initial_trace_address;
	output reg fifo_store_packet;
		
	//interface with network adapter input
	input packet_received;
	input full_packet_stored;
	output reg  [ADDRESS_WIDTH-1:0]	na_adr_o;
   output reg								na_cyc_o;
   output reg								na_stb_o;
   output reg								na_we_o;
	
	//interface with ram memory
	input										wbmem_ack_i;
	output reg [ADDRESS_WIDTH-1:0]	wbmem_adr_o;
   output reg								wbmem_cyc_o;
   output reg								wbmem_stb_o;
   output reg								wbmem_we_o;
	output reg [2:0]						wbmem_cti_o;
	output reg [3:0]						wbmem_sel_o;

	//flags for defining wbm_dat_o
	output reg shift_left_data_out;
	output reg event_id_out;
	output reg size_flag;

	//FSM states definition
	parameter BIT_STATES = 4;
	parameter IDLE = 0;
	parameter WRITE_SIZE_1 = 1;
	parameter WRITE_SIZE_2 = 2;
	parameter WRITE_LSB_1 = 3;
	parameter WRITE_LSB_2 = 4;
	parameter WRITE_MSB_1 = 5;
	parameter WRITE_MSB_2 = 6;
	parameter PACKET_TO_QUEUE = 7;
	
	reg [BIT_STATES-1:0] current_state;
	reg [BIT_STATES-1:0] nxt_state;


	//Memory range reserved for DMA
	parameter MEM_MIN_ADDR = 32'h000FF058;
	parameter MEM_MAX_ADDR = 32'h000FFFF8;
//	parameter MEM_MAX_ADDR = 32'h000FF114;


	//Address counter
	reg [ADDRESS_WIDTH-1:0] address;
	reg enable;
	
	
	
	//Overwritting indicates if the memory is being overwritten
	//or if it is first time to write in current address
	reg overwritting;
	reg nxt_overwritting;
	
	
	//Increase address logic
	always @ (posedge clk)
	begin
		if (rst) begin
			address <= MEM_MIN_ADDR;
		end else begin
			if (enable) begin
				if (address == MEM_MAX_ADDR) begin
					address <= MEM_MIN_ADDR;
				end else begin
					address <= address + 4;
				end
			end
		end
	end


	//Overwritting flag logic
	always @ (*)
	begin
		nxt_overwritting = overwritting;
		if (address == MEM_MAX_ADDR) begin
			nxt_overwritting = 1'b1;
		end
	end

	
	reg [ADDRESS_WIDTH-1:0] nxt_initial_trace_address;
	reg event_id_flag;
	reg nxt_event_id_flag;
	//combinational logic of FSM
	always @ (*)
	begin
		//default values
		//wbm output signals
		wbmem_adr_o = 32'h00000000;
		wbmem_cyc_o = 1'b0;
		wbmem_stb_o = 1'b0;
		wbmem_we_o = 1'b0;
		wbmem_cti_o = 3'h7;
		wbmem_sel_o = 4'b0000;
		//wb network adapter signals for controlling output data from FIFO
		na_adr_o = 6'h00;
		na_cyc_o = 1'b0;
		na_stb_o = 1'b0;
		na_we_o = 1'b0;
		
		enable = 0;
		shift_left_data_out = 1'b0;
		fifo_store_packet = 1'b0;
		event_id_out = 1'b0;
		size_flag = 1'b0;
		
		nxt_event_id_flag = event_id_flag;
		nxt_initial_trace_address = initial_trace_address;
		nxt_state = current_state;
		
		case (current_state)
		
			IDLE: 
			begin//wait until data is prepared in wb interface with network adapter
				if (packet_received) begin
					if (!overwritting) begin //First time memory is written
						wbmem_adr_o = address;
						nxt_state = WRITE_SIZE_1;
						nxt_initial_trace_address = address;
					end else begin
						if (address < last_address_read) begin //When overwritting, check if address is available
							wbmem_adr_o = address;
							nxt_state = WRITE_SIZE_1;
							nxt_initial_trace_address = address;
						end
					end
				end	
			end
				
			WRITE_SIZE_1:
			begin
				na_adr_o = 6'd3;
				na_cyc_o = 1'b1;
				na_stb_o = 1'b1;
				na_we_o = 1'b0;

				wbmem_adr_o = address;
				wbmem_sel_o = 4'b1111;
				wbmem_cyc_o = 1'b1;
				wbmem_stb_o = 1'b1;
				wbmem_we_o = 1'b1;
				
				size_flag = 1'b1;
				
				nxt_state = WRITE_SIZE_2;
			end
			
			WRITE_SIZE_2:
			begin
				wbmem_adr_o = address;
				wbmem_sel_o = 4'b1111;
				wbmem_cyc_o = 1'b1;
				wbmem_stb_o = 1'b1;
				wbmem_we_o = 1'b1;
				
				size_flag = 1'b1;
				nxt_event_id_flag = 1'b1;
				
				if (wbmem_ack_i) begin
					enable = 1'b1;
					nxt_state = WRITE_LSB_1;
				end
			end
			
			WRITE_LSB_1: //write data received through network adapter in memory
			begin
				na_adr_o = 6'd3;
				na_cyc_o = 1'b1;
				na_stb_o = 1'b1;
				na_we_o = 1'b0;

				wbmem_adr_o = address;
				wbmem_sel_o = 4'b0011;
				wbmem_cyc_o = 1'b1;
				wbmem_stb_o = 1'b1;
				wbmem_we_o = 1'b1;
				
				nxt_state = WRITE_LSB_2;
			end
			
			WRITE_LSB_2:
			begin
				wbmem_adr_o = address;
				wbmem_sel_o = 4'b0011;
				wbmem_cyc_o = 1'b1;
				wbmem_stb_o = 1'b1;
				wbmem_we_o = 1'b1;
				
				if (wbmem_ack_i) begin
					nxt_state = WRITE_MSB_1;
				end
			end
				
			WRITE_MSB_1:
			begin
				na_adr_o = 6'd3;
				na_cyc_o = 1'b1;
				na_stb_o = 1'b1;
				na_we_o = 1'b0;
				
				wbmem_adr_o = address;
				wbmem_cyc_o = 1'b1;
				wbmem_stb_o = 1'b1;
				wbmem_we_o = 1'b1;
				
				if (event_id_flag) begin //if data is event_id, activate the event_id_output
					wbmem_sel_o = 4'b0011;
					shift_left_data_out = 1'b0;
					event_id_out = 1'b1;
				end else begin
					wbmem_sel_o = 4'b1100;
					shift_left_data_out = 1'b1;
				end
				
				nxt_state = WRITE_MSB_2;
			end
			
			WRITE_MSB_2:
			begin
				wbmem_adr_o = address;
				wbmem_cyc_o = 1'b1;
				wbmem_stb_o = 1'b1;
				wbmem_we_o = 1'b1;
				
				if (event_id_flag) begin //if data is event_id, activate the event_id_output
					wbmem_sel_o = 4'b0011;
					shift_left_data_out = 1'b0;
					nxt_event_id_flag = 1'b0;
					event_id_out = 1'b1;
				end else begin
					wbmem_sel_o = 4'b1100;
					shift_left_data_out = 1'b1;
				end
				
				if (full_packet_stored & wbmem_ack_i) begin //packet complete, next state to store in ready queue
					enable = 1'b1;
					nxt_state = PACKET_TO_QUEUE;
				end else if (wbmem_ack_i) begin //packet incomplete, continue reading next data LSB
					enable = 1'b1;
					nxt_state = WRITE_LSB_1;
					nxt_event_id_flag = 1'b0;
				end
			end
				
			PACKET_TO_QUEUE:
			begin
				fifo_store_packet = 1'b1; //store initial address of current trace packet in ready queue
				if (address_ack) begin
					nxt_state = IDLE;
				end
			end					
		endcase
	end

	//sequential logic of FSM
	always @ (posedge clk)
	begin
		if (rst) begin
			current_state <= IDLE;
			initial_trace_address <= 32'h00000000;
			event_id_flag <= 1'b1;
			overwritting = 1'b0;
		end else begin
			current_state <= nxt_state;
			initial_trace_address <= nxt_initial_trace_address;
			event_id_flag <= nxt_event_id_flag;
			overwritting = nxt_overwritting;
		end	
	end
	
endmodule