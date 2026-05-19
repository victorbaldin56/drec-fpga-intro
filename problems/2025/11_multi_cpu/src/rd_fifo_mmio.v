// Core 1 MMIO: read port from async FIFO plus hex display output.
//
// MMIO word address map:
//   0x000 (byte 0x00): read  → FIFO head data (no pop)
//                      write → pop FIFO (advance read pointer)
//   0x001 (byte 0x04): read  → FIFO empty flag (bit 0)
//   0x002 (byte 0x08): write → hex display data

module rd_fifo_mmio (
    input  wire [29:0] i_addr,
    input  wire [31:0] i_data,
    input  wire        i_wren,
    output reg  [31:0] o_data,

    // Async FIFO read interface (combinatorial; registered inside async_fifo)
    output wire        o_fifo_pop,
    input  wire [31:0] i_fifo_rdata,
    input  wire        i_fifo_empty,

    // Hex display output
    output wire [31:0] o_display,
    output wire        o_display_we
);

wire sel_data   = (i_addr == 30'd0);   // byte 0x00
wire sel_status = (i_addr == 30'd1);   // byte 0x04
wire sel_disp   = (i_addr == 30'd2);   // byte 0x08

// Pop on write to the data address
assign o_fifo_pop   = i_wren & sel_data;

// Display: written when Core 1 stores to byte 0x08
assign o_display    = i_data;
assign o_display_we = i_wren & sel_disp;

// Read data mux (combinatorial)
always @(*) begin
    if (sel_data)
        o_data = i_fifo_rdata;
    else if (sel_status)
        o_data = {31'b0, i_fifo_empty};
    else
        o_data = 32'b0;
end

endmodule
