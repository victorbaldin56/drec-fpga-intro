// RV32I instruction decoder / control unit.
// Decodes instruction and generates all control signals.

// ALU op encoding: {alt, funct3}
// alu_src_a: 0=rs1, 1=PC, 2=zero(for LUI)
// alu_src_b: 0=rs2, 1=imm
// wb_src:    0=ALU, 1=MEM, 2=PC+4
// jump:      0=no, 1=JAL, 2=JALR

module control (
    input  wire [31:0] i_instr,

    output reg   [3:0] o_alu_op,
    output reg   [1:0] o_alu_src_a,  // 0=rs1, 1=PC, 2=zero
    output reg         o_alu_src_b,  // 0=rs2, 1=imm
    output reg         o_reg_we,
    output reg   [1:0] o_wb_src,     // 0=ALU, 1=MEM, 2=PC+4
    output reg         o_mem_we,
    output wire  [2:0] o_mem_funct3,
    output reg         o_branch,
    output reg   [1:0] o_jump        // 0=none, 1=JAL, 2=JALR
);

wire [6:0] opcode = i_instr[6:0];
wire [2:0] funct3 = i_instr[14:12];
wire       funct7_5 = i_instr[30];   // differentiates SUB/SRA from ADD/SRL

assign o_mem_funct3 = funct3;

// ALU op: {alt, funct3}
wire [3:0] alu_from_instr = {funct7_5, funct3};

localparam [6:0] OP_R      = 7'b0110011;
localparam [6:0] OP_I_ARITH= 7'b0010011;
localparam [6:0] OP_LOAD   = 7'b0000011;
localparam [6:0] OP_STORE  = 7'b0100011;
localparam [6:0] OP_BRANCH = 7'b1100011;
localparam [6:0] OP_LUI    = 7'b0110111;
localparam [6:0] OP_AUIPC  = 7'b0010111;
localparam [6:0] OP_JAL    = 7'b1101111;
localparam [6:0] OP_JALR   = 7'b1100111;

always @(*) begin
    // defaults (NOP-like)
    o_alu_op    = 4'b0000;   // ADD
    o_alu_src_a = 2'd0;      // rs1
    o_alu_src_b = 1'b0;      // rs2
    o_reg_we    = 1'b0;
    o_wb_src    = 2'd0;      // ALU result
    o_mem_we    = 1'b0;
    o_branch    = 1'b0;
    o_jump      = 2'd0;

    case (opcode)
        OP_R: begin
            o_alu_op    = alu_from_instr;
            o_alu_src_a = 2'd0;
            o_alu_src_b = 1'b0;
            o_reg_we    = 1'b1;
            o_wb_src    = 2'd0;
        end
        OP_I_ARITH: begin
            // For SRAI (funct3=101), funct7[5]=1 -> SUB encoding
            // For SRLI (funct3=101), funct7[5]=0
            // For others, funct7[5] is always 0
            o_alu_op    = (funct3 == 3'b001 || funct3 == 3'b101)
                          ? alu_from_instr : {1'b0, funct3};
            o_alu_src_a = 2'd0;
            o_alu_src_b = 1'b1;
            o_reg_we    = 1'b1;
            o_wb_src    = 2'd0;
        end
        OP_LOAD: begin
            o_alu_op    = 4'b0000;  // ADD: addr = rs1 + imm
            o_alu_src_a = 2'd0;
            o_alu_src_b = 1'b1;
            o_reg_we    = 1'b1;
            o_wb_src    = 2'd1;     // MEM
        end
        OP_STORE: begin
            o_alu_op    = 4'b0000;  // ADD: addr = rs1 + imm_s
            o_alu_src_a = 2'd0;
            o_alu_src_b = 1'b1;
            o_mem_we    = 1'b1;
        end
        OP_BRANCH: begin
            o_branch    = 1'b1;
        end
        OP_LUI: begin
            o_alu_op    = 4'b0000;  // ADD: 0 + imm_u
            o_alu_src_a = 2'd2;     // zero
            o_alu_src_b = 1'b1;
            o_reg_we    = 1'b1;
            o_wb_src    = 2'd0;
        end
        OP_AUIPC: begin
            o_alu_op    = 4'b0000;  // ADD: PC + imm_u
            o_alu_src_a = 2'd1;     // PC
            o_alu_src_b = 1'b1;
            o_reg_we    = 1'b1;
            o_wb_src    = 2'd0;
        end
        OP_JAL: begin
            o_alu_op    = 4'b0000;  // ADD: PC + imm_j (for jump target)
            o_alu_src_a = 2'd1;     // PC
            o_alu_src_b = 1'b1;
            o_reg_we    = 1'b1;
            o_wb_src    = 2'd2;     // PC+4
            o_jump      = 2'd1;
        end
        OP_JALR: begin
            o_alu_op    = 4'b0000;  // ADD: rs1 + imm_i
            o_alu_src_a = 2'd0;     // rs1
            o_alu_src_b = 1'b1;
            o_reg_we    = 1'b1;
            o_wb_src    = 2'd2;     // PC+4
            o_jump      = 2'd2;
        end
        default: begin
            // NOP (FENCE, SYSTEM)
        end
    endcase
end

endmodule
