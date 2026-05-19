// Load-Store Unit: handles byte/halfword/word load and store.
// For stores: generates byte mask and aligned data.
// For loads: sign/zero extends read data.

module lsu (
    input  wire [31:0] i_addr,      // byte address from ALU
    input  wire [31:0] i_wdata,     // store data (rs2)
    input  wire  [2:0] i_funct3,   // LB=0,LH=1,LW=2,LBU=4,LHU=5 / SB=0,SH=1,SW=2
    input  wire        i_we,        // 1 = store, 0 = load (or no-op)

    input  wire [31:0] i_rdata,     // word read from memory

    output wire [29:0] o_addr,      // word address to memory
    output wire [31:0] o_wdata,     // word to write to memory (aligned)
    output wire  [3:0] o_mask,      // byte enable mask
    output wire        o_we,        // write enable to memory
    output wire [31:0] o_rdata      // load result (sign/zero extended)
);

wire [1:0] byte_off = i_addr[1:0];  // byte offset within word

assign o_addr = i_addr[31:2];       // word address
assign o_we   = i_we;

// Store data and mask generation
reg [31:0] wdata_aligned;
reg  [3:0] mask;

always @(*) begin
    case (i_funct3[1:0])
        2'b00: begin  // SB
            wdata_aligned = {4{i_wdata[7:0]}};
            mask = 4'b0001 << byte_off;
        end
        2'b01: begin  // SH
            wdata_aligned = {2{i_wdata[15:0]}};
            mask = byte_off[1] ? 4'b1100 : 4'b0011;
        end
        default: begin  // SW
            wdata_aligned = i_wdata;
            mask = 4'b1111;
        end
    endcase
end

assign o_wdata = wdata_aligned;
assign o_mask  = mask;

// Load data extraction and sign extension
reg [31:0] rdata_out;

always @(*) begin
    case (i_funct3)
        3'b000: begin  // LB
            case (byte_off)
                2'b00: rdata_out = {{24{i_rdata[7]}},  i_rdata[7:0]};
                2'b01: rdata_out = {{24{i_rdata[15]}}, i_rdata[15:8]};
                2'b10: rdata_out = {{24{i_rdata[23]}}, i_rdata[23:16]};
                default: rdata_out = {{24{i_rdata[31]}}, i_rdata[31:24]};
            endcase
        end
        3'b001: begin  // LH
            rdata_out = byte_off[1]
                ? {{16{i_rdata[31]}}, i_rdata[31:16]}
                : {{16{i_rdata[15]}}, i_rdata[15:0]};
        end
        3'b010: begin  // LW
            rdata_out = i_rdata;
        end
        3'b100: begin  // LBU
            case (byte_off)
                2'b00: rdata_out = {24'b0, i_rdata[7:0]};
                2'b01: rdata_out = {24'b0, i_rdata[15:8]};
                2'b10: rdata_out = {24'b0, i_rdata[23:16]};
                default: rdata_out = {24'b0, i_rdata[31:24]};
            endcase
        end
        3'b101: begin  // LHU
            rdata_out = byte_off[1]
                ? {16'b0, i_rdata[31:16]}
                : {16'b0, i_rdata[15:0]};
        end
        default: rdata_out = i_rdata;
    endcase
end

assign o_rdata = rdata_out;

endmodule
