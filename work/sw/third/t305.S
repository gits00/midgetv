        # Check MULHSU
        # Here I shamelessly copy in cases from conformance suite

# RISC-V Compliance Test RV32IM-MUL-01
#
# Copyright (c) 2018, Imperas Software Ltd.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#      * Redistributions of source code must retain the above copyright
#        notice, this list of conditions and the following disclaimer.
#      * Redistributions in binary form must reproduce the above copyright
#        notice, this list of conditions and the following disclaimer in the
#        documentation and/or other materials provided with the distribution.
#      * Neither the name of the Imperas Software Ltd. nor the
#        names of its contributors may be used to endorse or promote products
#        derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Imperas Software Ltd. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Specification: RV32IM Base Integer Instruction Set, Version 2.0
# Description: Testing instruction MUL.

        #===========================================================
#include "midgetv.inc"
#include "fakecompliance.inc"        
        .globl _start

#ifndef onlyEBR
        .section .text
#endif

_trap_handler:
        simerr 42
        
_start:        
        // Set trap handler address
        la      x1,_trap_handler
        sw      x1,%lo(__mtvec)(x0)        

        # ---------------------------------------------------------------------------------------------
          
          RVTEST_IO_WRITE_STR(x31, "# Test number 1 - corner cases\n")
          // SIGNED RS1

        //                                        rs1   rs2     
   	TEST_MULDIV(mulhsu, x17, x18, 0,          0x0,  0x0,        1)
   	TEST_MULDIV(mulhsu, x19, x20, 0,          0x0,  0x1,        2)
   	TEST_MULDIV(mulhsu, x21, x22, 0,          0x0,  -0x1,       3) // aaaaaaaaaaaaaa
   	TEST_MULDIV(mulhsu, x23, x24, 0,          0x0,  0x7fffffff, 4)
   	TEST_MULDIV(mulhsu, x25, x26, 0,          0x0,  0x80000000, 5)
   
   	# ---------------------------------------------------------------------------------------------
   
   	RVTEST_IO_WRITE_STR(x31, "# Test number 2 - corner cases\n")
   
   	TEST_MULDIV(mulhsu, x27, x28, 0,          0x1,  0x0,        6)
   	TEST_MULDIV(mulhsu, x29, x30, 0,          0x1,  0x1,        7)
   	TEST_MULDIV(mulhsu, x21, x3,  0,          0x1,  -0x1,       8)
   	TEST_MULDIV(mulhsu, x4, x8,   0,          0x1,  0x7fffffff, 9)
   	TEST_MULDIV(mulhsu, x9, x11,  0,          0x1,  0x80000000, 10)
   
   	# ---------------------------------------------------------------------------------------------
   
   	RVTEST_IO_WRITE_STR(x31, "# Test number 3 - corner cases\n")
   
        TEST_MULDIV(mulhsu, x12, x13, 0,          -0x1, 0x0,        11) // Xaaaaaaaaaaa
 	TEST_MULDIV(mulhsu, x14, x15, 0xffffffff, -0x1, 0x1,        12)
 	TEST_MULDIV(mulhsu, x16, x17, 0xffffffff, -0x1, -0x1,       13)
 	TEST_MULDIV(mulhsu, x18, x19, 0xffffffff, -0x1, 0x7fffffff, 14)
 	TEST_MULDIV(mulhsu, x20, x21, 0xffffffff, -0x1, 0x80000000, 15)
 
 	# ---------------------------------------------------------------------------------------------
 
        RVTEST_IO_WRITE_STR(x31, "# Test number 4 - corner cases\n")
 
        TEST_MULDIV(mulhsu, x22, x23, 0, 0x7fffffff, 0x0, 16)
        TEST_MULDIV(mulhsu, x24, x25, 0, 0x7fffffff, 0x1, 17)
 	TEST_MULDIV(mulhsu, x26, x27, 0x7ffffffe, 0x7fffffff, -0x1, 18)
        TEST_MULDIV(mulhsu, x28, x29, 0x3fffffff, 0x7fffffff, 0x7fffffff, 19)
        TEST_MULDIV(mulhsu, x30, x21, 0x3fffffff, 0x7fffffff, 0x80000000, 20)
 
 	# ---------------------------------------------------------------------------------------------
 
 	RVTEST_IO_WRITE_STR(x31, "# Test number 5 - corner cases\n")
 
 	TEST_MULDIV(mulhsu, x3, x4, 0, 0x80000000, 0x0, 21)
	TEST_MULDIV(mulhsu, x8, x9, 0xffffffff, 0x80000000, 0x1, 22)
	TEST_MULDIV(mulhsu, x11, x12, 0x80000000, 0x80000000, -0x1, 23)
	TEST_MULDIV(mulhsu, x13, x14, 0xc0000000, 0x80000000, 0x7fffffff, 24)
	TEST_MULDIV(mulhsu, x15, x16, 0xc0000000, 0x80000000, 0x80000000, 25)
 
 	RVTEST_IO_WRITE_STR(x31, "Test End\n")
        simend
