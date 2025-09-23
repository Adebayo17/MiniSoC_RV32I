// ==================================================
// Debug Utilities
// Version 1.0
// Reusable debug macros for Verilog designs
// ==================================================

`ifndef DEBUG_UTILS_VH
`define DEBUG_UTILS_VH

// Debug message macro
`ifdef DEBUG
  `define DEBUG_MSG(x) $display x
  `define DEBUG_WARNING(x) $display("[DEBUG WARNING] ", x)
  `define DEBUG_ERROR(x) $display("[DEBUG ERROR] ", x)
  `define DEBUG_INFO(x) $display("[DEBUG INFO] ", x)
`else
  `define DEBUG_MSG(x)
  `define DEBUG_WARNING(x)
  `define DEBUG_ERROR(x)
  `define DEBUG_INFO(x)
`endif

// Conditional display based on debug level
`ifdef DEBUG_LEVEL
  `if DEBUG_LEVEL >= 1
    `define DEBUG_L1(x) $display("[DEBUG L1] ", x)
  `else
    `define DEBUG_L1(x)
  `endif
  
  `if DEBUG_LEVEL >= 2
    `define DEBUG_L2(x) $display("[DEBUG L2] ", x)
  `else
    `define DEBUG_L2(x)
  `endif
  
  `if DEBUG_LEVEL >= 3
    `define DEBUG_L3(x) $display("[DEBUG L3] ", x)
  `else
    `define DEBUG_L3(x)
  `endif
`else
  `define DEBUG_L1(x)
  `define DEBUG_L2(x)
  `define DEBUG_L3(x)
`endif

// Debug with timestamp
`ifdef DEBUG
  `define DEBUG_TIME(x) $display("[DEBUG @ %0t] ", $time, x)
`else
  `define DEBUG_TIME(x)
`endif

// Assertion macro (only active in debug mode)
`ifdef DEBUG
  `define DEBUG_ASSERT(condition, message) \
    if (!(condition)) begin \
      $display("[DEBUG ASSERTION FAILED] %s at time %0t", message, $time); \
      $display("    Condition: %s", `"condition`"); \
    end
`else
  `define DEBUG_ASSERT(condition, message)
`endif

`endif // DEBUG_UTILS_VH