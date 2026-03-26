// ==================================================
// Debug Utilities
// Reusable debug macros for Verilog designs
// ==================================================

`ifndef DEBUG_UTILS_VH
`define DEBUG_UTILS_VH


`ifdef SYNTHESIS
  `undef DEBUG
`else 
  // Default: Debug Activated for simulation
  `define DEBUG 1
`endif 


`ifdef DEBUG
    `define DEBUG_INFO(msg)    $display msg ;
    `define DEBUG_WARNING(msg) $display msg ;
    `define DEBUG_ERROR(msg)   $display msg ;
    `define DEBUG_TIME(msg)    $display("[TIME %0t] ", $time, msg);
`else
    // Synthesis: MACROs are empty
    `define DEBUG_INFO(msg)
    `define DEBUG_WARNING(msg)
    `define DEBUG_ERROR(msg)
    `define DEBUG_TIME(msg)
`endif

`endif // DEBUG_UTILS_VH