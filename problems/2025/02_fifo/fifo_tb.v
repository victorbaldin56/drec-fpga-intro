`timescale 1ns/1ps

module fifo_tb;

parameter DEPTH_LOG2 = 4;
parameter WIDTH      = 8;
parameter DEPTH      = 1 << DEPTH_LOG2;

reg              clk, rst_n;
reg  [WIDTH-1:0] i_data;
reg              i_push, i_pop;
wire [WIDTH-1:0] o_data;
wire             o_full, o_empty;

fifo #(.DEPTH_LOG2(DEPTH_LOG2), .WIDTH(WIDTH)) dut (
    .clk(clk), .rst_n(rst_n), .i_data(i_data), .i_push(i_push),
    .i_pop(i_pop), .o_data(o_data), .o_full(o_full), .o_empty(o_empty)
);

always #5 clk = ~clk;

integer i, failed;
reg [WIDTH-1:0] expected;

initial begin
    clk = 0; rst_n = 0; i_push = 0; i_pop = 0; i_data = 0; failed = 0;
    repeat(2) @(posedge clk);
    rst_n = 1; @(posedge clk);

    if (!o_empty) begin $display("FAIL: not empty after reset"); failed=failed+1; end
    else $display("PASS: empty after reset");

    i_push = 1;
    for (i = 0; i < DEPTH; i = i + 1) begin
        i_data = i[WIDTH-1:0];
        @(posedge clk);
    end
    i_push = 0; @(posedge clk);

    if (!o_full) begin $display("FAIL: not full after %0d pushes", DEPTH); failed=failed+1; end
    else $display("PASS: full after %0d pushes", DEPTH);

    i_pop = 1;
    for (i = 0; i < DEPTH; i = i + 1) begin
        expected = i[WIDTH-1:0];
        if (o_data !== expected) begin
            $display("FAIL pop[%0d]: got=%h expected=%h", i, o_data, expected);
            failed = failed + 1;
        end else
            $display("PASS pop[%0d]=%h", i, o_data);
        @(posedge clk);
    end
    i_pop = 0; @(posedge clk);

    if (!o_empty) begin $display("FAIL: not empty after drain"); failed=failed+1; end
    else $display("PASS: empty after drain");

    if (failed == 0) $display("ALL TESTS PASSED");
    else $display("%0d TEST(S) FAILED", failed);
    $finish;
end

endmodule
