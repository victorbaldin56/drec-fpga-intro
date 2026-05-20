`include "config.vh"

// MMIO crossbar: decodes CPU MMIO bus and routes writes to peripherals.
// Currently only the hex display is mapped (word address XBAR_HEXD_ADDR0).

module mmio_xbar (
    input  wire [29:0] i_mmio_addr,
    input  wire [31:0] i_mmio_data,
    input  wire  [3:0] i_mmio_mask,
    input  wire        i_mmio_wren,
    output reg  [31:0] o_mmio_data,

    output wire [15:0] o_hexd_data,
    output wire        o_hexd_wren
);

assign o_hexd_data = i_mmio_data[15:0];
assign o_hexd_wren = i_mmio_wren && (i_mmio_addr == `XBAR_HEXD_ADDR0);

always @(*) begin
    case (i_mmio_addr)
        `XBAR_HEXD_ADDR0: o_mmio_data = {16'h0000, i_mmio_data[15:0]};
        default:          o_mmio_data = 32'h00000000;
    endcase
end

endmodule
