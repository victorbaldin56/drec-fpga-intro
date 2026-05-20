// FPGA top-level for 04_uart_rx.
// Board: Altera Cyclone IV E EP4CE15F23C8, 50 MHz oscillator.
//
// Receives bytes over UART at 115200 baud and displays the last received
// byte as two hex digits on the right-most digits of the 4-digit 7-segment
// display (driven via a 74HC595 shift register on the board).
//
// Wiring:
//   USB-UART adapter TX  →  RXD pin (PIN_V1)
//   USB-UART adapter GND →  board GND  (3.3 V logic)

module fpga_top (
    input  wire CLK,    // 50 MHz board oscillator   (PIN_T22)
    input  wire RSTN,   // Active-low reset button    (PIN_U20)
    input  wire RXD,    // UART RX from adapter TX    (PIN_V1)
    // 74HC595 serial shift-register driving the 7-segment display
    output wire DS,     // Serial data                (PIN_AA1)
    output wire OE,     // Output enable, active-low  (PIN_Y2)
    output wire SHCP,   // Shift clock                (PIN_W1)
    output wire STCP    // Storage/latch clock        (PIN_Y1)
);

// Two-FF reset synchroniser (async assert, sync release)
reg rstn_d, rst_n;
always @(posedge CLK or negedge RSTN) begin
    if (!RSTN) begin
        rstn_d <= 1'b0;
        rst_n  <= 1'b0;
    end else begin
        rstn_d <= 1'b1;
        rst_n  <= rstn_d;
    end
end

// UART receiver
wire [7:0] rx_data;
wire       rx_valid;

uart_rx #(
    .CLK_FREQ (50_000_000),
    .BAUD_RATE(115200)
) u_rx (
    .clk    (CLK     ),
    .rst_n  (rst_n   ),
    .i_rx   (RXD     ),
    .o_data (rx_data ),
    .o_valid(rx_valid)
);

// Multiplexed 4-digit hex display controller
wire [3:0] anodes;
wire [7:0] segments;

hex_display #(
    .CLK_FREQ(50_000_000)
) u_disp (
    .clk       (CLK              ),
    .rst_n     (rst_n            ),
    .i_data    ({8'h00, rx_data} ),
    .i_we      (rx_valid         ),
    .o_anodes  (anodes           ),
    .o_segments(segments         )
);

// 74HC595 serial driver – packs {segments[7:0], anodes[3:0]} → 12-bit word
ctrl_74hc595 u_ctrl (
    .clk    (CLK                ),
    .rst_n  (rst_n              ),
    .i_data ({segments, anodes} ),
    .o_stcp (STCP               ),
    .o_shcp (SHCP               ),
    .o_ds   (DS                 ),
    .o_oe   (OE                 )
);

endmodule
