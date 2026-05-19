// Branch comparator for RV32I B-type instructions.
// i_op = funct3.

module cmp (
    input  wire [31:0] i_a,
    input  wire [31:0] i_b,
    input  wire  [2:0] i_op,
    output reg         o_taken
);

always @(*) begin
    case (i_op)
        3'b000: o_taken = (i_a == i_b);
        3'b001: o_taken = (i_a != i_b);
        3'b100: o_taken = ($signed(i_a) < $signed(i_b));
        3'b101: o_taken = ($signed(i_a) >= $signed(i_b));
        3'b110: o_taken = (i_a < i_b);
        3'b111: o_taken = (i_a >= i_b);
        default: o_taken = 1'b0;
    endcase
end

endmodule
