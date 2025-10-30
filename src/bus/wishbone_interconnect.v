module wishbone_interconnect #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and Reset
    input wire                      clk,
    input wire                      rst_n,

    // Master interface (from CPU)
    input wire                      wbm_cpu_cyc,
    input wire                      wbm_cpu_stb,
    input wire                      wbm_cpu_we,
    input wire [ADDR_WIDTH-1:0]     wbm_cpu_addr,
    input wire [DATA_WIDTH-1:0]     wbm_cpu_data_write,
    input wire [3:0]                wbm_cpu_sel,
    output reg [DATA_WIDTH-1:0]     wbm_cpu_data_read,
    output reg                      wbm_cpu_ack,

    // Slave 0: IMEM
    output reg                      wbs_imem_cyc,
    output reg                      wbs_imem_stb,
    output reg                      wbs_imem_we,
    output reg [ADDR_WIDTH-1:0]     wbs_imem_addr,
    output reg [DATA_WIDTH-1:0]     wbs_imem_data_write,
    output reg [3:0]                wbs_imem_sel,
    input wire [DATA_WIDTH-1:0]     wbs_imem_data_read,
    input wire                      wbs_imem_ack,

    // Slave 1: DMEM
    output reg                      wbs_dmem_cyc,
    output reg                      wbs_dmem_stb,
    output reg                      wbs_dmem_we,
    output reg [ADDR_WIDTH-1:0]     wbs_dmem_addr,
    output reg [DATA_WIDTH-1:0]     wbs_dmem_data_write,
    output reg [3:0]                wbs_dmem_sel,
    input wire [DATA_WIDTH-1:0]     wbs_dmem_data_read,
    input wire                      wbs_dmem_ack,

    // Slave 2: UART
    output reg                      wbs_uart_cyc,
    output reg                      wbs_uart_stb,
    output reg                      wbs_uart_we,
    output reg [ADDR_WIDTH-1:0]     wbs_uart_addr,
    output reg [DATA_WIDTH-1:0]     wbs_uart_data_write,
    output reg [3:0]                wbs_uart_sel,
    input wire [DATA_WIDTH-1:0]     wbs_uart_data_read,
    input wire                      wbs_uart_ack,

    // Slave 3: TIMER
    output reg                      wbs_timer_cyc,
    output reg                      wbs_timer_stb,
    output reg                      wbs_timer_we,
    output reg [ADDR_WIDTH-1:0]     wbs_timer_addr,
    output reg [DATA_WIDTH-1:0]     wbs_timer_data_write,
    output reg [3:0]                wbs_timer_sel,
    input wire [DATA_WIDTH-1:0]     wbs_timer_data_read,
    input wire                      wbs_timer_ack,

    // Slave 4: GPIO
    output reg                      wbs_gpio_cyc,
    output reg                      wbs_gpio_stb,
    output reg                      wbs_gpio_we,
    output reg [ADDR_WIDTH-1:0]     wbs_gpio_addr,
    output reg [DATA_WIDTH-1:0]     wbs_gpio_data_write,
    output reg [3:0]                wbs_gpio_sel,
    input wire [DATA_WIDTH-1:0]     wbs_gpio_data_read,
    input wire                      wbs_gpio_ack
);

    // -------------------------------------------
    // Internal Pipeline Registers
    // -------------------------------------------
    
    // Stage 1: Input Registration
    reg                      wbm_cpu_cyc_reg;
    reg                      wbm_cpu_stb_reg;
    reg                      wbm_cpu_we_reg;
    reg [ADDR_WIDTH-1:0]     wbm_cpu_addr_reg;
    reg [DATA_WIDTH-1:0]     wbm_cpu_data_write_reg;
    reg [3:0]                wbm_cpu_sel_reg;
    
    // Stage 2: Decoded Selection
    reg [2:0]                sel_slave_reg;
    reg                      valid_request_reg;
    
    // Stage 3: Output Registration
    reg [DATA_WIDTH-1:0]     wbm_cpu_data_read_reg;
    reg                      wbm_cpu_ack_reg;

    // -------------------------------------------
    // Slave Selection Encoding
    // -------------------------------------------
    localparam [2:0] SLAVE_IMEM  = 3'd0;
    localparam [2:0] SLAVE_DMEM  = 3'd1;
    localparam [2:0] SLAVE_UART  = 3'd2;
    localparam [2:0] SLAVE_TIMER = 3'd3;
    localparam [2:0] SLAVE_GPIO  = 3'd4;
    localparam [2:0] SLAVE_NONE  = 3'd7;

    localparam [19:0] BASE_ADDR_IMEM  = 20'h00000;
    localparam [19:0] BASE_ADDR_DMEM  = 20'h10000;
    localparam [19:0] BASE_ADDR_UART  = 20'h20000;
    localparam [19:0] BASE_ADDR_TIMER = 20'h30000;
    localparam [19:0] BASE_ADDR_GPIO  = 20'h40000;
    
    // -------------------------------------------
    // Combinational Address Decode (Stage 1)
    // -------------------------------------------
    reg [2:0] sel_slave_combo;

    always @(*) begin
        sel_slave_combo = SLAVE_NONE;

        case (wbm_cpu_addr_reg[31:12])  // Use REGISTERED address
            BASE_ADDR_IMEM:   sel_slave_combo = SLAVE_IMEM; 
            BASE_ADDR_DMEM:   sel_slave_combo = SLAVE_DMEM; 
            BASE_ADDR_UART:   sel_slave_combo = SLAVE_UART; 
            BASE_ADDR_TIMER:  sel_slave_combo = SLAVE_TIMER; 
            BASE_ADDR_GPIO:   sel_slave_combo = SLAVE_GPIO; 
            default:          sel_slave_combo = SLAVE_NONE;
        endcase
    end

    // -------------------------------------------
    // Pipeline Stage 1: Input Registration
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbm_cpu_cyc_reg        <= 1'b0;
            wbm_cpu_stb_reg        <= 1'b0;
            wbm_cpu_we_reg         <= 1'b0;
            wbm_cpu_addr_reg       <= {ADDR_WIDTH{1'b0}};
            wbm_cpu_data_write_reg <= {DATA_WIDTH{1'b0}};
            wbm_cpu_sel_reg        <= 4'b0;
        end else begin
            // Register all inputs from CPU
            wbm_cpu_cyc_reg        <= wbm_cpu_cyc;
            wbm_cpu_stb_reg        <= wbm_cpu_stb;
            wbm_cpu_we_reg         <= wbm_cpu_we;
            wbm_cpu_addr_reg       <= wbm_cpu_addr;
            wbm_cpu_data_write_reg <= wbm_cpu_data_write;
            wbm_cpu_sel_reg        <= wbm_cpu_sel;
        end
    end

    // -------------------------------------------
    // Pipeline Stage 2: Slave Selection
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sel_slave_reg      <= SLAVE_NONE;
            valid_request_reg  <= 1'b0;
        end else begin
            sel_slave_reg      <= sel_slave_combo;
            valid_request_reg  <= wbm_cpu_cyc_reg && wbm_cpu_stb_reg;
        end
    end

    // -------------------------------------------
    // Pipeline Stage 3: Slave Connection & Output
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all slave outputs
            wbs_imem_cyc        <= 1'b0;
            wbs_imem_stb        <= 1'b0;
            wbs_imem_we         <= 1'b0;
            wbs_imem_addr       <= {ADDR_WIDTH{1'b0}};
            wbs_imem_data_write <= {DATA_WIDTH{1'b0}};
            wbs_imem_sel        <= 4'b0;

            wbs_dmem_cyc        <= 1'b0;
            wbs_dmem_stb        <= 1'b0;
            wbs_dmem_we         <= 1'b0;
            wbs_dmem_addr       <= {ADDR_WIDTH{1'b0}};
            wbs_dmem_data_write <= {DATA_WIDTH{1'b0}};
            wbs_dmem_sel        <= 4'b0;
            
            wbs_uart_cyc        <= 1'b0;
            wbs_uart_stb        <= 1'b0;
            wbs_uart_we         <= 1'b0;
            wbs_uart_addr       <= {ADDR_WIDTH{1'b0}};
            wbs_uart_data_write <= {DATA_WIDTH{1'b0}};
            wbs_uart_sel        <= 4'b0;
            
            wbs_timer_cyc       <= 1'b0;
            wbs_timer_stb       <= 1'b0;
            wbs_timer_we        <= 1'b0;
            wbs_timer_addr      <= {ADDR_WIDTH{1'b0}};
            wbs_timer_data_write<= {DATA_WIDTH{1'b0}};
            wbs_timer_sel       <= 4'b0;
            
            wbs_gpio_cyc        <= 1'b0;
            wbs_gpio_stb        <= 1'b0;
            wbs_gpio_we         <= 1'b0;
            wbs_gpio_addr       <= {ADDR_WIDTH{1'b0}};
            wbs_gpio_data_write <= {DATA_WIDTH{1'b0}};
            wbs_gpio_sel        <= 4'b0;
            
            wbm_cpu_data_read   <= {DATA_WIDTH{1'b0}};
            wbm_cpu_ack         <= 1'b0;
        end else begin
            // Default: deselect all slaves
            wbs_imem_cyc        <= 1'b0;
            wbs_imem_stb        <= 1'b0;
            wbs_imem_we         <= 1'b0;
            wbs_imem_addr       <= {ADDR_WIDTH{1'b0}};
            wbs_imem_data_write <= {DATA_WIDTH{1'b0}};
            wbs_imem_sel        <= 4'b0;

            wbs_dmem_cyc        <= 1'b0;
            wbs_dmem_stb        <= 1'b0;
            wbs_dmem_we         <= 1'b0;
            wbs_dmem_addr       <= {ADDR_WIDTH{1'b0}};
            wbs_dmem_data_write <= {DATA_WIDTH{1'b0}};
            wbs_dmem_sel        <= 4'b0;
            
            wbs_uart_cyc        <= 1'b0;
            wbs_uart_stb        <= 1'b0;
            wbs_uart_we         <= 1'b0;
            wbs_uart_addr       <= {ADDR_WIDTH{1'b0}};
            wbs_uart_data_write <= {DATA_WIDTH{1'b0}};
            wbs_uart_sel        <= 4'b0;
            
            wbs_timer_cyc       <= 1'b0;
            wbs_timer_stb       <= 1'b0;
            wbs_timer_we        <= 1'b0;
            wbs_timer_addr      <= {ADDR_WIDTH{1'b0}};
            wbs_timer_data_write<= {DATA_WIDTH{1'b0}};
            wbs_timer_sel       <= 4'b0;
            
            wbs_gpio_cyc        <= 1'b0;
            wbs_gpio_stb        <= 1'b0;
            wbs_gpio_we         <= 1'b0;
            wbs_gpio_addr       <= {ADDR_WIDTH{1'b0}};
            wbs_gpio_data_write <= {DATA_WIDTH{1'b0}};
            wbs_gpio_sel        <= 4'b0;
            
            // Default CPU outputs
            wbm_cpu_ack         <= 1'b0;
            wbm_cpu_data_read   <= {DATA_WIDTH{1'b0}};

            // Route to selected slave based on REGISTERED selection
            if (valid_request_reg) begin
                case (sel_slave_reg)
                    SLAVE_IMEM: begin
                        wbs_imem_cyc            <= 1'b1;
                        wbs_imem_stb            <= 1'b1;
                        wbs_imem_we             <= wbm_cpu_we_reg && 1'b0; // IMEM write protection
                        wbs_imem_addr           <= wbm_cpu_addr_reg;
                        wbs_imem_data_write     <= wbm_cpu_data_write_reg;
                        wbs_imem_sel            <= wbm_cpu_sel_reg;
                        wbm_cpu_data_read       <= wbs_imem_data_read;
                        wbm_cpu_ack             <= wbs_imem_ack;
                    end

                    SLAVE_DMEM: begin
                        wbs_dmem_cyc            <= 1'b1;
                        wbs_dmem_stb            <= 1'b1;
                        wbs_dmem_we             <= wbm_cpu_we_reg;
                        wbs_dmem_addr           <= wbm_cpu_addr_reg;
                        wbs_dmem_data_write     <= wbm_cpu_data_write_reg;
                        wbs_dmem_sel            <= wbm_cpu_sel_reg;
                        wbm_cpu_data_read       <= wbs_dmem_data_read;
                        wbm_cpu_ack             <= wbs_dmem_ack;
                    end
                    
                    SLAVE_UART: begin
                        wbs_uart_cyc            <= 1'b1;
                        wbs_uart_stb            <= 1'b1;
                        wbs_uart_we             <= wbm_cpu_we_reg;
                        wbs_uart_addr           <= wbm_cpu_addr_reg;
                        wbs_uart_data_write     <= wbm_cpu_data_write_reg;
                        wbs_uart_sel            <= wbm_cpu_sel_reg;
                        wbm_cpu_data_read       <= wbs_uart_data_read;
                        wbm_cpu_ack             <= wbs_uart_ack;
                    end
                    
                    SLAVE_TIMER: begin
                        wbs_timer_cyc           <= 1'b1;
                        wbs_timer_stb           <= 1'b1;
                        wbs_timer_we            <= wbm_cpu_we_reg;
                        wbs_timer_addr          <= wbm_cpu_addr_reg;
                        wbs_timer_data_write    <= wbm_cpu_data_write_reg;
                        wbs_timer_sel           <= wbm_cpu_sel_reg;
                        wbm_cpu_data_read       <= wbs_timer_data_read;
                        wbm_cpu_ack             <= wbs_timer_ack;
                    end
                    
                    SLAVE_GPIO: begin
                        wbs_gpio_cyc            <= 1'b1;
                        wbs_gpio_stb            <= 1'b1;
                        wbs_gpio_we             <= wbm_cpu_we_reg;
                        wbs_gpio_addr           <= wbm_cpu_addr_reg;
                        wbs_gpio_data_write     <= wbm_cpu_data_write_reg;
                        wbs_gpio_sel            <= wbm_cpu_sel_reg;
                        wbm_cpu_data_read       <= wbs_gpio_data_read;
                        wbm_cpu_ack             <= wbs_gpio_ack;
                    end
                    
                    default: begin
                        // Invalid address - acknowledge with error data
                        wbm_cpu_ack       <= 1'b1;
                        wbm_cpu_data_read <= 32'hDEAD_BEEF;  // Error pattern
                    end
                endcase
            end
        end
    end

    // -------------------------------------------
    // Debug and Monitoring
    // -------------------------------------------
    // synthesis translate_off
    reg [31:0] access_count;
    reg [31:0] error_count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            access_count <= 0;
            error_count <= 0;
        end else begin
            if (wbm_cpu_ack) begin
                access_count <= access_count + 1;
                if (sel_slave_reg == SLAVE_NONE) begin
                    error_count <= error_count + 1;
                    $display("[INTERCONNECT] Error: Invalid address %h at time %t", 
                             wbm_cpu_addr_reg, $time);
                end
            end
        end
    end
    // synthesis translate_on

endmodule


// module wishbone_interconnect #(
//     parameter ADDR_WIDTH = 32,
//     parameter DATA_WIDTH = 32
// ) (
//     // Clock and Reset
//     input wire                      clk,
//     input wire                      rst_n,

//     // Master interface (from CPU)
//     input wire                      wbm_cpu_cyc,
//     input wire                      wbm_cpu_stb,
//     input wire                      wbm_cpu_we,
//     input wire [ADDR_WIDTH-1:0]     wbm_cpu_addr,
//     input wire [DATA_WIDTH-1:0]     wbm_cpu_data_write,
//     input wire [3:0]                wbm_cpu_sel,
//     output reg [DATA_WIDTH-1:0]     wbm_cpu_data_read,
//     output reg                      wbm_cpu_ack,

//     // Slave 0: IMEM
//     output reg                      wbs_imem_cyc,
//     output reg                      wbs_imem_stb,
//     output reg                      wbs_imem_we,
//     output reg [ADDR_WIDTH-1:0]     wbs_imem_addr,
//     output reg [DATA_WIDTH-1:0]     wbs_imem_data_write,
//     output reg [3:0]                wbs_imem_sel,
//     input wire [DATA_WIDTH-1:0]     wbs_imem_data_read,
//     input wire                      wbs_imem_ack,

//     // Slave 1: DMEM
//     output reg                      wbs_dmem_cyc,
//     output reg                      wbs_dmem_stb,
//     output reg                      wbs_dmem_we,
//     output reg [ADDR_WIDTH-1:0]     wbs_dmem_addr,
//     output reg [DATA_WIDTH-1:0]     wbs_dmem_data_write,
//     output reg [3:0]                wbs_dmem_sel,
//     input wire [DATA_WIDTH-1:0]     wbs_dmem_data_read,
//     input wire                      wbs_dmem_ack,

//     // Slave 2: UART
//     output reg                      wbs_uart_cyc,
//     output reg                      wbs_uart_stb,
//     output reg                      wbs_uart_we,
//     output reg [ADDR_WIDTH-1:0]     wbs_uart_addr,
//     output reg [DATA_WIDTH-1:0]     wbs_uart_data_write,
//     output reg [3:0]                wbs_uart_sel,
//     input wire [DATA_WIDTH-1:0]     wbs_uart_data_read,
//     input wire                      wbs_uart_ack,

//     // Slave 3: TIMER
//     output reg                      wbs_timer_cyc,
//     output reg                      wbs_timer_stb,
//     output reg                      wbs_timer_we,
//     output reg [ADDR_WIDTH-1:0]     wbs_timer_addr,
//     output reg [DATA_WIDTH-1:0]     wbs_timer_data_write,
//     output reg [3:0]                wbs_timer_sel,
//     input wire [DATA_WIDTH-1:0]     wbs_timer_data_read,
//     input wire                      wbs_timer_ack,

//     // Slave 4: GPIO
//     output reg                      wbs_gpio_cyc,
//     output reg                      wbs_gpio_stb,
//     output reg                      wbs_gpio_we,
//     output reg [ADDR_WIDTH-1:0]     wbs_gpio_addr,
//     output reg [DATA_WIDTH-1:0]     wbs_gpio_data_write,
//     output reg [3:0]                wbs_gpio_sel,
//     input wire [DATA_WIDTH-1:0]     wbs_gpio_data_read,
//     input wire                      wbs_gpio_ack
// );

//     // -------------------------------------------
//     // Internal Decode Signals
//     // -------------------------------------------
    
//     localparam [2:0] SLAVE_IMEM  = 3'd0;
//     localparam [2:0] SLAVE_DMEM  = 3'd1;
//     localparam [2:0] SLAVE_UART  = 3'd2;
//     localparam [2:0] SLAVE_TIMER = 3'd3;
//     localparam [2:0] SLAVE_GPIO  = 3'd4;
//     localparam [2:0] SLAVE_NONE  = 3'd7;

//     localparam [19:0] BASE_ADDR_IMEM  = 20'h00000;
//     localparam [19:0] BASE_ADDR_DMEM  = 20'h10000;
//     localparam [19:0] BASE_ADDR_UART  = 20'h20000;
//     localparam [19:0] BASE_ADDR_TIMER = 20'h30000;
//     localparam [19:0] BASE_ADDR_GPIO  = 20'h40000;
    
//     reg [2:0] sel_slave;

//     // -------------------------------------------
//     // Address Decdode
//     // -------------------------------------------

//     always @(*) begin
//         sel_slave = 3'd7; // Invalid

//         case (wbm_cpu_addr[31:12])
//             BASE_ADDR_IMEM:   sel_slave   = SLAVE_IMEM ; 
//             BASE_ADDR_DMEM:   sel_slave   = SLAVE_DMEM ; 
//             BASE_ADDR_UART:   sel_slave   = SLAVE_UART ; 
//             BASE_ADDR_TIMER:  sel_slave   = SLAVE_TIMER; 
//             BASE_ADDR_GPIO:   sel_slave   = SLAVE_GPIO ; 
//             default:          sel_slave   = SLAVE_NONE ;
//         endcase
//     end

//     // -------------------------------------------
//     // Route signals to one slave, default to zero
//     // -------------------------------------------

//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             // Reset all outputs
//             wbs_imem_cyc        <= 1'b0;
//             wbs_imem_stb        <= 1'b0;
//             wbs_imem_we         <= 1'b0;
//             wbs_imem_addr       <= {ADDR_WIDTH{1'b0}};
//             wbs_imem_data_write <= {DATA_WIDTH{1'b0}};
//             wbs_imem_sel        <= 4'b0;

//             wbs_dmem_cyc        <= 1'b0;
//             wbs_dmem_stb        <= 1'b0;
//             wbs_dmem_we         <= 1'b0;
//             wbs_dmem_addr       <= {ADDR_WIDTH{1'b0}};
//             wbs_dmem_data_write <= {DATA_WIDTH{1'b0}};
//             wbs_dmem_sel        <= 4'b0;
            
//             wbs_uart_cyc        <= 1'b0;
//             wbs_uart_stb        <= 1'b0;
//             wbs_uart_we         <= 1'b0;
//             wbs_uart_addr       <= {ADDR_WIDTH{1'b0}};
//             wbs_uart_data_write <= {DATA_WIDTH{1'b0}};
//             wbs_uart_sel        <= 4'b0;
            
//             wbs_timer_cyc       <= 1'b0;
//             wbs_timer_stb       <= 1'b0;
//             wbs_timer_we        <= 1'b0;
//             wbs_timer_addr      <= {ADDR_WIDTH{1'b0}};
//             wbs_timer_data_write<= {DATA_WIDTH{1'b0}};
//             wbs_timer_sel       <= 4'b0;
            
//             wbs_gpio_cyc        <= 1'b0;
//             wbs_gpio_stb        <= 1'b0;
//             wbs_gpio_we         <= 1'b0;
//             wbs_gpio_addr       <= {ADDR_WIDTH{1'b0}};
//             wbs_gpio_data_write <= {DATA_WIDTH{1'b0}};
//             wbs_gpio_sel        <= 4'b0;
            
//             wbm_cpu_data_read   <= {DATA_WIDTH{1'b0}};
//             wbm_cpu_ack         <= 1'b0;
//         end else begin
//             // Default: deselect all slaves
//             wbs_imem_cyc        <= 1'b0;
//             wbs_imem_stb        <= 1'b0;
//             wbs_imem_we         <= 1'b0;
//             wbs_imem_addr       <= {ADDR_WIDTH{1'b0}};
//             wbs_imem_data_write <= {DATA_WIDTH{1'b0}};
//             wbs_imem_sel        <= 4'b0;

//             wbs_dmem_cyc        <= 1'b0;
//             wbs_dmem_stb        <= 1'b0;
//             wbs_dmem_we         <= 1'b0;
//             wbs_dmem_addr       <= {ADDR_WIDTH{1'b0}};
//             wbs_dmem_data_write <= {DATA_WIDTH{1'b0}};
//             wbs_dmem_sel        <= 4'b0;
            
//             wbs_uart_cyc        <= 1'b0;
//             wbs_uart_stb        <= 1'b0;
//             wbs_uart_we         <= 1'b0;
//             wbs_uart_addr       <= {ADDR_WIDTH{1'b0}};
//             wbs_uart_data_write <= {DATA_WIDTH{1'b0}};
//             wbs_uart_sel        <= 4'b0;
            
//             wbs_timer_cyc       <= 1'b0;
//             wbs_timer_stb       <= 1'b0;
//             wbs_timer_we        <= 1'b0;
//             wbs_timer_addr      <= {ADDR_WIDTH{1'b0}};
//             wbs_timer_data_write<= {DATA_WIDTH{1'b0}};
//             wbs_timer_sel       <= 4'b0;
            
//             wbs_gpio_cyc        <= 1'b0;
//             wbs_gpio_stb        <= 1'b0;
//             wbs_gpio_we         <= 1'b0;
//             wbs_gpio_addr       <= {ADDR_WIDTH{1'b0}};
//             wbs_gpio_data_write <= {DATA_WIDTH{1'b0}};
//             wbs_gpio_sel        <= 4'b0;
            
//             wbm_cpu_ack         <= 1'b0;
//             wbm_cpu_data_read   <= {DATA_WIDTH{1'b0}};

//             // Route to selected slave
//             case (sel_slave)
//                 SLAVE_IMEM: begin
//                     wbs_imem_cyc            <= wbm_cpu_cyc;
//                     wbs_imem_stb            <= wbm_cpu_stb;
//                     wbs_imem_we             <= wbm_cpu_we && 1'b0; // to avoid write attempt
//                     wbs_imem_addr           <= wbm_cpu_addr;
//                     wbs_imem_data_write     <= wbm_cpu_data_write;
//                     wbs_imem_sel            <= wbm_cpu_sel;
//                     wbm_cpu_data_read       <= wbs_imem_data_read;
//                     wbm_cpu_ack             <= wbs_imem_ack;
//                 end

//                 SLAVE_DMEM: begin
//                     wbs_dmem_cyc            <= wbm_cpu_cyc;
//                     wbs_dmem_stb            <= wbm_cpu_stb;
//                     wbs_dmem_we             <= wbm_cpu_we;
//                     wbs_dmem_addr           <= wbm_cpu_addr;
//                     wbs_dmem_data_write     <= wbm_cpu_data_write;
//                     wbs_dmem_sel            <= wbm_cpu_sel;
//                     wbm_cpu_data_read       <= wbs_dmem_data_read;
//                     wbm_cpu_ack             <= wbs_dmem_ack;
//                 end
                
//                 SLAVE_UART: begin
//                     wbs_uart_cyc            <= wbm_cpu_cyc;
//                     wbs_uart_stb            <= wbm_cpu_stb;
//                     wbs_uart_we             <= wbm_cpu_we;
//                     wbs_uart_addr           <= wbm_cpu_addr;
//                     wbs_uart_data_write     <= wbm_cpu_data_write;
//                     wbs_uart_sel            <= wbm_cpu_sel;
//                     wbm_cpu_data_read       <= wbs_uart_data_read;
//                     wbm_cpu_ack             <= wbs_uart_ack;
//                 end
                
//                 SLAVE_TIMER: begin
//                     wbs_timer_cyc           <= wbm_cpu_cyc;
//                     wbs_timer_stb           <= wbm_cpu_stb;
//                     wbs_timer_we            <= wbm_cpu_we;
//                     wbs_timer_addr          <= wbm_cpu_addr;
//                     wbs_timer_data_write    <= wbm_cpu_data_write;
//                     wbs_timer_sel           <= wbm_cpu_sel;
//                     wbm_cpu_data_read       <= wbs_timer_data_read;
//                     wbm_cpu_ack             <= wbs_timer_ack;
//                 end
                
//                 SLAVE_GPIO: begin
//                     wbs_gpio_cyc            <= wbm_cpu_cyc;
//                     wbs_gpio_stb            <= wbm_cpu_stb;
//                     wbs_gpio_we             <= wbm_cpu_we;
//                     wbs_gpio_addr           <= wbm_cpu_addr;
//                     wbs_gpio_data_write     <= wbm_cpu_data_write;
//                     wbs_gpio_sel            <= wbm_cpu_sel;
//                     wbm_cpu_data_read       <= wbs_gpio_data_read;
//                     wbm_cpu_ack             <= wbs_gpio_ack;
//                 end
                
//                 default: begin
//                     // Invalid address - acknowledge with error data
//                     if (wbm_cpu_cyc && wbm_cpu_stb) begin
//                         wbm_cpu_ack       <= 1'b1;
//                         wbm_cpu_data_read <= 32'hDEAD_BEEF;  // Error pattern
//                     end
//                 end
//             endcase
//         end
//     end 
// endmodule
