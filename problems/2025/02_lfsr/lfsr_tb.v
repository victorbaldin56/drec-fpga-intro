`timescale 1ns/1ps

module lfsr_tb;

reg        clk, rst_n;
wire [7:0] o_data;

lfsr dut (.clk(clk), .rst_n(rst_n), .o_data(o_data));

always #5 clk = ~clk;

integer i, failed;

initial begin
    clk    = 0;
    rst_n  = 0;
    failed = 0;
    repeat(2) @(posedge clk);
    rst_n = 1;

    for (i = 0; i < 300; i = i + 1) begin
        @(posedge clk);
        #1;
        $display("cycle %3d: %08b (%h)", i, o_data, o_data);
        if (o_data === 8'h00) begin
            $display("FAIL: zero at cycle %0d", i);
            failed = failed + 1;
        end
    end

    if (failed == 0) $display("PASS: no zero in 300 cycles");
    else $display("FAIL: %0d zero(s)", failed);
    $finish;
end

endmodule
