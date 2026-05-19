`timescale 1ns/1ps

module rf_2r1w_tb;

reg        clk, rst_n;
reg  [4:0] i_ra1, i_ra2, i_wa;
reg [31:0] i_wd;
reg        i_we;
wire [31:0] o_rd1, o_rd2;

rf_2r1w dut (.clk(clk), .rst_n(rst_n),
             .i_ra1(i_ra1), .i_ra2(i_ra2), .o_rd1(o_rd1), .o_rd2(o_rd2),
             .i_wa(i_wa), .i_wd(i_wd), .i_we(i_we));

always #5 clk = ~clk;

integer failed;

task write_reg;
    input [4:0]  addr;
    input [31:0] data;
    begin
        i_wa = addr; i_wd = data; i_we = 1;
        @(posedge clk);
        i_we = 0;
    end
endtask

task check_rd1;
    input [4:0]  addr;
    input [31:0] expected;
    begin
        i_ra1 = addr; #1;
        if (o_rd1 !== expected) begin
            $display("FAIL x%0d: got=%h expected=%h", addr, o_rd1, expected);
            failed = failed + 1;
        end else
            $display("PASS x%0d = %h", addr, o_rd1);
    end
endtask

initial begin
    clk = 0; rst_n = 0; i_we = 0; i_ra1 = 0; i_ra2 = 0; i_wa = 0; i_wd = 0; failed = 0;
    repeat(2) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    write_reg(5'd1,  32'hDEADBEEF);
    write_reg(5'd2,  32'hCAFEBABE);
    write_reg(5'd31, 32'h12345678);
    write_reg(5'd0,  32'hFFFFFFFF); // should have no effect

    @(posedge clk);

    check_rd1(5'd1,  32'hDEADBEEF);
    check_rd1(5'd2,  32'hCAFEBABE);
    check_rd1(5'd31, 32'h12345678);
    check_rd1(5'd0,  32'h00000000);

    i_ra2 = 5'd2; #1;
    if (o_rd2 !== 32'hCAFEBABE) begin
        $display("FAIL port2 x2: %h", o_rd2); failed=failed+1;
    end else
        $display("PASS port2 x2 = %h", o_rd2);

    if (failed == 0) $display("ALL TESTS PASSED");
    else $display("%0d TEST(S) FAILED", failed);
    $finish;
end

endmodule
