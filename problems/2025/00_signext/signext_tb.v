`timescale 1ns/1ps

module signext_tb;

reg  [11:0] data12;
wire [31:0] out12_beh, out12_str;

signext   #(.N(12), .M(32)) dut_beh_12 (.i_data(data12), .o_data(out12_beh));
signext_s #(.N(12), .M(32)) dut_str_12 (.i_data(data12), .o_data(out12_str));

reg  [19:0] data20;
wire [31:0] out20_beh, out20_str;

signext   #(.N(20), .M(32)) dut_beh_20 (.i_data(data20), .o_data(out20_beh));
signext_s #(.N(20), .M(32)) dut_str_20 (.i_data(data20), .o_data(out20_str));

integer errors;

task check32;
    input [31:0] got_beh;
    input [31:0] got_str;
    input [31:0] expected;
    input [8*16-1:0] label;
    begin
        if (got_beh !== expected || got_str !== expected) begin
            $display("FAIL %s: beh=%h str=%h expected=%h", label, got_beh, got_str, expected);
            errors = errors + 1;
        end else
            $display("PASS %s: %h", label, got_beh);
    end
endtask

initial begin
    errors = 0;

    data12 = 12'h07F; #1;
    check32(out12_beh, out12_str, 32'h0000007F, "N12_pos");

    data12 = 12'hFFF; #1;
    check32(out12_beh, out12_str, 32'hFFFFFFFF, "N12_neg_all1");

    data12 = 12'h800; #1;
    check32(out12_beh, out12_str, 32'hFFFFF800, "N12_neg_min");

    data12 = 12'h000; #1;
    check32(out12_beh, out12_str, 32'h00000000, "N12_zero");

    data20 = 20'h0FFFF; #1;
    check32(out20_beh, out20_str, 32'h0000FFFF, "N20_pos");

    data20 = 20'hFFFFF; #1;
    check32(out20_beh, out20_str, 32'hFFFFFFFF, "N20_neg_all1");

    data20 = 20'h80000; #1;
    check32(out20_beh, out20_str, 32'hFFF80000, "N20_neg_min");

    data20 = 20'h00000; #1;
    check32(out20_beh, out20_str, 32'h00000000, "N20_zero");

    if (errors == 0)
        $display("ALL TESTS PASSED");
    else
        $display("%0d TEST(S) FAILED", errors);

    $finish;
end

endmodule
