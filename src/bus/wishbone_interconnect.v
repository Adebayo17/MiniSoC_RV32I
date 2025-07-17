module wishbone_interconnect #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and Reset
    input wire                      clk,
    input wire                      rst_n,

    // Master interface (from CPU)
    input wire                      wb_m_cpu_cyc,
    input wire                      wb_m_cpu_stb,
    input wire                      wb_m_cpu_we,
    input wire [ADDR_WIDTH-1:0]     wb_m_cpu_addr,
    input wire [DATA_WIDTH-1:0]     wb_m_cpu_data_write,
    input wire [3:0]                wb_m_cpu_sel,
    output reg [DATA_WIDTH-1:0]     wb_m_cpu_data_read,
    output reg                      wb_m_cpu_ack,

    // Slave 0: IMEM
    output reg                      wb_s0_imem_cyc,
    output reg                      wb_s0_imem_stb,
    output reg                      wb_s0_imem_we,
    output reg [ADDR_WIDTH-1:0]     wb_s0_imem_addr,
    output reg [DATA_WIDTH-1:0]     wb_s0_imem_data_write,
    output reg [3:0]                wb_s0_imem_sel,
    input wire [DATA_WIDTH-1:0]     wb_s0_imem_data_read,
    input wire                      wb_s0_imem_ack,

    // Slave 1: DMEM
    output reg                      wb_s1_dmem_cyc,
    output reg                      wb_s1_dmem_stb,
    output reg                      wb_s1_dmem_we,
    output reg [ADDR_WIDTH-1:0]     wb_s1_dmem_addr,
    output reg [DATA_WIDTH-1:0]     wb_s1_dmem_data_write,
    output reg [3:0]                wb_s1_dmem_sel,
    input wire [DATA_WIDTH-1:0]     wb_s1_dmem_data_read,
    input wire                      wb_s1_dmem_ack,

    // Slave 2: UART
    output reg                      wb_s2_uart_cyc,
    output reg                      wb_s2_uart_stb,
    output reg                      wb_s2_uart_we,
    output reg [ADDR_WIDTH-1:0]     wb_s2_uart_addr,
    output reg [DATA_WIDTH-1:0]     wb_s2_uart_data_write,
    output reg [3:0]                wb_s2_uart_sel,
    input wire [DATA_WIDTH-1:0]     wb_s2_uart_data_read,
    input wire                      wb_s2_uart_ack,

    // Slave 3: TIMER
    output reg                      wb_s3_timer_cyc,
    output reg                      wb_s3_timer_stb,
    output reg                      wb_s3_timer_we,
    output reg [ADDR_WIDTH-1:0]     wb_s3_timer_addr,
    output reg [DATA_WIDTH-1:0]     wb_s3_timer_data_write,
    output reg [3:0]                wb_s3_timer_sel,
    input wire [DATA_WIDTH-1:0]     wb_s3_timer_data_read,
    input wire                      wb_s3_timer_ack,

    // Slave 4: GPIO
    output reg                      wb_s4_gpio_cyc,
    output reg                      wb_s4_gpio_stb,
    output reg                      wb_s4_gpio_we,
    output reg [ADDR_WIDTH-1:0]     wb_s4_gpio_addr,
    output reg [DATA_WIDTH-1:0]     wb_s4_gpio_data_write,
    output reg [3:0]                wb_s4_gpio_sel,
    input wire [DATA_WIDTH-1:0]     wb_s4_gpio_data_read,
    input wire                      wb_s4_gpio_ack
);

    // -------------------------------------------
    // Internal Decode Signals
    // -------------------------------------------
    
    localparam [2:0] SLAVE_IMEM  = 3'd0;
    localparam [2:0] SLAVE_DMEM  = 3'd1;
    localparam [2:0] SLAVE_UART  = 3'd2;
    localparam [2:0] SLAVE_TIMER = 3'd3;
    localparam [2:0] SLAVE_GPIO  = 3'd4;
    localparam [2:0] SLAVE_NONE  = 3'd7;
    
    reg [2:0] sel_slave;

    // -------------------------------------------
    // Address Decdode
    // -------------------------------------------

    always @(*) begin
        sel_slave = 3'd7; // Invalid

        case (wb_m_cpu_addr[31:12])
            20'h00000:  sel_slave   = SLAVE_IMEM ; 
            20'h10000:  sel_slave   = SLAVE_DMEM ; 
            20'h20000:  sel_slave   = SLAVE_UART ; 
            20'h30000:  sel_slave   = SLAVE_TIMER; 
            20'h40000:  sel_slave   = SLAVE_GPIO ; 
            default:    sel_slave   = SLAVE_NONE ;
        endcase
    end

    // -------------------------------------------
    // Route signals to one slave, default to zero
    // -------------------------------------------

    always @(*) begin
        // Default: deselect all
        {wb_s0_imem_cyc, wb_s1_dmem_cyc, wb_s2_uart_cyc, wb_s3_timer_cyc, wb_s4_gpio_cyc} = 0;
        {wb_s0_imem_stb, wb_s1_dmem_stb, wb_s2_uart_stb, wb_s3_timer_stb, wb_s4_gpio_stb} = 0;
        {wb_s0_imem_we,  wb_s1_dmem_we,  wb_s2_uart_we,  wb_s3_timer_we,  wb_s4_gpio_we } = 0;

        wb_m_cpu_data_read       = 32'hDEADDEAD;
        wb_m_cpu_ack             = 0;

        case (sel_slave)
            SLAVE_IMEM: begin
                wb_s0_imem_cyc           = wb_m_cpu_cyc;
                wb_s0_imem_stb           = wb_m_cpu_stb;
                wb_s0_imem_we            = wb_m_cpu_we;
                wb_s0_imem_addr          = wb_m_cpu_addr;
                wb_s0_imem_data_write    = wb_m_cpu_data_write;
                wb_s0_imem_sel           = wb_m_cpu_sel;
                wb_m_cpu_data_read       = wb_s0_imem_data_read;
                wb_m_cpu_ack             = wb_s0_imem_ack;
            end
            SLAVE_DMEM: begin
                wb_s1_dmem_cyc           = wb_m_cpu_cyc;
                wb_s1_dmem_stb           = wb_m_cpu_stb;
                wb_s1_dmem_we            = wb_m_cpu_we;
                wb_s1_dmem_addr          = wb_m_cpu_addr;
                wb_s1_dmem_data_write    = wb_m_cpu_data_write;
                wb_s1_dmem_sel           = wb_m_cpu_sel;
                wb_m_cpu_data_read       = wb_s1_dmem_data_read;
                wb_m_cpu_ack             = wb_s1_dmem_ack;
            end
            SLAVE_UART: begin
                wb_s2_uart_cyc           = wb_m_cpu_cyc;
                wb_s2_uart_stb           = wb_m_cpu_stb;
                wb_s2_uart_we            = wb_m_cpu_we;
                wb_s2_uart_addr          = wb_m_cpu_addr;
                wb_s2_uart_data_write    = wb_m_cpu_data_write;
                wb_s2_uart_sel           = wb_m_cpu_sel;
                wb_m_cpu_data_read       = wb_s2_uart_data_read;
                wb_m_cpu_ack             = wb_s2_uart_ack;
            end
            SLAVE_TIMER: begin
                wb_s3_timer_cyc          = wb_m_cpu_cyc;
                wb_s3_timer_stb          = wb_m_cpu_stb;
                wb_s3_timer_we           = wb_m_cpu_we;
                wb_s3_timer_addr         = wb_m_cpu_addr;
                wb_s3_timer_data_write   = wb_m_cpu_data_write;
                wb_s3_timer_sel          = wb_m_cpu_sel;
                wb_m_cpu_data_read       = wb_s3_timer_data_read;
                wb_m_cpu_ack             = wb_s3_timer_ack;
            end
            SLAVE_GPIO: begin
                wb_s4_gpio_cyc           = wb_m_cpu_cyc;
                wb_s4_gpio_stb           = wb_m_cpu_stb;
                wb_s4_gpio_we            = wb_m_cpu_we;
                wb_s4_gpio_addr          = wb_m_cpu_addr;
                wb_s4_gpio_data_write    = wb_m_cpu_data_write;
                wb_s4_gpio_sel           = wb_m_cpu_sel;
                wb_m_cpu_data_read       = wb_s4_gpio_data_read;
                wb_m_cpu_ack             = wb_s4_gpio_ack;
            end
            default: begin
                // No slave selected
                if (wb_m_cpu_cyc && wb_m_cpu_stb) begin
                    wb_m_cpu_ack = 1;   // Acknowledge but return error data
                end
            end 
        endcase
    end    
endmodule





