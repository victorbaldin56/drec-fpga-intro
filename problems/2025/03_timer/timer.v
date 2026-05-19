// Countdown timer: 60.0 s -> 0.0 s in 1/10 s steps, displayed on a
// 4-digit multiplexed 7-segment display.
//
// Display layout (active-low anodes):
//   o_anodes[3] = digit3 (tens of seconds, 0-6)
//   o_anodes[2] = digit2 (ones of seconds, 0-9) + decimal point
//   o_anodes[1] = digit1 (tenths of seconds, 0-9)
//   o_anodes[0] = blank
//
// Example: count=600 -> "60.0", count=599 -> "59.9", count=0 -> " 0.0"
// After reaching 0 the counter wraps back to 600 and loops.

module timer #(
    parameter CLK_FREQ = 50_000_000
) (
    input        clk,
    input        rst_n,
    output [3:0] o_anodes,
    output [7:0] o_segments
);

// ---------------------------------------------------------------------------
// 10 Hz tick generator (counts CLK_FREQ/10 clocks)
// ---------------------------------------------------------------------------
localparam integer TICK_MAX = CLK_FREQ / 10 - 1;

reg [25:0] tick_cnt;
reg        tick_10hz;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tick_cnt  <= 0;
        tick_10hz <= 1'b0;
    end else begin
        if (tick_cnt == TICK_MAX[25:0]) begin
            tick_cnt  <= 0;
            tick_10hz <= 1'b1;
        end else begin
            tick_cnt  <= tick_cnt + 1'b1;
            tick_10hz <= 1'b0;
        end
    end
end

// ---------------------------------------------------------------------------
// Countdown counter: 600 down to 0 (tenths of seconds)
// ---------------------------------------------------------------------------
reg [9:0] count; // 0..600

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        count <= 10'd600;
    else if (tick_10hz) begin
        if (count == 10'd0)
            count <= 10'd600;
        else
            count <= count - 1'b1;
    end
end

// ---------------------------------------------------------------------------
// BCD decomposition
//   digit3 = count / 100        (tens of seconds: 0-6)
//   digit2 = (count / 10) % 10  (ones of seconds: 0-9)
//   digit1 = count % 10         (tenths: 0-9)
// ---------------------------------------------------------------------------
reg [3:0] digit3, digit2, digit1;

always @(*) begin
    // Integer division implemented with subtraction-based lookup is too large;
    // use Verilog / and % operators (supported by Icarus for constant-RHS
    // and synthesised as combinational dividers).
    digit3 = count / 100;
    digit2 = (count / 10) % 10;
    digit1 = count % 10;
end

// ---------------------------------------------------------------------------
// Display multiplexer: ~1 kHz refresh (DIV_MAX clocks per digit slot)
// ---------------------------------------------------------------------------
localparam integer DIV_MAX = CLK_FREQ / 50000 - 1;

reg [15:0] div_cnt;
reg        disp_tick;
reg [1:0]  digit_idx;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_cnt   <= 0;
        disp_tick <= 1'b0;
    end else begin
        if (div_cnt == DIV_MAX[15:0]) begin
            div_cnt   <= 0;
            disp_tick <= 1'b1;
        end else begin
            div_cnt   <= div_cnt + 1'b1;
            disp_tick <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        digit_idx <= 2'd0;
    else if (disp_tick)
        digit_idx <= digit_idx + 1'b1;
end

// ---------------------------------------------------------------------------
// Anode and nibble selection
// digit_idx cycles 0..3; we map:
//   idx 3 -> digit3 (tens of seconds)   anode[3] low
//   idx 2 -> digit2 (ones of seconds)   anode[2] low  + DP
//   idx 1 -> digit1 (tenths)            anode[1] low
//   idx 0 -> blank                      anode[0] high (off)
// ---------------------------------------------------------------------------
reg [3:0]  cur_nibble;
reg        show_dp;
reg [3:0]  o_anodes_r;

always @(*) begin
    case (digit_idx)
        2'd3: begin
            cur_nibble  = digit3;
            show_dp     = 1'b0;
            o_anodes_r  = 4'b0111; // anode[3] low
        end
        2'd2: begin
            cur_nibble  = digit2;
            show_dp     = 1'b1;   // decimal point after ones digit
            o_anodes_r  = 4'b1011; // anode[2] low
        end
        2'd1: begin
            cur_nibble  = digit1;
            show_dp     = 1'b0;
            o_anodes_r  = 4'b1101; // anode[1] low
        end
        default: begin             // idx 0 -> blank digit
            cur_nibble  = 4'hF;   // will display blank via special handling
            show_dp     = 1'b0;
            o_anodes_r  = 4'b1111; // all anodes high = all digits off
        end
    endcase
end

assign o_anodes = o_anodes_r;

// ---------------------------------------------------------------------------
// 7-segment decoder for digits 0-9, plus blank (F treated as blank here)
// Segment order: {DP, G, F, E, D, C, B, A} active-low
// DP bit: 0 = on, 1 = off (active low)
// ---------------------------------------------------------------------------
reg [7:0] seg_base;
always @(*) begin
    case (cur_nibble)
        4'd0: seg_base = 8'b1100_0000; // 0
        4'd1: seg_base = 8'b1111_1001; // 1
        4'd2: seg_base = 8'b1010_0100; // 2
        4'd3: seg_base = 8'b1011_0000; // 3
        4'd4: seg_base = 8'b1001_1001; // 4
        4'd5: seg_base = 8'b1001_0010; // 5
        4'd6: seg_base = 8'b1000_0010; // 6
        4'd7: seg_base = 8'b1111_1000; // 7
        4'd8: seg_base = 8'b1000_0000; // 8
        4'd9: seg_base = 8'b1001_0000; // 9
        default: seg_base = 8'b1111_1111; // blank
    endcase
end

// Apply DP: bit 7 = 0 means DP on (active-low)
assign o_segments = show_dp ? {1'b0, seg_base[6:0]} : seg_base;

endmodule
