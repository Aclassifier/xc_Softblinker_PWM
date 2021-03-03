/*
 * _globals.h
 *
 *  Created on: 15. aug. 2018
 *      Author: teig
 */

#ifndef GLOBALS_H_
    #define GLOBALS_H_

    #include "_lib_pwm_softblinker_params.h" // Common

    #define min(a,b) (((a)<(b))?(a):(b))
    #define max(a,b) (((a)>(b))?(a):(b))
    #define abs(a)   (((a)<0)?(-(a)):(a))

    #define t_swap(type,a,b) {type t = a; a = b; b = t;}

    #define NUM_ELEMENTS(array) (sizeof(array) / sizeof(array[0])) // Kernighan & Pike p22

    typedef enum {low_is_on,  high_is_off} led_on_low_t;  // 0 is led_on
    typedef enum {low_is_off, high_is_on}  led_on_high_t; // 1 is led_on

    #define AFTER_32(a,b) ((a-b)>0)

    #ifdef DO_ASSERTS
        #define ASSERT_DELAY_32(d) do {if (d > INT_MAX) fail("Overflow");} while (0) // Needs <so646.h<, <limits.h> and <xassert.h>
        // INT_MAX is 2147483647 is what fits into 31 bits or last value before a signed 32 bits wraps around
    #else
        #define ASSERT_DELAY_32(d)
    #endif

    #define NOW_32(tmr,time) do {tmr :> time;} while(0) // A tick is 10ns
    // ÒProgramming XC on XMOS DevicesÓ (Douglas Watt)
    //     If the delay between the two input values fits in 31 bits, timerafter is guaranteed to behave correctly,
    //     otherwise it may behave incorrectly due to overlow or underflow. This means that a timer can be used to
    //     measure up to a total of 2exp31 / (100 mill) = 21s.

    typedef enum {beep_off = 0, beep_now = 1} beep_high_e; // Must be {0,1} like this! Using boolean expression on it


    #define IS_MYTARGET_VOID               0
    #define IS_MYTARGET_STARTKIT           1 // Not used here
    #define IS_MYTARGET_XCORE_200_EXPLORER 2 // Maybe?
    #define IS_MYTARGET_XCORE_XA_MODULE    3

    #if (MYTARGET==IS_MYTARGET_STARTKIT)
        #error No PIN placement
    #elif (MYTARGET==XCORE-200-EXPLORER)
        #define IS_MYTARGET IS_MYTARGET_XCORE_200_EXPLORER
        // Observe PWM=001 for xflash
    #elif (MYTARGET==XCORE-XA-MODULE)
        #error XCORE-XA-MODULE I have no idea how to flash!
    #else
        #error NO TARGET DEFINED
    #endif

    #define CONFIG_BARRIER 1 // 0 uses no barrier                            ->  7 chanends
                             // 1 uses chan based barrier and a barrier task -> 11 chanends
    #define CONFIG_NUM_TASKS_PER_LED 1 //
#else
    #error Nested include "_globals.h"
#endif
