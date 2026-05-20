module signext #(
    parameter N = 12,
    parameter M = 32
)(
    input  wire [N-1:0] i_data,
    output wire [M-1:0] o_data
);

assign o_data = {{(M-N){i_data[N-1]}}, i_data};

endmodule


module signext_s #(
    parameter N = 12,
    parameter M = 32
)(
    input  wire [N-1:0] i_data,
    output wire [M-1:0] o_data
);

genvar k;

generate
    for (k = 0; k < N; k = k + 1) begin : copy_input
        assign o_data[k] = i_data[k];
    end
endgenerate

generate
    for (k = N; k < M; k = k + 1) begin : sign_fill
        assign o_data[k] = i_data[N-1];
    end
endgenerate

endmodule
