// Data memory: combinational read, synchronous byte-enabled write.
module dmem #(
    parameter WORDS = 1024
) (
    input  wire        clk,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  be,
    output wire [31:0] rdata
);
    localparam AW = $clog2(WORDS);

    reg [31:0] mem [0:WORDS-1];
    wire [AW-1:0] idx = addr[AW+1:2];

    integer i;
    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            mem[i] = 32'b0;
    end

    assign rdata = mem[idx];

    always @(posedge clk) begin
        if (be[0]) mem[idx][7:0]   <= wdata[7:0];
        if (be[1]) mem[idx][15:8]  <= wdata[15:8];
        if (be[2]) mem[idx][23:16] <= wdata[23:16];
        if (be[3]) mem[idx][31:24] <= wdata[31:24];
    end
endmodule
