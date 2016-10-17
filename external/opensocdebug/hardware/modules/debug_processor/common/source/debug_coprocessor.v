/* Copyright (c) 2013 by the author(s)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * =============================================================================
 *
 * This is the debug co-processor top-module.
 *
 * Author(s):
 *   Ignacio Alonso Blanco <ga26pay@mytum.de>
 */

`include "lisnoc_def.vh"
`include "dbg_config.vh"

module debug_coprocessor(
   // Outputs
   dbgnoc_in_ready, dbgnoc_out_flit, dbgnoc_out_valid,
   // Inputs
   clk, rst, rst_cpu, rst_sys, dbgnoc_in_flit, dbgnoc_in_valid, dbgnoc_out_ready
//   cpu_stall
   );

   parameter DBG_NOC_FLIT_DATA_WIDTH = 16;
   parameter DBG_NOC_FLIT_TYPE_WIDTH = 2;
   localparam DBG_NOC_FLIT_WIDTH = DBG_NOC_FLIT_DATA_WIDTH + DBG_NOC_FLIT_TYPE_WIDTH;

	localparam DATA_WIDTH = 32;
	localparam ADDRESS_WIDTH = 32;
	
	//virtual channels definition
	parameter DBG_NOC_VCHANNELS = 2;
	parameter DBG_NOC_CONF_VCHANNEL = 0;
	parameter DBG_NOC_TRACE_VCHANNEL = 1;

	parameter ID       = 0;
   parameter CORES    = 1;
   parameter COREBASE = 0;
   parameter DOMAIN_NUMCORES = CORES;

   parameter NR_MASTERS = CORES*2 + 1; // 2xCORE (DATA[1] + INSTRUCTIONS[0]) + 1xNETWORK_ADAPTER (DMA[2])
   parameter NR_SLAVES = 5; // 1xNA_CONF[1] + 1xMEMORY[0] + 1xBOOTROM[2] + 2xNETWORK_ADAPTER[3-in][4-out]

   /* memory size in bytes */
   parameter MEM_SIZE = 250*1024; // 250 KB
   parameter MEM_FILE = "diagnosis_test.vmem";
	//Memory range reserved for DMA
	parameter MEM_MIN_ADDR = 32'h000122A0;
	parameter MEM_MAX_ADDR = 32'h00014000;
	
	parameter GLOBAL_MEMORY_SIZE = 32'h0;
   parameter GLOBAL_MEMORY_TILE = 32'hx;

   parameter DMA_ENTRIES = 1;

   parameter config_t CONFIG = 'x;

	// port definitions
   input clk;
   input rst, rst_cpu, rst_sys;

	//dbgnoc interface
   input	 [DBG_NOC_FLIT_WIDTH-1:0] 	dbgnoc_in_flit;
   input  [DBG_NOC_VCHANNELS-1:0] 	dbgnoc_in_valid;
   output [DBG_NOC_VCHANNELS-1:0] 	dbgnoc_in_ready;
   output [DBG_NOC_FLIT_WIDTH-1:0] 	dbgnoc_out_flit;
   output [DBG_NOC_VCHANNELS-1:0]	dbgnoc_out_valid;
   input  [DBG_NOC_VCHANNELS-1:0] 	dbgnoc_out_ready;

	//wb memory interface
   wire [ADDRESS_WIDTH-1:0] 	wb_mem_adr_i;
   wire [1:0]    					wb_mem_bte_i;
   wire [2:0]    					wb_mem_cti_i;
   wire          					wb_mem_cyc_i;
   wire [DATA_WIDTH-1:0]		wb_mem_dat_i;
   wire [4-1:0]  					wb_mem_sel_i;
   wire          					wb_mem_stb_i;
   wire          					wb_mem_we_i;
   wire         					wb_mem_ack_o;
   wire         					wb_mem_err_o;
   wire         					wb_mem_rty_o;
   wire [DATA_WIDTH-1:0] 		wb_mem_dat_o;
   wire          					wb_mem_clk_i;
   wire          					wb_mem_rst_i;

	//wishbone slave interface
   wire [ADDRESS_WIDTH-1:0]   busms_adr_o[0:NR_MASTERS-1];
   wire          					busms_cyc_o[0:NR_MASTERS-1];
   wire [DATA_WIDTH-1:0]   	busms_dat_o[0:NR_MASTERS-1];
   wire [3:0]    					busms_sel_o[0:NR_MASTERS-1];
   wire          					busms_stb_o[0:NR_MASTERS-1];
   wire          					busms_we_o[0:NR_MASTERS-1];
   wire          					busms_cab_o[0:NR_MASTERS-1];
   wire [2:0]    					busms_cti_o[0:NR_MASTERS-1];
   wire [1:0]    					busms_bte_o[0:NR_MASTERS-1];
   wire          					busms_ack_i[0:NR_MASTERS-1];
   wire          					busms_rty_i[0:NR_MASTERS-1];
   wire          					busms_err_i[0:NR_MASTERS-1];
   wire [DATA_WIDTH-1:0]   	busms_dat_i[0:NR_MASTERS-1];
	//wishbone master interface
   wire [ADDRESS_WIDTH-1:0]   bussl_adr_i[0:NR_SLAVES-1];
   wire          					bussl_cyc_i[0:NR_SLAVES-1];
   wire [DATA_WIDTH-1:0]   	bussl_dat_i[0:NR_SLAVES-1];
   wire [3:0]    					bussl_sel_i[0:NR_SLAVES-1];
   wire          					bussl_stb_i[0:NR_SLAVES-1];
   wire          					bussl_we_i[0:NR_SLAVES-1];
   wire          					bussl_cab_i[0:NR_SLAVES-1];
   wire [2:0]    					bussl_cti_i[0:NR_SLAVES-1];
   wire [1:0]    					bussl_bte_i[0:NR_SLAVES-1];
   wire          					bussl_ack_o[0:NR_SLAVES-1];
   wire          					bussl_rty_o[0:NR_SLAVES-1];
   wire          					bussl_err_o[0:NR_SLAVES-1];
   wire [DATA_WIDTH-1:0]  		bussl_dat_o[0:NR_SLAVES-1];

   wire          					snoop_enable;
   wire [ADDRESS_WIDTH-1:0]   snoop_adr;

   wire [31:0]   pic_ints_i [0:CORES-1];
   assign pic_ints_i[0][31:3] = 17'h0;
   assign pic_ints_i[0][1:0] = 2'b00;

   genvar        c, m;
	
   wire [ADDRESS_WIDTH*NR_MASTERS-1:0] busms_adr_o_flat;
   wire [NR_MASTERS-1:0]    				busms_cyc_o_flat;
   wire [DATA_WIDTH*NR_MASTERS-1:0] 	busms_dat_o_flat;
   wire [4*NR_MASTERS-1:0]  				busms_sel_o_flat;
   wire [NR_MASTERS-1:0]    				busms_stb_o_flat;
   wire [NR_MASTERS-1:0]    				busms_we_o_flat;
   wire [NR_MASTERS-1:0]    				busms_cab_o_flat;
   wire [3*NR_MASTERS-1:0]  				busms_cti_o_flat;
   wire [2*NR_MASTERS-1:0]  				busms_bte_o_flat;
   wire [NR_MASTERS-1:0]    				busms_ack_i_flat;
   wire [NR_MASTERS-1:0]    				busms_rty_i_flat;
   wire [NR_MASTERS-1:0]    				busms_err_i_flat;
   wire [DATA_WIDTH*NR_MASTERS-1:0] 	busms_dat_i_flat;
   mor1kx_trace_exec [CORES-1:0] 	trace;

   generate
      for (m = 0; m < NR_MASTERS; m = m + 1) begin : gen_busms_flat
         assign busms_adr_o_flat[ADDRESS_WIDTH*(m+1)-1:ADDRESS_WIDTH*m] = busms_adr_o[m];
         assign busms_cyc_o_flat[m] = busms_cyc_o[m];
         assign busms_dat_o_flat[DATA_WIDTH*(m+1)-1:DATA_WIDTH*m] = busms_dat_o[m];
         assign busms_sel_o_flat[4*(m+1)-1:4*m] = busms_sel_o[m];
         assign busms_stb_o_flat[m] = busms_stb_o[m];
         assign busms_we_o_flat[m] = busms_we_o[m];
         assign busms_cab_o_flat[m] = busms_cab_o[m];      
         assign busms_cti_o_flat[3*(m+1)-1:3*m] = busms_cti_o[m];
         assign busms_bte_o_flat[2*(m+1)-1:2*m] = busms_bte_o[m];
         assign busms_ack_i[m] = busms_ack_i_flat[m];
         assign busms_rty_i[m] = busms_rty_i_flat[m];
         assign busms_err_i[m] = busms_err_i_flat[m];
         assign busms_dat_i[m] = busms_dat_i_flat[DATA_WIDTH*(m+1)-1:DATA_WIDTH*m];
      end
   endgenerate
   
	//CPU Core
   generate
      for (c = 0; c < CORES; c = c + 1) begin : gen_cores
         /* mor1kx_module AUTO_TEMPLATE(
          .clk_i          (clk),
          .rst_i          (rst_cpu),
          .bus_clk_i      (clk),
          .bus_rst_i      (rst_cpu),
          .dbg_.*_o       (),
          .dbg_stall_i    (1'b0),
          .dbg_ewt_i      (1'b0),
          .dbg_stb_i      (1'b0),
          .dbg_we_i       (1'b0),
          .dbg_adr_i      (32'h00000000),
          .dbg_dat_i      (32'h00000000),
          .iwb_\(.*\)     (busms_\1[c*2][]),
          .dwb_\(.*\)     (busms_\1[c*2+1][]),
          .pic_ints_i     (pic_ints_i[c]),
          .snoop_enable_i (snoop_enable),
          .snoop_adr_i    (snoop_adr),
          .trace          (trace[`DEBUG_TRACE_EXEC_WIDTH*(c+1)-1:`DEBUG_TRACE_EXEC_WIDTH*c]),
          ); */
         mor1kx_module
               #(.ID(0))
         u_core (
                 /*AUTOINST*/
                 // Outputs
                 .dbg_lss_o             (),                      // Templated
                 .dbg_is_o              (),                      // Templated
                 .dbg_wp_o              (),                      // Templated
                 .dbg_bp_o              (),                      // Templated
                 .dbg_dat_o             (),                      // Templated
                 .dbg_ack_o             (),                      // Templated
                 .iwb_cyc_o             (busms_cyc_o[c*2]),      // Templated
                 .iwb_adr_o             (busms_adr_o[c*2][ADDRESS_WIDTH-1:0]), // Templated
                 .iwb_stb_o             (busms_stb_o[c*2]),      // Templated
                 .iwb_we_o              (busms_we_o[c*2]),       // Templated
                 .iwb_sel_o             (busms_sel_o[c*2][3:0]), // Templated
                 .iwb_dat_o             (busms_dat_o[c*2][DATA_WIDTH-1:0]), // Templated
                 .iwb_bte_o             (busms_bte_o[c*2][1:0]), // Templated
                 .iwb_cti_o             (busms_cti_o[c*2][2:0]), // Templated
                 .dwb_cyc_o             (busms_cyc_o[c*2+1]),    // Templated
                 .dwb_adr_o             (busms_adr_o[c*2+1][ADDRESS_WIDTH-1:0]), // Templated
                 .dwb_stb_o             (busms_stb_o[c*2+1]),    // Templated
                 .dwb_we_o              (busms_we_o[c*2+1]),     // Templated
                 .dwb_sel_o             (busms_sel_o[c*2+1][3:0]), // Templated
                 .dwb_dat_o             (busms_dat_o[c*2+1][DATA_WIDTH-1:0]), // Templated
                 .dwb_bte_o             (busms_bte_o[c*2+1][1:0]), // Templated
                 .dwb_cti_o             (busms_cti_o[c*2+1][2:0]), // Templated
                 .trace_exec            (trace), 		 // Templated
                 // Inputs
                 .clk_i                 (clk),                   // Templated
                 .bus_clk_i             (clk),                   // Templated
                 .rst_i                 (rst_cpu),               // Templated
                 .bus_rst_i             (rst_cpu),               // Templated
                 .dbg_stall_i           (1'b0),             // Templated
                 .dbg_ewt_i             (1'b0),                  // Templated
                 .dbg_stb_i             (1'b0),                  // Templated
                 .dbg_we_i              (1'b0),                  // Templated
                 .dbg_adr_i             (32'h00000000),          // Templated
                 .dbg_dat_i             (32'h00000000),          // Templated
                 .pic_ints_i            (pic_ints_i[c]),         // Templated
                 .iwb_ack_i             (busms_ack_i[c*2]),      // Templated
                 .iwb_err_i             (busms_err_i[c*2]),      // Templated
                 .iwb_rty_i             (busms_rty_i[c*2]),      // Templated
                 .iwb_dat_i             (busms_dat_i[c*2][DATA_WIDTH-1:0]), // Templated
                 .dwb_ack_i             (busms_ack_i[c*2+1]),    // Templated
                 .dwb_err_i             (busms_err_i[c*2+1]),    // Templated
                 .dwb_rty_i             (busms_rty_i[c*2+1]),    // Templated
                 .dwb_dat_i             (busms_dat_i[c*2+1][DATA_WIDTH-1:0]), // Templated
                 .snoop_enable_i        (snoop_enable),          // Templated
                 .snoop_adr_i           (snoop_adr));            // Templated

         
         assign busms_cab_o[c*2] = 1'b0;
         assign busms_cab_o[c*2+1] = 1'b0;
      end
   endgenerate
         
	
	//Wishbone Bus System		
   /* wb_bus_b3 AUTO_TEMPLATE(
    .clk_i      (clk),
    .rst_i      (rst_sys),
    .m_\(.*\)_o (busms_\1_i_flat),
    .m_\(.*\)_i (busms_\1_o_flat),
    .s_\(.*\)_o ({bussl_\1_i[4],bussl_\1_i[3],bussl_\1_i[2],bussl_\1_i[1],bussl_\1_i[0]}),
    .s_\(.*\)_i ({bussl_\1_o[4],bussl_\1_o[3],bussl_\1_o[2],bussl_\1_o[1],bussl_\1_o[0]}),
    .snoop_en_o (snoop_enable),
    .snoop_adr_o (snoop_adr),
    .bus_hold (1'b0),
    .bus_hold_ack (),
    ); */
	 wb_bus_b3
		#(.MASTERS(NR_MASTERS),.SLAVES(NR_SLAVES),
		 .S0_RANGE_WIDTH(1),.S0_RANGE_MATCH(1'h0),  // memory
		 .S1_RANGE_WIDTH(4),.S1_RANGE_MATCH(4'he),  // network adapter configuration
		 .S2_RANGE_WIDTH(8),.S2_RANGE_MATCH(8'hff), // bootrom
		 .S3_RANGE_WIDTH(12),.S3_RANGE_MATCH(12'hfe8), // fifo for ready queue
		 .S4_RANGE_WIDTH(12),.S4_RANGE_MATCH(12'hfe0)) // dbgnoc output network adapter
   u_bus(/*AUTOINST*/
         // Outputs
         .m_dat_o                       (busms_dat_i_flat),      // Templated
         .m_ack_o                       (busms_ack_i_flat),      // Templated
         .m_err_o                       (busms_err_i_flat),      // Templated
         .m_rty_o                       (busms_rty_i_flat),      // Templated
         .s_adr_o                       ({bussl_adr_i[4],bussl_adr_i[3],bussl_adr_i[2],bussl_adr_i[1],bussl_adr_i[0]}), // Templated
         .s_dat_o                       ({bussl_dat_i[4],bussl_dat_i[3],bussl_dat_i[2],bussl_dat_i[1],bussl_dat_i[0]}), // Templated
         .s_cyc_o                       ({bussl_cyc_i[4],bussl_cyc_i[3],bussl_cyc_i[2],bussl_cyc_i[1],bussl_cyc_i[0]}), // Templated
         .s_stb_o                       ({bussl_stb_i[4],bussl_stb_i[3],bussl_stb_i[2],bussl_stb_i[1],bussl_stb_i[0]}), // Templated
         .s_sel_o                       ({bussl_sel_i[4],bussl_sel_i[3],bussl_sel_i[2],bussl_sel_i[1],bussl_sel_i[0]}), // Templated
         .s_we_o                        ({bussl_we_i[4],bussl_we_i[3],bussl_we_i[2],bussl_we_i[1],bussl_we_i[0]}), 	// Templated
         .s_cti_o                       ({bussl_cti_i[4],bussl_cti_i[3],bussl_cti_i[2],bussl_cti_i[1],bussl_cti_i[0]}), // Templated
			.s_bte_o                       ({bussl_bte_i[4],bussl_bte_i[3],bussl_bte_i[2],bussl_bte_i[1],bussl_bte_i[0]}), // Templated
         .snoop_adr_o                   (snoop_adr),             // Templated
         .snoop_en_o                    (snoop_enable),          // Templated
         .bus_hold_ack                  (),                      // Templated
         // Inputs
         .clk_i                         (clk),                   // Templated
         .rst_i                         (rst_sys),               // Templated
         .m_adr_i                       (busms_adr_o_flat),      // Templated
         .m_dat_i                       (busms_dat_o_flat),      // Templated
         .m_cyc_i                       (busms_cyc_o_flat),      // Templated
         .m_stb_i                       (busms_stb_o_flat),      // Templated
         .m_sel_i                       (busms_sel_o_flat),      // Templated
         .m_we_i                        (busms_we_o_flat),       // Templated
         .m_cti_i                       (busms_cti_o_flat),      // Templated
         .m_bte_i                       (busms_bte_o_flat),      // Templated
         .s_dat_i                       ({bussl_dat_o[4],bussl_dat_o[3],bussl_dat_o[2],bussl_dat_o[1],bussl_dat_o[0]}), // Templated
         .s_ack_i                       ({bussl_ack_o[4],bussl_ack_o[3],bussl_ack_o[2],bussl_ack_o[1],bussl_ack_o[0]}), // Templated
         .s_err_i                       ({bussl_err_o[4],bussl_err_o[3],bussl_err_o[2],bussl_err_o[1],bussl_err_o[0]}), // Templated
         .s_rty_i                       ({bussl_rty_o[4],bussl_rty_o[3],bussl_rty_o[2],bussl_rty_o[1],bussl_rty_o[0]}), // Templated
         .bus_hold                      (1'b0));                         // Templated



	assign wb_mem_clk_i = clk;
   assign wb_mem_rst_i = rst;
	assign wb_mem_adr_i = bussl_adr_i[0];
   assign wb_mem_bte_i = bussl_bte_i[0];
   assign wb_mem_cti_i = bussl_cti_i[0];
   assign wb_mem_cyc_i = bussl_cyc_i[0];
   assign wb_mem_dat_i = bussl_dat_i[0];
   assign wb_mem_sel_i = bussl_sel_i[0];
   assign wb_mem_stb_i = bussl_stb_i[0];
   assign wb_mem_we_i  = bussl_we_i[0];
	
	assign bussl_ack_o[0] = wb_mem_ack_o;
	assign bussl_err_o[0] = wb_mem_err_o;
	assign bussl_rty_o[0] = wb_mem_rty_o;
	assign bussl_dat_o[0] = wb_mem_dat_o;
   

	//SRAM Module - System main memory
   /* wb_sram_sp AUTO_TEMPLATE(
    .wb_\(.*\) (wb_mem_\1),
    ); */
   wb_sram_sp
      #(.DW(32),
        .AW(32),
        .MEM_SIZE(MEM_SIZE),
        .MEM_FILE(MEM_FILE))
   u_ram(/*AUTOINST*/
            // Outputs
            .wb_ack_o                   (wb_mem_ack_o),          // Templated
            .wb_err_o                   (wb_mem_err_o),          // Templated
            .wb_rty_o                   (wb_mem_rty_o),          // Templated
            .wb_dat_o                   (wb_mem_dat_o[DATA_WIDTH-1:0]), // Templated
            // Inputs
            .wb_adr_i                   (wb_mem_adr_i[ADDRESS_WIDTH-1:0]), // Templated
            .wb_bte_i                   (wb_mem_bte_i[1:0]),          // Templated
            .wb_cti_i                   (wb_mem_cti_i[2:0]),          // Templated
            .wb_cyc_i                   (wb_mem_cyc_i),          // Templated
            .wb_dat_i                   (wb_mem_dat_i[DATA_WIDTH-1:0]), // Templated
            .wb_sel_i                   (wb_mem_sel_i[3:0]),          // Templated
            .wb_stb_i                   (wb_mem_stb_i),          // Templated
            .wb_we_i                    (wb_mem_we_i),           // Templated
            .wb_clk_i                   (wb_mem_clk_i),          // Templated
            .wb_rst_i                   (wb_mem_rst_i));         // Templated

   wire [DMA_ENTRIES-1:0] na_irq;
   /*
    *     +---+---+-...-+---+
    *     |   |   | dma |   |
    *     +---+---+-...-+---+
    * dma_entries-1      (0)
    *
    * map to irq lines of cpu
    *
    *  +-----+
    *  | dma |
    *  +-----+
    *     2
    */
//   assign pic_ints_i[0][2] = na_irq[0];



	wire [ADDRESS_WIDTH-1:0] bus_initial_trace_address;
 	wire fifo_store_packet;
	wire address_ack;
	wire [ADDRESS_WIDTH-1:0] discard_queue;
	
	//Network adapter module, including DMA module and configuration interface for Debug-NoC
	networkadapter_wb 
		#(.MEM_MIN_ADDR(MEM_MIN_ADDR),.MEM_MAX_ADDR(MEM_MAX_ADDR),
		  .DBG_NOC_FLIT_DATA_WIDTH(DBG_NOC_FLIT_DATA_WIDTH),.DBG_NOC_FLIT_TYPE_WIDTH(DBG_NOC_FLIT_TYPE_WIDTH),
		  .DATA_WIDTH(DATA_WIDTH),.ADDRESS_WIDTH(ADDRESS_WIDTH),
		  .DBG_NOC_VCHANNELS(DBG_NOC_VCHANNELS),.DBG_NOC_CONF_VCHANNEL(DBG_NOC_CONF_VCHANNEL),.DBG_NOC_TRACE_VCHANNEL(DBG_NOC_TRACE_VCHANNEL))
	u_networkadapter_wb(
	       .clk						(clk),
	       .rst						(rst),
			 //Inputs
	       .dbgnoc_out_ready	(dbgnoc_out_ready),
	       .dbgnoc_in_flit		(dbgnoc_in_flit),
	       .dbgnoc_in_valid		(dbgnoc_in_valid),
			 .wbm_dat_i				(busms_dat_i[2*CORES][DATA_WIDTH-1:0]),
	       .wbm_ack_i				(busms_ack_i[2*CORES]),
			 .wbm_err_i				(busms_err_i[2*CORES]),
			 .wbm_rty_i				(busms_rty_i[2*CORES]),
			 .address_ack			(address_ack),
			 .last_address_read	(discard_queue),
	       // Outputs
	       .dbgnoc_out_flit		(dbgnoc_out_flit),
	       .dbgnoc_out_valid	(dbgnoc_out_valid),
	       .dbgnoc_in_ready		(dbgnoc_in_ready),
	       .wbm_adr_o				(busms_adr_o[2*CORES][ADDRESS_WIDTH-1:0]),
	       .wbm_we_o				(busms_we_o[2*CORES]),
	       .wbm_cyc_o				(busms_cyc_o[2*CORES]),
	       .wbm_stb_o				(busms_stb_o[2*CORES]),
	       .wbm_dat_o				(busms_dat_o[2*CORES][DATA_WIDTH-1:0]),
			 .wbm_cti_o				(busms_cti_o[2*CORES]),
			 .wbm_sel_o				(busms_sel_o[2*CORES]),
			 .irq_na					(), // interrupt lines not used
			 .bus_initial_trace_address (bus_initial_trace_address),
 			 .fifo_store_packet	(fifo_store_packet),
			 // Inputs
			 .wbs_adr_i          		(bussl_adr_i[4][ADDRESS_WIDTH-1:0]),
          .wbs_dat_i          		(bussl_dat_i[4][DATA_WIDTH-1:0]),
          .wbs_cyc_i          		(bussl_cyc_i[4]),
          .wbs_stb_i         		 	(bussl_stb_i[4]),
          .wbs_we_i        		   (bussl_we_i[4]),
			 // Outputs
			 .wbs_dat_o       		   (bussl_dat_o[4][DATA_WIDTH-1:0]),
          .wbs_ack_o      			   (bussl_ack_o[4]),
          .wbs_err_o     		    	(bussl_err_o[4]),
          .wbs_rty_o     		      (bussl_rty_o[4]));
	
	//Packer queue, including both ready and discard queue
	packet_queue
     #(.NOC_DATA_WIDTH(DBG_NOC_FLIT_DATA_WIDTH),.NOC_TYPE_WIDTH(DBG_NOC_FLIT_TYPE_WIDTH),.fifo_depth(32),
		 .DATA_WIDTH(DATA_WIDTH),.ADDRESS_WIDTH(ADDRESS_WIDTH))
   u_packet_queue(
			 // Inputs
	       .clk						(clk),
	       .rst						(rst),
			 .wbs_adr_i          (bussl_adr_i[3][ADDRESS_WIDTH-1:0]),
          .wbs_dat_i          (bussl_dat_i[3][DATA_WIDTH-1:0]),
          .wbs_cyc_i          (bussl_cyc_i[3]),
          .wbs_stb_i          (bussl_stb_i[3]),
          .wbs_we_i           (bussl_we_i[3]),
			 .bus_initial_trace_address (bus_initial_trace_address),
 			 .fifo_store_packet	(fifo_store_packet),
			 // Outputs
			 .wbs_dat_o          (bussl_dat_o[3][DATA_WIDTH-1:0]),
          .wbs_ack_o          (bussl_ack_o[3]),
          .wbs_err_o          (bussl_err_o[3]),
          .wbs_rty_o          (bussl_rty_o[3]),
			 .address_ack			(address_ack),
			 .discard_queue		(discard_queue));
	
	
	//Bootrom for initialization of the CPU Core
   /* bootrom AUTO_TEMPLATE(
    .clk(clk),
    .rst(rst_sys),
    .wb_dat_o (bussl_dat_o[2][]),
    .wb_ack_o (bussl_ack_o[2][]),
    .wb_err_o (bussl_err_o[2][]),
    .wb_rty_o (bussl_rty_o[2][]),
    .wb_adr_i (bussl_adr_i[2][]),
    .wb_dat_i (bussl_dat_i[2][]),
    .wb_cyc_i (bussl_cyc_i[2][]),
    .wb_stb_i (bussl_stb_i[2][]),
    .wb_sel_i (bussl_sel_i[2][]),
    ); */
   bootrom
      u_bootrom(/*AUTOINST*/
                // Outputs
                .wb_dat_o               (bussl_dat_o[2][DATA_WIDTH-1:0]),  // Templated
                .wb_ack_o               (bussl_ack_o[2]),        // Templated
                .wb_err_o               (bussl_err_o[2]),        // Templated
                .wb_rty_o               (bussl_rty_o[2]),        // Templated
                // Inputs
                .clk                    (clk),                   // Templated
                .rst                    (rst_sys),               // Templated
                .wb_adr_i               (bussl_adr_i[2][ADDRESS_WIDTH-1:0]),  // Templated
                .wb_dat_i               (bussl_dat_i[2][DATA_WIDTH-1:0]),  // Templated
                .wb_cyc_i               (bussl_cyc_i[2]),        // Templated
                .wb_stb_i               (bussl_stb_i[2]),        // Templated
                .wb_sel_i               (bussl_sel_i[2][3:0]));  // Templated


	//Network adapter configuration interface
	/* networkadapter_ct AUTO_TEMPLATE(
    .clk(clk),
    .rst(rst_sys),
    .wbs_\(.*\)   (bussl_\1[1]),
    .wbm_\(.*\)      (busms_\1[NR_MASTERS-1]),
    .irq    (na_irq),
    );*/
   na_conf_wb
      #(.TILEID(ID),
        .CONFIG(CONFIG))
      u_na_conf(
`ifdef OPTIMSOC_CLOCKDOMAINS
 `ifdef OPTIMSOC_CDC_DYNAMIC
           .cdc_conf                     (cdc_conf[2:0]),
           .cdc_enable                   (cdc_enable),
 `endif
`endif
           /*AUTOINST*/
           // Outputs
           .wbs_ack_o                   (bussl_ack_o[1]),        // Templated
           .wbs_rty_o                   (bussl_rty_o[1]),        // Templated
           .wbs_err_o                   (bussl_err_o[1]),        // Templated
           .wbs_dat_o                   (bussl_dat_o[1]),        // Templated
           // Inputs
           .clk                         (clk),                   // Templated
           .rst                         (rst_sys),               // Templated
           .wbs_adr_i                   (bussl_adr_i[1]),        // Templated
           .wbs_cyc_i                   (bussl_cyc_i[1]),        // Templated
           .wbs_dat_i                   (bussl_dat_i[1]),        // Templated
           .wbs_sel_i                   (bussl_sel_i[1]),        // Templated
           .wbs_stb_i                   (bussl_stb_i[1]),        // Templated
           .wbs_we_i                    (bussl_we_i[1]),         // Templated
           .wbs_cab_i                   (bussl_cab_i[1]),        // Templated
           .wbs_cti_i                   (bussl_cti_i[1]),        // Templated
           .wbs_bte_i                   (bussl_bte_i[1]));       // Templated


   logic [31:0]        			trace_r3 [0:CORES-1];
   wire [CORES-1:0]                 	termination;

// synthesis translate_off
   genvar j;
   generate
      for (j = 0; j < CORES; j = j+1) begin 
         
	  r3_checker
          u_r3_checker( .clk(clk),
                        .valid(trace[j].valid),
                        .we (trace[j].wben),
                        .addr (trace[j].wbreg),
                        .data (trace[j].wbdata),
                        .r3 (trace_r3[j]));

            /* trace_monitor AUTO_TEMPLATE(
             .enable  (trace_enable[j]),
             .wb_pc   (trace_pc[j]),
             .wb_insn (trace_insn[j]),
             .r3      (trace_r3[j]),
             .supv    (),
             .termination  (termination[j]),
             .termination_all (termination),
             ); */
         trace_monitor
           #(.STDOUT_FILENAME({"diag-stdout.",index2string(j)}),
             .TRACEFILE_FILENAME({"diag-trace.",index2string(j)}),
             .ENABLE_TRACE(0),
             .ID(j),
             .TERM_CROSS_NUM(CORES))
         u_mon0(/*AUTOINST*/
                // Outputs
                .termination            (termination[j]),        // Templated
                // Inputs
                .clk                    (clk),
                .enable                 (trace[j].valid),        // Templated
                .wb_pc                  (trace[j].pc),           // Templated
                .wb_insn                (trace[j].insn),         // Templated
                .r3                     (trace_r3[j]),           // Templated
                .termination_all        (termination));          // Templated

      end
   endgenerate
// synthesis translate_on

	`include "optimsoc_functions.vh"
	
endmodule

// Local Variables:
// verilog-library-directories:("../../*/verilog/")
// verilog-auto-inst-param-value: t
// End:
