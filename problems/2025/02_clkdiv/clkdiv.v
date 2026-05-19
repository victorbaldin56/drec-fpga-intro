module clkdiv #(
    parameter CLK_IN_FREQ = 50_000_000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire  [1:0] i_sel,
    output reg         o_clk
);

localparam [31:0] HALF_9600   = CLK_IN_FREQ / (2 *   9_600) - 1;
localparam [31:0] HALF_38400  = CLK_IN_FREQ / (2 *  38_400) - 1;
localparam [31:0] HALF_115200 = CLK_IN_FREQ / (2 * 115_200) - 1;

reg [31:0] counter;
reg [31:0] half_period;

always @(*) begin
    case (i_sel)
        2'd0:    half_period = HALF_9600;
        2'd1:    half_period = HALF_38400;
        2'd2:    half_period = HALF_115200;
        default: half_period = HALF_9600;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter <= 32'd0;
        o_clk   <= 1'b0;
    end else begin
        if (counter >= half_period) begin
            counter <= 32'd0;
            o_clk   <= ~o_clk;
        end else begin
            counter <= counter + 32'd1;
        end
    end
end

endmodule
