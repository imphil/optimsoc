`include "lisnoc_def.vh"

module na_conf_wb(
`ifdef OPTIMSOC_CLOCKDOMAINS
 `ifdef OPTIMSOC_CDC_DYNAMIC
		cdc_conf, cdc_enable,
 `endif
`endif
   // Outputs
   wbs_ack_o, wbs_rty_o, wbs_err_o, wbs_dat_o,
   // Inputs
   clk, rst, wbs_adr_i, wbs_cyc_i, wbs_dat_i, wbs_sel_i, 
	wbs_stb_i, wbs_we_i, wbs_cab_i, wbs_cti_i, wbs_bte_i
   );

   parameter TILEID = 0;
   parameter COREBASE = 0;
   
   parameter config_t CONFIG = 'x;
	
   input clk;
	input rst;
	
	input [31:0]          wbs_adr_i;
   input                 wbs_cyc_i;
   input [31:0]          wbs_dat_i;
   input [3:0]           wbs_sel_i;
   input                 wbs_stb_i;
   input                 wbs_we_i;
   input                 wbs_cab_i;
   input [2:0]           wbs_cti_i;
   input [1:0]           wbs_bte_i;
   output                wbs_ack_o;
   output                wbs_rty_o;
   output                wbs_err_o;
   output [31:0]         wbs_dat_o;
	
`ifdef OPTIMSOC_CLOCKDOMAINS
 `ifdef OPTIMSOC_CDC_DYNAMIC
   output [2:0]          cdc_conf;
   output                cdc_enable;
 `endif
`endif

	/* networkadapter_conf AUTO_TEMPLATE(
    .data   (wbs_dat_o[]),
    .ack    (wbs_ack_o[]),
    .rty    (wbs_rty_o[]),
    .err    (wbs_err_o[]),
    .adr    (wbs_adr_i[15:0]),
    .we     (wbs_cyc_i & wbs_stb_i & wbs_we_i),
    .data_i (wbs_dat_i),
    ); */
	 
	networkadapter_conf
     #(.CONFIG		      (CONFIG),
       .TILEID                (TILEID),
       .CONF_MPSIMPLE_PRESENT (0),
       .CONF_DMA_PRESENT      (0),
       .COREBASE              (COREBASE))
   u_conf(
`ifdef OPTIMSOC_CLOCKDOMAINS
 `ifdef OPTIMSOC_CDC_DYNAMIC
          .cdc_conf                     (cdc_conf[2:0]),
          .cdc_enable                   (cdc_enable),
 `endif
`endif
          /*AUTOINST*/
          // Outputs
          .data                         (wbs_dat_o),    // Templated
          .ack                          (wbs_ack_o),    // Templated
          .rty                          (wbs_rty_o),    // Templated
          .err                          (wbs_err_o),    // Templated
          // Inputs
          .clk                          (clk),
          .rst                          (rst),
          .adr                          (wbs_adr_i[15:0]),       // Templated
          .we                           (wbs_cyc_i & wbs_stb_i & wbs_we_i), // Templated
          .data_i                       (wbs_dat_i));            // Templated
			 	
endmodule
