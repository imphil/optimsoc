/* Copyright (c) 2012-2016 by the author(s)
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
 * A 2x2 distributed memory system with four compute tiles (CCCC)
 *
 * Author(s):
 *   Stefan Wallentowitz <stefan.wallentowitz@tum.de>
 */

`include "lisnoc_def.vh"
`include "dbg_config.vh"

import dii_package::dii_flit;
import optimsoc::*;

module system_2x2_cccc_dm(
      input clk, rst,

      glip_channel c_glip_in,
      glip_channel c_glip_out,

      output [4*32-1:0] wb_ext_adr_i,
      output [4*1-1:0]  wb_ext_cyc_i,
      output [4*32-1:0] wb_ext_dat_i,
      output [4*4-1:0]  wb_ext_sel_i,
      output [4*1-1:0]  wb_ext_stb_i,
      output [4*1-1:0]  wb_ext_we_i,
      output [4*1-1:0]  wb_ext_cab_i,
      output [4*3-1:0]  wb_ext_cti_i,
      output [4*2-1:0]  wb_ext_bte_i,
      input [4*1-1:0]   wb_ext_ack_o,
      input [4*1-1:0]   wb_ext_rty_o,
      input [4*1-1:0]   wb_ext_err_o,
      input [4*32-1:0]  wb_ext_dat_o
      );
   
   // number of tiles in this system
   // This parameter is mainly intended to provide a more descriptive name in
   // places where this value is used; you cannot simply change this parameter 
   // without also adjusting the NoC.
   localparam NUM_TILES = 4;

   parameter config_t CONFIG = 'x;

   logic       rst_sys, rst_cpu;   
   
   dii_flit [1:0] debug_ring_segment_dbgif_in;
   logic [1:0] debug_ring_segment_dbgif_in_ready;
   dii_flit [1:0] debug_ring_segment_dbgif_out;
   logic [1:0] debug_ring_segment_dbgif_out_ready;   
   
   dii_flit [1:0] debug_ring_segment_dpr_in;
   logic [1:0] debug_ring_segment_dpr_in_ready;
   dii_flit [1:0] debug_ring_segment_dpr_out;
   logic [1:0] debug_ring_segment_dpr_out_ready;   
   
   dii_flit [1:0] debug_ring_segment_tile_in [0:NUM_TILES-1];
   logic [1:0] debug_ring_segment_tile_in_ready [0:NUM_TILES-1];   
   dii_flit [1:0] debug_ring_segment_tile_out [0:NUM_TILES-1];
   logic [1:0] debug_ring_segment_tile_out_ready [0:NUM_TILES-1];
   
   
   // connect debug NoC
   // -> DBGIF -> TILE 0 -> TILE 1 -> ... -> TILE NUM_TILES-1 -> DPR -> (back to beginning)
   
   // DBGIF -> TILE 0
   assign debug_ring_segment_tile_in[0] = debug_ring_segment_dbgif_out;
   assign debug_ring_segment_dbgif_out_ready = debug_ring_segment_tile_in_ready[0];
   
   // TILE 1 -> TILE 2 -> TILE 3
   assign debug_ring_segment_tile_in[1] = debug_ring_segment_tile_out[0];
   assign debug_ring_segment_tile_out_ready[0] = debug_ring_segment_tile_in_ready[1];
   
   assign debug_ring_segment_tile_in[2] = debug_ring_segment_tile_out[1];
   assign debug_ring_segment_tile_out_ready[1] = debug_ring_segment_tile_in_ready[2];   

   assign debug_ring_segment_tile_in[3] = debug_ring_segment_tile_out[2];
   assign debug_ring_segment_tile_out_ready[2] = debug_ring_segment_tile_in_ready[3];
   
   // TILE 3 -> DPR
   assign debug_ring_segment_dpr_in = debug_ring_segment_tile_out[3];
   assign debug_ring_segment_tile_out_ready[3] = debug_ring_segment_dpr_in_ready;
   
   // virtual-channel cross-over at the end of the ring (VC0 -> VC1)
   // required for deadlock avoidance
   dii_flit ring_tie;
   assign ring_tie.valid = 0;
   logic  ring_tie_ready;
   assign debug_ring_segment_dbgif_in = {debug_ring_segment_dpr_out[0], ring_tie};
   assign debug_ring_segment_dpr_out_ready = {ring_tie_ready, debug_ring_segment_dbgif_in_ready[1]};

   /*assign debug_ring_segment_dbgif_in = { debug_ring_segment_tile_out[3][0], ring_tie};
   assign debug_ring_segment_tile_out_ready[3] = {ring_tie_ready, debug_ring_segment_dbgif_in_ready[1]};*/
      
   
   
   /*assign debug_ring_segment_dbgif_in = debug_ring_segment_dpr_out;
   assign debug_ring_segment_dpr_out_ready = debug_ring_segment_dbgif_in;*/


   // We are routing the debug in a meander 
   // XXX: why?
   /*assign debug_ring_segment_tile_in[1] = debug_ring_segment_tile_out[0];
   assign debug_ring_segment_tile_out_ready[0] = debug_ring_segment_tile_in_ready[1];
   assign debug_ring_segment_tile_in[3] = debug_ring_segment_tile_out[1];
   assign debug_ring_segment_tile_out_ready[1] = debug_ring_segment_tile_in_ready[3];
   assign debug_ring_segment_tile_in[2] = debug_ring_segment_tile_out[3];
   assign debug_ring_segment_tile_out_ready[3] = debug_ring_segment_tile_in_ready[2];*/

   // The debug interface (dbgif) contains the elementary modules needed in the
   // debug system: the host interface module (HIM) and the system control
   // module (SCM)
   debug_interface
      #(
         .SYSTEMID    (1),
         .NUM_MODULES (CONFIG.DEBUG_NUM_MODS)
      )
      u_debuginterface
      (
         .clk            (clk),
         .rst            (rst),
         .sys_rst        (rst_sys),
         .cpu_rst        (rst_cpu),
         .glip_in        (c_glip_in),
         .glip_out       (c_glip_out),
         .ring_out       (debug_ring_segment_dbgif_out),
         .ring_out_ready (debug_ring_segment_dbgif_out_ready),
         .ring_in        (debug_ring_segment_dbgif_in),
         .ring_in_ready  (debug_ring_segment_dbgif_in_ready)
      );
      

   // Flits from NoC->tiles
   wire [CONFIG.NOC_FLIT_WIDTH-1:0] link_in_flit[0:3];
   wire [CONFIG.NOC_VCHANNELS-1:0] link_in_valid[0:3];
   wire [CONFIG.NOC_VCHANNELS-1:0] link_in_ready[0:3];

   // Flits from tiles->NoC
   wire [CONFIG.NOC_FLIT_WIDTH-1:0]   link_out_flit[0:3];
   wire [CONFIG.NOC_VCHANNELS-1:0] link_out_valid[0:3];
   wire [CONFIG.NOC_VCHANNELS-1:0] link_out_ready[0:3];

   /* lisnoc_mesh2x2 AUTO_TEMPLATE(
    .link\(.*\)_in_\(.*\)_.* (link_out_\2[\1]),
    .link\(.*\)_out_\(.*\)_.* (link_in_\2[\1]),
    .clk(clk),
    .rst(rst_sys),
    ); */
   lisnoc_mesh2x2
      #(.vchannels(CONFIG.NOC_VCHANNELS),.in_fifo_length(2),.out_fifo_length(2))
      u_mesh(/*AUTOINST*/
         // Outputs
         .link0_in_ready_o          (link_out_ready[0]),     // Templated
         .link0_out_flit_o          (link_in_flit[0]),       // Templated
         .link0_out_valid_o         (link_in_valid[0]),      // Templated
         .link1_in_ready_o          (link_out_ready[1]),     // Templated
         .link1_out_flit_o          (link_in_flit[1]),       // Templated
         .link1_out_valid_o         (link_in_valid[1]),      // Templated
         .link2_in_ready_o          (link_out_ready[2]),     // Templated
         .link2_out_flit_o          (link_in_flit[2]),       // Templated
         .link2_out_valid_o         (link_in_valid[2]),      // Templated
         .link3_in_ready_o          (link_out_ready[3]),     // Templated
         .link3_out_flit_o          (link_in_flit[3]),       // Templated
         .link3_out_valid_o         (link_in_valid[3]),      // Templated
         // Inputs
         .clk                       (clk),                   // Templated
         .rst                       (rst_sys),               // Templated
         .link0_in_flit_i           (link_out_flit[0]),      // Templated
         .link0_in_valid_i          (link_out_valid[0]),     // Templated
         .link0_out_ready_i         (link_in_ready[0]),      // Templated
         .link1_in_flit_i           (link_out_flit[1]),      // Templated
         .link1_in_valid_i          (link_out_valid[1]),     // Templated
         .link1_out_ready_i         (link_in_ready[1]),      // Templated
         .link2_in_flit_i           (link_out_flit[2]),      // Templated
         .link2_in_valid_i          (link_out_valid[2]),     // Templated
         .link2_out_ready_i         (link_in_ready[2]),      // Templated
         .link3_in_flit_i           (link_out_flit[3]),      // Templated
         .link3_in_valid_i          (link_out_valid[3]),     // Templated
         .link3_out_ready_i         (link_in_ready[3]));     // Templated

   genvar i;
   generate
      for (i=0; i<NUM_TILES; i=i+1) begin : gen_ct
         compute_tile_dm
            #(.CONFIG (CONFIG),
               .ID(i),
               .DEBUG_BASEID(2 /* 0: HIM, 1: SCM */ + i*CONFIG.DEBUG_MODS_PER_TILE) )
            u_ct(.clk                        (clk),
               .rst_cpu                    (rst_cpu),
               .rst_sys                    (rst_sys),
               .rst_dbg                    (rst),
               .debug_ring_in              (debug_ring_segment_tile_in[i]),
               .debug_ring_in_ready        (debug_ring_segment_tile_in_ready[i]),
               .debug_ring_out             (debug_ring_segment_tile_out[i]),
               .debug_ring_out_ready       (debug_ring_segment_tile_out_ready[i]),

               .wb_ext_ack_o               (wb_ext_ack_o[i]),
               .wb_ext_rty_o               (wb_ext_rty_o[i]),
               .wb_ext_err_o               (wb_ext_err_o[i]),
               .wb_ext_dat_o               (wb_ext_dat_o[(i+1)*32-1:i*32]),
               .wb_ext_adr_i               (wb_ext_adr_i[(i+1)*32-1:i*32]),
               .wb_ext_cyc_i               (wb_ext_cyc_i[i]),
               .wb_ext_dat_i               (wb_ext_dat_i[(i+1)*32-1:i*32]),
               .wb_ext_sel_i               (wb_ext_sel_i[(i+1)*4-1:i*4]),
               .wb_ext_stb_i               (wb_ext_stb_i[i]),
               .wb_ext_we_i                (wb_ext_we_i[i]),
               .wb_ext_cab_i               (wb_ext_cab_i[i]),
               .wb_ext_cti_i               (wb_ext_cti_i[(i+1)*3-1:i*3]),
               .wb_ext_bte_i               (wb_ext_bte_i[(i+1)*2-1:i*2]),

               .noc_in_ready               (link_in_ready[i][CONFIG.NOC_VCHANNELS-1:0]),
               .noc_out_flit               (link_out_flit[i][CONFIG.NOC_FLIT_WIDTH-1:0]),
               .noc_out_valid              (link_out_valid[i][CONFIG.NOC_VCHANNELS-1:0]),

               .noc_in_flit                (link_in_flit[i][CONFIG.NOC_FLIT_WIDTH-1:0]),
               .noc_in_valid               (link_in_valid[i][CONFIG.NOC_VCHANNELS-1:0]),
               .noc_out_ready              (link_out_ready[i][CONFIG.NOC_VCHANNELS-1:0]));
      end
   endgenerate


   // diagnosis processor (DPR)
   // XXX: Currently the NoC connection is BROKEN and this module *does not* work
   generate
      if (CONFIG.DEBUG_DPR) begin
         // DII router
         dii_flit dii_dpr_in;
         logic dii_dpr_in_ready;
         dii_flit dii_dpr_out;
         logic dii_dpr_out_ready;
      
         debug_ring_expand
            #(.PORTS(1))
         u_dpr_debug_ring_segment
            (.clk          (clk),
               .rst           (rst),
               .id_map        ({10'(CONFIG.DEBUG_NUM_MODS)}),
               .dii_in        (dii_dpr_in),
               .dii_in_ready  (dii_dpr_in_ready),
               .dii_out       (dii_dpr_out),
               .dii_out_ready (dii_dpr_out_ready),
               .ext_in        (debug_ring_segment_dpr_in),
               .ext_in_ready  (debug_ring_segment_dpr_in_ready),
               .ext_out       (debug_ring_segment_dpr_out),
               .ext_out_ready (debug_ring_segment_dpr_out_ready));
            
         // diagnosis processor itself
         osd_debug_processor #(
               .CONFIG (CONFIG))
            u_debug_processor(
               .clk  (clk),
               .rst  (rst_sys),
               .id   (CONFIG.DEBUG_NUM_MODS), // it's the last module in the debug infrastructure 
               .debug_in (dii_dpr_out),
               .debug_in_ready (dii_dpr_out_ready),
               .debug_out (dii_dpr_in),
               .debug_out_ready (dii_dpr_in_ready),
               .rst_cpu (rst_sys));
      end else begin
         assign debug_ring_segment_dpr_out = debug_ring_segment_dpr_in; 
         assign debug_ring_segment_dpr_in_ready = debug_ring_segment_dpr_out_ready;
      end
   endgenerate

endmodule

`include "lisnoc_undef.vh"

// Local Variables:
// verilog-library-directories:("../../../../../external/lisnoc/rtl/meshs/" "../../*/verilog")
// verilog-auto-inst-param-value: t
// End:
