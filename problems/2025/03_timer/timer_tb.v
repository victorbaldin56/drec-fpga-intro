`timescale 1ns/1ps

// Testbench for timer module.
// Uses CLK_FREQ=1000 to make simulation fast.
// At 1000 Hz: 10 Hz tick every 100 clocks, so 600 ticks = 60000 clocks.
// We simulate 70000 clocks to see the full 60.0->0.0 countdown and wrap.

module timer_tb;

    parameter CLK_FREQ = 1000;

    reg        clk;
    reg        rst_n;
    wire [3:0] o_anodes;
    wire [7:0] o_segments;

    timer #(.CLK_FREQ(CLK_FREQ)) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .o_anodes   (o_anodes),
        .o_segments (o_segments)
    );

    // 1 us clock period
    initial clk = 1'b0;
    always #500 clk = ~clk;

    // Expose internal count for monitoring (hierarchical reference)
    // Print count value every 10 Hz tick
    integer prev_count;
    initial prev_count = -1;

    always @(posedge clk) begin
        if (dut.count !== prev_count) begin
            $display("t=%0t us  count=%0d  (= %0d.%0ds)",
                     $time/1000,
                     dut.count,
                     dut.count / 10,
                     dut.count % 10);
            prev_count = dut.count;
        end
    end

    initial begin
        $dumpfile("timer_tb.vcd");
        $dumpvars(0, timer_tb);

        rst_n = 1'b0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;

        $display("Timer started. CLK_FREQ=%0d Hz. Simulating full countdown...", CLK_FREQ);

        // Full countdown: 601 ticks * (CLK_FREQ/10) clocks each + margin
        repeat(65000) @(posedge clk);

        $display("Simulation done.");
        $finish;
    end

endmodule
