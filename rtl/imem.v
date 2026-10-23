// Instruction memory: combinational read, word addressed internally.
// Simulation only: the program is loaded with +prog=<file.hex>.
module imem #(
    parameter WORDS = 1024
) (
    input  wire [31:0] addr,
    output wire [31:0] rdata
);
    localparam AW = $clog2(WORDS);

    reg [31:0] mem [0:WORDS-1];
    reg [1023:0] prog_file;
    reg [31:0]   word;

    // Read words one by one rather than $readmemh, which warns whenever
    // the program is shorter than the memory.
    integer i, fd;
    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            mem[i] = 32'h00000013;                // NOP
        if ($value$plusargs("prog=%s", prog_file)) begin
            fd = $fopen(prog_file, "r");
            if (fd == 0) begin
                $display("ERROR: cannot open %0s", prog_file);
                $finish(0);
            end
            i = 0;
            while (i < WORDS && $fscanf(fd, "%h\n", word) == 1) begin
                mem[i] = word;
                i = i + 1;
            end
            $fclose(fd);
        end
    end

    assign rdata = mem[addr[AW+1:2]];
endmodule
