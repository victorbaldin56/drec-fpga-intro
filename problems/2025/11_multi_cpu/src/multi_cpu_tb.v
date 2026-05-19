// Two-core RV32I system testbench.
//
// Core 0 (clk0 = 10 ns period): sends numbers 1, 2, 3, ... via async FIFO.
// Core 1 (clk1 = 12 ns period): reads from FIFO and displays each value.
//
// MMIO map — Core 0 (wr_fifo_mmio):
//   byte 0x00  read  → FIFO full flag (stall when 1)
//   byte 0x04  write → push word to FIFO
//
// MMIO map — Core 1 (rd_fifo_mmio):
//   byte 0x00  read  → FIFO head data
//   byte 0x00  write → pop FIFO (advance read pointer)
//   byte 0x04  read  → FIFO empty flag (stall when 1)
//   byte 0x08  write → hex display output (monitored in TB)
//
// Core 0 program (samples/core0.txt):
//   00100093  addi x1, x0, 1         # x1 = number to send
//   00002103  lw   x2, 0(x0)         # poll: x2 = full flag
//   fe001ee3  bne  x2, x0, -4        # loop if full
//   00102223  sw   x1, 4(x0)         # push x1 to FIFO
//   00108093  addi x1, x1, 1         # x1++
//   fe1ff06f  jal  x0, -16           # back to poll
//
// Core 1 program (samples/core1.txt):
//   00402083  lw   x1, 4(x0)         # poll: x1 = empty flag
//   fe000ee3  bne  x1, x0, -4        # loop if empty
//   00002083  lw   x1, 0(x0)         # read FIFO head data
//   00002023  sw   x0, 0(x0)         # pop FIFO
//   00102423  sw   x1, 8(x0)         # write to display
//   fedff06f  jal  x0, -20           # back to poll

`timescale 1ns/1ps

module multi_cpu_tb;

// -----------------------------------------------------------------------
// Clocks and reset
// -----------------------------------------------------------------------
reg clk0  = 1'b0;  // Core 0: 100 MHz (10 ns period)
reg clk1  = 1'b0;  // Core 1: ~83 MHz (12 ns period)
reg rst_n = 1'b0;

always #5  clk0 <= ~clk0;
always #6  clk1 <= ~clk1;

// Deassert reset after 4 clk0 cycles
initial begin
    repeat (4) @(posedge clk0);
    @(negedge clk0);
    rst_n <= 1'b1;
end

// -----------------------------------------------------------------------
// Core 0: sender
// -----------------------------------------------------------------------
wire [29:0] c0_mmio_addr;
wire [31:0] c0_mmio_data;
wire  [3:0] c0_mmio_mask;
wire        c0_mmio_wren;
wire [31:0] c0_mmio_rdata;

wire [31:0] c0_fifo_wdata;
wire        c0_fifo_push;
wire        c0_fifo_full;

cpu_top #(
    .IMEM_FILE      ("samples/core0.txt"),
    .IMEM_ADDR_WIDTH(6),
    .DMEM_ADDR_WIDTH(5)
) cpu0 (
    .clk        (clk0         ),
    .rst_n      (rst_n        ),
    .o_mmio_addr(c0_mmio_addr ),
    .o_mmio_data(c0_mmio_data ),
    .o_mmio_mask(c0_mmio_mask ),
    .o_mmio_wren(c0_mmio_wren ),
    .i_mmio_data(c0_mmio_rdata)
);

wr_fifo_mmio wr_mmio (
    .i_addr      (c0_mmio_addr ),
    .i_data      (c0_mmio_data ),
    .i_wren      (c0_mmio_wren ),
    .o_data      (c0_mmio_rdata),
    .o_fifo_wdata(c0_fifo_wdata),
    .o_fifo_push (c0_fifo_push ),
    .i_fifo_full (c0_fifo_full )
);

// -----------------------------------------------------------------------
// Core 1: receiver + display
// -----------------------------------------------------------------------
wire [29:0] c1_mmio_addr;
wire [31:0] c1_mmio_data;
wire  [3:0] c1_mmio_mask;
wire        c1_mmio_wren;
wire [31:0] c1_mmio_rdata;

wire        c1_fifo_pop;
wire [31:0] c1_fifo_rdata;
wire        c1_fifo_empty;
wire [31:0] c1_display;
wire        c1_display_we;

cpu_top #(
    .IMEM_FILE      ("samples/core1.txt"),
    .IMEM_ADDR_WIDTH(6),
    .DMEM_ADDR_WIDTH(5)
) cpu1 (
    .clk        (clk1         ),
    .rst_n      (rst_n        ),
    .o_mmio_addr(c1_mmio_addr ),
    .o_mmio_data(c1_mmio_data ),
    .o_mmio_mask(c1_mmio_mask ),
    .o_mmio_wren(c1_mmio_wren ),
    .i_mmio_data(c1_mmio_rdata)
);

rd_fifo_mmio rd_mmio (
    .i_addr      (c1_mmio_addr ),
    .i_data      (c1_mmio_data ),
    .i_wren      (c1_mmio_wren ),
    .o_data      (c1_mmio_rdata),
    .o_fifo_pop  (c1_fifo_pop  ),
    .i_fifo_rdata(c1_fifo_rdata),
    .i_fifo_empty(c1_fifo_empty),
    .o_display   (c1_display   ),
    .o_display_we(c1_display_we)
);

// -----------------------------------------------------------------------
// Async FIFO connecting Core 0 (write) and Core 1 (read)
// -----------------------------------------------------------------------
async_fifo #(
    .WIDTH     (32),
    .DEPTH_LOG2(4)
) fifo (
    .wr_clk  (clk0          ),
    .wr_rst_n(rst_n         ),
    .i_wdata (c0_fifo_wdata ),
    .i_push  (c0_fifo_push  ),
    .o_full  (c0_fifo_full  ),

    .rd_clk  (clk1          ),
    .rd_rst_n(rst_n         ),
    .o_rdata (c1_fifo_rdata ),
    .i_pop   (c1_fifo_pop   ),
    .o_empty (c1_fifo_empty )
);

// -----------------------------------------------------------------------
// Monitor: print each value Core 1 writes to the display
// -----------------------------------------------------------------------
always @(posedge clk1) begin
    if (c1_display_we)
        $display("[%0t ns] display = %0d", $time, c1_display);
end

// -----------------------------------------------------------------------
// Simulation control
// -----------------------------------------------------------------------
initial begin
    $dumpvars(0, multi_cpu_tb);
    #3000;
    $finish;
end

endmodule
