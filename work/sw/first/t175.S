        # CSRW 
        # The smallest midgetv have no CSR, but the instruction is decoded 
        # nevertheless. This is to check the decoding
        # =============================================================================
#include "midgetv.inc"
        .globl _start
        # =============================================================================
        # Entry point for CSR instructions
        .org 0x108
        lw      x1,%lo(__yy)(x0)        // CSR address
        li      x3,0x123
        bne     x1,x3,1f

/* Following introduction of RVC instructions, the CSR type must 
 * unfortunately be decoded in emulation code
 */
        lw      x1,%lo(CSRretadr)(x0)
        lh      x1,0(x1)
        srli    x1,x1,10
        andi    x1,x1,28        // CSR type
        li      x2,4
        bne     x1,x2,2f
        simend
        
1:      simerr  1
2:      simerr  2
3:      simerr  3
4:      simerr  4
5:      simerr  5
6:      simerr  6
#ifndef onlyEBR
        .section .text
#endif

_start:
        csrrw x1,0x123,x2 // gives immediate 0x123
        simdump
        simerr 7
