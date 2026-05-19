// 2-stage pipelined RV32I CPU core (IPC~1).
// Stage 1 (IF): present PC to imem; imem registers address (1-cycle latency).
// Stage 2 (EX): decode/execute instruction from imem output; writeback.
//
// Hazards:
//   LOAD: 1-cycle stall (imem stalled, bubble inserted in EX, WB next cycle).
//   Branch/Jump taken: 1-cycle penalty (flush pipeline, redirect fetch).
//   No other data hazards (register file write happens at end of EX, read is async).

`include "config.vh"

module core (
    input  wire        clk,
    input  wire        rst_n,

    output wire  [7:0] o_instr_addr,   // combinatorial byte-addr[9:2] to imem
    output wire        o_instr_stall,  // stall imem address register
    input  wire [31:0] i_instr_data,   // instruction output from imem

    output wire [29:0] o_mem_addr,
    output wire [31:0] o_mem_data,
    output wire        o_mem_we,
    output wire  [3:0] o_mem_mask,
    input  wire [31:0] i_mem_data
);

// -----------------------------------------------------------------------
// Pipeline registers
// -----------------------------------------------------------------------
// pc   : byte address currently presented to imem (IF stage fetch PC).
//        After posedge, imem holds this address and i_instr_data is valid.
//        Initialized to 4 so the first latch at posedge 1 sets pc_ex=0
//        using the instruction that imem reset exposes at addr 0.
reg [31:0] pc;
reg [31:0] pc_ex;     // PC of instruction currently in EX
reg [31:0] instr_ex;  // instruction currently in EX
reg        valid_ex;  // EX stage has a valid (non-bubble) instruction
reg        load_wb;   // LOAD writeback pending (uses instr_ex for rd/funct3)

// -----------------------------------------------------------------------
// Instruction decode (from EX pipeline register)
// -----------------------------------------------------------------------
wire [31:0] instr  = instr_ex;
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
        2'd1: alu_a = pc_ex;
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

// Memory write enable: only when EX has a valid store (never during WB or bubbles)
assign o_mem_we = mem_we_w & valid_ex & !load_wb;

// -----------------------------------------------------------------------
// Next PC (computed from EX stage)
// -----------------------------------------------------------------------
wire is_load_ex = (opcode == 7'b0000011);

wire [31:0] pc_plus4_ex = pc_ex + 32'd4;
wire [31:0] pc_branch   = pc_ex + imm_b;
wire [31:0] pc_jal      = pc_ex + imm_j;
wire [31:0] pc_jalr     = {alu_result[31:1], 1'b0};

wire [31:0] next_pc_ex = (jump == 2'd1)           ? pc_jal    :
                         (jump == 2'd2)           ? pc_jalr   :
                         (branch && branch_taken) ? pc_branch :
                                                    pc_plus4_ex;

// -----------------------------------------------------------------------
// Hazard signals
// -----------------------------------------------------------------------
// Stall IF when LOAD is in EX (first cycle): need 1 more cycle for dmem.
wire stall_load  = valid_ex && is_load_ex && !load_wb;

// Flush pipeline when branch taken or jump in EX (not during LOAD WB).
wire flush_branch = valid_ex && !load_wb &&
                    ((branch && branch_taken) || (jump != 2'd0));

// -----------------------------------------------------------------------
// Instruction fetch address (IF stage)
// When flushing, immediately redirect to branch/jump target so imem
// captures the correct address this posedge (1-cycle penalty).
// -----------------------------------------------------------------------
assign o_instr_addr  = flush_branch ? next_pc_ex[9:2] : pc[9:2];
assign o_instr_stall = stall_load;

// -----------------------------------------------------------------------
// Write-back mux
// -----------------------------------------------------------------------
always @(*) begin
    rf_we   = 1'b0;
    wb_data = alu_result;

    if (load_wb) begin
        // Second cycle of LOAD: dmem data ready.
        rf_we   = reg_we;
        wb_data = mem_rdata;
    end else if (valid_ex && !is_load_ex) begin
        rf_we   = reg_we;
        wb_data = (wb_src == 2'd1) ? mem_rdata  :
                  (wb_src == 2'd2) ? pc_plus4_ex :
                                     alu_result;
    end
end

// -----------------------------------------------------------------------
// Pipeline sequential logic
// -----------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // pc=4: first latch picks up imem's reset output (addr_d=0 → instr_0)
        // and sets pc_ex = pc-4 = 0. valid_ex=1 lets the decode logic run on
        // the reset NOP (instr_ex=0) without causing side-effects.
        pc       <= 32'd4;
        pc_ex    <= 32'd0;
        instr_ex <= 32'd0;
        valid_ex <= 1'b1;
        load_wb  <= 1'b0;
    end else begin
        if (flush_branch) begin
            // Redirect fetch; flush pipeline register (insert bubble).
            // Imem captured next_pc_ex via o_instr_addr = next_pc_ex[9:2].
            // Set pc = next_pc_ex+4 so that pc_ex = pc-4 = next_pc_ex next cycle.
            pc       <= next_pc_ex + 32'd4;
            instr_ex <= i_instr_data;  // wrong instruction, but valid_ex=0
            pc_ex    <= pc - 32'd4;    // don't care (valid_ex=0)
            valid_ex <= 1'b0;
            load_wb  <= 1'b0;
        end else if (stall_load) begin
            // First cycle of LOAD: stall IF (imem doesn't advance), insert bubble.
            // Don't touch pc (keep current fetch address).
            // Keep instr_ex = LOAD for WB next cycle.
            valid_ex <= 1'b0;
            load_wb  <= 1'b1;
            // pc, instr_ex, pc_ex unchanged
        end else if (load_wb) begin
            // Second cycle of LOAD: WB happens combinatorially above.
            // Resume normal pipeline advance.
            pc       <= pc + 32'd4;
            instr_ex <= i_instr_data;
            pc_ex    <= pc - 32'd4;
            valid_ex <= 1'b1;
            load_wb  <= 1'b0;
        end else begin
            // Normal advance.
            pc       <= pc + 32'd4;
            instr_ex <= i_instr_data;
            pc_ex    <= pc - 32'd4;
            valid_ex <= 1'b1;
        end
    end
end

endmodule
