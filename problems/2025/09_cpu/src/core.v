// 3-stage pipelined RV32I CPU core: IF | EX | WB.
//
// Stage 1 (IF):  Present PC to imem (1-cycle registered fetch latency).
// Stage 2 (EX):  Decode/execute; compute memory address; ALU.
// Stage 3 (WB):  Register writeback: ALU result, PC+4, or dmem data (LOAD).
//
// Hazard handling:
//   Non-LOAD data hazard: WB→EX forwarding (1 stage back, covers all RAW cases).
//   LOAD-use hazard:      1-cycle stall (LOAD in EX, consumer in IF → bubble in EX).
//   Branch/Jump:          1-cycle flush (EX detects, flushes EX→IF bubble).

`include "config.vh"

module core (
    input  wire        clk,
    input  wire        rst_n,

    output wire  [7:0] o_instr_addr,   // combinatorial byte-addr[9:2] to imem
    output wire        o_instr_stall,  // stall imem address register
    input  wire [31:0] i_instr_data,   // instruction from imem

    output wire [29:0] o_mem_addr,
    output wire [31:0] o_mem_data,
    output wire        o_mem_we,
    output wire  [3:0] o_mem_mask,
    input  wire [31:0] i_mem_data
);

// -----------------------------------------------------------------------
// IF stage: program counter
// -----------------------------------------------------------------------
// pc=4 at reset: imem reset exposes addr_d=0 → i_instr_data=mem[0] on cycle 1,
// so instr_ex gets instr_0 with pc_ex = pc-4 = 0 at posedge 1. ✓
reg [31:0] pc;

wire [7:0]  if_addr;   // driven combinatorially below

// -----------------------------------------------------------------------
// IF/EX pipeline register
// -----------------------------------------------------------------------
reg [31:0] instr_ex;
reg [31:0] pc_ex;
reg        valid_ex;

// -----------------------------------------------------------------------
// EX stage: instruction decode
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
// EX/WB pipeline register
// -----------------------------------------------------------------------
reg [31:0] alu_result_wb;  // ALU result (or LOAD byte address)
reg [31:0] pc_plus4_wb;    // PC+4 for JAL/JALR return address
reg  [4:0] rd_wb;
reg  [2:0] funct3_wb;
reg  [1:0] wb_src_wb;      // 0=ALU, 1=MEM, 2=PC+4
reg        reg_we_wb;
reg        valid_wb;
reg        is_load_wb;

// -----------------------------------------------------------------------
// Control signals (from EX stage)
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
// Register file (write driven by WB stage)
// -----------------------------------------------------------------------
wire [31:0] rs1_raw, rs2_raw;
reg  [31:0] wb_data_comb;  // WB data computed combinatorially
reg         wb_rf_we;      // WB register write enable

reg_file reg_file (
    .clk    (clk         ),
    .rst_n  (rst_n       ),
    .i_rs1  (rs1         ),
    .i_rs2  (rs2         ),
    .o_rd1  (rs1_raw     ),
    .o_rd2  (rs2_raw     ),
    .i_rd   (rd_wb       ),
    .i_wdata(wb_data_comb),
    .i_we   (wb_rf_we    )
);

// -----------------------------------------------------------------------
// WB stage: compute writeback data combinatorially
// -----------------------------------------------------------------------
// Load sign/zero extension from dmem output.
reg [31:0] mem_rdata_wb;

always @(*) begin
    case (funct3_wb)
        3'b000: mem_rdata_wb = {{24{i_mem_data[7]}},  i_mem_data[7:0]};   // LB
        3'b001: mem_rdata_wb = {{16{i_mem_data[15]}}, i_mem_data[15:0]};  // LH
        3'b010: mem_rdata_wb = i_mem_data;                                  // LW
        3'b100: mem_rdata_wb = {24'b0, i_mem_data[7:0]};                   // LBU
        3'b101: mem_rdata_wb = {16'b0, i_mem_data[15:0]};                  // LHU
        default: mem_rdata_wb = i_mem_data;
    endcase
end

always @(*) begin
    wb_rf_we    = valid_wb && reg_we_wb;
    wb_data_comb = alu_result_wb;  // default

    if (is_load_wb)
        wb_data_comb = mem_rdata_wb;
    else if (wb_src_wb == 2'd2)
        wb_data_comb = pc_plus4_wb;
    else
        wb_data_comb = alu_result_wb;
end

// -----------------------------------------------------------------------
// Forwarding: WB → EX  (covers 1-cycle-old results)
// -----------------------------------------------------------------------
wire fwd_rs1 = valid_wb && reg_we_wb && (rd_wb != 5'd0) && (rd_wb == rs1);
wire fwd_rs2 = valid_wb && reg_we_wb && (rd_wb != 5'd0) && (rd_wb == rs2);

wire [31:0] rs1_eff = fwd_rs1 ? wb_data_comb : rs1_raw;
wire [31:0] rs2_eff = fwd_rs2 ? wb_data_comb : rs2_raw;

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
        2'd0: alu_a = rs1_eff;
        2'd1: alu_a = pc_ex;
        default: alu_a = 32'd0;
    endcase

    alu_b = alu_src_b ? imm_sel : rs2_eff;
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
    .i_a    (rs1_eff    ),
    .i_b    (rs2_eff    ),
    .i_op   (funct3     ),
    .o_taken(branch_taken)
);

// -----------------------------------------------------------------------
// LSU (EX stage)
// -----------------------------------------------------------------------
wire [29:0] ex_mem_addr;
wire [31:0] ex_mem_wdata;
wire  [3:0] ex_mem_mask;
wire        ex_mem_we;
wire [31:0] ex_mem_rdata;  // not used directly; WB stage reads i_mem_data

lsu lsu (
    .i_addr  (alu_result),
    .i_wdata (rs2_eff   ),
    .i_funct3(mem_funct3),
    .i_we    (mem_we    ),
    .i_rdata (i_mem_data),
    .o_addr  (ex_mem_addr),
    .o_wdata (ex_mem_wdata),
    .o_mask  (ex_mem_mask),
    .o_we    (ex_mem_we  ),
    .o_rdata (ex_mem_rdata)
);

// Memory address: when LOAD is in WB, re-present LOAD address so dmem output
// stays valid (sel_dmem correct in xbar). EX bubble holds during LOAD stall.
assign o_mem_addr = (valid_wb && is_load_wb) ? alu_result_wb[31:2] : ex_mem_addr;
assign o_mem_data = ex_mem_wdata;
assign o_mem_mask = ex_mem_mask;
// Write enable only when EX has a valid non-LOAD instruction.
assign o_mem_we   = ex_mem_we & valid_ex;

// -----------------------------------------------------------------------
// Next PC (EX stage)
// -----------------------------------------------------------------------
wire is_load_ex = (opcode == 7'b0000011);
wire [31:0] pc_plus4_ex = pc_ex + 32'd4;
wire [31:0] next_pc_ex  = (jump == 2'd1)           ? (pc_ex + imm_j)              :
                           (jump == 2'd2)           ? {alu_result[31:1], 1'b0}     :
                           (branch && branch_taken) ? (pc_ex + imm_b)              :
                                                      pc_plus4_ex;

// -----------------------------------------------------------------------
// Hazard detection
// -----------------------------------------------------------------------
// LOAD-use: LOAD in EX and the next instruction (in IF) reads LOAD's rd.
wire [4:0] if_rs1 = i_instr_data[19:15];
wire [4:0] if_rs2 = i_instr_data[24:20];
wire load_use = valid_ex && is_load_ex && (rd != 5'd0) &&
                (if_rs1 == rd || if_rs2 == rd);

wire flush_branch = valid_ex && !load_use &&
                    ((branch && branch_taken) || (jump != 2'd0));

// -----------------------------------------------------------------------
// Fetch address (IF stage)
// -----------------------------------------------------------------------
assign o_instr_addr  = flush_branch ? next_pc_ex[9:2] : pc[9:2];
assign o_instr_stall = load_use;

// -----------------------------------------------------------------------
// Pipeline sequential logic
// -----------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc            <= 32'd4;
        pc_ex         <= 32'd0;
        instr_ex      <= 32'd0;
        valid_ex      <= 1'b1;   // initial NOP in EX (instr_ex=0, no side-effects)
        alu_result_wb <= 32'd0;
        pc_plus4_wb   <= 32'd0;
        rd_wb         <= 5'd0;
        funct3_wb     <= 3'd0;
        wb_src_wb     <= 2'd0;
        reg_we_wb     <= 1'b0;
        valid_wb      <= 1'b0;
        is_load_wb    <= 1'b0;
    end else begin
        // --- EX → WB pipeline register ---
        // Always advance WB (it can't stall on its own; LOAD-use stall inserts bubble in EX).
        if (flush_branch || load_use) begin
            // Flush or stall: insert bubble into EX→WB transition.
            valid_wb   <= valid_ex && !flush_branch;
            // If stalling (load_use): let the LOAD's EX results flow to WB normally.
            if (!flush_branch && load_use) begin
                alu_result_wb <= alu_result;
                pc_plus4_wb   <= pc_plus4_ex;
                rd_wb         <= rd;
                funct3_wb     <= funct3;
                wb_src_wb     <= wb_src;
                reg_we_wb     <= reg_we;
                is_load_wb    <= is_load_ex;
                valid_wb      <= valid_ex;
            end else begin
                // flush: WB gets a bubble
                reg_we_wb  <= 1'b0;
                valid_wb   <= 1'b0;
                is_load_wb <= 1'b0;
            end
        end else begin
            alu_result_wb <= alu_result;
            pc_plus4_wb   <= pc_plus4_ex;
            rd_wb         <= rd;
            funct3_wb     <= funct3;
            wb_src_wb     <= wb_src;
            reg_we_wb     <= reg_we;
            is_load_wb    <= is_load_ex;
            valid_wb      <= valid_ex;
        end

        // --- IF → EX pipeline register ---
        if (flush_branch) begin
            // Flush: bubble in EX.
            valid_ex <= 1'b0;
            instr_ex <= 32'd0;
            pc_ex    <= 32'd0;
            // Redirect fetch PC.
            pc       <= next_pc_ex + 32'd4;
        end else if (load_use) begin
            // Stall: bubble in EX (consumer stays in IF, LOAD stays in EX already
            // moved to WB above).
            valid_ex <= 1'b0;
            instr_ex <= 32'd0;
            pc_ex    <= 32'd0;
            // pc and IF stay frozen (imem stall keeps i_instr_data stable).
        end else begin
            // Normal advance.
            valid_ex <= 1'b1;
            instr_ex <= i_instr_data;
            pc_ex    <= pc - 32'd4;
            pc       <= pc + 32'd4;
        end
    end
end

endmodule
