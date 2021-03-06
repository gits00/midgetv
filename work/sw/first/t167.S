        # Test cycle interrupt
        # =============================================================================
#include "midgetv.inc"
#include "midgetv_minimal_csr.S"
        
        .globl _start
        # =============================================================================
        // This trap handle to see if this midgetv has no system registers.
NoSysRegTrap:  
        lw      x1,%lo(__mcause)(x0)
        li      x31,5
        bne     x1,x31,5f      // ? Don't understand this
        // No system registers, so test
        // can not be performed.
        // Fake success.
        simend
5:      simerr  5
        

        # =============================================================================
NMI:
        simerr  99
InternalISR:
        // mepc should be the address of L or L+4.
        // mstatus.mpie should be 1.
        // mstatus.mie  should be 0.
        
        li      x1,__read_mstatus
        lw      x1,0(x1)
        li      x2,0b1100010000000
        //                |   |
        //                |   mie
        //                mpie
        bne     x2,x1,2f

        lw      x1,%lo(__mepc)(x0)
        la      x2,L
        beq     x1,x2,1f
        add     x2,x2,4
        bne     x1,x2,5f
1:      
        // Ensure mtimeincip == 1
        li      x1,__read_mip
//        lw      x18,0(x1)
//        srli    x18,x18,16
        lhu     x2,2(x1)
        
        addi    x2,x2,-1
        bne     x2,x0,6f

        // Clear mtimeincip by writing to mtime
        li      x3,__write_mtime
        lw      x2,0(x3)
        addi    x2,x2,1
        sw      x2,0(x3)

        // Ensure mtimeincip == 0
        lhu     x2,2(x1)
        bne     x2,x0,7f
        
        // return to the address in mepc
        mret
        
        
2:      simerr  2
4:      simerr  4
5:      simerr  5
6:      simerr  6
7:      simerr  7
        
#ifndef onlyEBR
        .section .text
#endif
        # =============================================================================
_start:
        li      x31,0xbabe
        la      x1,NoSysRegTrap         // Initiate mtvec
        sw      x1,%lo(__mtvec)(x0)
        li      x3,__read_mstatus       // Check to see if 
        lw      x4,0(x3)                // system registers implemented

        la      x1,NMI                  // Set up the internal ISR handle
        sw      x1,%lo(__rNMI_IIV)(x0)

        li      x1,8
        li      x2,__write_mstatus
        sw      x1,0(x2)                // Enable global interrupts
        li      x1,0x10000
        li      x2,__write_mie
        sw      x1,0(x2)                // Enable mtimeinc interrupts
        li      x1,0x3ffe
        sw      x1,%lo(__mcycle)(x0)    // Prime mcycle so we will soon have an interrupt

L:      lw      x10,%lo(_mtime)(x0)
        beq     x10,x0,L
       
        // Due to the handle MRET, mpie should now be 1
        li      x1,__read_mstatus
        lw      x1,0(x1)
        andi    x1,x1,0x80
        beq     x1,x0,8f
        simend

8:      simerr  8
