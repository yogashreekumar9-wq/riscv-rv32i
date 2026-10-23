`include "riscv_defs.vh"

// Single-cycle RV32I core. Every instruction completes in one clock:
// fetch, decode, execute, memory and writeback are all combinational,
// with only the PC, register file and data memory updating on the edge.
module riscv_core #(
    parameter RESET_PC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        rst,

    // Instruction memory
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // Data memory
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_be,
    input  wire [31:0] dmem_rdata,

    // Status
    output wire        halt,        // ECALL/EBREAK reached
    output wire        illegal      // illegal instruction reached
);
    // ---------------------------------------------------------------- fetch
    reg  [31:0] pc;
    wire [31:0] instr = imem_rdata;
    assign imem_addr = pc;

    // --------------------------------------------------------------- decode
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];

    wire       reg_write, alu_src_b, mem_read, mem_write;
    wire       branch, jal, jalr, sys_halt;
    wire [1:0] alu_src_a, wb_sel;
    wire [3:0] alu_op;

    decoder u_decoder (
        .instr     (instr),
        .reg_write (reg_write),
        .alu_src_a (alu_src_a),
        .alu_src_b (alu_src_b),
        .alu_op    (alu_op),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .wb_sel    (wb_sel),
        .branch    (branch),
        .jal       (jal),
        .jalr      (jalr),
        .halt      (sys_halt),
        .illegal   (illegal)
    );

    assign halt = sys_halt;
    wire stopped = rst | sys_halt | illegal;

    wire [31:0] imm;
    imm_gen u_imm_gen (
        .instr (instr),
        .imm   (imm)
    );

    wire [31:0] rs1_data, rs2_data, wb_data;
    regfile u_regfile (
        .clk (clk),
        .we  (reg_write & ~stopped),
        .rs1 (rs1),
        .rs2 (rs2),
        .rd  (rd),
        .wd  (wb_data),
        .rd1 (rs1_data),
        .rd2 (rs2_data)
    );

    // -------------------------------------------------------------- execute
    reg [31:0] alu_a;
    always @(*) begin
        case (alu_src_a)
            `A_PC:   alu_a = pc;
            `A_ZERO: alu_a = 32'b0;
            default: alu_a = rs1_data;
        endcase
    end
    wire [31:0] alu_b = alu_src_b ? imm : rs2_data;

    wire [31:0] alu_result;
    alu u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .op     (alu_op),
        .result (alu_result)
    );

    wire branch_taken;
    branch_unit u_branch_unit (
        .a      (rs1_data),
        .b      (rs2_data),
        .funct3 (funct3),
        .taken  (branch_taken)
    );

    // --------------------------------------------------------------- memory
    wire [31:0] load_data;
    load_store_unit u_lsu (
        .mem_write  (mem_write & ~stopped),
        .funct3     (funct3),
        .addr       (alu_result),
        .store_data (rs2_data),
        .mem_rdata  (dmem_rdata),
        .mem_wdata  (dmem_wdata),
        .mem_be     (dmem_be),
        .load_data  (load_data)
    );
    assign dmem_addr = alu_result;

    // ------------------------------------------------------------ writeback
    wire [31:0] pc_plus4 = pc + 32'd4;

    assign wb_data = (wb_sel == `WB_MEM) ? load_data :
                     (wb_sel == `WB_PC4) ? pc_plus4  :
                                           alu_result;

    // -------------------------------------------------------------- next PC
    wire [31:0] pc_target = pc + imm;      // JAL and branch target
    wire [31:0] next_pc   = jalr                         ? {alu_result[31:1], 1'b0} :
                            (jal | (branch & branch_taken)) ? pc_target :
                                                           pc_plus4;

    always @(posedge clk) begin
        if (rst)
            pc <= RESET_PC;
        else if (!stopped)
            pc <= next_pc;
    end
endmodule
