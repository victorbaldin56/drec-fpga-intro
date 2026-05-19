// FP16 multiplier (combinational)
// DAZ (denormals-as-zero), FTZ (flush-to-zero), RTZ rounding.

module fp16mul (
    input  wire [15:0] i_a,
    input  wire [15:0] i_b,
    output reg  [15:0] o_res
);

wire        a_sign = i_a[15];
wire [4:0]  a_bexp = i_a[14:10];
wire [9:0]  a_mant = i_a[9:0];

wire        b_sign = i_b[15];
wire [4:0]  b_bexp = i_b[14:10];
wire [9:0]  b_mant = i_b[9:0];

wire res_sign = a_sign ^ b_sign;

wire a_zero = (a_bexp == 5'h00);
wire b_zero = (b_bexp == 5'h00);
wire a_inf  = (a_bexp == 5'h1F);
wire b_inf  = (b_bexp == 5'h1F);

wire [10:0] a_sig = {1'b1, a_mant};
wire [10:0] b_sig = {1'b1, b_mant};

wire [21:0] prod = a_sig * b_sig;

// exp_sum = ea + eb - 15, use 7 bits
wire [6:0] exp_sum = {2'b00, a_bexp} + {2'b00, b_bexp} - 7'd15;

wire        prod_msb = prod[21];
wire [9:0]  mant_rtz = prod_msb ? prod[20:11] : prod[19:10];
wire [6:0]  exp_adj  = prod_msb ? (exp_sum + 7'd1) : exp_sum;

wire overflow  = (exp_adj >= 7'd31);
wire underflow = exp_adj[6] || (exp_adj == 7'd0);

always @(*) begin
    if (a_zero || b_zero)
        o_res = {res_sign, 15'h0000};
    else if (a_inf || b_inf)
        o_res = {res_sign, 5'h1F, 10'h000};
    else if (overflow)
        o_res = {res_sign, 5'h1F, 10'h000};
    else if (underflow)
        o_res = {res_sign, 15'h0000};
    else
        o_res = {res_sign, exp_adj[4:0], mant_rtz};
end

endmodule
