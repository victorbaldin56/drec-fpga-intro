// Core 0 MMIO: write port to async FIFO.
//
// MMIO word address map:
//   0x000 (byte 0x00): read  → FIFO full flag (bit 0)
//   0x001 (byte 0x04): write → push i_data into FIFO

module wr_fifo_mmio (
    input  wire [29:0] i_addr,
    input  wire [31:0] i_data,
    input  wire        i_wren,
    output wire [31:0] o_data,

    // Async FIFO write interface (combinatorial; registered inside async_fifo)
    output wire [31:0] o_fifo_wdata,
    output wire        o_fifo_push,
    input  wire        i_fifo_full
);

wire sel_status = (i_addr == 30'd0);   // byte 0x00
wire sel_push   = (i_addr == 30'd1);   // byte 0x04

assign o_fifo_wdata = i_data;
assign o_fifo_push  = i_wren & sel_push;
assign o_data       = sel_status ? {31'b0, i_fifo_full} : 32'b0;

endmodule
