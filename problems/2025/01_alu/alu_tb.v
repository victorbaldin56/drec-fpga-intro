`timescale 1ns/1ps

module alu_tb;

reg  [31:0] a, b;
reg   [3:0] op;
wire [31:0] result;

alu dut (.i_a(a), .i_b(b), .i_op(op), .o_result(result));

integer errors;

task check;
    input [31:0] expected;
    input [8*12-1:0] name;
    begin
        if (result !== expected) begin
            $display("FAIL %s: a=%h b=%h op=%b got=%h expected=%h",
                     name, a, b, op, result, expected);
            errors = errors + 1;
        end else
            $display("PASS %s: %h", name, result);
    end
endtask

initial begin
    errors = 0;

    a = 32'd10;       b = 32'd20;       op = 4'b0000; #1; check(32'd30,           "ADD_basic");
    a = 32'hFFFFFFFF; b = 32'd1;        op = 4'b0000; #1; check(32'h00000000,     "ADD_wrap");
    a = 32'd50;       b = 32'd15;       op = 4'b0001; #1; check(32'd35,           "SUB_basic");
    a = 32'd5;        b = 32'd10;       op = 4'b0001; #1; check(32'hFFFFFFFB,     "SUB_wrap");
    a = 32'h00000001; b = 32'd4;        op = 4'b0010; #1; check(32'h00000010,     "SLL_basic");
    a = 32'h00000001; b = 32'd31;       op = 4'b0010; #1; check(32'h80000000,     "SLL_31");
    a = 32'hFFFFFFFF; b = 32'd1;        op = 4'b0011; #1; check(32'd1,            "SLT_neg");
    a = 32'd5;        b = 32'd5;        op = 4'b0011; #1; check(32'd0,            "SLT_eq");
    a = 32'hFFFFFFFF; b = 32'd1;        op = 4'b0100; #1; check(32'd0,            "SLTU_big");
    a = 32'd1;        b = 32'hFFFFFFFF; op = 4'b0100; #1; check(32'd1,            "SLTU_small");
    a = 32'hA5A5A5A5; b = 32'hFFFFFFFF; op = 4'b0101; #1; check(32'h5A5A5A5A,    "XOR");
    a = 32'h80000000; b = 32'd1;        op = 4'b0110; #1; check(32'h40000000,     "SRL");
    a = 32'h80000000; b = 32'd1;        op = 4'b0111; #1; check(32'hC0000000,     "SRA_neg");
    a = 32'h40000000; b = 32'd1;        op = 4'b0111; #1; check(32'h20000000,     "SRA_pos");
    a = 32'hA0A0A0A0; b = 32'h0F0F0F0F; op = 4'b1000; #1; check(32'hAFAFAFAF,   "OR");
    a = 32'hFFFF0000; b = 32'h0F0F0F0F; op = 4'b1001; #1; check(32'h0F0F0000,    "AND");
    a = 32'd0;        b = 32'd0;        op = 4'b1111; #1; check(32'd0,            "DEFAULT");

    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TEST(S) FAILED", errors);
    $finish;
end

endmodule
