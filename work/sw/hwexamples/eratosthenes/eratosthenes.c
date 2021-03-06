/*  =============================================================================
    Part of midgetv
    2019. Copyright B. Nossum.
    For licence, see LICENCE
    =============================================================================
    Check SRAM by implementation of the sieve of Eratosthenes. The program remain
    in EBR.

    At startup on the upduion2 board we light the blue LED.
    At program completion we light either the red LED (error), or the green LED (ok).
    
    This program can be simulated as compiled for a PC, run bin/simeratosthenes

    This program may be simulated, but attention, this takes time.
    Wwith the default size of SRAM, 64 KiB, we have:
    time; ./m_ice40sim_SRAM.bin -c 0x7fffffff -s -i ../obj_dir/erastosthenes.bin; time
    Thu Jul 25 10:03:54 CEST 2019
    ../../obj_dir/erastosthenes.bin          success 26782493 instructions in 233562018 cycles, cpi =  8.72 At 24 MHz, runtime = 9.732 s
    Thu Jul 25 10:31:27 CEST 2019
    So a 30 min simulation time, long.
    Incidentially this indicates the simulator clock speed f = 233562018/1653 = 141 kHz.

*/
#include <stdint.h>

#if sim
// Simulation on PC
#define sim_ADRLINES 14
#define sim_RAMSIZEBYTES ((1<<sim_ADRLINES))
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
uint8_t theSRAM[sim_RAMSIZEBYTES];
uint8_t *SRAM = theSRAM;
int dummyled;
int volatile * volatile LED = &dummyled;
#else
uint8_t *SRAM = (uint8_t *)0x80000000;
#define LED (volatile uint32_t *)0x60000004
#endif



/////////////////////////////////////////////////////////////////////////////
/* The SRAM will alias. This is used to find the amount of SRAM we really have
 */
static uint32_t find_sizeofram( void ) {
        int i = 0;
        int adrofs1,adrofs2;
        while (1) {
                adrofs1 = (1<<i);
                adrofs2 = (1<<(i+1));
#if sim
                adrofs1 &= (sim_RAMSIZEBYTES-1);
                adrofs2 &= (sim_RAMSIZEBYTES-1);
#endif
                *(SRAM+adrofs1) = 0x55;
                *(SRAM+adrofs2) = 0;
                if ( *(SRAM+adrofs1) != 0x55 )
                        break;
                i++;
        }        
        return i;
}       
        
/////////////////////////////////////////////////////////////////////////////
static void simend( void ) {
#if sim
        exit( fprintf(stderr,"Simend\n" ) );
#else
        __asm__("sltu x0,x0,x0");
#endif
}

/////////////////////////////////////////////////////////////////////////////
static void simdump( void ) {
#if sim
        ;
#else
        __asm__("sltu x0,x31,x31");
#endif
}

/////////////////////////////////////////////////////////////////////////////
void fillmemFFFFFFFF( uint32_t *p, unsigned int n) {
        while ( n-- ) {
#if sim
                assert( (uint8_t *)p < SRAM + sim_RAMSIZEBYTES );
#endif
                *p++ = 0xffffffff;
        }
}

/////////////////////////////////////////////////////////////////////////////
static int isbitset(int i ) {
        return *(SRAM + (i>>3)) & (1<<(i&7));
}

/////////////////////////////////////////////////////////////////////////////
static void bitclear(int i ) {
        *(SRAM + (i>>3)) &= ~(1<<(i&7));
}

/////////////////////////////////////////////////////////////////////////////
//void showhalt( void ) {
//        int i = 0;
//#if sim
//        return;
//#endif
//        while (1) {
//                i++;
//                *LED = (i >> 12) & 3;
//        }
//}


/////////////////////////////////////////////////////////////////////////////
/* From the PC simulation we have precalculated what
   the checksum should be
*/
const uint32_t facit[18-10] = {
        0x001f3, // 10
        0x01013, // 11
        0x026c9, // 12
        0x04763, // 13
        0x11b0a, // 14
        0x31b85, // 15
        0x10965, // 16
        0x29b6f  // 17
};

/////////////////////////////////////////////////////////////////////////////
int main( void ) {
        volatile uint32_t checksum = 0;
        int ok = 0;
        uint32_t byteadrwidth;
        uint32_t bitadrwidth;
        int n;
        int looplim;
        int i,j;
        
        *LED = 4; // Blue

        byteadrwidth = find_sizeofram();
#if sim
        printf( "byteadrwidth = %d\n", byteadrwidth );
#endif
        bitadrwidth = byteadrwidth + 3;
        n = (1<<bitadrwidth);
        looplim = (1<<(bitadrwidth/2));
        if ( bitadrwidth & 1 )
                looplim += looplim/2; // 1.5 > sqrt(2)

        /* Special for ramsize 128 KiB. Here the first two words must be 0,
         * We move the apparent start of SRAM, and adjusts n.
         * This is to make this program usable if we implement a specific
         * "feature" in the 128 KiB decoding interface.
         */
        if ( byteadrwidth == 17 ) {
                n -= 64;
                SRAM += 8;
        }
        fillmemFFFFFFFF( (uint32_t *)SRAM, n>>5 );

#if sim
        printf( "Ramsize in bits : n=0x%x. Looplim = 0x%x\n", n, looplim );
#endif

        /* To find the primes up to n, We only have to loop to sqrt(n),
         * sqrt(n) == looplim.
         */
        for ( i = 2; i < looplim; i++ ) {
                if ( isbitset(i) ) {
                        /* Remove all multiples of this prime: */
                        for ( j = 2*i; j < n; j += i ) {
                                bitclear(j);
                        }
                }
        }

        /* Traverse resulting list. In PC simulation, print the
           prime number. We make a simple checksum with the
           xor of all primes
        */
        for ( i = 2; i < n; i++ ) {
                if ( isbitset(i) ) {
                        checksum ^= i;
#if sim
                        printf( "%d ", i );
#endif
                }
        }

        ok = facit[byteadrwidth-10] == checksum;

#if sim
        if ( ok ) {
                printf( "\nOK - checksum = 0x%8.8x\n", checksum );
        } else {
                printf( "\nError or %d Uncovered. Facit:0x%x\n", byteadrwidth, checksum );
        }
#else
        if ( ok ) {
                *LED = 2; // Green
        } else {
                *LED = 1; // Red
        }
#endif
        while ( 1 ) {                
                simend(); // Hang on devboard
        }
}
        
