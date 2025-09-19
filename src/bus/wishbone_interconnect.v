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
    // Internal Decode Signals
    // -------------------------------------------
    
    localparam [2:0] SLAVE_DMEM  = 3'd1;
    localparam [2:0] SLAVE_UART  = 3'd2;
    localparam [2:0] SLAVE_TIMER = 3'd3;
    localparam [2:0] SLAVE_GPIO  = 3'd4;
    localparam [2:0] SLAVE_NONE  = 3'd7;

    localparam [19:0] BASE_ADDR_DMEM  = 20'h10000;
    localparam [19:0] BASE_ADDR_UART  = 20'h20000;
    localparam [19:0] BASE_ADDR_TIMER = 20'h30000;
    localparam [19:0] BASE_ADDR_GPIO  = 20'h40000;
    
    reg [2:0] sel_slave;

    // -------------------------------------------
    // Address Decdode
    // -------------------------------------------

    always @(*) begin
        sel_slave = 3'd7; // Invalid

        case (wbm_cpu_addr[31:12])
            BASE_ADDR_DMEM:   sel_slave   = SLAVE_DMEM ; 
            BASE_ADDR_UART:   sel_slave   = SLAVE_UART ; 
            BASE_ADDR_TIMER:  sel_slave   = SLAVE_TIMER; 
            BASE_ADDR_GPIO:   sel_slave   = SLAVE_GPIO ; 
            default:          sel_slave   = SLAVE_NONE ;
        endcase
    end

    // -------------------------------------------
    // Route signals to one slave, default to zero
    // -------------------------------------------

    always @(*) begin
        // Default: deselect all
        {wbs_dmem_cyc, wbs_uart_cyc, wbs_timer_cyc, wbs_gpio_cyc} = 0;
        {wbs_dmem_stb, wbs_uart_stb, wbs_timer_stb, wbs_gpio_stb} = 0;
        {wbs_dmem_we,  wbs_uart_we,  wbs_timer_we,  wbs_gpio_we } = 0;

        wbm_cpu_data_read       = 32'hDEADDEAD;
        wbm_cpu_ack             = 0;

        case (sel_slave)
            SLAVE_DMEM: begin
                wbs_dmem_cyc           = wbm_cpu_cyc;
                wbs_dmem_stb           = wbm_cpu_stb;
                wbs_dmem_we            = wbm_cpu_we;
                wbs_dmem_addr          = wbm_cpu_addr;
                wbs_dmem_data_write    = wbm_cpu_data_write;
                wbs_dmem_sel           = wbm_cpu_sel;
                wbm_cpu_data_read      = wbs_dmem_data_read;
                wbm_cpu_ack            = wbs_dmem_ack;
            end
            SLAVE_UART: begin
                wbs_uart_cyc           = wbm_cpu_cyc;
                wbs_uart_stb           = wbm_cpu_stb;
                wbs_uart_we            = wbm_cpu_we;
                wbs_uart_addr          = wbm_cpu_addr;
                wbs_uart_data_write    = wbm_cpu_data_write;
                wbs_uart_sel           = wbm_cpu_sel;
                wbm_cpu_data_read      = wbs_uart_data_read;
                wbm_cpu_ack            = wbs_uart_ack;
            end
            SLAVE_TIMER: begin
                wbs_timer_cyc          = wbm_cpu_cyc;
                wbs_timer_stb          = wbm_cpu_stb;
                wbs_timer_we           = wbm_cpu_we;
                wbs_timer_addr         = wbm_cpu_addr;
                wbs_timer_data_write   = wbm_cpu_data_write;
                wbs_timer_sel          = wbm_cpu_sel;
                wbm_cpu_data_read      = wbs_timer_data_read;
                wbm_cpu_ack            = wbs_timer_ack;
            end
            SLAVE_GPIO: begin
                wbs_gpio_cyc           = wbm_cpu_cyc;
                wbs_gpio_stb           = wbm_cpu_stb;
                wbs_gpio_we            = wbm_cpu_we;
                wbs_gpio_addr          = wbm_cpu_addr;
                wbs_gpio_data_write    = wbm_cpu_data_write;
                wbs_gpio_sel           = wbm_cpu_sel;
                wbm_cpu_data_read      = wbs_gpio_data_read;
                wbm_cpu_ack            = wbs_gpio_ack;
            end
            default: begin
                // No slave selected
                if (wbm_cpu_cyc && wbm_cpu_stb) begin
                    wbm_cpu_ack = 1;   // Acknowledge but return error data
                end
            end 
        endcase
    end    
endmodule
