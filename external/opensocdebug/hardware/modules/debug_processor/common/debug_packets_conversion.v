import dii_package::dii_flit;

module debug_packets_conversion(
      input               clk, rst,
      input dii_flit      dbgnoc_in_flit,
      input [1:0]     		dbgnoc_in_valid,
      input [1:0]		dbgnoc_out_ready,

      output dii_flit     dbgnoc_in_flit_conv,
      output [1:0]     	dbgnoc_in_valid_conv,
      output [1:0]	dbgnoc_out_ready_conv
      );

  parameter FLIT_STORAGE = 32;

  assign dbgnoc_out_ready_conv = dbgnoc_out_ready;

  dii_flit in_flit_storage [FLIT_STORAGE - 1:0];
  dii_flit trace_packet [4:0];
  logic [15:0] counter = 0;
  logic [3:0] counter_packet = 0;
  logic packet_rdy, release_packet_rdy = 0;
  logic [15:0] size, count_data_out = 1;

  localparam BIT_STATES = 4;
  localparam IDLE = 0;
  localparam SIZE_OUT = 1;
  localparam DEST_OUT = 2;
  localparam ID_OUT = 3;
  localparam DATA_OUT = 4;

  reg [BIT_STATES-1:0] current_state;
  reg [BIT_STATES-1:0] nxt_state;

  // FSM Sequential Logic
  always @ (posedge clk)
  begin
	if (rst) begin
		current_state <= IDLE;
	end else begin
		current_state <= nxt_state;
	end	
  end

  // FSM Next State Logic
  always @ (*)
  begin
	nxt_state = current_state;
	case (current_state)
		IDLE: 
		begin
			if (packet_rdy) begin
				nxt_state = DEST_OUT; 			
			end	
		end

/*		SIZE_OUT:
		begin
				nxt_state = DEST_OUT; 				
		end
*/				
		DEST_OUT:
		begin
				nxt_state = ID_OUT; 				
		end
		
		ID_OUT:
		begin
				nxt_state = DATA_OUT; 				
		end		
	
		DATA_OUT:
		begin
			if (count_data_out == size - 1) begin
				nxt_state = IDLE; 			
			end					
		end					
	endcase
  end

  // FSM Output Logic
  always @ (*)
  begin
	release_packet_rdy = 0;
/*	if (current_state == SIZE_OUT) begin
		dbgnoc_in_flit_conv = {2'b01, size};
		dbgnoc_in_valid_conv = 2'b10;
        end else*/ if (current_state == DEST_OUT) begin
		dbgnoc_in_flit_conv = {2'b01, 5'b00110, 11'b0};
		dbgnoc_in_valid_conv = 2'b10;
		release_packet_rdy = 1;
        end else if (current_state == ID_OUT) begin
		dbgnoc_in_flit_conv = {2'b00, in_flit_storage[0].data};
		dbgnoc_in_valid_conv = 2'b10;
	end else if (current_state != DATA_OUT) begin
		dbgnoc_in_flit_conv = 0;
		dbgnoc_in_valid_conv = 0;
	end		
  end


  always @ (posedge clk)
  begin
	if (count_data_out == size - 1) begin
		count_data_out = 0;			
	end if (current_state == DATA_OUT | current_state == ID_OUT) begin
		count_data_out = count_data_out + 1;
		if (count_data_out == size - 1) begin
			dbgnoc_in_flit_conv = {2'b10, in_flit_storage[count_data_out].data};
			dbgnoc_in_valid_conv = 2'b10;
		end else begin
			dbgnoc_in_flit_conv = {2'b00, in_flit_storage[count_data_out].data};
			dbgnoc_in_valid_conv = 2'b10;
		end			
	end
  end


  always @ (posedge clk)
  begin
	if (rst) begin
		counter = 0;
		counter_packet = 0;
		packet_rdy = 0;
	end else begin
		if (dbgnoc_in_valid[1] == 1) begin
			trace_packet[counter_packet] = dbgnoc_in_flit;			
			if (dbgnoc_in_flit.last) begin
				counter_packet = 0;			
			end else begin			
				counter_packet = counter_packet + 1;
			end			
			if (trace_packet[4] == 18'h30002) begin
				in_flit_storage[counter] = trace_packet[2];
				in_flit_storage[counter + 1] = trace_packet[3];	
				size = counter;				
				counter = 0;
				trace_packet[4] = 0;
				packet_rdy = 1;
		
			end else if(counter_packet == 4) begin			
				in_flit_storage[counter] = trace_packet[2];
				in_flit_storage[counter + 1] = trace_packet[3];								
				counter = counter + 2;
				if (current_state != IDLE) begin
					packet_rdy = 0;
				end
			end else if (current_state != IDLE) begin
				packet_rdy = 0;
			end				
		end else if (current_state != IDLE) begin
			packet_rdy = 0;
		end	
	end	
  end
endmodule