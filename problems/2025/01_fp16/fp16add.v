// FP16 adder (combinational)
// DAZ (denormals-as-zero), FTZ (flush-to-zero), RTZ rounding.

module fp16add (
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

wire a_zero = (a_bexp == 5'h00);
wire b_zero = (b_bexp == 5'h00);
wire a_inf  = (a_bexp == 5'h1F);
wire b_inf  = (b_bexp == 5'h1F);

// DAZ: zero significand for zero/denormal exponent
wire [10:0] a_sig = a_zero ? 11'h000 : {1'b1, a_mant};
wire [10:0] b_sig = b_zero ? 11'h000 : {1'b1, b_mant};

// Select big/small by exponent (a wins ties)
wire        a_larger   = (a_bexp >= b_bexp);
wire [4:0]  exp_big    = a_larger ? a_bexp  : b_bexp;
wire        sign_big   = a_larger ? a_sign  : b_sign;
wire        sign_small = a_larger ? b_sign  : a_sign;
wire [10:0] sig_big    = a_larger ? a_sig   : b_sig;
wire [10:0] sig_small  = a_larger ? b_sig   : a_sig;

wire [4:0] shift     = exp_big - (a_larger ? b_bexp : a_bexp);
wire [4:0] shift_cap = (shift > 5'd11) ? 5'd11 : shift;

wire [10:0] sig_small_sh = sig_small >> shift_cap;

wire add_op = (sign_big == sign_small);

wire [11:0] sum = add_op
    ? ({1'b0, sig_big} + {1'b0, sig_small_sh})
    : ({1'b0, sig_big} - {1'b0, sig_small_sh});

// Priority encode leading 1 in sum[11:0]
reg [4:0]  lz;
always @(*) begin
    casez (sum[11:0])
        12'b1???????????: lz = 5'd0;
        12'b01??????????: lz = 5'd1;
        12'b001?????????: lz = 5'd2;
        12'b0001????????: lz = 5'd3;
        12'b00001???????: lz = 5'd4;
        12'b000001??????: lz = 5'd5;
        12'b0000001?????: lz = 5'd6;
        12'b00000001????: lz = 5'd7;
        12'b000000001???: lz = 5'd8;
        12'b0000000001??: lz = 5'd9;
        12'b00000000001?: lz = 5'd10;
        12'b000000000001: lz = 5'd11;
        default:          lz = 5'd12;
    endcase
end

reg [11:0] norm_sig;
reg  [6:0] res_exp;

always @(*) begin
    if (lz == 5'd0) begin
        norm_sig = sum >> 1;
        res_exp  = {2'b00, exp_big} + 7'd1;
    end else if (lz == 5'd1) begin
        norm_sig = sum;
        res_exp  = {2'b00, exp_big};
    end else begin
        norm_sig = sum << (lz - 5'd1);
        res_exp  = {2'b00, exp_big} - {2'b00, (lz - 5'd1)};
    end
end

wire [9:0] res_mant   = norm_sig[9:0];
wire       res_zero   = (sum == 12'd0) || (lz == 5'd12);
wire       overflow   = (res_exp >= 7'd31);
wire       underflow  = res_exp[6] || (res_exp == 7'd0);

always @(*) begin
    if (a_inf || b_inf) begin
        if (a_inf && b_inf && (a_sign != b_sign))
            o_res = {1'b0, 5'h1F, 10'h000};
        else if (a_inf)
            o_res = {a_sign, 5'h1F, 10'h000};
        else
            o_res = {b_sign, 5'h1F, 10'h000};
    end else if (res_zero) begin
        o_res = 16'h0000;
    end else if (overflow) begin
        o_res = {sign_big, 5'h1F, 10'h000};
    end else if (underflow) begin
        o_res = {sign_big, 15'h0000};
    end else begin
        o_res = {sign_big, res_exp[4:0], res_mant};
    end
end

endmodule
