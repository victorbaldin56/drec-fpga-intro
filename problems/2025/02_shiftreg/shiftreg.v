// 8-bit shift register (shift right), parallel load, shift enable.

module shiftreg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire  [7:0] i_data,
    input  wire        i_load,
    input  wire        i_en,
    output wire        o_bit
);

reg [7:0] shreg;

assign o_bit = shreg[0];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        shreg <= 8'h00;
    else if (i_load)
        shreg <= i_data;
    else if (i_en)
        shreg <= {1'b0, shreg[7:1]};
end

endmodule
