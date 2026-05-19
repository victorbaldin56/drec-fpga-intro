`timescale 1ns/1ps

// Testbench for hex_display.
// Uses CLK_FREQ=1000 to keep simulation fast while exercising all digit slots.
// Sets i_data = 16'hABCD, pulses i_we for one cycle, then runs long enough to
// observe all four digits being multiplexed.

module hex_display_tb;

    // Use a small CLK_FREQ so DIV_MAX = 1000/50000-1 would be 0; use 50000
    // as CLK_FREQ to match exactly the divider boundary while keeping sim time
    // reasonable with a 1ns clock.
    parameter CLK_FREQ = 50_000;

    reg        clk;
    reg        rst_n;
    reg [15:0] i_data;
    reg        i_we;
    wire [3:0] o_anodes;
    wire [7:0] o_segments;

    // DUT
    hex_display #(.CLK_FREQ(CLK_FREQ)) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .i_data     (i_data),
        .i_we       (i_we),
        .o_anodes   (o_anodes),
        .o_segments (o_segments)
    );

    // 10 ns clock period -> 100 MHz (CLK_FREQ not used for real timing here,
    // only the parameter matters for divider math)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Monitor changes
    always @(posedge clk) begin
        if (!o_anodes[3]) $display("t=%0t  digit3 (MS) anodes=%b seg=%b", $time, o_anodes, o_segments);
        if (!o_anodes[2]) $display("t=%0t  digit2       anodes=%b seg=%b", $time, o_anodes, o_segments);
        if (!o_anodes[1]) $display("t=%0t  digit1       anodes=%b seg=%b", $time, o_anodes, o_segments);
        if (!o_anodes[0]) $display("t=%0t  digit0 (LS) anodes=%b seg=%b", $time, o_anodes, o_segments);
    end

    integer i;
    initial begin
        $dumpfile("hex_display_tb.vcd");
        $dumpvars(0, hex_display_tb);

        // Reset
        rst_n  = 1'b0;
        i_data = 16'h0000;
        i_we   = 1'b0;
        repeat(4) @(posedge clk);

        rst_n = 1'b1;
        @(posedge clk);

        // Write 0xABCD
        i_data = 16'hABCD;
        i_we   = 1'b1;
        @(posedge clk);
        i_we   = 1'b0;

        $display("Wrote 0xABCD. Simulating display refresh cycles...");

        // Run enough clocks to see 8 full digit cycles (8 * DIV_MAX clocks)
        // DIV_MAX = CLK_FREQ/50000 - 1 = 0 when CLK_FREQ=50000, so each tick
        // every 1 clock.  Run 40 clocks to cycle through digits several times.
        repeat(200) @(posedge clk);

        $display("Simulation complete.");
        $finish;
    end

endmodule
