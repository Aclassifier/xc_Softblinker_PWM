/*
  * pwm_softblinker.xc
 *
 *  Created on: 22. juni 2020
 *      Author: teig
 */

#include <xs1.h>
#include <platform.h> // slice
#include <timer.h>    // delay_milliseconds(200), XS1_TIMER_HZ etc
#include <stdint.h>   // uint8_t
#include <stdio.h>    // printf
#include <string.h>   // memcpy
#include <xccompat.h> // REFERENCE_PARAM(my_app_ports_t, my_app_ports) -> my_app_ports_t &my_app_ports
#include <iso646.h>   // not etc.

#include "_version.h"  // First this..
#include "_globals.h"  // ..then this

#include "maths.h"

#include "pwm_softblinker.h"

// ---
// Control printing
// See https://stackoverflow.com/questions/1644868/define-macro-for-debug-printing-in-c
// ---

#define DEBUG_PRINT_TEST 0
#define debug_print(fmt, ...) do { if((DEBUG_PRINT_TEST==1) and (DEBUG_PRINT_GLOBAL_APP==1)) printf(fmt, __VA_ARGS__); } while (0)

#if (CONFIG_NUM_TASKS_PER_LED==2)

    [[combinable]]
    void softblinker_task (
            const unsigned        id_task, // For printing only
            client pwm_if         if_pwm,
            server softblinker_if if_softblinker)
    {
        debug_print ("%u softblinker_task started\n", id_task);

        // --- softblinker_context_t for softblinker_pwm_for_LED_task
        timer        tmr;
        time32_t     timeout;
        bool         pwm_running;
        unsigned     pwm_one_percent_ticks;
        signed       now_percentage;
        percentage_t max_percentage;
        percentage_t min_percentage;
        signed       inc_percentage;
        // ---

        pwm_running = false;
        pwm_one_percent_ticks = SOFTBLINK_DEFAULT_PERIOD_MS * XS1_TIMER_KHZ;
        now_percentage        = SOFTBLINK_DEFAULT_MAX_PERCENTAGE; // [-1..101]
        max_percentage        = SOFTBLINK_DEFAULT_MAX_PERCENTAGE;
        min_percentage        = SOFTBLINK_DEFAULT_MIN_PERCENTAGE;
        inc_percentage        = (-1); // [-1,+1]

        tmr :> timeout;
        timeout += pwm_one_percent_ticks;

        while (1) {
            select {
                case (pwm_running) => tmr when timerafter(timeout) :> void: {
                    bool min_set;
                    bool max_set;

                    timeout += pwm_one_percent_ticks;

                    now_percentage += inc_percentage; // [0..100] but [-1..101] possible if 0 or 100 was just set in set_LED_intensity
                    {now_percentage, min_set, max_set} =
                            in_range_signed_min_max_set (now_percentage, min_percentage, max_percentage); // [0..100]

                    if ((min_set) or (max_set)) { // Send 100 and 0 only once
                        inc_percentage = (-inc_percentage); // Change sign for next timeout to scan in the other direction
                    } else {
                        if_pwm.set_LED_intensity ((percentage_t) now_percentage); // [0..100]
                    }

                } break;

                case if_softblinker.set_LED_intensity_range (const percentage_t min_percentage_, const percentage_t max_percentage_): {

                    min_percentage = (percentage_t) in_range_signed ((signed) min_percentage_, SOFTBLINK_DEFAULT_MIN_PERCENTAGE, SOFTBLINK_DEFAULT_MAX_PERCENTAGE);
                    max_percentage = (percentage_t) in_range_signed ((signed) max_percentage_, SOFTBLINK_DEFAULT_MIN_PERCENTAGE, SOFTBLINK_DEFAULT_MAX_PERCENTAGE);
                    //
                    //     min_percentage   0 here and min_percentage may be decremented to  -1 in timerafter (*)
                    //     max_percentage 100 here and max_percentage may be incremented to 101 in timerafter (*)
                    // (*) Conflict with jumping above or below present range resolved with in_range_signed_min_max_set in timerafter

                    // Printing disturbs 1ms update messages above, so will appear to "blink"
                    debug_print ("%u set_LED_intensity %u %u\n", id_task, min_percentage, max_percentage);

                    if (max_percentage == min_percentage) { // No change of intensity
                        pwm_running = false;
                        if_pwm.set_LED_intensity (max_percentage);
                    } else if (not pwm_running) {
                        pwm_running = true;
                        tmr :> timeout; // immediate timeout
                    } else { // pwm_running already
                        // No code
                        // Don't disturb running timerafter
                    }
                } break;

                case if_softblinker.set_LED_period_ms (const unsigned period_ms_, const LED_start_at_e LED_start_at): {

                    unsigned period_ms = in_range_signed (period_ms_, SOFTBLINK_PERIOD_MIN_MS, SOFTBLINK_PERIOD_MAX_MS);

                    // Printing disturbs 1ms update messages above, so will appear to "blink"
                    debug_print ("%u set_LED_period_ms %u\n", id_task, period_ms);

                    unsigned pwm_one_percent_ticks_ = ((period_ms/SOFTBLINK_PERIOD_MIN_MS) * XS1_TIMER_KHZ);

                    if (LED_start_at == dark) {
                        now_percentage = SOFTBLINK_DEFAULT_MIN_PERCENTAGE;
                    } else if (LED_start_at == full) {
                        now_percentage = SOFTBLINK_DEFAULT_MAX_PERCENTAGE;
                    } else {
                        // cont, no code
                    }

                    pwm_one_percent_ticks = pwm_one_percent_ticks_;

                } break;
            }
        }
    }

