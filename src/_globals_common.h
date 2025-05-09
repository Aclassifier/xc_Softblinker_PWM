/*
 * _globals_common.h
 *
 *  Created on: 23. sep. 2020
 *      Author: teig
 */


#ifndef GLOBALS_COMMON_H_
  #define GLOBALS_COMMON_H_

    // BOOLEAN #include <stdbool.h> if C99
    // See http://www.teigfam.net/oyvind/home/technology/165-xc-code-examples/#bool
    typedef enum {false,true} bool; // 0,1 This typedef matches any integer-type type like long, int, unsigned, char, bool

    typedef unsigned id_task_t;

    typedef signed int time32_t; // signed int (=signed) or unsigned int (=unsigned) both ok, as long as they are monotoneously increasing
                                 // XC/XMOS 100 MHz increment every 10 ns for max 2exp32 = 4294967296,
                                 // ie. divide by 100 mill = 42.9.. seconds

    typedef enum {LED_off  = 0, LED_on   = 1} LED_high_e;  // Must be {0,1} like this! Using boolean expression on it

    typedef enum {pin_low  = 0, pin_high = 1} port_pin_e;  // Must be {0,1} like this! Using boolean expression on it

    #define DEBUG_PRINT_GLOBAL_APP 0 // 0: all printf off
                                     // 1: controlled locally in each xc file

#else
    #error Nested inlude "_global_common.h"
#endif /* GLOBALS_COMMON_H_ */
