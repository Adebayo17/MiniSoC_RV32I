module io_pad (
    // Digital core interface
    input wire          pad_in,     // From core to pad
    output wire         pad_out,    // From pad to core  
    input wire          pad_oe,     // Output enable (1=output, 0=input)
    
    // Physical pad interface
    inout wire          pad_io      // Bi-directional physical pin
);

    // --------------------------------------------------
    // Output Driver
    // --------------------------------------------------
    assign pad_io = pad_oe ? pad_in : 1'bz;

    // --------------------------------------------------
    // Input Receiver
    // --------------------------------------------------
    assign pad_out = pad_io;


endmodule