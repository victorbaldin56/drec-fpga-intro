// Synchronous FIFO, depth = 2^DEPTH_LOG2, parametric width.
// Full/empty detected via MSB of (DEPTH_LOG2+1)-bit pointers.

module fifo #(
    parameter DEPTH_LOG2 = 4,
    parameter WIDTH      = 8
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire [WIDTH-1:0]  i_data,
    input  wire              i_push,
    input  wire              i_pop,
    output wire [WIDTH-1:0]  o_data,
    output wire              o_full,
    output wire              o_empty
);

localparam DEPTH = 1 << DEPTH_LOG2;

reg [WIDTH-1:0]    mem [0:DEPTH-1];
reg [DEPTH_LOG2:0] wr_ptr;
reg [DEPTH_LOG2:0] rd_ptr;

wire [DEPTH_LOG2-1:0] wr_addr = wr_ptr[DEPTH_LOG2-1:0];
wire [DEPTH_LOG2-1:0] rd_addr = rd_ptr[DEPTH_LOG2-1:0];

assign o_full  = (wr_ptr == {~rd_ptr[DEPTH_LOG2], rd_ptr[DEPTH_LOG2-1:0]});
assign o_empty = (wr_ptr == rd_ptr);
assign o_data  = mem[rd_addr];

integer k;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= {(DEPTH_LOG2+1){1'b0}};
        rd_ptr <= {(DEPTH_LOG2+1){1'b0}};
        for (k = 0; k < DEPTH; k = k + 1)
            mem[k] <= {WIDTH{1'b0}};
    end else begin
        if (i_push) begin
            mem[wr_addr] <= i_data;
            wr_ptr       <= wr_ptr + {{DEPTH_LOG2{1'b0}}, 1'b1};
        end
        if (i_pop) begin
            rd_ptr <= rd_ptr + {{DEPTH_LOG2{1'b0}}, 1'b1};
        end
    end
end

endmodule
