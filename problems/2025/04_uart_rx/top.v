// Board top-level for 04_uart_rx.
// Receives bytes over UART and displays them on a 4-digit 7-segment display.
//
// Tested target: Altera Cyclone IV E, 50 MHz board oscillator.
// Adapt pin assignments in Quartus Pin Planner to match your board.
//
// Connections (external CH340/CP2102/FT232 USB-UART adapter):
//   adapter TX  →  uart_rxd GPIO pin   (FPGA receives)
//   adapter GND →  board GND           (common ground)
//   Use 3.3 V logic level on the adapter.

module top #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input  wire       clk,       // 50 MHz board oscillator
    input  wire       rst_n,     // active-low reset (board push-button)
    input  wire       uart_rxd,  // UART RX from USB-UART adapter TX pin

    // 7-segment display (active-low segments and anodes)
    output wire [6:0] seg,       // segments a..g
    output wire       dp,        // decimal point (always off)
    output wire [3:0] an         // digit anodes, active-low
);

wire [7:0] rx_data;
wire       rx_valid;

uart_rx #(
    .CLK_FREQ (CLK_FREQ ),
    .BAUD_RATE(BAUD_RATE)
) u_rx (
    .clk    (clk     ),
    .rst_n  (rst_n   ),
    .i_rx   (uart_rxd),
    .o_data (rx_data ),
    .o_valid(rx_valid)
);

wire [7:0] seg_full;

hex_display #(
    .CLK_FREQ(CLK_FREQ)
) u_disp (
    .clk       (clk              ),
    .rst_n     (rst_n            ),
    .i_data    ({8'h00, rx_data} ),  // received byte on rightmost 2 digits
    .i_we      (rx_valid         ),
    .o_anodes  (an               ),
    .o_segments(seg_full         )
);

// seg_full = {dp, g, f, e, d, c, b, a}
assign dp  = seg_full[7];
assign seg = seg_full[6:0];

endmodule