#endif // CONFIG_NUM_TASKS_PER_LED

// Standard type PWM based on timeouts
// But there would be another way to do this:
// This does not attach a timer to the port itself and use the @ number-of-ticks and timed output feature of XC. More about that here:
//     XS1 Ports: use and specification MS_PER_PERCENT_TO_PERIOD_MS_FACTOR8 see https://www.xmos.com/file/xs1-ports-specification/
//     Introduction to XS1 ports        2010 see https://www.xmos.com/file/xs1-ports-introduction/
//     XMOS Programming Guide           2015 see https://www.xmos.com/download/XMOS-Programming-Guide-(documentation)(F).pdf

//
typedef enum {activated, deactivated} port_is_e;

#define ACTIVATE_PORT(sign) do {outP1 <: (1 xor sign);} while (0)
        // to activated: 0 = 1 xor 1 = [1 xor active_low]

#define DEACTIVATE_PORT(sign) do {outP1 <: (0 xor sign);} while (0)
        // to deactivated: 1 = 0 xor 1 = [0 xor active_low]
//

#if (CONFIG_NUM_TASKS_PER_LED==2)

    [[combinable]]
    void pwm_for_LED_task (
            const unsigned      id_task, // For printing only
            server pwm_if       if_pwm,
            out buffered port:1 outP1)
    {
        // --- pwm_context_t for softblinker_pwm_for_LED_task
        timer           tmr;
        time32_t        timeout;
        port_pin_sign_e port_pin_sign;
        unsigned        pwm_one_percent_ticks;
        time32_t        port_activated_percentage;
        bool            pwm_running;
        port_is_e       port_is;
        // ---

        port_pin_sign = PWM_PORT_PIN_SIGN;

        debug_print ("%u pwm_for_LED_task started\n", id_task);

        pwm_one_percent_ticks     = PWM_ONE_PERCENT_TICS;
        port_activated_percentage = 100;                  // This implies [1], [2] and [3] below
        pwm_running               = false;                // [1] no timerafter (doing_pwn when not 0% or not 100%)
        port_is                   = activated;            // [2] "LED on"
                                                          //
        ACTIVATE_PORT(port_pin_sign);                     // [3]

        while (1) {
            // #pragma ordered // May be used if not [[combinable]] to assure priority of the PWM, if that is wanted
            #pragma xta endpoint "start"
            select {
                case (pwm_running) => tmr when timerafter(timeout) :> void: {
                    if (port_is == deactivated) {
                        #pragma xta endpoint "stop"
                        ACTIVATE_PORT(port_pin_sign);
                        timeout += (port_activated_percentage * pwm_one_percent_ticks);
                        port_is  = activated;
                    } else {
                        DEACTIVATE_PORT(port_pin_sign);
                        timeout += ((100 - port_activated_percentage) * pwm_one_percent_ticks);
                        port_is  = deactivated;;
                    }
                } break;

                case if_pwm.set_LED_intensity (const percentage_t percentage) : {

                    port_activated_percentage = percentage;

                    if (port_activated_percentage == 100) { // No need to involve any timerafter and get a short off blip
                        pwm_running = false;
                        ACTIVATE_PORT(port_pin_sign);
                    } else if (port_activated_percentage == 0) { // No need to involve any timerafter and get a short on blink
                        pwm_running = false;
                        DEACTIVATE_PORT(port_pin_sign);
                    } else if (not pwm_running) {
                        pwm_running = true;
                        tmr :> timeout; // immediate timeout
                    } else { // pwm_running already
                        // No code
                        // Don't disturb running timerafter, just let it use the new port_activated_percentage when it gets there
                    }
                } break;
            }
        }
    }

