# Small programs: bubble sort an array in memory, then compute fib(20).

    li   s0, 0x200              # array base
    li   s1, 8                  # length

    li   t0, 9
    sw   t0, 0(s0)
    li   t0, -3
    sw   t0, 4(s0)
    li   t0, 27
    sw   t0, 8(s0)
    li   t0, 0
    sw   t0, 12(s0)
    li   t0, 14
    sw   t0, 16(s0)
    li   t0, -100
    sw   t0, 20(s0)
    li   t0, 5
    sw   t0, 24(s0)
    li   t0, 1
    sw   t0, 28(s0)

    # bubble sort (signed, ascending)
    li   t0, 0                  # i
    addi t6, s1, -1             # n - 1
outer:
    bge  t0, t6, sorted
    li   t1, 0                  # j
    sub  t5, t6, t0             # inner limit = n - 1 - i
inner:
    bge  t1, t5, inner_done
    slli t2, t1, 2
    add  t2, t2, s0
    lw   t3, 0(t2)
    lw   t4, 4(t2)
    ble  t3, t4, noswap
    sw   t4, 0(t2)
    sw   t3, 4(t2)
noswap:
    addi t1, t1, 1
    j    inner
inner_done:
    addi t0, t0, 1
    j    outer

sorted:                         # expect -100 -3 0 1 5 9 14 27
    li   gp, 1
    lw   t0, 0(s0)
    li   t1, -100
    bne  t0, t1, fail
    li   gp, 2
    lw   t0, 4(s0)
    li   t1, -3
    bne  t0, t1, fail
    li   gp, 3
    lw   t0, 8(s0)
    bnez t0, fail
    li   gp, 4
    lw   t0, 12(s0)
    li   t1, 1
    bne  t0, t1, fail
    li   gp, 5
    lw   t0, 16(s0)
    li   t1, 5
    bne  t0, t1, fail
    li   gp, 6
    lw   t0, 20(s0)
    li   t1, 9
    bne  t0, t1, fail
    li   gp, 7
    lw   t0, 24(s0)
    li   t1, 14
    bne  t0, t1, fail
    li   gp, 8
    lw   t0, 28(s0)
    li   t1, 27
    bne  t0, t1, fail

    li   gp, 9                  # fib(20) = 6765, iteratively
    li   t0, 0
    li   t1, 1
    li   t2, 20
fib:
    beqz t2, fib_done
    add  t3, t0, t1
    mv   t0, t1
    mv   t1, t3
    addi t2, t2, -1
    j    fib
fib_done:
    li   t1, 6765
    bne  t0, t1, fail

pass:
    li   a0, 0
    ecall
fail:
    mv   a0, gp
    ecall
