/*
**
** Copyright 2020 OpenHW Group
**
** Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
** you may not use this file except in compliance with the License.
** You may obtain a copy of the License at
**
**     https://solderpad.org/licenses/
**
** Unless required by applicable law or agreed to in writing, software
** distributed under the License is distributed on an "AS IS" BASIS,
** WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
** See the License for the specific language governing permissions and
** limitations under the License.
**
*/

/*#include <stdint.h>
#include <stdio.h>

int main(int argc, char* arg[]) {
	
	printf("%d: Hello World !", 0);
	
	int a = 0;
	for (int i = 0; i < 5; i++)
	{
		a += i;
	}
	return 0;
}*/

#include <stdint.h>

/* ---- Dichiarazione funzione S-mode ---- */
/* Mettiamo la funzione in una sezione dedicata .s_text */
void s_function() __attribute__((section(".s_text")));
void s_function() {
    volatile int a = 42;  // operazioni dummy
    a++;                  // esempio di uso della memoria
    while(1);             // loop infinito per test
}

/* ---- Ottenere automaticamente l'indirizzo della funzione S-mode ---- */
extern void s_function();
#define S_FUNC_ADDR ((uintptr_t)&s_function)

/* ---- Salta alla funzione S-mode configurando MPP e mepc ---- */
void jump_to_s() {
    uintptr_t ms;
    __asm__ volatile ("csrr %0, mstatus" : "=r"(ms));
    ms &= ~(3UL << 11);       // pulisce MPP
    ms |=  (1UL << 11);       // MPP = S-mode (1)
    __asm__ volatile ("csrw mstatus, %0" :: "r"(ms));

    __asm__ volatile ("csrw mepc, %0" :: "r"(S_FUNC_ADDR));
    //__asm__ volatile ("csrw stvec, %0" :: "r"(S_FUNC_ADDR));
    __asm__ volatile ("mret" ::: "memory");
}

/* ---- Main ---- */
int main() {
    uint64_t write_val = 0x3000000000081000;
    // PMP configuration
    asm volatile (
        "li t0, 0x80000000 >> 0\n"   // indirizzo base >>2
        "csrw pmpaddr0, t0\n"
        "li t0, 0x90000000 >> 0\n"
        "csrw pmpaddr1, t0\n"
        "li t0, (0b01 << 3) | 0b111\n" // TOR mode + R/W/X
        "csrw pmpcfg0, t0\n"
    );
    uint64_t *mpt_entry1 = (uint64_t *)0x81000000;
/*
    //******************* 1-walking level *****************************
    
    // Leaf-entry --> access allowed
    //*mpt_entry1 = 0x03FFFFFFFFFFFC03ULL;
*/

/*
    //******************* 2-walking levels *****************************

    // Non-leaf entry
    *mpt_entry1 = 0x0000000024000001ULL;
    // Leaf-entry --> access allowed  
    uint64_t *mpt_entry2 = (uint64_t *)0x90000000;
    *mpt_entry2 = 0x3FFFFFFFFFFFC03ULL;
*/

/*
    //******************* 3-walking levels *****************************

    // Non-leaf entry
    *mpt_entry1 = 0x0000000024000001ULL;
    // Non-leaf-entry
    uint64_t *mpt_entry2 = (uint64_t *)0x90000000;
    *mpt_entry2 = 0x0000000024000001ULL;
    // Leaf-entry --> access allowed
    uint64_t *mpt_entry3 = (uint64_t *)0x90000200;
    *mpt_entry3 = 0x3FFFFFFFFFFFC03ULL;
*/
    // Enable MPT via MMPT register
    __asm__ volatile (
        "csrw 0x7C3, %0"
        :
        : "r"(write_val)
        : "memory"
    );

    jump_to_s();
    return 0;
}

