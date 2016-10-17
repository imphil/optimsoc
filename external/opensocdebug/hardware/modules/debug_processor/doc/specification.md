# Introduction

This document specifies the implementation of the *Debug Processor*. The debug processor is used to process the debug packets of one or more debug units and to forward the results to the user. All trace packets were stored in the SRAM
cell of the debug processor unit. Thus the processor has enough time to process the packets without losing any information. The debug processor unit contains a CPU,
SRAM cell, boot ROM module, packet queue module, network adapter configuration module and a network adapter including a DMA controller.

## License

This work is licensed under the Creative Commons
Attribution-ShareAlike 4.0 International License. To view a copy of
this license, visit
[http://creativecommons.org/licenses/by-sa/4.0/](http://creativecommons.org/licenses/by-sa/4.0/)
or send a letter to Creative Commons, PO Box 1866, Mountain View, CA
94042, USA.

You are free to share and adapt this work for any purpose as long as
you follow the following terms: (i) Attribution: You must give
appropriate credit and indicate if changes were made, (ii) ShareAlike:
If you modify or derive from this work, you must distribute it under
the same license as the original.

## Authors

Tim Fritzmann

# System Interface

There is a generic interface between the CPU Debug Unit and the system:

 Signal             | Direction              | Description
 -------------------| -----------------------| -----------
 `rst_cpu`          | System->Debug Processor| Reset signal of the main CPU (on reset needed for setting PC to its inital value 0x100)
