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

#define DEBUG_PRINT_TEST 1
#define debug_print(fmt, ...) do { if((DEBUG_PRINT_TEST==1) and (DEBUG_PRINT_GLOBAL_APP==1)) printf(fmt, __VA_ARGS__); } while (0)

#define INC_ONE_UP     1
#define DEC_ONE_DOWN (-1)

#if (CONFIG_NUM_TASKS_PER_LED==2)

    [[combinable]]
    void softblinker_task_ok (
            const unsigned        id_task, // For printing only
            client pwm_if         if_pwm,
            server softblinker_if if_softblinker,
            out buffered port:1   out_port_toggle_on_direction_change)   // Toggle when LED max
    {
        debug_print ("%u softblinker_task started\n", id_task);

        // --- softblinker_context_t for softblinker_pwm_for_LED_task
        timer            tmr;
        time32_t         timeout;
        bool             pwm_running;
        unsigned         pwm_one_percent_ticks;
        signed           now_percentage;
        percentage_t     max_percentage;
        percentage_t     min_percentage;
        signed           inc_percentage;
        transition_pwm_e transition_pwm;
        bool             port_toggle_on_direction_change = false;
        // ---

        pwm_running           = false;
        pwm_one_percent_ticks = SOFTBLINK_DEFAULT_PERIOD_MS * XS1_TIMER_KHZ;
        now_percentage        = SOFTBLINK_DEFAULT_MAX_PERCENTAGE; // [-1..101]
        max_percentage        = SOFTBLINK_DEFAULT_MAX_PERCENTAGE;
        min_percentage        = SOFTBLINK_DEFAULT_MIN_PERCENTAGE;
        inc_percentage        = DEC_ONE_DOWN;
        transition_pwm        = slide_transition_pwm;

        tmr :> timeout;
        timeout += pwm_one_percent_ticks;

        while (1) {
            select {
                case (pwm_running) => tmr when timerafter(timeout) :> void: {
                    bool min_set;
                    bool max_set;

                    timeout += pwm_one_percent_ticks;

                    // [ 0..9]:  0,1,2,3,4,5,6,7,8, 9
                    // [10..1]: 10,9,8,7,6,5,4,3,2, 1
                    now_percentage += inc_percentage; // [0..100] but [-1..101] possible if 0 or 100 was just set in set_LED_intensity
                    // [1..10]:  1,2,3,4,5,6,7,8,9,10,11
                    // [9.. 0]:  9,8,7,6,5,4,3,2,1, 0,

                    {now_percentage, min_set, max_set} =
                            in_range_signed_min_max_set (now_percentage, 1+min_percentage, max_percentage); // [0..100] out
                    // "Sign has to be found experimentally". Ok. THIS makes 200.0 ms specified equal to 200.0 ms period

                    if (             //                                   ##  because in_range_signed_min_max_set does "<" and ">" params
                        (min_set) or // counted down to (1+min_percentage)-1 =   0 ->   0 out
                        (max_set)) { // counted up to     (max_percentage)+1 = 101 -> 100 out

                        out_port_toggle_on_direction_change <: port_toggle_on_direction_change; // JUST FOR THE SCOPE. 200ms->5.00Hz

                        port_toggle_on_direction_change = not port_toggle_on_direction_change;
                        inc_percentage = (-inc_percentage); // Change sign for next timeout to scan in the other direction
                    } else {
                        if_pwm.set_LED_intensity ((percentage_t) now_percentage, transition_pwm); // [0..100]
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
                        if_pwm.set_LED_intensity (max_percentage, transition_pwm);
                    } else if (not pwm_running) {
                        pwm_running = true;
                        tmr :> timeout; // immediate timeout
                    } else { // pwm_running already
                        // No code
                        // Don't disturb running timerafter
                    }
                } break;

                case if_softblinker.set_LED_period_linear_ms (
                        const unsigned         period_ms_,
                        const start_LED_at_e   start_LED_at,
                        const transition_pwm_e transition_pwm_): {

                    // It seems like linear is ok for softblinking of a LED, ie. "softblink" is soft
                    // I have not tried any other, like sine. I would assume it would feel like dark_LED longer

                    unsigned period_ms = in_range_signed (period_ms_, SOFTBLINK_PERIOD_MIN_MS, SOFTBLINK_PERIOD_MAX_MS);

                    // Printing disturbs 1ms update messages above, so will appear to "blink"
                    debug_print ("%u set_LED_period_linear_ms %u\n", id_task, period_ms);

                    unsigned pwm_one_percent_ticks_ = ((period_ms/SOFTBLINK_PERIOD_MIN_MS) * XS1_TIMER_KHZ);

                    if (start_LED_at == dark_LED) {
                        now_percentage = SOFTBLINK_DEFAULT_MIN_PERCENTAGE;
                    } else if (start_LED_at == full_LED) {
                        now_percentage = SOFTBLINK_DEFAULT_MAX_PERCENTAGE;
                    } else {
                        // continuous_LED, no code
                    }

                    pwm_one_percent_ticks = pwm_one_percent_ticks_;
                    transition_pwm = transition_pwm_;

                } break;
            }
        }
    }


    [[combinable]]
    void softblinker_task (
            const unsigned        id_task, // For printing only
            client pwm_if         if_pwm,
            server softblinker_if if_softblinker,
            out buffered port:1   out_port_toggle_on_direction_change) // Toggle when LED max
    {
        debug_print ("%u softblinker_task started\n", id_task);

        // --- softblinker_context_t for softblinker_pwm_for_LED_task
        timer            tmr;
        time32_t         timeout;
        bool             pwm_running;
        unsigned         pwm_one_percent_ticks;
        signed           now_percentage;
        percentage_t     max_percentage;
        percentage_t     min_percentage;
        signed           inc_percentage;
        transition_pwm_e transition_pwm;
        // ---

        pwm_running           = false;
        pwm_one_percent_ticks = SOFTBLINK_DEFAULT_PERIOD_MS * XS1_TIMER_KHZ;
        now_percentage        = SOFTBLINK_DEFAULT_MAX_PERCENTAGE;
        max_percentage        = SOFTBLINK_DEFAULT_MAX_PERCENTAGE;
        min_percentage        = SOFTBLINK_DEFAULT_MIN_PERCENTAGE;
        inc_percentage        = DEC_ONE_DOWN;
        transition_pwm        = slide_transition_pwm;

        tmr :> timeout;
        timeout += pwm_one_percent_ticks;

        while (1) {
            select {
                case (pwm_running) => tmr when timerafter(timeout) :> void: {

                    timeout += pwm_one_percent_ticks;
                    // Both min_percentage, now_percentage and max_percentage are set outside this block
                    // That's why both tests include "above" (>) and "below" (<)

                    if (now_percentage >= max_percentage) {
                        inc_percentage = DEC_ONE_DOWN;
                        now_percentage = max_percentage;
                        out_port_toggle_on_direction_change <: 0;
                    } else if (now_percentage <= min_percentage) {
                        inc_percentage = INC_ONE_UP;
                        now_percentage = min_percentage;
                        out_port_toggle_on_direction_change <: 1;
                    } else {}

                    now_percentage += inc_percentage;

                    // [1..100] [99..0]

                    if_pwm.set_LED_intensity ((percentage_t) now_percentage, transition_pwm); // [0..100]

                } break;

                case if_softblinker.set_LED_intensity_range (const percentage_t min_percentage_, const percentage_t max_percentage_): {

                    min_percentage = (percentage_t) in_range_signed ((signed) min_percentage_, SOFTBLINK_DEFAULT_MIN_PERCENTAGE, SOFTBLINK_DEFAULT_MAX_PERCENTAGE);
                    max_percentage = (percentage_t) in_range_signed ((signed) max_percentage_, SOFTBLINK_DEFAULT_MIN_PERCENTAGE, SOFTBLINK_DEFAULT_MAX_PERCENTAGE);

                    if (max_percentage == min_percentage) { // No change of intensity
                        pwm_running = false;
                        if_pwm.set_LED_intensity (max_percentage, transition_pwm);
                    } else if (not pwm_running) {
                        pwm_running = true;
                        tmr :> timeout; // immediate timeout
                    } else { // pwm_running already
                        // No code
                        // Don't disturb running timerafter
                    }

                    // Printing disturbs 1ms update messages above, so will appear to "blink"
                    debug_print ("%u set_LED_intensity (%u, %d) min %u now %d max %u \n", id_task, pwm_running, inc_percentage, min_percentage, now_percentage, max_percentage);
                } break;

                case if_softblinker.set_LED_period_linear_ms (
                        const unsigned         period_ms_,
                        const start_LED_at_e   start_LED_at,
                        const transition_pwm_e transition_pwm_): {

                    // It seems like linear is ok for softblinking of a LED, ie. "softblink" is soft
                    // I have not tried any other, like sine. I would assume it would feel like dark_LED longer

                    unsigned period_ms = in_range_signed (period_ms_, SOFTBLINK_PERIOD_MIN_MS, SOFTBLINK_PERIOD_MAX_MS);

                    unsigned pwm_one_percent_ticks_ = ((period_ms/SOFTBLINK_PERIOD_MIN_MS) * XS1_TIMER_KHZ);

                    if (start_LED_at == dark_LED) {
                        now_percentage = SOFTBLINK_DEFAULT_MIN_PERCENTAGE;
                    } else if (start_LED_at == full_LED) {
                        now_percentage = SOFTBLINK_DEFAULT_MAX_PERCENTAGE;
                    } else {
                        // continuous_LED, no code
                    }

                    pwm_one_percent_ticks = pwm_one_percent_ticks_;
                    transition_pwm = transition_pwm_;

                    // Printing disturbs 1ms update messages above, so will appear to "blink"
                    debug_print ("%u set_LED_period_linear_ms %u (%u, %d) min %u now %d max %u\n", id_task, period_ms, pwm_running, inc_percentage, min_percentage, now_percentage, max_percentage);

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

#define ACTIVATE_PORT(sign) do {out_port_LED <: (1 xor sign);} while (0)
        // to activated: 0 = 1 xor 1 = [1 xor active_low]

#define DEACTIVATE_PORT(sign) do {out_port_LED <: (0 xor sign);} while (0)
        // to deactivated: 1 = 0 xor 1 = [0 xor active_low]
//

#if (CONFIG_NUM_TASKS_PER_LED==2)

    [[combinable]]
    void pwm_for_LED_task (
            const unsigned      id_task, // For printing only
            server pwm_if       if_pwm,
            out buffered port:1 out_port_LED) // LED
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

        pwm_one_percent_ticks             = PWM_ONE_PERCENT_TICS;
        port_activated_percentage         = 100;                  // This implies [1], [2] and [3] below
        pwm_running                       = false;                // [1] no timerafter (doing_pwn when not 0% or not 100%)
        port_is                           = activated;            // [2] "LED on"
                                                             //
        ACTIVATE_PORT(port_pin_sign);                        // [3]

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
                        // timeout += (C_minus_port_activated_percentage * pwm_one_percent_ticks); // Slack 780 ns, worst 220 ns
                        // "loading" the same variable port_activated_percentage twice in the loop, even if one does an arithmetic
                        // operation, is faster by 30 ns than introducing a separate pre-calculated 100-value! Thanks, XTA!
                        // See commit id c8a5283 (13Jul2020)
                        // But observe that the set_LED_intensity may also delay the "start" loop
                        timeout += ((100 - port_activated_percentage) * pwm_one_percent_ticks);

                        port_is  = deactivated;;
                    }
                } break;

                case if_pwm.set_LED_intensity (const percentage_t percentage, const transition_pwm_e transition_pwm) : {

                    port_activated_percentage = percentage;

                    if (transition_pwm == slide_transition_pwm) {
                        pwm_running = true;
                    }
                    else  // else lock_transition_pwm
                    if (port_activated_percentage == 100) { // No need to involve any timerafter and get a short "off" blip
                        pwm_running = false;
                        ACTIVATE_PORT(port_pin_sign);
                    } else if (port_activated_percentage == 0) { // No need to involve any timerafter and get a short "on" blink
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
            out buffered port:1 out_port_LED,
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
            out buffered port:1   out_port_LED, // LED
            out buffered port:1   out_port_toggle_on_direction_change) // Toggle when LED max
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
                        set_LED_intensity (pwm_context, out_port_LED, (percentage_t) softblinker_context.now_percentage); // [0..100]
                    }

                } break;

                case if_softblinker.set_LED_intensity_range (const percentage_t min_percentage_, const percentage_t max_percentage_): {

                    // Printing disturbs 1ms update messages above, so will appear to "blink"
                    debug_print ("%u set_LED_intensity %u %u\n", id_task, min_percentage_, max_percentage_);

                    softblinker_context.min_percentage = (percentage_t) in_range_signed ((signed) min_percentage_, SOFTBLINK_DEFAULT_MIN_PERCENTAGE, SOFTBLINK_DEFAULT_MAX_PERCENTAGE);
                    softblinker_context.max_percentage = (percentage_t) in_range_signed ((signed) max_percentage_, SOFTBLINK_DEFAULT_MIN_PERCENTAGE, SOFTBLINK_DEFAULT_MAX_PERCENTAGE);

                    if (softblinker_context.max_percentage == softblinker_context.min_percentage) { // No change of intensity
                        softblinker_context.pwm_running = false;
                        set_LED_intensity (pwm_context, out_port_LED, softblinker_context.max_percentage);
                        // No code, timerafter will do it
                    } else if (not softblinker_context.pwm_running) {
                        softblinker_context.pwm_running = true;
                        softblinker_context.tmr :> softblinker_context.timeout; // immediate timeout
                    } else { // pwm_running already
                        // No code
                        // Don't disturb running timerafter
                    }
                } break;

                case if_softblinker.set_LED_period_linear_ms (const unsigned period_ms_, const start_LED_at_e start_LED_at): {

                    unsigned period_ms = in_range_signed (period_ms_, SOFTBLINK_PERIOD_MIN_MS, SOFTBLINK_PERIOD_MAX_MS);

                    // Printing disturbs 1ms update messages above, so will appear to "blink"
                    debug_print ("%u set_LED_period_linear_ms %u\n", id_task, period_ms);

                    unsigned pwm_one_percent_ticks_ = ((period_ms/SOFTBLINK_PERIOD_MIN_MS) * XS1_TIMER_KHZ);

                    if (start_LED_at == dark_LED) {
                        softblinker_context.now_percentage = SOFTBLINK_DEFAULT_MIN_PERCENTAGE;
                    } else if (start_LED_at == full_LED) {
                        softblinker_context.now_percentage = SOFTBLINK_DEFAULT_MAX_PERCENTAGE;
                    } else {
                        // continuous_LED, no code
                    }

                    softblinker_context.pwm_one_percent_ticks = pwm_one_percent_ticks_;
                } break;
            }
        }
    }
#endif // CONFIG_NUM_TASKS_PER_LED

