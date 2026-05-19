// UART transmitter
// Frame format: 1 start bit (0), 8 data bits LSB-first, 1 stop bit (1).
// Idle line = 1.

module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input            clk,
    input            rst_n,
    input  [7:0]     i_data,
    input            i_valid,   // pulse high to start transmission
    output           o_tx,
    output           o_busy
);

// ---------------------------------------------------------------------------
// Baud rate generator
// ---------------------------------------------------------------------------
localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

reg [15:0] baud_cnt;
reg        baud_tick; // one cycle per bit period

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        baud_cnt  <= 0;
        baud_tick <= 1'b0;
    end else if (o_busy) begin
        if (baud_cnt == CLKS_PER_BIT[15:0] - 1) begin
            baud_cnt  <= 0;
            baud_tick <= 1'b1;
        end else begin
            baud_cnt  <= baud_cnt + 1'b1;
            baud_tick <= 1'b0;
        end
    end else begin
        baud_cnt  <= 0;
        baud_tick <= 1'b0;
    end
end

// ---------------------------------------------------------------------------
// Transmit shift register and bit counter
// ---------------------------------------------------------------------------
// State: IDLE=0, START=1, DATA=2, STOP=3
localparam IDLE  = 2'd0,
           START = 2'd1,
           DATA  = 2'd2,
           STOP  = 2'd3;

reg [1:0] state;
reg [7:0] shift_reg;
reg [2:0] bit_cnt;
reg       tx_reg;

assign o_tx   = tx_reg;
assign o_busy = (state != IDLE);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state     <= IDLE;
        tx_reg    <= 1'b1;
        shift_reg <= 8'h00;
        bit_cnt   <= 3'd0;
    end else begin
        case (state)
            IDLE: begin
                tx_reg <= 1'b1;
                if (i_valid) begin
                    shift_reg <= i_data;
                    state     <= START;
                    baud_cnt  <= 0; // reset baud counter on start
                end
            end

            START: begin
                tx_reg <= 1'b0; // start bit
                if (baud_tick) begin
                    bit_cnt <= 3'd0;
                    state   <= DATA;
                end
            end

            DATA: begin
                tx_reg <= shift_reg[0];
                if (baud_tick) begin
                    shift_reg <= {1'b0, shift_reg[7:1]};
                    if (bit_cnt == 3'd7) begin
                        state <= STOP;
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end
            end

            STOP: begin
                tx_reg <= 1'b1; // stop bit
                if (baud_tick) begin
                    state <= IDLE;
                end
            end

            default: begin
                state  <= IDLE;
                tx_reg <= 1'b1;
            end
        endcase
    end
end

endmodule
