#include "midgetv.inc"
        .globl _start
        .section .text
#include "midgetv_dump_compliance.S"
_start: 
#include "DIVU.S"
