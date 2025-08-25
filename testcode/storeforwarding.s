storeforwarding.s:
.align 4
.section .text
.globl _start
_start:
    # Initialize base address in a register
    la t0, 0xeceb0000  

    li t1, 42         # Load immediate value 42 into t1
    sw t1, 0(t0)      # Store t1 into memory at address in t0

    li t1, 73         # Load immediate value 73 into t1
    sw t1, 0(t0)      # Store t1 into memory at address in t0

    li t1, 123        # Load immediate value 123 into t1
    sw t1, 0(t0)      # Store t1 into memory at address in t0

    li t1, 256        # Load immediate value 256 into t1
    sw t1, 0(t0)      # Final store to memory at address in t0

    # Load the final value into a different register
    lw t2, 0(t0)      # Load word from memory into t2

    slti x0, x0, -256