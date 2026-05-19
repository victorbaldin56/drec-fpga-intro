// Multi-cycle RV32I CPU core.
// LOAD = 3 cycles (IF -> EX -> WB), all others = 2 cycles (IF -> EX).
// Combinatorial o_instr_addr from pc; imem registers once (1-cycle fetch latency).
// Registered dmem (1-cycle memory latency).

`include "config.vh"

module core (
    input  wire        clk,
    input  wire        rst_n,

    output wire  [7:0] o_instr_addr,
    input  wire [31:0] i_instr_data,

    output wire [29:0] o_mem_addr,
    output wire [31:0] o_mem_data,
    output wire        o_mem_we,
    output wire  [3:0] o_mem_mask,
    input  wire [31:0] i_mem_data
);

// -----------------------------------------------------------------------
// State machine
// -----------------------------------------------------------------------
localparam S_IF = 2'd0;  // Instruction Fetch: imem captures pc address
localparam S_EX = 2'd1;  // Execute: instruction valid on i_instr_data
localparam S_WB = 2'd2;  // Write-Back (LOAD only): dmem result ready

reg [1:0] state;

// -----------------------------------------------------------------------
// Program counter
// -----------------------------------------------------------------------
reg [31:0] pc;

// Combinatorial address to imem — one register stage in imem gives 1-cycle latency.
assign o_instr_addr = pc[9:2];

// -----------------------------------------------------------------------
// Instruction decode (directly from imem output in EX/WB states)
// -----------------------------------------------------------------------
wire [31:0] instr  = i_instr_data;
wire  [6:0] opcode = instr[6:0];
wire  [4:0] rd     = instr[11:7];
wire  [2:0] funct3 = instr[14:12];
wire  [4:0] rs1    = instr[19:15];
wire  [4:0] rs2    = instr[24:20];

wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
wire [31:0] imm_u = {instr[31:12], 12'b0};
wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

// -----------------------------------------------------------------------
// Control signals
// -----------------------------------------------------------------------
wire  [3:0] alu_op;
wire  [1:0] alu_src_a;
wire        alu_src_b;
wire        reg_we;
wire  [1:0] wb_src;
wire        mem_we;
wire  [2:0] mem_funct3;
wire        branch;
wire  [1:0] jump;

control control (
    .i_instr     (instr      ),
    .o_alu_op    (alu_op     ),
    .o_alu_src_a (alu_src_a  ),
    .o_alu_src_b (alu_src_b  ),
    .o_reg_we    (reg_we     ),
    .o_wb_src    (wb_src     ),
    .o_mem_we    (mem_we     ),
    .o_mem_funct3(mem_funct3 ),
    .o_branch    (branch     ),
    .o_jump      (jump       )
);

// -----------------------------------------------------------------------
// Register file
// -----------------------------------------------------------------------
wire [31:0] rs1_data, rs2_data;
reg  [31:0] wb_data;
reg         rf_we;

reg_file reg_file (
    .clk    (clk     ),
    .rst_n  (rst_n   ),
    .i_rs1  (rs1     ),
    .i_rs2  (rs2     ),
    .o_rd1  (rs1_data),
    .o_rd2  (rs2_data),
    .i_rd   (rd      ),
    .i_wdata(wb_data ),
    .i_we   (rf_we   )
);

// -----------------------------------------------------------------------
// ALU
// -----------------------------------------------------------------------
reg  [31:0] alu_a, alu_b, imm_sel;
wire [31:0] alu_result;

always @(*) begin
    case (opcode)
        7'b0100011: imm_sel = imm_s;
        7'b0110111: imm_sel = imm_u;
        7'b0010111: imm_sel = imm_u;
        7'b1101111: imm_sel = imm_j;
        7'b1100111: imm_sel = imm_i;
        default:    imm_sel = imm_i;
    endcase

    case (alu_src_a)
        2'd0: alu_a = rs1_data;
        2'd1: alu_a = pc;
        default: alu_a = 32'd0;
    endcase

    alu_b = alu_src_b ? imm_sel : rs2_data;
end

alu alu (
    .i_a     (alu_a     ),
    .i_b     (alu_b     ),
    .i_op    (alu_op    ),
    .o_result(alu_result)
);

// -----------------------------------------------------------------------
// Branch comparator
// -----------------------------------------------------------------------
wire branch_taken;

cmp cmp (
    .i_a    (rs1_data   ),
    .i_b    (rs2_data   ),
    .i_op   (funct3     ),
    .o_taken(branch_taken)
);

// -----------------------------------------------------------------------
// LSU
// -----------------------------------------------------------------------
wire [29:0] mem_addr_w;
wire [31:0] mem_wdata_w;
wire  [3:0] mem_mask_w;
wire        mem_we_w;
wire [31:0] mem_rdata;

lsu lsu (
    .i_addr  (alu_result),
    .i_wdata (rs2_data  ),
    .i_funct3(mem_funct3),
    .i_we    (mem_we    ),
    .i_rdata (i_mem_data),
    .o_addr  (mem_addr_w),
    .o_wdata (mem_wdata_w),
    .o_mask  (mem_mask_w),
    .o_we    (mem_we_w  ),
    .o_rdata (mem_rdata )
);

assign o_mem_addr = mem_addr_w;
assign o_mem_data = mem_wdata_w;
assign o_mem_mask = mem_mask_w;

// Memory write enable: only during S_EX to prevent spurious writes
assign o_mem_we = mem_we_w & (state == S_EX);

// -----------------------------------------------------------------------
// Next PC
// -----------------------------------------------------------------------
wire is_load = (opcode == 7'b0000011);

wire [31:0] pc_plus4  = pc + 32'd4;
wire [31:0] pc_branch = pc + imm_b;
wire [31:0] pc_jal    = pc + imm_j;
wire [31:0] pc_jalr   = {alu_result[31:1], 1'b0};

wire [31:0] next_pc = (jump == 2'd1)           ? pc_jal    :
                      (jump == 2'd2)           ? pc_jalr   :
                      (branch && branch_taken) ? pc_branch :
                                                 pc_plus4;

// -----------------------------------------------------------------------
// Write-back combinatorial logic
// -----------------------------------------------------------------------
always @(*) begin
    rf_we   = 1'b0;
    wb_data = alu_result;

    case (state)
        S_EX: begin
            if (!is_load) begin
                rf_we   = reg_we;
                wb_data = (wb_src == 2'd1) ? mem_rdata :
                          (wb_src == 2'd2) ? pc_plus4  :
                                             alu_result;
            end
        end
        S_WB: begin
            rf_we   = reg_we;
            wb_data = mem_rdata;
        end
        default: begin end
    endcase
end

// -----------------------------------------------------------------------
// State machine
// -----------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IF;
        pc    <= 32'd0;
    end else begin
        case (state)
            S_IF: begin
                // imem captures pc address on this posedge;
                // instruction available on i_instr_data next cycle.
                state <= S_EX;
            end
            S_EX: begin
                // Instruction valid on i_instr_data now; execute.
                if (is_load) begin
                    // Issue memory read; wait for result.
                    state <= S_WB;
                end else begin
                    pc    <= next_pc;
                    state <= S_IF;
                end
            end
            S_WB: begin
                // Load result available from dmem (registered in S_EX).
                pc    <= next_pc;
                state <= S_IF;
            end
            default: state <= S_IF;
        endcase
    end
end

endmodule
