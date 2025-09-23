module timer #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32
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
    output reg                       wbs_ack
);

    // -------------------------------------------
    // Parameter Definitions (register offsets)
    // -------------------------------------------
    localparam [11:0] REG_TIMER_COUNT    = 12'h000;  // Counter Value (Read-Only)
    localparam [11:0] REG_TIMER_CMP      = 12'h004;  // Compare Value
    localparam [11:0] REG_TIMER_CTRL     = 12'h008;  // Control register
    localparam [11:0] REG_TIMER_STATUS   = 12'h00C;  // Status Register

    // Control register bits
    localparam CTRL_ENABLE     = 0;  // Timer enable
    localparam CTRL_RESET      = 1;  // Reset Counter Register
    localparam CTRL_ONESHOT    = 2;  // One-shot mode (0=free-running)
    localparam CTRL_PRESCALE0  = 3;  // Prescaler bits [2:3]
    localparam CTRL_PRESCALE1  = 4;  // Prescaler bits [2:3]

    // Status register bits
    localparam STATUS_MATCH      = 0;  // Compare match occurred
    localparam STATUS_OVERFLOW   = 1;  // Counter overflow occurred

    // Prescaler values
    localparam [1:0] PRESCALE_1    = 2'b00;  // Clock / 1
    localparam [1:0] PRESCALE_8    = 2'b01;  // Clock / 8
    localparam [1:0] PRESCALE_64   = 2'b10;  // Clock / 64
    localparam [1:0] PRESCALE_1024 = 2'b11;  // Clock / 1024

    // Overflow value
    localparam [DATA_WIDTH-1:0] OVERFLOW_VALUE = 32'h0000_1000;

    // -------------------------------------------
    // Internal Registers
    // -------------------------------------------
    reg [31:0] count_reg;
    reg [31:0] cmp_reg;
    reg [4:0]  ctrl_reg;
    reg [1:0]  status_reg;

    // Internal signals
    reg [31:0] prescaler_counter;
    reg        prescaler_tick;
    reg        match_flag;
    reg        overflow_flag;

    // Read Detection signals
    reg status_read_match;
    reg status_read_overflow;
    

    // -------------------------------------------
    // Address Decode
    // -------------------------------------------
    wire [11:0] reg_offset = wbs_addr[11:0];

    wire sel_count    = (reg_offset == REG_TIMER_COUNT);
    wire sel_cmp      = (reg_offset == REG_TIMER_CMP);
    wire sel_ctrl     = (reg_offset == REG_TIMER_CTRL);
    wire sel_status   = (reg_offset == REG_TIMER_STATUS);


    // -------------------------------------------
    // Prescaler Logic
    // -------------------------------------------
    wire [1:0] prescale_sel = ctrl_reg[CTRL_PRESCALE1:CTRL_PRESCALE0];
    wire [31:0] prescale_max = (prescale_sel == PRESCALE_1)    ? 32'd1 :
                               (prescale_sel == PRESCALE_8)    ? 32'd8 :
                               (prescale_sel == PRESCALE_64)   ? 32'd64 :
                               (prescale_sel == PRESCALE_1024) ? 32'd1024 : 32'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prescaler_counter <= 32'b0;
            prescaler_tick <= 1'b0;
        end else if (ctrl_reg[CTRL_ENABLE]) begin
            if (prescaler_counter == prescale_max - 1) begin
                prescaler_counter <= 32'b0;
                prescaler_tick <= 1'b1;
            end else begin
                prescaler_counter <= prescaler_counter + 1;
                prescaler_tick <= 1'b0;
            end
        end else begin
            prescaler_counter <= 32'b0;
            prescaler_tick <= 1'b0;
        end
    end

    // -------------------------------------------
    // Counter Logic
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_reg <= 32'b0;
            match_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end else if (ctrl_reg[CTRL_RESET]) begin
            count_reg <= 32'b0;
            match_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end else if (ctrl_reg[CTRL_ENABLE] && prescaler_tick) begin
            // Check for compare match
            if (count_reg == cmp_reg) begin
                match_flag <= 1'b1;
                if (ctrl_reg[CTRL_ONESHOT]) begin
                    // Stop in one-shot mode
                    count_reg <= count_reg;
                end else begin
                    count_reg <= count_reg + 1;
                end
            end else begin
                match_flag <= 1'b0;
                count_reg <= count_reg + 1;
            end
            
            // Check for overflow
            if (count_reg == OVERFLOW_VALUE) begin
                overflow_flag <= 1'b1;
            end else begin
                overflow_flag <= 1'b0;
            end
        end else begin
            match_flag <= 1'b0;
        end
    end

    // -------------------------------------------
    // Status Register Logic
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_reg <= 2'b00;
        end else begin
            // Set flags on events
            if (match_flag)    status_reg[STATUS_MATCH]    <= 1'b1;
            if (overflow_flag) status_reg[STATUS_OVERFLOW] <= 1'b1;

            // Clear flags on status register write
            if (status_read_match)    status_reg[STATUS_MATCH]    <= 1'b0;
            if (status_read_overflow) status_reg[STATUS_OVERFLOW] <= 1'b0;
        end
    end



    // -------------------------------------------
    // Wishbone ACK
    // -------------------------------------------
    reg tmp_r_ack;
    reg tmp_w_ack;

    // -------------------------------------------
    // Wishbone Read
    // -------------------------------------------
    always @(*) begin
        wbs_data_read = {DATA_WIDTH{1'b0}};
        tmp_r_ack     = 1'b0;

        if (wbs_cyc && wbs_stb && !wbs_we) begin
            tmp_r_ack = 1'b1;
            case (reg_offset)
                REG_TIMER_COUNT:   wbs_data_read = count_reg;
                REG_TIMER_CMP:     wbs_data_read = cmp_reg;
                REG_TIMER_CTRL:    wbs_data_read = {27'b0, ctrl_reg}; 
                REG_TIMER_STATUS:  wbs_data_read = {30'b0, status_reg}; 
                default:           wbs_data_read = {DATA_WIDTH{1'b0}};
            endcase
        end
    end


    // -------------------------------------------
    // Wishbone Write
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmp_reg                 <= 32'b0;
            ctrl_reg                <= 5'b00000;  // Disabled, free-running, prescale=1
            status_read_match       <= 1'b0;
            status_read_overflow    <= 1'b0;
            tmp_w_ack               <= 1'b0;
        end else begin
            tmp_w_ack <= 1'b0;

            // default deassert 
            status_read_match    <= 1'b0;
            status_read_overflow <= 1'b0;

            // Self-clear ctrl reset bit
            if (ctrl_reg[CTRL_RESET]) ctrl_reg[CTRL_RESET] <= 1'b0;
            
            if (wbs_cyc && wbs_stb && wbs_we) begin
                tmp_w_ack <= 1'b1;
                
                case (reg_offset)
                    REG_TIMER_CMP: begin
                        if (wbs_sel[0]) cmp_reg[7:0]   <= wbs_data_write[7:0];
                        if (wbs_sel[1]) cmp_reg[15:8]  <= wbs_data_write[15:8];
                        if (wbs_sel[2]) cmp_reg[23:16] <= wbs_data_write[23:16];
                        if (wbs_sel[3]) cmp_reg[31:24] <= wbs_data_write[31:24];
                    end
                    
                    REG_TIMER_CTRL: begin
                        if (wbs_sel[0]) ctrl_reg <= wbs_data_write[4:0];
                    end
                    
                    REG_TIMER_STATUS: begin
                        // Writing 1 to clear flags - only clear if the flag is currently set
                        if (wbs_sel[0]) begin
                            status_read_match       <= status_reg[STATUS_MATCH] && wbs_data_write[STATUS_MATCH];
                            status_read_overflow    <= status_reg[STATUS_OVERFLOW] && wbs_data_write[STATUS_OVERFLOW];
                        end
                    end
                endcase
            end
        end
    end


    // -------------------------------------------
    // ACK generation
    // -------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wbs_ack <= 1'b0;
        else
            wbs_ack <= (wbs_cyc && wbs_stb && (tmp_r_ack || tmp_w_ack));
    end

endmodule
