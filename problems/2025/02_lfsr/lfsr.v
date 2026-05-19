// 8-bit Fibonacci LFSR
// Polynomial: x^8 + x^6 + x^5 + x^4 + 1
// Feedback = XOR of bits 7, 5, 4, 3; shift left, insert at bit 0.

module lfsr (
    input  wire        clk,
    input  wire        rst_n,
    output reg   [7:0] o_data
);

wire feedback = o_data[7] ^ o_data[5] ^ o_data[4] ^ o_data[3];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        o_data <= 8'hFF;
    else
        o_data <= {o_data[6:0], feedback};
end

endmodule
