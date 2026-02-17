module wishbone_interconnect #(
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 32,
    parameter IMEM_SIZE_KB      = 8,    // 8KB
    parameter DMEM_SIZE_KB      = 4,    // 4KB
    parameter PERIPH_SIZE_KB    = 4     // 4KB for each peripheral
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
    // Memory Map Constants (based on your top_soc.v)
    // -------------------------------------------
    localparam [31:0] IMEM_BASE_ADDR  = 32'h0000_0000;
    localparam [31:0] DMEM_BASE_ADDR  = 32'h1000_0000;
    localparam [31:0] UART_BASE_ADDR  = 32'h2000_0000;
    localparam [31:0] TIMER_BASE_ADDR = 32'h3000_0000;
    localparam [31:0] GPIO_BASE_ADDR  = 32'h4000_0000;

    localparam [31:0] IMEM_SIZE_BYTES   = IMEM_SIZE_KB * 1024;
    localparam [31:0] DMEM_SIZE_BYTES   = DMEM_SIZE_KB * 1024;
    localparam [31:0] PERIPH_SIZE_BYTES = PERIPH_SIZE_KB * 1024;
    
    localparam [31:0] IMEM_END_ADDR     = IMEM_BASE_ADDR  + IMEM_SIZE_BYTES - 1;
    localparam [31:0] DMEM_END_ADDR     = DMEM_BASE_ADDR  + DMEM_SIZE_BYTES - 1;
    localparam [31:0] UART_END_ADDR     = UART_BASE_ADDR  + PERIPH_SIZE_BYTES - 1;
    localparam [31:0] TIMER_END_ADDR    = TIMER_BASE_ADDR + PERIPH_SIZE_BYTES - 1;
    localparam [31:0] GPIO_END_ADDR     = GPIO_BASE_ADDR  + PERIPH_SIZE_BYTES - 1;

    // -------------------------------------------
    // Slave Selection Encoding
    // -------------------------------------------
    localparam [2:0] SLAVE_IMEM  = 3'd0;
    localparam [2:0] SLAVE_DMEM  = 3'd1;
    localparam [2:0] SLAVE_UART  = 3'd2;
    localparam [2:0] SLAVE_TIMER = 3'd3;
    localparam [2:0] SLAVE_GPIO  = 3'd4;
    localparam [2:0] SLAVE_NONE  = 3'd7;

    // -------------------------------------------
    // Pipeline Registers (1-cycle latency)
    // -------------------------------------------
    reg [2:0]               sel_slave_reg;
    reg                     address_valid_reg;
    reg                     request_active_reg;
    
    reg                     wbm_cpu_cyc_reg;
    reg                     wbm_cpu_stb_reg;
    reg                     wbm_cpu_we_reg;
    reg [ADDR_WIDTH-1:0]    wbm_cpu_addr_reg;
    reg [DATA_WIDTH-1:0]    wbm_cpu_data_write_reg;
    reg [3:0]               wbm_cpu_sel_reg;

    // -------------------------------------------
    // Stage 1: Combinational Address Decode
    // -------------------------------------------
    reg [2:0] sel_slave_combo;
    reg       address_valid_combo;

    always @(*) begin
        // defaults
        sel_slave_combo = SLAVE_NONE;
        address_valid_combo = 1'b0;

        // Decode address combinationally
        if (wbm_cpu_addr >= IMEM_BASE_ADDR && wbm_cpu_addr <= IMEM_END_ADDR) begin
            sel_slave_combo   = SLAVE_IMEM;
            address_valid_combo = 1'b1;
        end 
        else if (wbm_cpu_addr >= DMEM_BASE_ADDR && wbm_cpu_addr <= DMEM_END_ADDR) begin
            sel_slave_combo   = SLAVE_DMEM;
            address_valid_combo = 1'b1;
        end 
        else if (wbm_cpu_addr >= UART_BASE_ADDR && wbm_cpu_addr <= UART_END_ADDR) begin
            sel_slave_combo   = SLAVE_UART;
            address_valid_combo = 1'b1;
        end 
        else if (wbm_cpu_addr >= TIMER_BASE_ADDR && wbm_cpu_addr <= TIMER_END_ADDR) begin
            sel_slave_combo   = SLAVE_TIMER;
            address_valid_combo = 1'b1;
        end 
        else if (wbm_cpu_addr >= GPIO_BASE_ADDR && wbm_cpu_addr <= GPIO_END_ADDR) begin
            sel_slave_combo   = SLAVE_GPIO;
            address_valid_combo = 1'b1;
        end 
        else begin
            sel_slave_combo = SLAVE_NONE;
            address_valid_combo = 1'b0;
        end
    end

    // -------------------------------------------
    // Pipeline Stage 1: Register Inputs and Decode
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sel_slave_reg      <= SLAVE_NONE;
            address_valid_reg  <= 1'b0;
            request_active_reg <= 1'b0;
            
            wbm_cpu_cyc_reg        <= 1'b0;
            wbm_cpu_stb_reg        <= 1'b0;
            wbm_cpu_we_reg         <= 1'b0;
            wbm_cpu_addr_reg       <= {ADDR_WIDTH{1'b0}};
            wbm_cpu_data_write_reg <= {DATA_WIDTH{1'b0}};
            wbm_cpu_sel_reg        <= 4'b0;
        end else begin
            sel_slave_reg      <= sel_slave_combo;
            address_valid_reg  <= address_valid_combo;
            request_active_reg <= wbm_cpu_cyc && wbm_cpu_stb;
            
            // Register master inputs
            wbm_cpu_cyc_reg        <= wbm_cpu_cyc;
            wbm_cpu_stb_reg        <= wbm_cpu_stb;
            wbm_cpu_we_reg         <= wbm_cpu_we;
            wbm_cpu_addr_reg       <= wbm_cpu_addr;
            wbm_cpu_data_write_reg <= wbm_cpu_data_write;
            wbm_cpu_sel_reg        <= wbm_cpu_sel;
        end
    end

    // -------------------------------------------
    // Stage 2: Drive Selected Slave (combinational from registered values)
    // -------------------------------------------
    always @(*) begin
        // Default slave outputs
        wbs_imem_cyc        = 1'b0;
        wbs_imem_stb        = 1'b0;
        wbs_imem_we         = 1'b0;
        wbs_imem_addr       = {ADDR_WIDTH{1'b0}};
        wbs_imem_data_write = {DATA_WIDTH{1'b0}};
        wbs_imem_sel        = 4'b0;

        wbs_dmem_cyc        = 1'b0;
        wbs_dmem_stb        = 1'b0;
        wbs_dmem_we         = 1'b0;
        wbs_dmem_addr       = {ADDR_WIDTH{1'b0}};
        wbs_dmem_data_write = {DATA_WIDTH{1'b0}};
        wbs_dmem_sel        = 4'b0;

        wbs_uart_cyc        = 1'b0;
        wbs_uart_stb        = 1'b0;
        wbs_uart_we         = 1'b0;
        wbs_uart_addr       = {ADDR_WIDTH{1'b0}};
        wbs_uart_data_write = {DATA_WIDTH{1'b0}};
        wbs_uart_sel        = 4'b0;

        wbs_timer_cyc       = 1'b0;
        wbs_timer_stb       = 1'b0;
        wbs_timer_we        = 1'b0;
        wbs_timer_addr      = {ADDR_WIDTH{1'b0}};
        wbs_timer_data_write= {DATA_WIDTH{1'b0}};
        wbs_timer_sel       = 4'b0;

        wbs_gpio_cyc        = 1'b0;
        wbs_gpio_stb        = 1'b0;
        wbs_gpio_we         = 1'b0;
        wbs_gpio_addr       = {ADDR_WIDTH{1'b0}};
        wbs_gpio_data_write = {DATA_WIDTH{1'b0}};
        wbs_gpio_sel        = 4'b0;

        // If request is active and address is valid, drive the selected slave
        if (request_active_reg && address_valid_reg) begin
            case (sel_slave_reg)
                SLAVE_IMEM: begin
                    wbs_imem_cyc        = 1'b1;
                    wbs_imem_stb        = 1'b1;
                    wbs_imem_we         = 1'b0; // IMEM is read-only
                    wbs_imem_addr       = wbm_cpu_addr_reg;
                    wbs_imem_data_write = wbm_cpu_data_write_reg;
                    wbs_imem_sel        = wbm_cpu_sel_reg;
                end
                SLAVE_DMEM: begin
                    wbs_dmem_cyc        = 1'b1;
                    wbs_dmem_stb        = 1'b1;
                    wbs_dmem_we         = wbm_cpu_we_reg;
                    wbs_dmem_addr       = wbm_cpu_addr_reg;
                    wbs_dmem_data_write = wbm_cpu_data_write_reg;
                    wbs_dmem_sel        = wbm_cpu_sel_reg;
                end
                SLAVE_UART: begin
                    wbs_uart_cyc        = 1'b1;
                    wbs_uart_stb        = 1'b1;
                    wbs_uart_we         = wbm_cpu_we_reg;
                    wbs_uart_addr       = wbm_cpu_addr_reg;
                    wbs_uart_data_write = wbm_cpu_data_write_reg;
                    wbs_uart_sel        = wbm_cpu_sel_reg;
                end
                SLAVE_TIMER: begin
                    wbs_timer_cyc       = 1'b1;
                    wbs_timer_stb       = 1'b1;
                    wbs_timer_we        = wbm_cpu_we_reg;
                    wbs_timer_addr      = wbm_cpu_addr_reg;
                    wbs_timer_data_write= wbm_cpu_data_write_reg;
                    wbs_timer_sel       = wbm_cpu_sel_reg;
                end
                SLAVE_GPIO: begin
                    wbs_gpio_cyc        = 1'b1;
                    wbs_gpio_stb        = 1'b1;
                    wbs_gpio_we         = wbm_cpu_we_reg;
                    wbs_gpio_addr       = wbm_cpu_addr_reg;
                    wbs_gpio_data_write = wbm_cpu_data_write_reg;
                    wbs_gpio_sel        = wbm_cpu_sel_reg;
                end
                default: begin
                    // No slave driven
                end
            endcase
        end
    end


    // -------------------------------------------
    // Stage 3: Mux Back Response (COMBINATIONAL)
    // -------------------------------------------
    always @(*) begin
        // Default
        wbm_cpu_ack       = 1'b0;
        wbm_cpu_data_read = {DATA_WIDTH{1'b0}};
        
        // Only route the response if the slave is currently selected
        if (request_active_reg) begin
            if (address_valid_reg) begin
                case (sel_slave_reg)
                    SLAVE_IMEM: begin
                        wbm_cpu_ack       = wbs_imem_ack;
                        wbm_cpu_data_read = wbs_imem_data_read;
                    end
                    SLAVE_DMEM: begin
                        wbm_cpu_ack       = wbs_dmem_ack;
                        wbm_cpu_data_read = wbs_dmem_data_read;
                    end
                    SLAVE_UART: begin
                        wbm_cpu_ack       = wbs_uart_ack;
                        wbm_cpu_data_read = wbs_uart_data_read;
                    end
                    SLAVE_TIMER: begin
                        wbm_cpu_ack       = wbs_timer_ack;
                        wbm_cpu_data_read = wbs_timer_data_read;
                    end
                    SLAVE_GPIO: begin
                        wbm_cpu_ack       = wbs_gpio_ack;
                        wbm_cpu_data_read = wbs_gpio_data_read;
                    end
                    default: begin
                        wbm_cpu_ack       = 1'b1;
                        wbm_cpu_data_read = 32'hBADADD01;
                    end
                endcase
            end else begin
                // Invalid address - respond immediately to clear the bus
                wbm_cpu_ack       = 1'b1;
                wbm_cpu_data_read = 32'hDEAD_BEEF;
            end
        end
    end

    // -------------------------------------------
    // Stage 3: Mux Back Response (registered)
    // -------------------------------------------
    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         wbm_cpu_ack       <= 1'b0;
    //         wbm_cpu_data_read <= {DATA_WIDTH{1'b0}};
    //     end else begin
    //         // Default
    //         wbm_cpu_ack       <= 1'b0;
    //         wbm_cpu_data_read <= {DATA_WIDTH{1'b0}};
            
    //         // Check if we had an active request in the previous cycle
    //         if (request_active_reg) begin
    //             if (address_valid_reg) begin
    //                 // Valid address - wait for slave ACK
    //                 case (sel_slave_reg)
    //                     SLAVE_IMEM: begin
    //                         wbm_cpu_ack       <= wbs_imem_ack;
    //                         wbm_cpu_data_read <= wbs_imem_data_read;
    //                     end
    //                     SLAVE_DMEM: begin
    //                         wbm_cpu_ack       <= wbs_dmem_ack;
    //                         wbm_cpu_data_read <= wbs_dmem_data_read;
    //                     end
    //                     SLAVE_UART: begin
    //                         wbm_cpu_ack       <= wbs_uart_ack;
    //                         wbm_cpu_data_read <= wbs_uart_data_read;
    //                     end
    //                     SLAVE_TIMER: begin
    //                         wbm_cpu_ack       <= wbs_timer_ack;
    //                         wbm_cpu_data_read <= wbs_timer_data_read;
    //                     end
    //                     SLAVE_GPIO: begin
    //                         wbm_cpu_ack       <= wbs_gpio_ack;
    //                         wbm_cpu_data_read <= wbs_gpio_data_read;
    //                     end
    //                     default: begin
    //                         // Should not happen if address_valid_reg is true
    //                         wbm_cpu_ack       <= 1'b1;
    //                         wbm_cpu_data_read <= 32'hBADADD01;
    //                     end
    //                 endcase
    //             end else begin
    //                 // Invalid address - respond immediately in next cycle
    //                 wbm_cpu_ack       <= 1'b1;
    //                 wbm_cpu_data_read <= 32'hDEAD_BEEF;
    //             end
    //         end
    //     end
    // end

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
        end else if (wbm_cpu_ack) begin
            access_count <= access_count + 1;
            if (!address_valid_reg) begin
                error_count <= error_count + 1;
                $display("[INTERCONNECT] Error: Invalid address %h at time %t", 
                         wbm_cpu_addr_reg, $time);
            end
        end
    end
    
    // Monitor for combinatorial loops
    reg wbm_cpu_stb_prev;
    reg wbm_cpu_ack_prev;
    integer loop_counter;
    
    initial begin
        wbm_cpu_stb_prev = 1'b0;
        wbm_cpu_ack_prev = 1'b0;
        loop_counter = 0;
    end
    
    always @(posedge clk) begin
        // Check for immediate ACK (possible combinatorial loop)
        if (wbm_cpu_stb && wbm_cpu_ack) begin
            loop_counter <= loop_counter + 1;
            if (loop_counter > 10) begin
                $display("[INTERCONNECT] WARNING: Possible combinatorial loop detected!");
                $display("  STB and ACK are asserted simultaneously %d times", loop_counter);
            end
        end else begin
            loop_counter <= 0;
        end
        wbm_cpu_stb_prev <= wbm_cpu_stb;
        wbm_cpu_ack_prev <= wbm_cpu_ack;
    end
    // synthesis translate_on

endmodule