    .section .s_text, "ax"
    .globl s_function
    .type s_function, @function
s_function:
    li t0, 42              # a = 42
    addi t0, t0, 1         # a++ (dummy operations)
    jal rvtest_code_begin  # jump to the test code
    j .                      
    .size s_function, .-s_function
loop:
    j loop                 # while(1)
