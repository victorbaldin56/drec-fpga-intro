module mux4 #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH-1:0] i_d0,
    input  wire [WIDTH-1:0] i_d1,
    input  wire [WIDTH-1:0] i_d2,
    input  wire [WIDTH-1:0] i_d3,
    input  wire       [1:0] i_sel,
    output wire [WIDTH-1:0] o_data
);

assign o_data = i_sel[1] ? (i_sel[0] ? i_d3 : i_d2)
                         : (i_sel[0] ? i_d1 : i_d0);

endmodule
