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
 * A testbench for a 2x2 CCCC system with distributed memory
 *
 * Parameters:
 *   USE_DEBUG:
 *     Enable the OSD-based debug system.
 *
 *   NUM_CORES:
 *     Number of CPU cores inside each compute tile (default: 1)
 *
 *   LMEM_SIZE:
 *     Size of the local distributed memory in bytes (default: 32 MB)
 *
 * Author(s):
 *   Philipp Wagner <philipp.wagner@tum.de>
 *   Stefan Wallentowitz <stefan.wallentowitz@tum.de>
 */

`include "dbg_config.vh"

import dii_package::dii_flit;
import opensocdebug::mor1kx_trace_exec;
import optimsoc::*;

module tb_system_2x2_cccc(
`ifdef verilator
   input clk,
   input rst
`endif
   );

   parameter USE_DEBUG = 0;
   parameter integer NUM_CORES = 1;
   parameter integer LMEM_SIZE = 32*1024*1024;

   localparam base_config_t
     BASE_CONFIG = '{ NUMTILES: 4,
                      NUMCTS: 4,
                      CTLIST: {{60{16'hx}}, 16'h0, 16'h1, 16'h2, 16'h3},
                      CORES_PER_TILE: 32'(NUM_CORES),
                      GMEM_SIZE: 0,
                      GMEM_TILE: 'x,
                      NOC_DATA_WIDTH: 32,
                      NOC_TYPE_WIDTH: 2,
                      NOC_VCHANNELS: 3,
                      NOC_VC_MPSIMPLE: 0,
                      NOC_VC_DMA_REQ: 1,
                      NOC_VC_DMA_RESP: 2,
                      MEMORY_ACCESS: DISTRIBUTED,
                      LMEM_SIZE: LMEM_SIZE,
                      LMEM_STYLE: PLAIN,
                      USE_DEBUG: 1'(USE_DEBUG),
                      DEBUG_STM: 1,
                      DEBUG_CTM: 1,
                      DEBUG_CEG: 1,
                      DEBUG_DPR: 0
                      };

   localparam config_t CONFIG = derive_config(BASE_CONFIG);

   logic rst_sys, rst_cpu;

   logic cpu_stall;
   assign cpu_stall = 0;

// In Verilator, we feed clk and rst from the C++ toplevel, in ModelSim & Co.
// these signals are generated inside this testbench.
`ifndef verilator
   reg clk;
   reg rst;
`endif

   // Reset signals
   // In simulations with debug system, these signals can be triggered through
   // the host software. In simulations without debug systems, we only rely on
   // the global reset signal.
   generate
      if (CONFIG.USE_DEBUG == 0) begin : gen_use_debug_rst
         assign rst_sys = rst;
         assign rst_cpu = rst;
      end
   endgenerate

   glip_channel c_glip_in(.*);
   glip_channel c_glip_out(.*);

   logic com_rst, logic_rst;

   if (CONFIG.USE_DEBUG == 1) begin : gen_use_debug_glip
      // TCP communication interface (simulation only)
      glip_tcp_toplevel
        u_glip
          (
           .*,
           .clk_io    (clk),
           .clk_logic (clk),
           .fifo_in   (c_glip_in),
           .fifo_out  (c_glip_out)
           );
   end // if (CONFIG.USE_DEBUG == 1)

   // Monitor system behavior in simulation
   genvar t;
   genvar i;

   wire [CONFIG.NUMCTS*CONFIG.CORES_PER_TILE-1:0] termination;

   generate
      for (t = 0; t < CONFIG.NUMCTS; t = t + 1) begin : gen_tracemon_ct

         logic [31:0] trace_r3 [0:CONFIG.CORES_PER_TILE-1];
         mor1kx_trace_exec [CONFIG.CORES_PER_TILE-1:0] trace;
         assign trace = u_system.gen_ct[t].u_ct.trace;

         for (i = 0; i < CONFIG.CORES_PER_TILE; i = i + 1) begin : gen_tracemon_core
            r3_checker
               u_r3_checker(
                  .clk(clk),
                  .valid(trace[i].valid),
                  .we (trace[i].wben),
                  .addr (trace[i].wbreg),
                  .data (trace[i].wbdata),
                  .r3 (trace_r3[i])
               );

            trace_monitor
               #(
                  .STDOUT_FILENAME({"stdout.",index2string((t*CONFIG.CORES_PER_TILE)+i)}),
                  .TRACEFILE_FILENAME({"trace.",index2string((t*CONFIG.CORES_PER_TILE)+i)}),
                  .ENABLE_TRACE(0),
                  .ID((t*CONFIG.CORES_PER_TILE)+i),
                  .TERM_CROSS_NUM(CONFIG.NUMCTS*CONFIG.CORES_PER_TILE)
               )
               u_mon0(
                  .termination            (termination[(t*CONFIG.CORES_PER_TILE)+i]),
                  .clk                    (clk),
                  .enable                 (trace[i].valid),
                  .wb_pc                  (trace[i].pc),
                  .wb_insn                (trace[i].insn),
                  .r3                     (trace_r3[i]),
                  .termination_all        (termination)
              );
         end

      end
   endgenerate

   system_2x2_cccc_dm
     #(.CONFIG(CONFIG))
   u_system
     (.clk (clk),
      .rst (rst | logic_rst),
      .c_glip_in (c_glip_in),
      .c_glip_out (c_glip_out)
      );

// Generate testbench signals.
// In Verilator, these signals are generated in the C++ toplevel testbench
`ifndef verilator
   initial begin
      clk = 1'b1;
      rst = 1'b1;
      #15;
      rst = 1'b0;
   end

   always clk = #1.25 ~clk;
`endif

   `include "optimsoc_functions.vh"
endmodule

// Local Variables:
// verilog-library-directories:("." "../../../../src/rtl/*/verilog")
// verilog-auto-inst-param-value: t
// End:
