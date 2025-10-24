/*
 Author: Valerio Di Domenico <valerio.didomenico@unina.it>
 Description:
   This code is used to test MPTWs of PTW, Load Unit, Store Unit and IF Unit.
*/


//*************************************** DEFAULT *************************************** 
/*
#include <stdint.h>
#include <stdio.h>

int main(int argc, char* arg[]) {
	
	printf("%d: Hello World !", 0);
	
	int a = 0;
	for (int i = 0; i < 5; i++)
	{
		a += i;
	}
	return 0;
}
*/

//*************************************** MPT TESTS *************************************** */

#include <stdint.h>
volatile uint32_t *reg = (uint32_t *)0x80001000; 
void s_function() __attribute__((section(".s_text")));
void s_function() {
    volatile int a = 42;  // dummy operations
    a++;
    *reg = 1;             // to_host=1 means stop simulation
    while(1);             // loop 
}

extern void s_function();
#define S_FUNC_ADDR ((uintptr_t)&s_function)

void jump_to_s() {
    uintptr_t ms;
    __asm__ volatile ("csrr %0, mstatus" : "=r"(ms));
    ms &= ~(3UL << 11);       // clean MPP
    ms |=  (1UL << 11);       // MPP = S-mode (1)
    __asm__ volatile ("csrw mstatus, %0" :: "r"(ms));

    __asm__ volatile ("csrw mepc, %0" :: "r"(S_FUNC_ADDR));
    //__asm__ volatile ("csrw stvec, %0" :: "r"(S_FUNC_ADDR));
    //*reg = 1; 
    __asm__ volatile ("mret" ::: "memory");
}

/* ---- Main ---- */
int main() {

    uint64_t write_val = 0x3000000000081000;

    // PMP configuration
    asm volatile (
        "li t0, 0x80000000 >> 0\n"   // base-address >>2
        "csrw pmpaddr0, t0\n"
        "li t0, 0x90000000 >> 0\n"
        "csrw pmpaddr1, t0\n"
        "li t0, (0b01 << 3) | 0b111\n" // TOR mode + R/W/X
        "csrw pmpcfg0, t0\n"
    );

    uint64_t *mpt_entry1 = (uint64_t *)0x81000000;

/*  //******************* Test case 1 *********************************
    //******************* 1-walking level *****************************
    
    // Leaf-entry --> access allowed
    *mpt_entry1 = 0x3FFFFFFFFFFFC03ULL;
*/
/*  //******************* Test case 2 *********************************
    //******************* 2-walking levels *****************************

    // Non-leaf entry
    *mpt_entry1 = 0x0000000024000001ULL;
    // Leaf-entry --> access allowed  
    uint64_t *mpt_entry2 = (uint64_t *)0x90000000;
    *mpt_entry2 = 0x3FFFFFFFFFFFC03ULL;
 */
    //******************* Test case 3 *********************************
    //******************* 4-walking levels *****************************

    // Non-leaf entry
    *mpt_entry1 = 0x0000000024000001ULL;
    // Non-leaf-entry
    uint64_t *mpt_entry2 = (uint64_t *)0x90000000;
    *mpt_entry2 = 0x0000000024000001ULL;
    // Leaf-entry --> access allowed
    uint64_t *mpt_entry3 = (uint64_t *)0x90000200;
    *mpt_entry3 = 0x3FFFFFFFFFFFC03ULL;

/*  //******************* Test case 4 ********************************* 
    //******************* 4-walking levels with error *******************

    // Non-leaf entry
    *mpt_entry1 = 0x0000000024000001ULL;
    // Non-leaf-entry
    uint64_t *mpt_entry2 = (uint64_t *)0x90000000;
    *mpt_entry2 = 0x0000000024000001ULL;
    // Leaf-entry --> access not allowed
    uint64_t *mpt_entry3 = (uint64_t *)0x90000200;
    *mpt_entry3 = 0x0000000000000003ULL;
*/

    // Enable MPT via MMPT register
    __asm__ volatile (
        "csrw 0x7C3, %0"
        :
        : "r"(write_val)
        : "memory"
    );

    // Write satp register to enable virtual memory
    __asm__ volatile (
        "csrw satp, %0"
        :
        : "r"(8ULL << 60 | 0x80008ULL) // write here the ppn corresponding to the root page table that should be mapped at 0x80008000 (look at link.ld)
    ); // we have to shift the ppn by 12 bits because PTW computes "a" value as satp.ppn*PAGESIZE where PAGESIZE is 4096 (2^12)

    uint64_t *page_table_entry1 = (uint64_t *)0x80008010; // Address of the first page table entry
    *page_table_entry1 = 0b100000000000000000000011101111ULL; // Value of the first page table entry

    jump_to_s();  // jump to S-mode
    return 0;
}
