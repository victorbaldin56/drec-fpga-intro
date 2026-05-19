// Single-cycle RV32I CPU core.
// All instructions complete in 1 clock cycle.
// Supports: R, I, S, B, U, J types (excluding SYSTEM/FENCE).

`include "config.vh"

module core (
    input  wire        clk,
    input  wire        rst_n,

    output wire [29:0] o_instr_addr,
    input  wire [31:0] i_instr_data,

    output wire [29:0] o_mem_addr,
    output wire [31:0] o_mem_data,
    output wire        o_mem_we,
    output wire  [3:0] o_mem_mask,
    input  wire [31:0] i_mem_data
);

// -----------------------------------------------------------------------
// Program counter
// -----------------------------------------------------------------------
reg [31:0] pc;

assign o_instr_addr = pc[31:2];

// -----------------------------------------------------------------------
// Instruction decode
// -----------------------------------------------------------------------
wire [31:0] instr  = i_instr_data;
wire  [6:0] opcode = instr[6:0];
wire  [4:0] rd     = instr[11:7];
wire  [2:0] funct3 = instr[14:12];
wire  [4:0] rs1    = instr[19:15];
wire  [4:0] rs2    = instr[24:20];

// Immediate generation
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
wire [31:0] wb_data;

reg_file reg_file (
    .clk    (clk      ),
    .rst_n  (rst_n    ),
    .i_rs1  (rs1      ),
    .i_rs2  (rs2      ),
    .o_rd1  (rs1_data ),
    .o_rd2  (rs2_data ),
    .i_rd   (rd       ),
    .i_wdata(wb_data  ),
    .i_we   (reg_we   )
);

// -----------------------------------------------------------------------
// ALU inputs
// -----------------------------------------------------------------------
reg [31:0] alu_a, alu_b, imm_sel;

// Select immediate for ALU B
always @(*) begin
    case (opcode)
        7'b0000011: imm_sel = imm_i;  // LOAD
        7'b0100011: imm_sel = imm_s;  // STORE
        7'b0110111: imm_sel = imm_u;  // LUI
        7'b0010111: imm_sel = imm_u;  // AUIPC
        7'b1101111: imm_sel = imm_j;  // JAL
        7'b1100111: imm_sel = imm_i;  // JALR
        default:    imm_sel = imm_i;  // I-type arith
    endcase
end

always @(*) begin
    case (alu_src_a)
        2'd0: alu_a = rs1_data;
        2'd1: alu_a = pc;
        default: alu_a = 32'd0;
    endcase
    alu_b = alu_src_b ? imm_sel : rs2_data;
end

// -----------------------------------------------------------------------
// ALU
// -----------------------------------------------------------------------
wire [31:0] alu_result;

alu alu (
    .i_a     (alu_a      ),
    .i_b     (alu_b      ),
    .i_op    (alu_op     ),
    .o_result(alu_result )
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
// LSU / Memory access
// -----------------------------------------------------------------------
wire [29:0] mem_addr_w;
wire [31:0] mem_wdata_w;
wire  [3:0] mem_mask_w;
wire        mem_we_w;
wire [31:0] mem_rdata;

lsu lsu (
    .i_addr  (alu_result ),
    .i_wdata (rs2_data   ),
    .i_funct3(mem_funct3 ),
    .i_we    (mem_we     ),
    .i_rdata (i_mem_data ),
    .o_addr  (mem_addr_w ),
    .o_wdata (mem_wdata_w),
    .o_mask  (mem_mask_w ),
    .o_we    (mem_we_w   ),
    .o_rdata (mem_rdata  )
);

assign o_mem_addr = mem_addr_w;
assign o_mem_data = mem_wdata_w;
assign o_mem_we   = mem_we_w;
assign o_mem_mask = mem_mask_w;

// -----------------------------------------------------------------------
// Write-back mux
// -----------------------------------------------------------------------
assign wb_data = (wb_src == 2'd1) ? mem_rdata :
                 (wb_src == 2'd2) ? (pc + 32'd4) :
                                    alu_result;

// -----------------------------------------------------------------------
// Next PC logic
// -----------------------------------------------------------------------
wire [31:0] pc_plus4    = pc + 32'd4;
wire [31:0] pc_branch   = pc + imm_b;
wire [31:0] pc_jal      = pc + imm_j;
wire [31:0] pc_jalr     = {alu_result[31:1], 1'b0};  // rs1+imm, clear bit0

wire [31:0] next_pc;

assign next_pc = (jump == 2'd1)              ? pc_jal    :
                 (jump == 2'd2)              ? pc_jalr   :
                 (branch && branch_taken)    ? pc_branch :
                                               pc_plus4;

// -----------------------------------------------------------------------
// PC register
// -----------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pc <= 32'd0;
    else
        pc <= next_pc;
end

endmodule
