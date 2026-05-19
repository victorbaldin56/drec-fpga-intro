`timescale 1ns/1ps

// Testbench for uart_rx.
// Sends bytes 0xA5 and 0x3C via uart_tx, checks that uart_rx receives them.
// CLK_FREQ = 50_000_000, BAUD_RATE = 115200
// Bit period = 50000000/115200 ~= 434 clocks = 8680 ns at 5ns/clock.
// Two UART frames (10 bits each) = 8680 ns * 20 = 173600 ns + margin.
// We run 250000 clock cycles to be safe.

module uart_rx_tb;

    parameter CLK_FREQ  = 50_000_000;
    parameter BAUD_RATE = 115200;

    reg clk;
    reg rst_n;

    // TX side
    reg  [7:0] tx_data;
    reg        tx_valid;
    wire       tx_serial;
    wire       tx_busy;

    // RX side
    wire [7:0] rx_data;
    wire       rx_valid;

    // DUTs
    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_tx (
        .clk    (clk),
        .rst_n  (rst_n),
        .i_data (tx_data),
        .i_valid(tx_valid),
        .o_tx   (tx_serial),
        .o_busy (tx_busy)
    );

    uart_rx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_rx (
        .clk    (clk),
        .rst_n  (rst_n),
        .i_rx   (tx_serial),
        .o_data (rx_data),
        .o_valid(rx_valid)
    );

    // 10 ns clock (100 MHz - close enough to 50 MHz for divider math;
    // use 5 ns for 100 MHz so CLKS_PER_BIT = 868 which is adequate)
    // Actually let's use 5 ns (200 MHz) - we override nothing, the DUT
    // parameters define the dividers.  Use 10 ns (100 MHz) for speed.
    // The DUT is parameterised for 50 MHz; use a 20 ns clock (50 MHz).
    initial clk = 1'b0;
    always #10 clk = ~clk; // 20 ns period = 50 MHz

    // Result tracking
    integer pass_count;
    integer fail_count;
    reg [7:0] expected [0:1];

    always @(posedge clk) begin
        if (rx_valid) begin
            if (rx_data === expected[pass_count + fail_count]) begin
                $display("RECEIVED byte %0d: 0x%02X  -- PASS",
                         pass_count + fail_count, rx_data);
                pass_count = pass_count + 1;
            end else begin
                $display("RECEIVED byte %0d: 0x%02X (expected 0x%02X)  -- FAIL",
                         pass_count + fail_count, rx_data,
                         expected[pass_count + fail_count]);
                fail_count = fail_count + 1;
            end
        end
    end

    // Task: send one byte and wait until TX is idle again
    task send_byte;
        input [7:0] data;
        begin
            @(posedge clk);
            tx_data  = data;
            tx_valid = 1'b1;
            @(posedge clk);
            tx_valid = 1'b0;
            // Wait until TX finishes (busy goes low)
            wait (!tx_busy);
            // Extra guard cycles between bytes
            repeat(10) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("uart_rx_tb.vcd");
        $dumpvars(0, uart_rx_tb);

        pass_count = 0;
        fail_count = 0;
        expected[0] = 8'hA5;
        expected[1] = 8'h3C;

        rst_n    = 1'b0;
        tx_data  = 8'h00;
        tx_valid = 1'b0;

        repeat(10) @(posedge clk);
        rst_n = 1'b1;
        repeat(5)  @(posedge clk);

        $display("Sending 0xA5...");
        send_byte(8'hA5);

        $display("Sending 0x3C...");
        send_byte(8'h3C);

        // Wait a bit more for the RX to process the last byte
        repeat(1000) @(posedge clk);

        $display("---");
        if (pass_count == 2 && fail_count == 0)
            $display("ALL TESTS PASSED (%0d/2)", pass_count);
        else
            $display("TESTS FAILED: %0d passed, %0d failed", pass_count, fail_count);

        $finish;
    end

endmodule
