
// Runs one program on riscv_top until ECALL/EBREAK.
// Test convention: a0 (x10) == 0 means pass, otherwise a0 holds the
// number of the failing check.
//
// Plusargs:
//   +prog=<file.hex>   program image (required)
//   +max_cycles=<n>    timeout, default 100000
//   +trace             print every retired instruction
//   +vcd               dump waves to build/wave.vcd
module tb_riscv;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire halt, illegal;

    riscv_top dut (
        .clk     (clk),
        .rst     (rst),
        .halt    (halt),
        .illegal (illegal)
    );

    always #5 clk = ~clk;

    integer cycles = 0;
    integer max_cycles;
    reg     trace;
    reg [1023:0] prog;

    wire [31:0] pc    = dut.u_core.pc;
    wire [31:0] instr = dut.u_core.instr;
    wire [31:0] a0    = dut.u_core.u_regfile.regs[10];

    initial begin
        if (!$value$plusargs("prog=%s", prog)) begin
            $display("ERROR: no +prog=<file.hex> given");
            $finish(0);
        end
        if (!$value$plusargs("max_cycles=%d", max_cycles))
            max_cycles = 100000;
        trace = $test$plusargs("trace");
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/wave.vcd");
            $dumpvars(0, tb_riscv);
        end

        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        if (!rst) begin
            if (trace) begin
                $write("%6d  pc=%08h  instr=%08h", cycles, pc, instr);
                if (dut.u_core.u_regfile.we && dut.u_core.rd != 0)
                    $write("  x%0d <= %08h", dut.u_core.rd, dut.u_core.wb_data);
                if (dut.dmem_be != 0)
                    $write("  mem[%08h] <= %08h (be=%b)",
                           dut.dmem_addr, dut.dmem_wdata, dut.dmem_be);
                $write("\n");
            end

            if (illegal) begin
                $display("FAIL  illegal instruction %08h at pc=%08h", instr, pc);
                $finish(0);
            end else if (halt) begin
                if (a0 == 0)
                    $display("PASS  (%0d cycles)", cycles);
                else
                    $display("FAIL  check #%0d  (pc=%08h, %0d cycles)", a0, pc, cycles);
                $finish(0);
            end else if (cycles >= max_cycles) begin
                $display("FAIL  timeout after %0d cycles (pc=%08h)", cycles, pc);
                $finish(0);
            end
            cycles = cycles + 1;
        end
    end
endmodule
