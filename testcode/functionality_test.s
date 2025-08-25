functionality_test.s:
.align 4
.section .text
.globl _start
_start:

li x1,  1
li x2,  2
li x30, 5

#   all results are in decimal

#   R-Type instructions
add x3, x1, x2      #   result = 3
sub x4, x2, x1      #   result = 1
sll x5, x2, x1      #   result = 4
slt x6, x1, x2      #   result = 1
sltu x7, x1, x2     #   result = 1
xor x8, x1, x2      #   result = 3
srl x9, x1, x2      #   result = 1
sra x10, x1, x2     #   result = 1
or x11, x1, x2      #   result = 3
and x12, x1, x2     #   result = 0


#   I-type instructions
addi x13, x1, 1     #   result = 2
slti x14, x1, 2     #   result = 1
sltiu x15, x1, 2    #   result = 1
xori x16, x1, 3     #   result = 2
ori x17, x1, 5      #   result = 5
andi x18, x1, 5     #   result = 1
slli x19, x1, 2     #   result = 4
srli x20, x2, 1     #   result = 1
srai x21, x2, 1     #   result = 1
lui x30, 12         #   result = 0xC000

#   M extension instructions
mul x22, x1, x2     #   result = 2
mulh x23, x1, x2    #   result = 0
mulhu x24, x1, x2   #   result = 0
mulhsu x25, x1, x2  #   result = 0
div x26, x30, x2    #   result = 2
divu x27, x30, x2   #   result = 2
rem x28, x30, x2    #   result = 1
remu x29, x30, x2   #   result = 1

halt:
    slti x0, x0, -256