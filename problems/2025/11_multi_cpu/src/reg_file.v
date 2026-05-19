// 32x32-bit register file. x0 always 0.
// Async read, sync write.

module reg_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire  [4:0] i_rs1,
    input  wire  [4:0] i_rs2,
    output wire [31:0] o_rd1,
    output wire [31:0] o_rd2,
    input  wire  [4:0] i_rd,
    input  wire [31:0] i_wdata,
    input  wire        i_we
);

reg [31:0] regs [1:31];

assign o_rd1 = (i_rs1 == 5'd0) ? 32'd0 : regs[i_rs1];
assign o_rd2 = (i_rs2 == 5'd0) ? 32'd0 : regs[i_rs2];

integer k;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (k = 1; k < 32; k = k + 1)
            regs[k] <= 32'd0;
    end else if (i_we && (i_rd != 5'd0)) begin
        regs[i_rd] <= i_wdata;
    end
end

endmodule
