// Async FIFO with Gray-code pointer synchronization (2-FF synchronizers).
// Full flag in wr_clk domain; empty flag in rd_clk domain.
// Read data is combinatorial from the memory array.

module async_fifo #(
    parameter WIDTH      = 32,
    parameter DEPTH_LOG2 = 4
)(
    // Write port (wr_clk domain)
    input  wire              wr_clk,
    input  wire              wr_rst_n,
    input  wire [WIDTH-1:0]  i_wdata,
    input  wire              i_push,
    output wire              o_full,

    // Read port (rd_clk domain)
    input  wire              rd_clk,
    input  wire              rd_rst_n,
    output wire [WIDTH-1:0]  o_rdata,
    input  wire              i_pop,
    output wire              o_empty
);

localparam DEPTH = 1 << DEPTH_LOG2;

// Dual-port memory (written in wr_clk, read combinatorially)
reg [WIDTH-1:0] mem [0:DEPTH-1];

// -----------------------------------------------------------------------
// Write pointer (wr_clk domain) — binary and Gray
// -----------------------------------------------------------------------
reg [DEPTH_LOG2:0] wr_ptr;
wire [DEPTH_LOG2:0] wr_ptr_gray = wr_ptr ^ (wr_ptr >> 1);

// -----------------------------------------------------------------------
// Read pointer (rd_clk domain) — binary and Gray
// -----------------------------------------------------------------------
reg [DEPTH_LOG2:0] rd_ptr;
wire [DEPTH_LOG2:0] rd_ptr_gray = rd_ptr ^ (rd_ptr >> 1);

// -----------------------------------------------------------------------
// Synchronize wr_ptr_gray into rd_clk domain (2-FF)
// -----------------------------------------------------------------------
reg [DEPTH_LOG2:0] wr_gray_s1, wr_gray_s2;
always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
        wr_gray_s1 <= 0;
        wr_gray_s2 <= 0;
    end else begin
        wr_gray_s1 <= wr_ptr_gray;
        wr_gray_s2 <= wr_gray_s1;
    end
end

// -----------------------------------------------------------------------
// Synchronize rd_ptr_gray into wr_clk domain (2-FF)
// -----------------------------------------------------------------------
reg [DEPTH_LOG2:0] rd_gray_s1, rd_gray_s2;
always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
        rd_gray_s1 <= 0;
        rd_gray_s2 <= 0;
    end else begin
        rd_gray_s1 <= rd_ptr_gray;
        rd_gray_s2 <= rd_gray_s1;
    end
end

// -----------------------------------------------------------------------
// Full: write pointer has wrapped DEPTH ahead of synchronized read pointer.
// Standard Gray-code full condition (Cummings): top two bits inverted.
// -----------------------------------------------------------------------
assign o_full = (wr_ptr_gray ==
    {~rd_gray_s2[DEPTH_LOG2:DEPTH_LOG2-1], rd_gray_s2[DEPTH_LOG2-2:0]});

// -----------------------------------------------------------------------
// Empty: read pointer equals synchronized write pointer (both Gray).
// -----------------------------------------------------------------------
assign o_empty = (rd_ptr_gray == wr_gray_s2);

// -----------------------------------------------------------------------
// Write logic
// -----------------------------------------------------------------------
integer j;
always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
        wr_ptr <= 0;
        for (j = 0; j < DEPTH; j = j + 1)
            mem[j] <= {WIDTH{1'b0}};
    end else if (i_push && !o_full) begin
        mem[wr_ptr[DEPTH_LOG2-1:0]] <= i_wdata;
        wr_ptr <= wr_ptr + 1;
    end
end

// -----------------------------------------------------------------------
// Read logic
// -----------------------------------------------------------------------
always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n)
        rd_ptr <= 0;
    else if (i_pop && !o_empty)
        rd_ptr <= rd_ptr + 1;
end

// Read data: combinatorial from current rd_ptr
assign o_rdata = mem[rd_ptr[DEPTH_LOG2-1:0]];

endmodule
