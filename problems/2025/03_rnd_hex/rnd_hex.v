// Top-level module: 16-bit LFSR output displayed on a 4-digit 7-segment
// display.  All sub-modules are defined inline in this file.
//
// Sub-modules:
//   lfsr16      - 16-bit Galois LFSR, polynomial x^16+x^14+x^13+x^11+1
//   hex_display - 4-digit multiplexed 7-segment controller (copy from 03_hex_display)
//   rnd_hex     - top-level wrapper

// ---------------------------------------------------------------------------
// 16-bit Galois LFSR
// Polynomial: x^16 + x^14 + x^13 + x^11 + 1
// Taps (XOR feedback into): bits 16(msb carry), 14, 13, 11
// In Galois form the feedback taps are at positions 14, 13, 11 (0-indexed
// from LSB: bits 13, 12, 10).
// Seed: 16'hACE1 (non-zero)
// ---------------------------------------------------------------------------
module lfsr16 (
    input             clk,
    input             rst_n,
    output reg [15:0] o_data
);
    wire feedback = o_data[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_data <= 16'hACE1;
        end else begin
            // Galois LFSR shift: feedback XOR'd into tap positions
            // Taps at bit positions 15(msb->0), 13, 12, 10 (for x^16,x^14,x^13,x^11)
            o_data[15] <= feedback;
            o_data[14] <= o_data[15];
            o_data[13] <= o_data[14] ^ feedback; // x^14 tap
            o_data[12] <= o_data[13] ^ feedback; // x^13 tap
            o_data[11] <= o_data[12];
            o_data[10] <= o_data[11] ^ feedback; // x^11 tap
            o_data[9]  <= o_data[10];
            o_data[8]  <= o_data[9];
            o_data[7]  <= o_data[8];
            o_data[6]  <= o_data[7];
            o_data[5]  <= o_data[6];
            o_data[4]  <= o_data[5];
            o_data[3]  <= o_data[4];
            o_data[2]  <= o_data[3];
            o_data[1]  <= o_data[2];
            o_data[0]  <= o_data[1];
        end
    end
endmodule

// ---------------------------------------------------------------------------
// 4-digit multiplexed 7-segment hex display controller
// (Identical to 03_hex_display/hex_display.v - inlined here so this file is
//  self-contained.)
// ---------------------------------------------------------------------------
module hex_display_rh #(
    parameter CLK_FREQ = 50_000_000
) (
    input             clk,
    input             rst_n,
    input  [15:0]     i_data,
    input             i_we,
    output reg [3:0]  o_anodes,
    output reg [7:0]  o_segments
);

    reg [15:0] data_reg;

    localparam integer DIV_MAX = CLK_FREQ / 50000 - 1;

    reg [15:0] div_cnt;
    reg        tick;
    reg [1:0]  digit_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_reg <= 16'h0000;
        else if (i_we)
            data_reg <= i_data;
    end

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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            digit_idx <= 2'd0;
        else if (tick)
            digit_idx <= digit_idx + 1'b1;
    end

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

    always @(*) begin
        case (digit_idx)
            2'd3: o_anodes = 4'b0111;
            2'd2: o_anodes = 4'b1011;
            2'd1: o_anodes = 4'b1101;
            2'd0: o_anodes = 4'b1110;
            default: o_anodes = 4'b1111;
        endcase
    end

    always @(*) begin
        case (nibble)
            4'h0: o_segments = 8'b1100_0000;
            4'h1: o_segments = 8'b1111_1001;
            4'h2: o_segments = 8'b1010_0100;
            4'h3: o_segments = 8'b1011_0000;
            4'h4: o_segments = 8'b1001_1001;
            4'h5: o_segments = 8'b1001_0010;
            4'h6: o_segments = 8'b1000_0010;
            4'h7: o_segments = 8'b1111_1000;
            4'h8: o_segments = 8'b1000_0000;
            4'h9: o_segments = 8'b1001_0000;
            4'hA: o_segments = 8'b1000_1000;
            4'hB: o_segments = 8'b1000_0011;
            4'hC: o_segments = 8'b1100_0110;
            4'hD: o_segments = 8'b1010_0001;
            4'hE: o_segments = 8'b1000_0110;
            4'hF: o_segments = 8'b1000_1110;
            default: o_segments = 8'b1111_1111;
        endcase
    end

endmodule

// ---------------------------------------------------------------------------
// Top-level: rnd_hex
// The LFSR runs every clock cycle.  i_we is permanently asserted so the
// display always tracks the live LFSR output.
// ---------------------------------------------------------------------------
module rnd_hex #(
    parameter CLK_FREQ = 50_000_000
) (
    input        clk,
    input        rst_n,
    output [3:0] o_anodes,
    output [7:0] o_segments
);

    wire [15:0] lfsr_data;

    lfsr16 u_lfsr (
        .clk   (clk),
        .rst_n (rst_n),
        .o_data(lfsr_data)
    );

    hex_display_rh #(.CLK_FREQ(CLK_FREQ)) u_display (
        .clk        (clk),
        .rst_n      (rst_n),
        .i_data     (lfsr_data),
        .i_we       (1'b1),       // always update
        .o_anodes   (o_anodes),
        .o_segments (o_segments)
    );

endmodule
