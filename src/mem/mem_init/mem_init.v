module mem_init #(
    parameter IMEM_BASE = 32'h0000_0000,
    parameter DMEM_BASE = 32'h1000_0000,
    parameter INIT_FILE = "firmware.hex",
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and reset
    input wire                      clk,
    input wire                      rst_n,

    // Initialization Control
    input wire                      init_start,
    output reg                      init_done,

    // IMEM Initialization Port
    output reg                      imem_init_en,
    output reg [ADDR_WIDTH-1:0]     imem_init_addr,
    output reg [DATA_WIDTH-1:0]     imem_init_data,

    // DMEM Initialization Port
    output reg                      dmem_init_en,
    output reg [ADDR_WIDTH-1:0]     dmem_init_addr,
    output reg [DATA_WIDTH-1:0]     dmem_init_data
);
    // -------------------------------------------
    // Memory for firmware data
    // -------------------------------------------
    reg [DATA_WIDTH-1:0] firmware_mem [0:1023];  


    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, firmware_mem);
            $display("[MEM_INIT] Loaded firmware from %s", INIT_FILE);
        end else begin
            $display("[MEM_INIT] No firmware file specified");
        end
    end

    // -------------------------------------------
    // Initialization FSM
    // -------------------------------------------
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] LOAD_IMEM  = 2'd1;
    localparam [1:0] LOAD_DMEM  = 2'd2;
    localparam [1:0] DONE       = 2'd3;

    reg [1:0] state;
    reg [ADDR_WIDTH-1:0] init_counter; 
    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            init_done       <= 0;
            imem_init_en    <= 0;
            imem_init_addr  <= 0;
            imem_init_data  <= 0;
            dmem_init_en    <= 0;
            dmem_init_addr  <= 0;
            dmem_init_data  <= 0;
            init_counter    <= 0;
        end else begin
            // Default values
            imem_init_en <= 0;
            dmem_init_en <= 0;

            case (state)
                IDLE: begin
                    if (init_start) begin
                        init_counter    <= 0;
                        state           <= LOAD_IMEM;
                        init_done       <= 0;
                    end
                end

                LOAD_IMEM: begin
                    imem_init_en    <= 1;
                    imem_init_addr  <= IMEM_BASE + (init_counter << 2);
                    imem_init_data  <= firmware_mem[init_counter];
                    
                    if (init_counter == 1023) begin
                        state           <= LOAD_DMEM;
                        init_counter    <= 0;
                    end else begin
                        init_counter    <= init_counter + 1;
                    end
                end

                LOAD_DMEM: begin
                    dmem_init_en    <= 1;
                    dmem_init_addr  <= DMEM_BASE + (init_counter << 2);
                    dmem_init_data  <= 32'h0;
                    
                    if (init_counter == 1023) begin
                        state           <= DONE;
                    end else begin
                        init_counter    <= init_counter + 1;
                    end
                end

                DONE: begin
                    init_done   <= 1;
                    state       <= IDLE;
                end
            endcase
        end
    end
endmodule