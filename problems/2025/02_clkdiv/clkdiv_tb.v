`timescale 1ns/1ps

module clkdiv_tb;

parameter CLK_IN_FREQ = 50_000_000;

reg        clk, rst_n;
reg  [1:0] i_sel;
wire       o_clk;

clkdiv #(.CLK_IN_FREQ(CLK_IN_FREQ)) dut (
    .clk(clk), .rst_n(rst_n), .i_sel(i_sel), .o_clk(o_clk)
);

always #10 clk = ~clk;

integer edge_count;
integer i;
integer failed;

initial begin
    clk    = 0;
    rst_n  = 0;
    i_sel  = 0;
    failed = 0;
    repeat(4) @(posedge clk);
    rst_n = 1;

    // sel=0 (9600 Hz): 50e6/9600/2 = ~2604 clk cycles per half period
    // Run 6000 system clocks -> expect ~2 toggles minimum
    i_sel = 2'd0;
    edge_count = 0;
    fork
        begin repeat(6000) @(posedge clk); end
        begin forever begin @(o_clk); edge_count = edge_count + 1; end end
    join_any
    if (edge_count >= 2) $display("PASS sel=0 (9600 Hz): %0d toggles", edge_count);
    else begin $display("FAIL sel=0: only %0d toggles", edge_count); failed=failed+1; end

    // sel=2 (115200 Hz): 50e6/115200/2 = ~217 clk cycles per half period
    i_sel = 2'd2;
    edge_count = 0;
    fork
        begin repeat(2000) @(posedge clk); end
        begin forever begin @(o_clk); edge_count = edge_count + 1; end end
    join_any
    if (edge_count >= 4) $display("PASS sel=2 (115200 Hz): %0d toggles", edge_count);
    else begin $display("FAIL sel=2: only %0d toggles", edge_count); failed=failed+1; end

    if (failed == 0) $display("ALL TESTS PASSED");
    else $display("%0d TEST(S) FAILED", failed);
    $finish;
end

endmodule
