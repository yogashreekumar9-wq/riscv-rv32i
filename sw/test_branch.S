# Branches, JAL and JALR.

    li   gp, 1                  # beq taken
    li   t0, 5
    li   t1, 5
    beq  t0, t1, ok1
    j    fail
ok1:
    li   gp, 2                  # beq not taken
    li   t1, 6
    beq  t0, t1, fail

    li   gp, 3                  # bne taken / not taken
    bne  t0, t1, ok3
    j    fail
ok3:
    bne  t0, t0, fail

    li   gp, 4                  # blt is signed: -1 < 1
    li   t0, -1
    li   t1, 1
    blt  t0, t1, ok4
    j    fail
ok4:
    li   gp, 5
    blt  t1, t0, fail
    blt  t0, t0, fail

    li   gp, 6                  # bltu is unsigned: 1 < 0xffffffff
    bltu t0, t1, fail
    bltu t1, t0, ok6
    j    fail
ok6:
    li   gp, 7                  # bge, including equal
    bge  t1, t0, ok7a
    j    fail
ok7a:
    bge  t0, t0, ok7b
    j    fail
ok7b:
    bge  t0, t1, fail

    li   gp, 8                  # bgeu
    bgeu t0, t1, ok8
    j    fail
ok8:
    bgeu t1, t0, fail

    li   gp, 9                  # jal + ret
    li   a1, 0
    jal  ra, func
    li   t2, 42
    bne  a1, t2, fail

    li   gp, 10                 # jalr clears bit 0 of the target, links pc+4
    jal  t4, base               # t4 = address of 'base'
base:
    addi t5, t4, 13             # base+12 with bit 0 set
    jalr ra, 0(t5)              # at base+4
    j    fail                   # base+8
    addi t6, t4, 8              # base+12: jump lands here
    bne  ra, t6, fail

    li   gp, 11                 # backward branch loop
    li   t0, 0
    li   t1, 10
loop:
    addi t0, t0, 1
    blt  t0, t1, loop
    li   t2, 10
    bne  t0, t2, fail

    li   gp, 12                 # forward jump skips code
    j    skip
    j    fail
skip:

pass:
    li   a0, 0
    ecall
fail:
    mv   a0, gp
    ecall

func:
    li   a1, 42
    ret
