# Loads and stores of every width, with sign/zero extension.

    li   s0, 0x100              # base address in data memory

    li   gp, 1                  # sw / lw
    li   t0, 0x12345678
    sw   t0, 0(s0)
    lw   t1, 0(s0)
    bne  t1, t0, fail

    li   gp, 2                  # lbu picks the right byte lane
    lbu  t1, 0(s0)
    li   t2, 0x78
    bne  t1, t2, fail
    lbu  t1, 3(s0)
    li   t2, 0x12
    bne  t1, t2, fail

    li   gp, 3                  # lhu upper half
    lhu  t1, 2(s0)
    li   t2, 0x1234
    bne  t1, t2, fail

    li   gp, 4                  # sb only touches one byte
    li   t0, 0xff
    sb   t0, 1(s0)
    lw   t1, 0(s0)
    li   t2, 0x1234ff78
    bne  t1, t2, fail

    li   gp, 5                  # lb sign-extends
    lb   t1, 1(s0)
    li   t2, -1
    bne  t1, t2, fail

    li   gp, 6                  # lbu zero-extends
    lbu  t1, 1(s0)
    li   t2, 0xff
    bne  t1, t2, fail

    li   gp, 7                  # sh only touches one half
    li   t0, 0x8001
    sh   t0, 2(s0)
    lw   t1, 0(s0)
    li   t2, 0x8001ff78
    bne  t1, t2, fail

    li   gp, 8                  # lh sign-extends
    lh   t1, 2(s0)
    li   t2, 0xffff8001
    bne  t1, t2, fail

    li   gp, 9                  # lhu zero-extends
    lhu  t1, 2(s0)
    li   t2, 0x8001
    bne  t1, t2, fail

    li   gp, 10                 # negative offset
    addi s1, s0, 8
    sw   t0, -4(s1)
    lw   t1, 4(s0)
    bne  t1, t0, fail

    li   gp, 11                 # neighbouring word untouched
    lw   t1, 0(s0)
    li   t2, 0x8001ff78
    bne  t1, t2, fail

    li   gp, 12                 # lh of lower half
    li   t0, 0xfffe
    sh   t0, 0(s0)
    lh   t1, 0(s0)
    li   t2, -2
    bne  t1, t2, fail

pass:
    li   a0, 0
    ecall
fail:
    mv   a0, gp
    ecall
