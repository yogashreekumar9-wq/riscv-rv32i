# ALU, immediate and upper-immediate instructions.
# gp holds the current check number; on failure it is reported in a0.

    li   gp, 1                  # add
    li   t0, 5
    li   t1, 7
    add  t2, t0, t1
    li   t3, 12
    bne  t2, t3, fail

    li   gp, 2                  # sub (negative result)
    sub  t2, t0, t1
    li   t3, -2
    bne  t2, t3, fail

    li   gp, 3                  # and
    li   t0, 0x0ff0
    li   t1, 0x00ff
    and  t2, t0, t1
    li   t3, 0x00f0
    bne  t2, t3, fail

    li   gp, 4                  # or
    or   t2, t0, t1
    li   t3, 0x0fff
    bne  t2, t3, fail

    li   gp, 5                  # xor
    xor  t2, t0, t1
    li   t3, 0x0f0f
    bne  t2, t3, fail

    li   gp, 6                  # slt (signed): -1 < 1
    li   t0, -1
    li   t1, 1
    slt  t2, t0, t1
    li   t3, 1
    bne  t2, t3, fail

    li   gp, 7                  # sltu: 0xffffffff < 1 is false
    sltu t2, t0, t1
    bnez t2, fail

    li   gp, 8                  # sll
    li   t0, 1
    li   t1, 31
    sll  t2, t0, t1
    li   t3, 0x80000000
    bne  t2, t3, fail

    li   gp, 9                  # srl
    li   t0, 0x80000000
    li   t1, 4
    srl  t2, t0, t1
    li   t3, 0x08000000
    bne  t2, t3, fail

    li   gp, 10                 # sra
    sra  t2, t0, t1
    li   t3, 0xf8000000
    bne  t2, t3, fail

    li   gp, 11                 # shift amount uses only rs2[4:0]
    li   t0, 1
    li   t1, 33
    sll  t2, t0, t1
    li   t3, 2
    bne  t2, t3, fail

    li   gp, 12                 # addi, most negative immediate
    addi t2, x0, -2048
    li   t3, -2048
    bne  t2, t3, fail

    li   gp, 13                 # slti
    li   t0, -5
    slti t2, t0, -4
    li   t3, 1
    bne  t2, t3, fail

    li   gp, 14                 # sltiu: immediate is sign-extended then unsigned
    li   t0, 5
    sltiu t2, t0, -1
    li   t3, 1
    bne  t2, t3, fail

    li   gp, 15                 # xori -1 == not
    xori t2, t0, -1
    li   t3, -6
    bne  t2, t3, fail

    li   gp, 16                 # ori / andi
    ori  t2, t0, 0x70
    li   t3, 0x75
    bne  t2, t3, fail
    andi t2, t2, 0x0f
    li   t3, 5
    bne  t2, t3, fail

    li   gp, 17                 # slli
    slli t2, t0, 3
    li   t3, 40
    bne  t2, t3, fail

    li   gp, 18                 # srli
    li   t0, 0x80000000
    srli t2, t0, 31
    li   t3, 1
    bne  t2, t3, fail

    li   gp, 19                 # srai
    srai t2, t0, 31
    li   t3, -1
    bne  t2, t3, fail

    li   gp, 20                 # lui
    lui  t2, 0x12345
    li   t3, 0x12345
    slli t3, t3, 12
    bne  t2, t3, fail

    li   gp, 21                 # auipc: result relative to its own pc
    jal  t4, here               # t4 = address of 'here'
here:
    auipc t2, 1
    sub  t2, t2, t4
    li   t3, 0x1000
    bne  t2, t3, fail

    li   gp, 22                 # writes to x0 are discarded
    addi x0, x0, 5
    add  t2, x0, x0
    bnez t2, fail

    li   gp, 23                 # add wraps on overflow
    li   t0, 0x7fffffff
    addi t2, t0, 1
    li   t3, 0x80000000
    bne  t2, t3, fail

pass:
    li   a0, 0
    ecall
fail:
    mv   a0, gp
    ecall