#endif // CONFIG_NUM_TASKS_PER_LED

typedef struct pwm_context_t {
    timer           tmr;
    time32_t        timeout;
    port_pin_sign_e port_pin_sign;
    unsigned        pwm_one_percent_ticks;
    time32_t        port_activated_percentage;
    bool            pwm_running;
    port_is_e       port_is;
} pwm_context_t;

typedef struct softblinker_context_t {
    timer        tmr;
    time32_t     timeout;
    bool         pwm_running;
    unsigned     pwm_one_percent_ticks;
    signed       now_percentage;
    percentage_t max_percentage;
    percentage_t min_percentage;
    signed       inc_percentage;
} softblinker_context_t;


#if (CONFIG_NUM_TASKS_PER_LED==1)

    void set_LED_intensity (
            pwm_context_t       &pwm_context,
            out buffered port:1 outP1,
            const percentage_t  percentage)
    {
        pwm_context.port_activated_percentage = percentage;

        if (pwm_context.port_activated_percentage == 100) { // No need to involve any timerafter and get a short off blip
            pwm_context.pwm_running = false;
            ACTIVATE_PORT(pwm_context.port_pin_sign);
        } else if (pwm_context.port_activated_percentage == 0) { // No need to involve any timerafter and get a short on blink
            pwm_context.pwm_running = false;
            DEACTIVATE_PORT(pwm_context.port_pin_sign);
        } else if (not pwm_context.pwm_running) {
            pwm_context.pwm_running = true;
            pwm_context.tmr :> pwm_context.timeout; // immediate timeout
        } else { // pwm_running already
            // No code
            // Don't disturb running timerafter, just let it use the new port_activated_percentage when it gets there
        }
    }

    [[combinable]]
    void softblinker_pwm_for_LED_task (
            const unsigned        id_task, // For printing only
            server softblinker_if if_softblinker,
            out buffered port:1   outP1)
    {
        debug_print ("%u softblinker_pwm_for_LED_task started\n", id_task);

        pwm_context_t         pwm_context;
        softblinker_context_t softblinker_context;

        softblinker_context.pwm_running           = false;
        softblinker_context.pwm_one_percent_ticks = SOFTBLINK_DEFAULT_PERIOD_MS * XS1_TIMER_KHZ;
        softblinker_context.now_percentage        = SOFTBLINK_DEFAULT_MAX_PERCENTAGE; // [-1..101]
        softblinker_context.max_percentage        = SOFTBLINK_DEFAULT_MAX_PERCENTAGE;
        softblinker_context.min_percentage        = SOFTBLINK_DEFAULT_MIN_PERCENTAGE;
        softblinker_context.inc_percentage        = (-1); // [-1,+1]

        pwm_context.port_pin_sign             = PWM_PORT_PIN_SIGN;
        pwm_context.pwm_one_percent_ticks     = PWM_ONE_PERCENT_TICS; // 10 uS. So 99% means 990 us activated and 10 us deactivated
        pwm_context.port_activated_percentage = 100;                  // This implies [1], [2] and [3] below
        pwm_context.pwm_running               = false;                // [1] no timerafter (doing_pwn when not 0% or not 100%)
        pwm_context.port_is                   = activated;            // [2] "LED on"
                                                                      //
        ACTIVATE_PORT(pwm_context.port_pin_sign);                     // [3]

        softblinker_context.tmr :> softblinker_context.timeout;
        softblinker_context.timeout += softblinker_context.pwm_one_percent_ticks;

        while (1) {
            // #pragma ordered // May be used if not [[combinable]] to assure priority of the PWM, if that is needed
            #pragma xta endpoint "start"
            select {
                case (pwm_context.pwm_running) => pwm_context.tmr when timerafter(pwm_context.timeout) :> void: {
                    if (pwm_context.port_is == deactivated) {
                        #pragma xta endpoint "stop"
                        ACTIVATE_PORT(pwm_context.port_pin_sign);
                        pwm_context.timeout += (pwm_context.port_activated_percentage * pwm_context.pwm_one_percent_ticks);
                        pwm_context.port_is  = activated;
                    } else {
                        DEACTIVATE_PORT(pwm_context.port_pin_sign);
                        pwm_context.timeout += ((100 - pwm_context.port_activated_percentage) * pwm_context.pwm_one_percent_ticks);
                        pwm_context.port_is  = deactivated;;
                    }
                } break;

                case (softblinker_context.pwm_running) => softblinker_context.tmr when timerafter(softblinker_context.timeout) :> void: {
                    bool min_set;
                    bool max_set;

                    softblinker_context.timeout += softblinker_context.pwm_one_percent_ticks;

                    softblinker_context.now_percentage += softblinker_context.inc_percentage; // [0..100] but [-1..101] possible if 0 or 100 was just set in set_LED_intensity
                    {softblinker_context.now_percentage, min_set, max_set} =
                            in_range_signed_min_max_set (softblinker_context.now_percentage, softblinker_context.min_percentage, softblinker_context.max_percentage); // [0..100]

                    if ((min_set) or (max_set)) { // Send 100 and 0 only once
                        softblinker_context.inc_percentage = (-softblinker_context.inc_percentage); // Change sign for next timeout to scan in the other direction
                    } else {
                        set_LED_intensity (pwm_context, outP1, (percentage_t) softblinker_context.now_percentage); // [0..100]
                    }

                } break;

                case if_softblinker.set_LED_intensity_range (const percentage_t min_percentage_, const percentage_t max_percentage_): {

                    // Printing disturbs 1ms update messages above, so will appear to "blink"
                    debug_print ("%u set_LED_intensity %u %u\n", id_task, min_percentage_, max_percentage_);

                    softblinker_context.min_percentage = (percentage_t) in_range_signed ((signed) min_percentage_, SOFTBLINK_DEFAULT_MIN_PERCENTAGE, SOFTBLINK_DEFAULT_MAX_PERCENTAGE);
                    softblinker_context.max_percentage = (percentage_t) in_range_signed ((signed) max_percentage_, SOFTBLINK_DEFAULT_MIN_PERCENTAGE, SOFTBLINK_DEFAULT_MAX_PERCENTAGE);

                    if (softblinker_context.max_percentage == softblinker_context.min_percentage) { // No change of intensity
                        softblinker_context.pwm_running = false;
                        set_LED_intensity (pwm_context, outP1, softblinker_context.max_percentage);
                        // No code, timerafter will do it
                    } else if (not softblinker_context.pwm_running) {
                        softblinker_context.pwm_running = true;
                        softblinker_context.tmr :> softblinker_context.timeout; // immediate timeout
                    } else { // pwm_running already
                        // No code
                        // Don't disturb running timerafter
                    }
                } break;

                case if_softblinker.set_LED_period_ms (const unsigned period_ms_, const LED_start_at_e LED_start_at): {

                    unsigned period_ms = in_range_signed (period_ms_, SOFTBLINK_PERIOD_MIN_MS, SOFTBLINK_PERIOD_MAX_MS);

                    // Printing disturbs 1ms update messages above, so will appear to "blink"
                    debug_print ("%u set_LED_period_ms %u\n", id_task, period_ms);

                    unsigned pwm_one_percent_ticks_ = ((period_ms/SOFTBLINK_PERIOD_MIN_MS) * XS1_TIMER_KHZ);

                    if (LED_start_at == dark) {
                        softblinker_context.now_percentage = SOFTBLINK_DEFAULT_MIN_PERCENTAGE;
                    } else if (LED_start_at == full) {
                        softblinker_context.now_percentage = SOFTBLINK_DEFAULT_MAX_PERCENTAGE;
                    } else {
                        // cont, no code
                    }

                    softblinker_context.pwm_one_percent_ticks = pwm_one_percent_ticks_;
                } break;
            }
        }
    }
#endif // CONFIG_NUM_TASKS_PER_LED

