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
#include <stdint.h>
#include <stdio.h>

int main() {
    uint64_t write_val = 0x3000000000080025;
    uint64_t read_val;
    uint64_t addr = 0x80000000;
    uint64_t sc_result;
 
    __asm__ volatile (
        "csrw 0x7C3, %0"
        :
        : "r"(write_val)
        : "memory"
    );

    __asm__ volatile (
    // Load-Reserved (Exclusive Read)
    "lr.d %[read], (%[addr])\n\t"
    // Try Exclusive Store
    "sc.d %[result], %[val], (%[addr])\n\t"
    : [read] "=&r"(read_val), [result] "=&r"(sc_result)
    : [addr] "r"(addr), [val] "r"(write_val)
    : "memory"
    );

/*
    
    // Genera un'eccezione di tipo ST_ADDR_MISALIGNED (cause = 6)
    volatile uint64_t *misaligned_addr = (uint64_t *)(0x80001003); // NON allineato a 8 byte

    __asm__ volatile (
        "sd %0, 0(%1)\n\t"     // Store word su indirizzo non allineato
        :
        : "r"(write_val), "r"(misaligned_addr)
        : "memory"
    );
  */  
    /*
    __asm__ volatile (
        "csrw 0x7C3, %0\n\t"
        ".word 0xFFFFFFFF\n\t"   // Istruzione illegale
        :
        : "r"(write_val)
        : "memory"
    );
    */

    /*
    volatile uint64_t *addr1 = (uint64_t *)0x80001000;
    volatile uint64_t *addr2 = (uint64_t *)0x80001008;

    uint64_t val1, val2;

    // Eseguiamo due operazioni di load
    __asm__ volatile (
        "ld %0, 0(%1)\n\t"
        "ld %2, 0(%3)\n\t"
        : "=r"(val1), "=r"(val2)
        : "r"(addr1), "r"(addr2)
        : "memory"
    );
*/
    return 0;
}

/*
#include <stdint.h>
#include <stdio.h>

int main(int argc, char* arg[]) {
	
    __asm__ volatile (
        "li t0, 1\n"            
        "csrw 0x7C3, t0\n"      
    );
	// printf("%d: Hello World !", 0);
	
	
    uint64_t value;

    __asm__ volatile (
        "csrr %0, 0x7C3"
        : "=r"(value)
        :
        : "memory"
    );

     if (value == 1){
        int a = 0;
        for (int i = 0; i < 5; i++)
        {
            a += i;
        }
     }

	return 0;
}
*/
/*
#include <stdint.h>

int main(int argc, char* arg[]) {
    volatile int a = 1234;
    int loaded_val;

    // Pointer to 'a'
    int* a_ptr = (int*)&a;

    // Use inline asm with lr.w
    __asm__ volatile (
        "lr.w %0, (%1)\n"
        : "=r"(loaded_val)      // output: value loaded from memory
        : "r"(a_ptr)            // input: address of a in a register
        : "memory"
    );

    for (int i = 0; i < 5; i++) {
        a += i;
    }

    return 0;
}
*/
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

/*
#include <stdint.h>

int main(int argc, char* argv[]) {
    volatile int a = 1234;
    int loaded_val, store_success, tmp;

    // Pointer to 'a'
    int* a_ptr = (int*)&a;

    // --- Store normale (SW) ---
    tmp = 5678;
    *a_ptr = tmp;  // Questo sarà il riferimento "normale" per confronto con SC

    // --- Store Condizionato (SC.W) ---
    // Finta riserva di memoria con LR.W
    __asm__ volatile (
        "lr.w %0, (%1)\n"
        : "=r"(loaded_val)
        : "r"(a_ptr)
        : "memory"
    );

    tmp = 4321; // valore che vogliamo scrivere condizionatamente
    __asm__ volatile (
        "sc.w %0, %2, (%1)\n"
        : "=r"(store_success)
        : "r"(a_ptr), "r"(tmp)
        : "memory"
    );

    // --- Atomic Swap (AMOSWAP.W) ---
    tmp = 999;
    __asm__ volatile (
        "amoswap.w %0, %2, (%1)\n"
        : "=r"(loaded_val)
        : "r"(a_ptr), "r"(tmp)
        : "memory"
    );

    return 0;
}
*/
