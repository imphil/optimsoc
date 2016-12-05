/* Copyright (c) 2016 by the author(s)
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
 * Debug interface between the host and the target system
 *
 * This module encapsulates the basic Open SoC Debug components, the Host
 * Interface Module (HIM) and the System Control Module (SCM).
 *
 * Parameters:
 *   NUM_MODULES:
 *     Number of modules in the debug system *in addition* to the HIM and SCM
 *     modules.
 *   SYSTEMID:
 *     Unique ID for the system (used for auto-discovery of system properties on
 *     the host).
 *
 * Author(s):
 *   Stefan Wallentowitz <stefan.wallentowitz@tum.de>
 */

import dii_package::dii_flit;

module debug_interface
  #(
    parameter SYSTEMID = 'x,
    parameter NUM_MODULES = 0,
    parameter MAX_PKT_LEN = 16
    )
  (
   input  clk,
   input  rst,

   // GLIP host connection
   glip_channel.slave glip_in,
   glip_channel.master glip_out,

   // ring connection
   output dii_flit [1:0] ring_out,
   input [1:0] ring_out_ready,
   input dii_flit [1:0] ring_in,
   output [1:0] ring_in_ready,

   // system reset request
   output sys_rst,

   // CPU reset request
   output cpu_rst
   );
   
   // number of units connected to the debug ring segment in this file
   localparam DEBUG_RING_SEGMENT_PORTS = 2;

   dii_flit [DEBUG_RING_SEGMENT_PORTS-1:0] dii_in;
   logic [DEBUG_RING_SEGMENT_PORTS-1:0] dii_in_ready;
   dii_flit [DEBUG_RING_SEGMENT_PORTS-1:0] dii_out;
   logic [DEBUG_RING_SEGMENT_PORTS-1:0] dii_out_ready;

   debug_ring_expand
     #(.PORTS(DEBUG_RING_SEGMENT_PORTS))
   u_debug_ring_segment
      (.clk          (clk),
      .rst           (rst),
      .id_map        ({10'd1,10'd0}),      
      .dii_in        (dii_in),
      .dii_in_ready  (dii_in_ready),
      .dii_out       (dii_out),
      .dii_out_ready (dii_out_ready),
      .ext_in        (ring_in),
      .ext_in_ready  (ring_in_ready),
      .ext_out       (ring_out),
      .ext_out_ready (ring_out_ready));

   osd_him
     #(.MAX_PKT_LEN(MAX_PKT_LEN))
   u_him
     (
      .clk           (clk),
      .rst           (rst),
      .glip_in       (glip_in),
      .glip_out      (glip_out),
      .dii_out       (dii_in[0]),
      .dii_out_ready (dii_in_ready[0]),
      .dii_in        (dii_out[0]),
      .dii_in_ready  (dii_out_ready[0])
      );

   osd_scm
      #(
         .SYSTEMID (SYSTEMID),
         .NUM_MOD  (NUM_MODULES)
      )
      u_scm (
         .clk(clk),
         .rst(rst),

         .id  (1), // SCM must be ID 1 for discovery to work
         .debug_in   (dii_out[1]),
         .debug_in_ready (dii_out_ready[1]),
         .debug_out (dii_in[1]),
         .debug_out_ready (dii_in_ready[1]),

         .sys_rst(sys_rst),
         .cpu_rst(cpu_rst)
     );

endmodule
