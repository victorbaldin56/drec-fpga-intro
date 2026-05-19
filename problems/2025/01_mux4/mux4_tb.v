`timescale 1ns/1ps

module mux4_tb;

parameter WIDTH = 8;

reg [WIDTH-1:0] d0, d1, d2, d3;
reg [1:0]       sel;
wire [WIDTH-1:0] out;

mux4 #(.WIDTH(WIDTH)) dut (
    .i_d0(d0), .i_d1(d1), .i_d2(d2), .i_d3(d3),
    .i_sel(sel), .o_data(out)
);

integer errors;

initial begin
    errors = 0;
    d0 = 8'hAA; d1 = 8'hBB; d2 = 8'hCC; d3 = 8'hDD;

    sel = 2'b00; #1;
    if (out !== 8'hAA) begin $display("FAIL sel=00"); errors=errors+1; end
    else $display("PASS sel=00: %h", out);

    sel = 2'b01; #1;
    if (out !== 8'hBB) begin $display("FAIL sel=01"); errors=errors+1; end
    else $display("PASS sel=01: %h", out);

    sel = 2'b10; #1;
    if (out !== 8'hCC) begin $display("FAIL sel=10"); errors=errors+1; end
    else $display("PASS sel=10: %h", out);

    sel = 2'b11; #1;
    if (out !== 8'hDD) begin $display("FAIL sel=11"); errors=errors+1; end
    else $display("PASS sel=11: %h", out);

    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TEST(S) FAILED", errors);
    $finish;
end

endmodule
