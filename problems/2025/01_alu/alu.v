module alu (
    input  wire [31:0]     i_a,
    input  wire [31:0]     i_b,
    input  wire  [3:0]     i_op,
    output reg  [31:0]     o_result
);

always @(*) begin
    case (i_op)
        4'b0000: o_result = i_a + i_b;
        4'b0001: o_result = i_a - i_b;
        4'b0010: o_result = i_a << i_b[4:0];
        4'b0011: o_result = ($signed(i_a) < $signed(i_b)) ? 32'd1 : 32'd0;
        4'b0100: o_result = (i_a < i_b) ? 32'd1 : 32'd0;
        4'b0101: o_result = i_a ^ i_b;
        4'b0110: o_result = i_a >> i_b[4:0];
        4'b0111: o_result = $signed(i_a) >>> i_b[4:0];
        4'b1000: o_result = i_a | i_b;
        4'b1001: o_result = i_a & i_b;
        default: o_result = 32'b0;
    endcase
end

endmodule
