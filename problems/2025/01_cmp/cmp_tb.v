`timescale 1ns/1ps

module cmp_tb;

reg  [31:0] a, b;
reg   [2:0] op;
wire        taken;

cmp dut (.i_a(a), .i_b(b), .i_op(op), .o_taken(taken));

integer errors;

task check;
    input expected;
    input [8*16-1:0] name;
    begin
        if (taken !== expected) begin
            $display("FAIL %s: a=%h b=%h op=%b got=%b expected=%b",
                     name, a, b, op, taken, expected);
            errors = errors + 1;
        end else
            $display("PASS %s", name);
    end
endtask

initial begin
    errors = 0;

    a = 32'd5;        b = 32'd5;        op = 3'b000; #1; check(1, "BEQ_eq");
    a = 32'd5;        b = 32'd6;        op = 3'b000; #1; check(0, "BEQ_neq");
    a = 32'd5;        b = 32'd6;        op = 3'b001; #1; check(1, "BNE_neq");
    a = 32'd5;        b = 32'd5;        op = 3'b001; #1; check(0, "BNE_eq");
    a = 32'hFFFFFFFF; b = 32'd1;        op = 3'b100; #1; check(1, "BLT_neg<pos");
    a = 32'd1;        b = 32'hFFFFFFFF; op = 3'b100; #1; check(0, "BLT_pos>neg");
    a = 32'd5;        b = 32'd5;        op = 3'b100; #1; check(0, "BLT_eq");
    a = 32'd1;        b = 32'hFFFFFFFF; op = 3'b101; #1; check(1, "BGE_pos>=neg");
    a = 32'd5;        b = 32'd5;        op = 3'b101; #1; check(1, "BGE_eq");
    a = 32'hFFFFFFFF; b = 32'd1;        op = 3'b101; #1; check(0, "BGE_neg<pos");
    a = 32'd1;        b = 32'hFFFFFFFF; op = 3'b110; #1; check(1, "BLTU_sml<big");
    a = 32'hFFFFFFFF; b = 32'd1;        op = 3'b110; #1; check(0, "BLTU_big>=sml");
    a = 32'd5;        b = 32'd5;        op = 3'b110; #1; check(0, "BLTU_eq");
    a = 32'hFFFFFFFF; b = 32'd1;        op = 3'b111; #1; check(1, "BGEU_big>=sml");
    a = 32'd5;        b = 32'd5;        op = 3'b111; #1; check(1, "BGEU_eq");
    a = 32'd1;        b = 32'hFFFFFFFF; op = 3'b111; #1; check(0, "BGEU_sml<big");
    a = 32'd0;        b = 32'd0;        op = 3'b010; #1; check(0, "DEFAULT");

    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TEST(S) FAILED", errors);
    $finish;
end

endmodule
