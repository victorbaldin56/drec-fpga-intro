// UART receiver using FSM.
// Frame format: 1 start bit (0), 8 data bits LSB-first, 1 stop bit (1).
//
// FSM states:
//   IDLE  - wait for falling edge on i_rx (start bit detected)
//   START - wait half bit period to centre sampling on first data bit
//   DATA  - sample 8 data bits, one per full bit period
//   STOP  - wait for stop bit, then emit o_valid

module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input            clk,
    input            rst_n,
    input            i_rx,
    output reg [7:0] o_data,
    output reg       o_valid
);

// ---------------------------------------------------------------------------
// Baud rate constants
// ---------------------------------------------------------------------------
localparam integer CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE;
localparam integer HALF_BIT      = CLKS_PER_BIT / 2;

// ---------------------------------------------------------------------------
// FSM states
// ---------------------------------------------------------------------------
localparam IDLE  = 2'd0,
           START = 2'd1,
           DATA  = 2'd2,
           STOP  = 2'd3;

// ---------------------------------------------------------------------------
// Double-flop synchroniser for i_rx
// ---------------------------------------------------------------------------
reg rx_meta, rx_sync, rx_prev;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_meta <= 1'b1;
        rx_sync <= 1'b1;
        rx_prev <= 1'b1;
    end else begin
        rx_meta <= i_rx;
        rx_sync <= rx_meta;
        rx_prev <= rx_sync;
    end
end

wire rx_falling = rx_prev & ~rx_sync; // detect falling edge

// ---------------------------------------------------------------------------
// FSM and sampling counter
// ---------------------------------------------------------------------------
reg [1:0]  state;
reg [15:0] sample_cnt;
reg [2:0]  bit_cnt;
reg [7:0]  shift_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state      <= IDLE;
        sample_cnt <= 0;
        bit_cnt    <= 3'd0;
        shift_reg  <= 8'h00;
        o_data     <= 8'h00;
        o_valid    <= 1'b0;
    end else begin
        o_valid <= 1'b0; // default: deassert

        case (state)
            // ------------------------------------------------------------------
            IDLE: begin
                if (rx_falling) begin
                    // Falling edge detected - start bit beginning
                    sample_cnt <= 0;
                    state      <= START;
                end
            end

            // ------------------------------------------------------------------
            // Wait half a bit period, then confirm start bit is still low.
            // This centres our sampling window on subsequent data bits.
            START: begin
                if (sample_cnt == HALF_BIT[15:0] - 1) begin
                    sample_cnt <= 0;
                    if (rx_sync == 1'b0) begin
                        // Valid start bit - proceed to data
                        bit_cnt <= 3'd0;
                        state   <= DATA;
                    end else begin
                        // Glitch - go back to idle
                        state <= IDLE;
                    end
                end else begin
                    sample_cnt <= sample_cnt + 1'b1;
                end
            end

            // ------------------------------------------------------------------
            // Sample one bit per full bit period (already centred from START).
            DATA: begin
                if (sample_cnt == CLKS_PER_BIT[15:0] - 1) begin
                    sample_cnt <= 0;
                    // Sample: LSB first
                    shift_reg <= {rx_sync, shift_reg[7:1]};
                    if (bit_cnt == 3'd7) begin
                        state <= STOP;
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end else begin
                    sample_cnt <= sample_cnt + 1'b1;
                end
            end

            // ------------------------------------------------------------------
            // Wait for the stop bit.  If stop bit is high, latch data and
            // assert o_valid for one cycle.
            STOP: begin
                if (sample_cnt == CLKS_PER_BIT[15:0] - 1) begin
                    sample_cnt <= 0;
                    state      <= IDLE;
                    if (rx_sync == 1'b1) begin
                        o_data  <= shift_reg;
                        o_valid <= 1'b1;
                    end
                    // If stop bit was 0 (framing error) we silently discard.
                end else begin
                    sample_cnt <= sample_cnt + 1'b1;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
