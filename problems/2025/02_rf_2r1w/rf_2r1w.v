// 32x32-bit register file, 2 async read ports, 1 sync write port.
// x0 always reads as zero.

module rf_2r1w (
    input  wire        clk,
    input  wire        rst_n,
    input  wire  [4:0] i_ra1,
    input  wire  [4:0] i_ra2,
    output wire [31:0] o_rd1,
    output wire [31:0] o_rd2,
    input  wire  [4:0] i_wa,
    input  wire [31:0] i_wd,
    input  wire        i_we
);

reg [31:0] regs [1:31];

assign o_rd1 = (i_ra1 == 5'd0) ? 32'd0 : regs[i_ra1];
assign o_rd2 = (i_ra2 == 5'd0) ? 32'd0 : regs[i_ra2];

integer k;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (k = 1; k < 32; k = k + 1)
            regs[k] <= 32'd0;
    end else if (i_we && (i_wa != 5'd0)) begin
        regs[i_wa] <= i_wd;
    end
end

endmodule
