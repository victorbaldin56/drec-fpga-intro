// 7-segment display controller for 16-bit hex numbers on a 4-digit
// multiplexed display.
//
// Digit mapping (active-low anodes, one-hot):
//   o_anodes[3] = leftmost  -> i_data[15:12]
//   o_anodes[2]             -> i_data[11:8]
//   o_anodes[1]             -> i_data[7:4]
//   o_anodes[0] = rightmost -> i_data[3:0]
//
// Segment encoding (active-HIGH): bit[7:0] = {A, B, C, D, E, F, G, DP}
// Refresh rate: CLK_FREQ / 50000 ~= 1 kHz per digit slot

module hex_display #(
    parameter CLK_FREQ = 50_000_000
) (
    input             clk,
    input             rst_n,
    input  [15:0]     i_data,
    input             i_we,
    output reg [3:0]  o_anodes,
    output reg [7:0]  o_segments
);

// ---------------------------------------------------------------------------
// Internal registers
// ---------------------------------------------------------------------------
reg [15:0] data_reg;

// Divide CLK_FREQ by 50000 to get ~1 kHz tick per digit slot.
localparam integer DIV_MAX = CLK_FREQ / 50000 - 1;

reg [15:0] div_cnt;
reg        tick;

// Current digit index: 0..3
reg [1:0] digit_idx;

// ---------------------------------------------------------------------------
// Data latch
// ---------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_reg <= 16'h0000;
    else if (i_we)
        data_reg <= i_data;
end

// ---------------------------------------------------------------------------
// Clock divider - produces one-cycle 'tick' every DIV_MAX+1 clocks
// ---------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_cnt <= 0;
        tick    <= 1'b0;
    end else begin
        if (div_cnt == DIV_MAX[15:0]) begin
            div_cnt <= 0;
            tick    <= 1'b1;
        end else begin
            div_cnt <= div_cnt + 1'b1;
            tick    <= 1'b0;
        end
    end
end

// ---------------------------------------------------------------------------
// Digit sequencer
// ---------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        digit_idx <= 2'd0;
    else if (tick)
        digit_idx <= digit_idx + 1'b1;
end

// ---------------------------------------------------------------------------
// Digit nibble selection
// ---------------------------------------------------------------------------
reg [3:0] nibble;
always @(*) begin
    case (digit_idx)
        2'd3: nibble = data_reg[15:12];
        2'd2: nibble = data_reg[11:8];
        2'd1: nibble = data_reg[7:4];
        2'd0: nibble = data_reg[3:0];
        default: nibble = 4'h0;
    endcase
end

// ---------------------------------------------------------------------------
// Anode driver (active low, one-hot)
// digit_idx 3 = leftmost digit = anodes[3] low
// digit_idx 0 = rightmost digit = anodes[0] low
// ---------------------------------------------------------------------------
always @(*) begin
    case (digit_idx)
        2'd3: o_anodes = 4'b0111;
        2'd2: o_anodes = 4'b1011;
        2'd1: o_anodes = 4'b1101;
        2'd0: o_anodes = 4'b1110;
        default: o_anodes = 4'b1111;
    endcase
end

// ---------------------------------------------------------------------------
// 7-segment hex decoder
// Board: active-HIGH segments, bit order {A, B, C, D, E, F, G, DP}
//   bit7=A  bit6=B  bit5=C  bit4=D  bit3=E  bit2=F  bit1=G  bit0=DP
// ---------------------------------------------------------------------------
always @(*) begin
    case (nibble)
        4'h0: o_segments = 8'b1111_1100; // 0: A,B,C,D,E,F
        4'h1: o_segments = 8'b0110_0000; // 1: B,C
        4'h2: o_segments = 8'b1101_1010; // 2: A,B,D,E,G
        4'h3: o_segments = 8'b1111_0010; // 3: A,B,C,D,G
        4'h4: o_segments = 8'b0110_0110; // 4: B,C,F,G
        4'h5: o_segments = 8'b1011_0110; // 5: A,C,D,F,G
        4'h6: o_segments = 8'b1011_1110; // 6: A,C,D,E,F,G
        4'h7: o_segments = 8'b1110_0000; // 7: A,B,C
        4'h8: o_segments = 8'b1111_1110; // 8: all
        4'h9: o_segments = 8'b1111_0110; // 9: A,B,C,D,F,G
        4'hA: o_segments = 8'b1110_1110; // A: A,B,C,E,F,G
        4'hB: o_segments = 8'b0011_1110; // b: C,D,E,F,G
        4'hC: o_segments = 8'b1001_1100; // C: A,D,E,F
        4'hD: o_segments = 8'b0111_1010; // d: B,C,D,E,G
        4'hE: o_segments = 8'b1001_1110; // E: A,D,E,F,G
        4'hF: o_segments = 8'b1000_1110; // F: A,E,F,G
        default: o_segments = 8'b0000_0000;
    endcase
end

endmodule
