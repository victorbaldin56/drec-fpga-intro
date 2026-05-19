module mux4 #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH-1:0] i_d0,
    input  wire [WIDTH-1:0] i_d1,
    input  wire [WIDTH-1:0] i_d2,
    input  wire [WIDTH-1:0] i_d3,
    input  wire       [1:0] i_sel,
    output reg  [WIDTH-1:0] o_data
);

always @(*) begin
    case (i_sel)
        2'b00: o_data = i_d0;
        2'b01: o_data = i_d1;
        2'b10: o_data = i_d2;
        2'b11: o_data = i_d3;
        default: o_data = {WIDTH{1'b0}};
    endcase
end

endmodule
