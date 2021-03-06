        # Check decoding of undefined instruction close to SB/SH/SW
        # =============================================================================
#include "midgetv.inc"
//#include "midgetv_minimal_csr.S"

        .globl _start
        # =============================================================================

        
#ifndef onlyEBR
        .section .text
#endif
_start:        
        // -----------------------------------------------------------------------------
        // Set trap handler address
        la      x10,_trap_handler
        la      x11,__mtvec
        sw      x10,0(x11)

        .word 0x00003023
        .word 0x00004023
        .word 0x00005023
        .word 0x00006023
        .word 0x00007023
        .word 0x40003023
        .word 0x00004023
        .word 0x00005023
        .word 0x00006023
LastOne:.word 0x00007023
        simerr 1
        
        // -----------------------------------------------------------------------------
_trap_handler:
        addi    x28,x28,1
        la      x31,__mepc
        lw      x30,0(x31)
        la      x29,LastOne
        beq     x29,x30,AtEnd
        addi    x30,x30,4
        sw      x30,0(x31)
        mret

AtEnd:
        li      x27,10
        bne     x28,x27,Failed
        simend

Failed:
        simerr  2
