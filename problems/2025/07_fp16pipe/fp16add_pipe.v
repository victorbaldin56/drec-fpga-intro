// FP16 adder, 3-stage pipeline.
// Stage 1: unpack, classify, select big/small operand.
// Stage 2: align (shift), add/subtract.
// Stage 3: normalize, assemble output.
// DAZ, FTZ, RTZ rounding. Active-low async reset.

module fp16add_pipe (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] i_a,
    input  wire [15:0] i_b,
    output reg  [15:0] o_res
);

// -----------------------------------------------------------------------
// Stage 1 combinational
// -----------------------------------------------------------------------
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

wire [10:0] a_sig = a_zero ? 11'h000 : {1'b1, a_mant};
wire [10:0] b_sig = b_zero ? 11'h000 : {1'b1, b_mant};

wire        a_larger    = (a_bexp >= b_bexp);
wire [4:0]  s1_exp_big  = a_larger ? a_bexp  : b_bexp;
wire        s1_sign_big = a_larger ? a_sign  : b_sign;
wire        s1_add_op   = (a_sign == b_sign);
wire [10:0] s1_sig_big  = a_larger ? a_sig   : b_sig;
wire [10:0] s1_sig_sml  = a_larger ? b_sig   : a_sig;
wire [4:0]  s1_shift    = s1_exp_big - (a_larger ? b_bexp : a_bexp);

wire s1_inf     = a_inf || b_inf;
wire s1_inf_nan = a_inf && b_inf && (a_sign != b_sign);
wire s1_inf_sgn = a_inf ? a_sign : b_sign;

// -----------------------------------------------------------------------
// Stage 1 -> 2 registers
// -----------------------------------------------------------------------
reg [4:0]  r2_exp_big;
reg        r2_sign_big;
reg        r2_add_op;
reg [10:0] r2_sig_big;
reg [10:0] r2_sig_sml;
reg [4:0]  r2_shift;
reg        r2_inf;
reg        r2_inf_nan;
reg        r2_inf_sgn;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r2_exp_big  <= 5'h0; r2_sign_big <= 1'b0; r2_add_op  <= 1'b0;
        r2_sig_big  <= 11'h0; r2_sig_sml <= 11'h0; r2_shift  <= 5'h0;
        r2_inf <= 1'b0; r2_inf_nan <= 1'b0; r2_inf_sgn <= 1'b0;
    end else begin
        r2_exp_big  <= s1_exp_big;  r2_sign_big <= s1_sign_big;
        r2_add_op   <= s1_add_op;   r2_sig_big  <= s1_sig_big;
        r2_sig_sml  <= s1_sig_sml;  r2_shift    <= s1_shift;
        r2_inf <= s1_inf; r2_inf_nan <= s1_inf_nan; r2_inf_sgn <= s1_inf_sgn;
    end
end

// -----------------------------------------------------------------------
// Stage 2 combinational
// -----------------------------------------------------------------------
wire [4:0]  s2_shift_cap = (r2_shift > 5'd11) ? 5'd11 : r2_shift;
wire [10:0] s2_sig_sml_sh = r2_sig_sml >> s2_shift_cap;

wire [11:0] s2_sum = r2_add_op
    ? ({1'b0, r2_sig_big} + {1'b0, s2_sig_sml_sh})
    : ({1'b0, r2_sig_big} - {1'b0, s2_sig_sml_sh});

// -----------------------------------------------------------------------
// Stage 2 -> 3 registers
// -----------------------------------------------------------------------
reg [11:0] r3_sum;
reg [4:0]  r3_exp_big;
reg        r3_sign_big;
reg        r3_inf;
reg        r3_inf_nan;
reg        r3_inf_sgn;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r3_sum <= 12'h0; r3_exp_big <= 5'h0; r3_sign_big <= 1'b0;
        r3_inf <= 1'b0; r3_inf_nan <= 1'b0; r3_inf_sgn <= 1'b0;
    end else begin
        r3_sum <= s2_sum; r3_exp_big <= r2_exp_big; r3_sign_big <= r2_sign_big;
        r3_inf <= r2_inf; r3_inf_nan <= r2_inf_nan; r3_inf_sgn <= r2_inf_sgn;
    end
end

// -----------------------------------------------------------------------
// Stage 3 combinational + output register
// -----------------------------------------------------------------------
reg [4:0] s3_lz;
always @(*) begin
    casez (r3_sum[11:0])
        12'b1???????????: s3_lz = 5'd0;
        12'b01??????????: s3_lz = 5'd1;
        12'b001?????????: s3_lz = 5'd2;
        12'b0001????????: s3_lz = 5'd3;
        12'b00001???????: s3_lz = 5'd4;
        12'b000001??????: s3_lz = 5'd5;
        12'b0000001?????: s3_lz = 5'd6;
        12'b00000001????: s3_lz = 5'd7;
        12'b000000001???: s3_lz = 5'd8;
        12'b0000000001??: s3_lz = 5'd9;
        12'b00000000001?: s3_lz = 5'd10;
        12'b000000000001: s3_lz = 5'd11;
        default:          s3_lz = 5'd12;
    endcase
end

reg [11:0] s3_norm;
reg  [6:0] s3_exp;
always @(*) begin
    if (s3_lz == 5'd0) begin
        s3_norm = r3_sum >> 1;
        s3_exp  = {2'b00, r3_exp_big} + 7'd1;
    end else if (s3_lz == 5'd1) begin
        s3_norm = r3_sum;
        s3_exp  = {2'b00, r3_exp_big};
    end else begin
        s3_norm = r3_sum << (s3_lz - 5'd1);
        s3_exp  = {2'b00, r3_exp_big} - {2'b00, (s3_lz - 5'd1)};
    end
end

wire [9:0] s3_mant     = s3_norm[9:0];
wire       s3_zero     = (r3_sum == 12'd0) || (s3_lz == 5'd12);
wire       s3_overflow = (s3_exp >= 7'd31);
wire       s3_uflow    = s3_exp[6] || (s3_exp == 7'd0);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_res <= 16'h0000;
    end else begin
        if (r3_inf) begin
            if (r3_inf_nan)
                o_res <= {1'b0, 5'h1F, 10'h000};
            else
                o_res <= {r3_inf_sgn, 5'h1F, 10'h000};
        end else if (s3_zero) begin
            o_res <= 16'h0000;
        end else if (s3_overflow) begin
            o_res <= {r3_sign_big, 5'h1F, 10'h000};
        end else if (s3_uflow) begin
            o_res <= {r3_sign_big, 15'h0000};
        end else begin
            o_res <= {r3_sign_big, s3_exp[4:0], s3_mant};
        end
    end
end

endmodule
