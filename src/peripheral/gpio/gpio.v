module gpio #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter N_GPIO       = 8
) (
    // Clock and reset
    input  wire                      clk,
    input  wire                      rst_n,
    
    // Wishbone Slave Interface
    input  wire                      wbs_cyc,
    input  wire                      wbs_stb,
    input  wire                      wbs_we,
    input  wire [ADDR_WIDTH-1:0]     wbs_addr,
    input  wire [DATA_WIDTH-1:0]     wbs_data_write,
    input  wire [3:0]                wbs_sel,
    output reg  [DATA_WIDTH-1:0]     wbs_data_read,
    output reg                       wbs_ack,

    // GPIO Physical Interface
    input  wire [N_GPIO-1:0]         gpio_in,    // GPIO input pins
    output reg  [N_GPIO-1:0]         gpio_out,   // GPIO output pins
    output reg  [N_GPIO-1:0]         gpio_oe     // GPIO output enable (1=output, 0=input)
);

    // -------------------------------------------
    // Parameter Definitions (register offsets)
    // -------------------------------------------
    localparam [11:0] REG_GPIO_DATA    = 12'h000;  // Data register
    localparam [11:0] REG_GPIO_DIR     = 12'h004;  // Direction register
    localparam [11:0] REG_GPIO_SET     = 12'h008;  // Set bits
    localparam [11:0] REG_GPIO_CLEAR   = 12'h00C;  // Clear bits
    localparam [11:0] REG_GPIO_TOGGLE  = 12'h010;  // Toggle bits

    // -------------------------------------------
    // Internal Registers
    // -------------------------------------------
    reg [N_GPIO-1:0] out_reg;   // stores values written for outputs
    reg [N_GPIO-1:0] dir_reg;   // direction register (1=output, 0=input)

    // reg [1:0]               ack_state;
    // reg                     ack_pending;
    // reg [ADDR_WIDTH-1:0]    pending_addr;
    // reg                     pending_we;
    // reg [3:0]               pending_sel;
    // reg [DATA_WIDTH-1:0]    pending_data;

    // // ACK State Machine
    // localparam ACK_IDLE    = 2'b00;
    // localparam ACK_DELAY   = 2'b01;
    // localparam ACK_ASSERT  = 2'b10;

    // -------------------------------------------
    // Input Synchronizers (to avoid metastability)
    // -------------------------------------------
    wire [N_GPIO-1:0] gpio_in_sync;
    genvar i;
    generate
        for (i = 0; i < N_GPIO; i = i + 1) begin : gpio_sync
            reg [1:0] sync_reg;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    sync_reg <= 2'b00;
                else
                    sync_reg <= {sync_reg[0], gpio_in[i]};
            end
            assign gpio_in_sync[i] = sync_reg[1];
        end
    endgenerate

    // -------------------------------------------
    // Derived Data Register
    // -------------------------------------------
    // If dir=1 → show output register value
    // If dir=0 → show synchronized input
    wire [N_GPIO-1:0] data_reg;
    assign data_reg = (dir_reg & out_reg) | (~dir_reg & gpio_in_sync);

    // -------------------------------------------
    // Address Decode
    // -------------------------------------------
    wire [11:0] reg_offset = wbs_addr[11:0];
    wire sel_data    = (reg_offset == REG_GPIO_DATA);
    wire sel_dir     = (reg_offset == REG_GPIO_DIR);
    wire sel_set     = (reg_offset == REG_GPIO_SET);
    wire sel_clear   = (reg_offset == REG_GPIO_CLEAR);
    wire sel_toggle  = (reg_offset == REG_GPIO_TOGGLE);


    // -------------------------------------------
    // Wishbone Read
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wbs_data_read <= {DATA_WIDTH{1'b0}};
        end else begin
            if (wbs_cyc && wbs_stb && !wbs_we) begin
                case (reg_offset)
                    REG_GPIO_DATA:   wbs_data_read <= {{(DATA_WIDTH-N_GPIO){1'b0}}, data_reg};
                    REG_GPIO_DIR:    wbs_data_read <= {{(DATA_WIDTH-N_GPIO){1'b0}}, dir_reg};
                    REG_GPIO_SET:    wbs_data_read <= {DATA_WIDTH{1'b0}}; // write-only
                    REG_GPIO_CLEAR:  wbs_data_read <= {DATA_WIDTH{1'b0}}; // write-only
                    REG_GPIO_TOGGLE: wbs_data_read <= {DATA_WIDTH{1'b0}}; // write-only
                    default:         wbs_data_read <= {DATA_WIDTH{1'b0}};
                endcase
            end else begin
                wbs_data_read <= {DATA_WIDTH{1'b0}};
            end
        end
    end

    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         wbs_data_read <= {DATA_WIDTH{1'b0}};
    //     end else begin
    //         // Only update read data when we're about to ACK
    //         if (ack_state == ACK_DELAY && !pending_we) begin
    //             case (pending_addr[11:0])
    //                 REG_GPIO_DATA:   wbs_data_read <= {{(DATA_WIDTH-N_GPIO){1'b0}}, data_reg};
    //                 REG_GPIO_DIR:    wbs_data_read <= {{(DATA_WIDTH-N_GPIO){1'b0}}, dir_reg};
    //                 default:         wbs_data_read <= {DATA_WIDTH{1'b0}};
    //             endcase
    //         end
    //     end
    // end

    // -------------------------------------------
    // Wishbone Write
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_reg   <= {N_GPIO{1'b0}};
            dir_reg   <= {N_GPIO{1'b0}};
        end else begin

            if (wbs_cyc && wbs_stb && wbs_we) begin
                case (reg_offset)
                    REG_GPIO_DATA:   if (wbs_sel[0]) out_reg <= wbs_data_write[N_GPIO-1:0];
                    REG_GPIO_DIR:    if (wbs_sel[0]) dir_reg <= wbs_data_write[N_GPIO-1:0];
                    REG_GPIO_SET:    if (wbs_sel[0]) out_reg <= out_reg |  wbs_data_write[N_GPIO-1:0];
                    REG_GPIO_CLEAR:  if (wbs_sel[0]) out_reg <= out_reg & ~wbs_data_write[N_GPIO-1:0];
                    REG_GPIO_TOGGLE: if (wbs_sel[0]) out_reg <= out_reg ^  wbs_data_write[N_GPIO-1:0];
                endcase
            end
        end
    end

    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         out_reg <= {N_GPIO{1'b0}};
    //         dir_reg <= {N_GPIO{1'b0}};
    //     end else begin
    //         // Process writes when we're about to ACK
    //         if (ack_state == ACK_DELAY && pending_we) begin
    //             case (pending_addr[11:0])
    //                 REG_GPIO_DATA:   if (pending_sel[0]) out_reg <= pending_data[N_GPIO-1:0];
    //                 REG_GPIO_DIR:    if (pending_sel[0]) dir_reg <= pending_data[N_GPIO-1:0];
    //                 REG_GPIO_SET:    if (pending_sel[0]) out_reg <= out_reg | pending_data[N_GPIO-1:0];
    //                 REG_GPIO_CLEAR:  if (pending_sel[0]) out_reg <= out_reg & ~pending_data[N_GPIO-1:0];
    //                 REG_GPIO_TOGGLE: if (pending_sel[0]) out_reg <= out_reg ^ pending_data[N_GPIO-1:0];
    //             endcase
    //         end
    //     end
    // end

    // -------------------------------------------
    // ACK generation
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wbs_ack <= 1'b0;
        else
            wbs_ack <= (wbs_cyc && wbs_stb);
    end

    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         ack_state <= ACK_IDLE;
    //         wbs_ack <= 1'b0;
    //         ack_pending <= 1'b0;
    //         pending_addr <= 0;
    //         pending_we <= 0;
    //         pending_sel <= 0;
    //         pending_data <= 0;
    //     end else begin
    //         case (ack_state)
    //             ACK_IDLE: begin
    //                 wbs_ack <= 1'b0;
    //                 if (wbs_cyc && wbs_stb) begin
    //                     // Latch request details
    //                     pending_addr <= wbs_addr;
    //                     pending_we <= wbs_we;
    //                     pending_sel <= wbs_sel;
    //                     pending_data <= wbs_data_write;
    //                     ack_state <= ACK_DELAY;
    //                     ack_pending <= 1'b1;
    //                 end
    //             end

    //             ACK_DELAY: begin
    //                 // Wait 1 cycle for synchronization/setup
    //                 // For reads: wait for synchronized input data
    //                 // For writes: wait for register update
    //                 ack_state <= ACK_ASSERT;
    //             end

    //             ACK_ASSERT: begin
    //                 // Assert ACK - data is now valid
    //                 wbs_ack <= 1'b1;
    //                 ack_state <= ACK_IDLE;
    //                 ack_pending <= 1'b0;
    //             end
    //         endcase
    //     end
    // end

    // -------------------------------------------
    // GPIO Outputs
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_out <= {N_GPIO{1'b0}};
            gpio_oe  <= {N_GPIO{1'b0}};
        end else begin
            gpio_out <= out_reg;  // drive pad outputs
            gpio_oe  <= dir_reg;  // direction control
        end
    end

endmodule