// 
// #include <stdint.h>
// 
// int main(int argc, char* arg[]) {
//     uint64_t write_val = 0x3000000000080025;
//     volatile int a = 1234;
//     int loaded_val;
//     int store_result;
//     int new_val = 5678;
// 
//     // Pointer to 'a'
//     int* a_ptr = (int*)&a;
// 
//     __asm__ volatile (
//         "csrw 0x7C3, %0"
//         :
//         : "r"(write_val)
//         : "memory"
//     );
// 
//     // Use inline asm with lr.w and sc.w
//     __asm__ volatile (
//         "lr.w %[val], (%[addr])\n"         // Load-reserved into val
//         "sc.w %[res], %[newval], (%[addr])\n" // Try store-conditional newval into a
//         : [val] "=&r"(loaded_val),         // output: value loaded from memory
//           [res] "=&r"(store_result)        // output: result of store-conditional (0 = success)
//         : [addr] "r"(a_ptr),               // input: address of 'a'
//           [newval] "r"(new_val)            // input: value to store
//         : "memory"
//     );
//     
//     /* ---- Switch a HS/S-mode e ritorno con mret ---- */
//     uintptr_t ms;
//         /* Leggi mstatus */
//         __asm__ volatile ("csrr %0, mstatus" : "=r"(ms));
//         /* MPP è in mstatus[12:11]: pulisci e metti 00 (U-mode) */
//         ms &= ~(3UL << 11);     // clear MPP
//         ms |=  (1UL << 11);     // set MPP=00 => U-mode
//         /* Scrivi mstatus aggiornato */
//         __asm__ volatile ("csrw mstatus, %0" :: "r"(ms));
// //
// //        /* Imposta mepc all'etichetta 1f e fai mret */
// //        __asm__ volatile (
// //            "la t0, 1f\n"       /* carica indirizzo dell'etichetta 1 */
// //            "csrw mepc, t0\n"   /* mepc <- 1f */
// //            "mret\n"            /* passa a HS/S-mode e salta a 1f   */
// //            "1:\n"
// //            :
// //            :
// //            : "t0", "memory"
// //        );
// 
//         __asm__ volatile (
//             "csrw mepc, %0\n"
//             :
//             : "r"(0x000000008000306CUL)
//             : "memory"
//         );
// 
// /*
//         __asm__ volatile (
//             "csrw mepc, %0\n"
//             :
//             : "r"(0x0000000080003000UL)
//             : "memory"
//         );
// */
// 
//         __asm__ volatile (
//             "mret\n"
//             :
//             :
//             : "memory"
//         );
// 
// 
//     return 0;
// 
// }


// ***********************************  AMO INSTRUCTIONS **********************************************
/*
#include <stdint.h>

int main(int argc, char* argv[]) {
    volatile int a = 1234;
    int loaded_val, store_success, tmp;

    // Pointer to 'a'
    int* a_ptr = (int*)&a;

    // Atomic Load-Reserved (lr.w)
    __asm__ volatile (
        "lr.w %0, (%1)\n"
        : "=r"(loaded_val)
        : "r"(a_ptr)
        : "memory"
    );

    // Atomic Store-Conditional (sc.w)
    tmp = 4321; // value we try to store
    __asm__ volatile (
        "sc.w %0, %2, (%1)\n"
        : "=r"(store_success)
        : "r"(a_ptr), "r"(tmp)
        : "memory"
    );

    // Atomic Swap (amoswap.w)
    tmp = 999;
    __asm__ volatile (
        "amoswap.w %0, %2, (%1)\n"
        : "=r"(loaded_val)
        : "r"(a_ptr), "r"(tmp)
        : "memory"
    );

    // Atomic Add (amoadd.w)
    tmp = 5;
    __asm__ volatile (
        "amoadd.w %0, %2, (%1)\n"
        : "=r"(loaded_val)
        : "r"(a_ptr), "r"(tmp)
        : "memory"
    );

    // Atomic XOR (amoxor.w)
    tmp = 0xFFFF;
    __asm__ volatile (
        "amoxor.w %0, %2, (%1)\n"
        : "=r"(loaded_val)
        : "r"(a_ptr), "r"(tmp)
        : "memory"
    );

    return 0;
}
*/