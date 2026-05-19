`timescale 1ns/1ps

module shiftreg_tb;

reg       clk, rst_n;
reg [7:0] i_data;
reg       i_load, i_en;
wire      o_bit;

shiftreg dut (.clk(clk), .rst_n(rst_n), .i_data(i_data),
              .i_load(i_load), .i_en(i_en), .o_bit(o_bit));

always #5 clk = ~clk;

localparam [7:0] TEST_VAL = 8'hA5; // 10100101

integer i, failed;
reg expected;

initial begin
    clk = 0; rst_n = 0; i_data = 0; i_load = 0; i_en = 0; failed = 0;
    repeat(2) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    i_data = TEST_VAL; i_load = 1;
    @(posedge clk);
    i_load = 0; i_en = 1;

    for (i = 0; i < 8; i = i + 1) begin
        expected = TEST_VAL[i];
        if (o_bit !== expected) begin
            $display("FAIL bit[%0d]: got=%b expected=%b", i, o_bit, expected);
            failed = failed + 1;
        end else
            $display("PASS bit[%0d]=%b", i, o_bit);
        @(posedge clk);
    end

    i_en = 0;
    if (failed == 0) $display("ALL TESTS PASSED");
    else $display("%0d TEST(S) FAILED", failed);
    $finish;
end

endmodule
