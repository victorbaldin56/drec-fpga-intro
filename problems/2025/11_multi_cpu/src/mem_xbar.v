// Memory crossbar: routes between data memory and MMIO space.

module mem_xbar #(
    parameter [29:0] DATA_START = 30'h0400,
    parameter [29:0] DATA_LIMIT = 30'h3FFF,
    parameter [29:0] MMIO_START = 30'h0000,
    parameter [29:0] MMIO_LIMIT = 30'h03FF
)(
    input  wire [29:0] i_addr,
    input  wire [31:0] i_data,
    input  wire        i_wren,
    input  wire  [3:0] i_mask,
    output wire [31:0] o_data,

    output wire [29:0] o_dmem_addr,
    output wire [31:0] o_dmem_data,
    output wire  [3:0] o_dmem_mask,
    output wire        o_dmem_wren,
    input  wire [31:0] i_dmem_data,

    output wire [29:0] o_mmio_addr,
    output wire [31:0] o_mmio_data,
    output wire  [3:0] o_mmio_mask,
    output wire        o_mmio_wren,
    input  wire [31:0] i_mmio_data
);

wire sel_dmem = (i_addr >= DATA_START) && (i_addr <= DATA_LIMIT);
wire sel_mmio = (i_addr >= MMIO_START) && (i_addr <= MMIO_LIMIT);

assign o_dmem_addr = i_addr;
assign o_dmem_data = i_data;
assign o_dmem_mask = i_mask;
assign o_dmem_wren = i_wren & sel_dmem;

assign o_mmio_addr = i_addr;
assign o_mmio_data = i_data;
assign o_mmio_mask = i_mask;
assign o_mmio_wren = i_wren & sel_mmio;

assign o_data = sel_dmem ? i_dmem_data :
                sel_mmio ? i_mmio_data :
                           32'h0;

endmodule
