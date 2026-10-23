// Translates byte/halfword/word accesses onto a 32-bit word-wide memory
// with byte enables. Accesses are assumed to be naturally aligned.
module load_store_unit (
    input  wire        mem_write,
    input  wire [2:0]  funct3,
    input  wire [31:0] addr,
    input  wire [31:0] store_data,   // rs2
    input  wire [31:0] mem_rdata,    // full word from memory
    output reg  [31:0] mem_wdata,
    output reg  [3:0]  mem_be,
    output reg  [31:0] load_data
);
    wire [1:0]  offset = addr[1:0];
    wire [31:0] shifted = mem_rdata >> {offset, 3'b000};

    // Store path: replicate data across lanes and pick byte enables.
    always @(*) begin
        case (funct3[1:0])
            2'b00: begin                                   // SB
                mem_wdata = {4{store_data[7:0]}};
                mem_be    = 4'b0001 << offset;
            end
            2'b01: begin                                   // SH
                mem_wdata = {2{store_data[15:0]}};
                mem_be    = offset[1] ? 4'b1100 : 4'b0011;
            end
            default: begin                                 // SW
                mem_wdata = store_data;
                mem_be    = 4'b1111;
            end
        endcase
        if (!mem_write)
            mem_be = 4'b0000;
    end

    // Load path: extract the addressed lane and extend.
    always @(*) begin
        case (funct3)
            3'b000:  load_data = {{24{shifted[7]}},  shifted[7:0]};   // LB
            3'b001:  load_data = {{16{shifted[15]}}, shifted[15:0]};  // LH
            3'b100:  load_data = {24'b0, shifted[7:0]};               // LBU
            3'b101:  load_data = {16'b0, shifted[15:0]};              // LHU
            default: load_data = mem_rdata;                           // LW
        endcase
    end
endmodule
