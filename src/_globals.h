/*
 * _globals.h
 *
 *  Created on: 15. aug. 2018
 *      Author: teig
 */

#ifndef GLOBALS_H_
#define GLOBALS_H_

#ifdef GLOBALS_H_ // To show that the below may also be defined in library space

    // BOOLEAN #include <stdbool.h> if C99
    // See http://www.teigfam.net/oyvind/home/technology/165-xc-code-examples/#bool
    typedef enum {false,true} bool; // 0,1 This typedef matches any integer-type type like long, int, unsigned, char, bool

    #define min(a,b) (((a)<(b))?(a):(b))
    #define max(a,b) (((a)>(b))?(a):(b))
    #define abs(a)   (((a)<0)?(-(a)):(a))

    #define t_swap(type,a,b) {type t = a; a = b; b = t;}

    #define NUM_ELEMENTS(array) (sizeof(array) / sizeof(array[0])) // Kernighan & Pike p22

    typedef signed int time32_t; // signed int (=signed) or unsigned int (=unsigned) both ok, as long as they are monotoneously increasing
                                 // XC/XMOS 100 MHz increment every 10 ns for max 2exp32 = 4294967296,
                                 // ie. divide by 100 mill = 42.9.. seconds

    typedef enum {led_on, led_off} led_on_low_t; // 0 is led_on

    #define AFTER_32(a,b) ((a-b)>0)

    #ifdef DO_ASSERTS
        #define ASSERT_DELAY_32(d) do {if (d > INT_MAX) fail("Overflow");} while (0) // Needs <so646.h<, <limits.h> and <xassert.h>
        // INT_MAX is 2147483647 is what fits into 31 bits or last value before a signed 32 bits wraps around
    #else
        #define ASSERT_DELAY_32(d)
    #endif

    #define NOW_32(tmr,time) do {tmr :> time;} while(0) // A tick is 10ns
    // “Programming XC on XMOS Devices” (Douglas Watt)
    //     If the delay between the two input values fits in 31 bits, timerafter is guaranteed to behave correctly,
    //     otherwise it may behave incorrectly due to overlow or underflow. This means that a timer can be used to
    //     measure up to a total of 2exp31 / (100 mill) = 21s.

    typedef enum {beep_off = 0, beep_now = 1} beep_high_e; // Must be {0,1} like this! Using boolean expression on it
    typedef enum {LED_off  = 0, LED_on   = 1} LED_high_e;  // Must be {0,1} like this! Using boolean expression on it
    typedef enum {pin_low  = 0, pin_high = 1} port_pin_e;  // Must be {0,1} like this! Using boolean expression on it

#endif

#define IS_MYTARGET_VOID               0
#define IS_MYTARGET_STARTKIT           1 // Not used here
#define IS_MYTARGET_XCORE_200_EXPLORER 2 // Maybe?
#define IS_MYTARGET_XCORE_XA_MODULE    3

#if (MYTARGET==XCORE-200-EXPLORER)
    #define IS_MYTARGET                  IS_MYTARGET_XCORE_200_EXPLORER
    // Observe PWM=001 for xflash
#elif (MYTARGET==XCORE-XA-MODULE)
    #define IS_MYTARGET IS_MYTARGET_XCORE_XA_MODULE
    //
    // The XMOS XS1-XAU8A-10-FB265 processor that's on XCORE-XA-MODULE
    // https://www.xmos.com/download/XS1-XAU8A-10-FB265-Datasheet(1.1).pdf
    // https://www.farnell.com/datasheets/1886306.pdf (however 8 xCORE)
    // https://www.xmos.com/download/xCORE-XA-Module-Board-Hardware-Manual(1.0).pdf
    //
    // https://www.teigfam.net/oyvind/home/technology/208-my-processor-to-analogue-audio-equaliser-notes/
    //
    // XCORE        64KB internal single-cycle SRAM for code and data storage
    //               8KB internal OTP for application boot code
    //                   DEBUG via xCORE xTAG
    // ARM         128KB internal single-cycle SRAM for code and data storage
    //            1024KB internal SPI FLASH of type AT25FS010 according to XCORE-XA-MODULE.xn. Boots ARM which again may boot XCORE
    //                   DEBUG via SEGGER J-Link OB
    // EXTERNAL    512KB external SPI FLASH of type M25P40. Used to boot XCORE
    //
#else
    #error NO TARGET DEFINED
#endif

// CONFIGURATIONS                 (xyz)
#define CONFIG_NUM_SOFTBLIKER_LEDS 2   // [1,2]
#define CONFIG_NUM_TASKS_PER_LED    2  // [1,2]
#define CONFIG_PAR_ON_CORES          8 // [1-8]
                                       // (xyz)                                8-cores  10-timers 32-chanends  From my_script-xta (code will run even if timing analysis fails!)
                                       // (11z)  1 LED 1 TASK
                                       // (113):                Constraints:   C: 2     T: 2      C:  2        Violation: 40.0 ns
                                       // (12z)  1 LEDS 2 TASKS
                                       // (121):                Constraints:   C: 2     T: 2      C:  2               error: Failed to find route with id:
                                       // (122):                Constraints:   C:1      T:1       C:0                 error: Failed to find route with id:
                                       // (123):                Constraints:   C:  3    T:  3     C:    4      Slack: 760.0 ns
                                       // (124):                Constraints:   C: 2     T: 2      C:  2               error: Failed to find route with id:
                                       // (125):                Constraints:   C:  3    T:  3     C:    4      Slack: 750.0 ns
                                       // (21z)  2 LEDS 1 TASK
                                       // (212):                Constraints:   C: 2     T: 2      C:  3                error: Failed to find route with id:
                                       // (213):                Constraints:   C:  3    T:  3     C:   3       Slack: 0.0 ns
                                       // (214):                Constraints:   C:1      T:1       C:0                 error: Failed to find route with id:
                                       // (22z)  2 LEDS 2 TASKS
                                       // (221):                Constraints:   C:  3    T:  3     C:  3               error: Failed to find route with id:
                                       // (222):                Constraints:   C: 2     T: 2      C:  3               error: Failed to find route with id:
                                       // (223):                Constraints:   C:    5  T:    5   C:      7    Slack: 760.0 ns
                                       // (224):                Constraints:   C:1      T:1       C:0                 error: Failed to find route with id:
                                       // (225):                Constraints:   C:    5  T:    5   C:       7   Slack: 760.0 ns
                                       // (226):                Constraints:   C:    5  T:    5   C:       7   Slack: 760.0 ns
                                       // (227):                Constraints:   C:   4   T:   4    C:      6    Slack: 760.0 ns
                                       // (228):                Constraints:   C:  3    T:  3     C:     3     Slack: 760.0 ns

#define CONFIG_BARRIER 1 // 0 No barrier
                         // 1 interface  Total 12 chanends
                         // 2 chan       Total 11 chanends

#define DEBUG_PRINT_GLOBAL_APP 1 // 0: all printf off
                                 // 1: controlled locally in each xc file

#endif
