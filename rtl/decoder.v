`include "riscv_defs.vh"

// Main control: opcode/funct3/funct7 -> datapath control signals.
module decoder (
    input  wire [31:0] instr,
    output reg         reg_write,
    output reg  [1:0]  alu_src_a,   // `A_RS1 / `A_PC / `A_ZERO
    output reg         alu_src_b,   // 0 = rs2, 1 = immediate
    output reg  [3:0]  alu_op,
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  wb_sel,      // `WB_ALU / `WB_MEM / `WB_PC4
    output reg         branch,
    output reg         jal,
    output reg         jalr,
    output reg         halt,        // ECALL / EBREAK
    output reg         illegal
);
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    always @(*) begin
        reg_write = 1'b0;
        alu_src_a = `A_RS1;
        alu_src_b = 1'b0;
        alu_op    = `ALU_ADD;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        wb_sel    = `WB_ALU;
        branch    = 1'b0;
        jal       = 1'b0;
        jalr      = 1'b0;
        halt      = 1'b0;
        illegal   = 1'b0;

        case (opcode)
            `OP_LUI: begin
                reg_write = 1'b1;
                alu_src_a = `A_ZERO;
                alu_src_b = 1'b1;
            end
            `OP_AUIPC: begin
                reg_write = 1'b1;
                alu_src_a = `A_PC;
                alu_src_b = 1'b1;
            end
            `OP_JAL: begin
                reg_write = 1'b1;
                jal       = 1'b1;
                wb_sel    = `WB_PC4;
            end
            `OP_JALR: begin
                reg_write = 1'b1;
                jalr      = 1'b1;
                alu_src_b = 1'b1;
                wb_sel    = `WB_PC4;
                illegal   = (funct3 != 3'b000);
            end
            `OP_BRANCH: begin
                branch    = 1'b1;
                illegal   = (funct3 == 3'b010) || (funct3 == 3'b011);
            end
            `OP_LOAD: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1;
                mem_read  = 1'b1;
                wb_sel    = `WB_MEM;
                illegal   = (funct3 == 3'b011) || (funct3[2:1] == 2'b11);
            end
            `OP_STORE: begin
                mem_write = 1'b1;
                alu_src_b = 1'b1;
                illegal   = (funct3[2] || funct3[1:0] == 2'b11);
            end
            `OP_IMM: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1;
                // funct7[5] only selects SRAI vs SRLI; for other I-type ops
                // those bits are part of the immediate.
                alu_op    = {(funct3 == 3'b101) & funct7[5], funct3};
                if (funct3 == 3'b001)
                    illegal = (funct7 != 7'b0000000);
                else if (funct3 == 3'b101)
                    illegal = (funct7 != 7'b0000000) && (funct7 != 7'b0100000);
            end
            `OP_REG: begin
                reg_write = 1'b1;
                alu_op    = {funct7[5], funct3};
                illegal   = !((funct7 == 7'b0000000) ||
                              (funct7 == 7'b0100000 &&
                               (funct3 == 3'b000 || funct3 == 3'b101)));
            end
            `OP_FENCE: begin
                // Single-cycle, in-order, no caches: FENCE is a no-op.
            end
            `OP_SYSTEM: begin
                // ECALL / EBREAK stop the simulation; no CSRs implemented.
                halt = 1'b1;
            end
            default: begin
                illegal = 1'b1;
            end
        endcase

        // Never let an illegal instruction change architectural state.
        if (illegal) begin
            reg_write = 1'b0;
            mem_write = 1'b0;
            branch    = 1'b0;
            jal       = 1'b0;
            jalr      = 1'b0;
        end
    end
endmodule
