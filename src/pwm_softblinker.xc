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
#include "barrier.h"
#include "pwm_softblinker.h"

// ---
// Control printing
// See https://stackoverflow.com/questions/1644868/define-macro-for-debug-printing-in-c
// ---

#define DEBUG_PRINT_TEST 1
#define debug_print(fmt, ...) do { if((DEBUG_PRINT_TEST==1) and (DEBUG_PRINT_GLOBAL_APP==1)) printf(fmt, __VA_ARGS__); } while (0)

#define INC_ONE_UP     1
#define DEC_ONE_DOWN (-1)
#define PERIOD_MS_TO_ONE_STEP_TICKS(period,steps,value) do {value=(period*XS1_TIMER_KHZ)/(steps*2); } while (0)

unsigned
period_ms_to_one_step_ticks (
        const unsigned          period_ms,
        const intensity_steps_e intensity_steps) {

    return (period_ms * XS1_TIMER_KHZ) / (intensity_steps * 2);
    //      200       * 100 * 1000     / 1000 * 2 divides
    //      200       * 100 * 1000     /  600 * 2 does not divide
    //      200       * 100 * 1000     /  500 * 2 divides
}

#if (CONFIG_NUM_TASKS_PER_LED==2)
    #if (CONFIG_BARRIER==1)

        [[combinable]]
        void softblinker_task (
                const unsigned        id_task, // For printing only
                client pwm_if         if_pwm,
                server softblinker_if if_softblinker,
                out buffered port:1   out_port_toggle_on_direction_change, // Toggle when LED max
                server barrier_if     if_barrier)
        {
            debug_print ("%u softblinker_task started\n", id_task);

            // --- softblinker_context_t for softblinker_pwm_for_LED_task
            timer             tmr;
            time32_t          timeout;
            bool              do_next_intensity_at_intervals;
            unsigned          one_step_at_intervals_ticks;
            signed            now_intensity;
            intensity_t       max_intensity;
            intensity_t       min_intensity;
            signed            inc_steps;
            transition_pwm_e  transition_pwm;
            intensity_steps_e intensity_steps;
            unsigned          frequency_Hz;
            synch_e           do_synchronization;
            bool              updated_do_synchronization;
            synch_e           await_synchronized;
            // ---

            do_next_intensity_at_intervals   = false;
            now_intensity                    = DEFAULT_FULL_INTENSITY;
            max_intensity                    = DEFAULT_FULL_INTENSITY;
            min_intensity                    = DEFAULT_DARK_INTENSITY;
            inc_steps                        = DEC_ONE_DOWN;
            transition_pwm                   = slide_transition_pwm;
            intensity_steps                  = DEFAULT_INTENSITY_STEPS;
            frequency_Hz                     = DEFAULT_PWM_FREQUENCY_HZ;
            do_synchronization               = synch_none;
            updated_do_synchronization = synch_none;
            await_synchronized               = synch_none;

            one_step_at_intervals_ticks = period_ms_to_one_step_ticks (DEFAULT_SOFTBLINK_PERIOD_MS, intensity_steps);

            tmr :> timeout;
            timeout += one_step_at_intervals_ticks;

            while (1) {
                select {
                    case (do_next_intensity_at_intervals) => tmr when timerafter(timeout) :> void: {

                        timeout += one_step_at_intervals_ticks;
                        // Both min_intensity, now_intensity and max_intensity are set outside this block
                        // That's why both tests include "above" (>) and "below" (<)

                        if (now_intensity >= max_intensity) {
                            if (do_synchronization == synch_active) {
                                do_next_intensity_at_intervals = false;
                                if_barrier.awaiting_synch();
                            } else {
                                inc_steps = DEC_ONE_DOWN;
                                now_intensity = max_intensity;
                                out_port_toggle_on_direction_change <: 0;
                            }

                        } else if (now_intensity <= min_intensity) {
                            inc_steps = INC_ONE_UP;
                            now_intensity = min_intensity;
                            out_port_toggle_on_direction_change <: 1;
                        } else {}

                        now_intensity += inc_steps;

                        // [1..100] [99..0] (Eaxmple for steps_0100)

                        if_pwm.set_LED_intensity (frequency_Hz, intensity_steps, (intensity_t) now_intensity, transition_pwm);

                    } break;

                    case if_softblinker.set_LED_intensity_range (
                            const unsigned          frequency_Hz_,    // 0 -> actives port
                            const intensity_steps_e intensity_steps_, // [1..]
                            const intensity_t       min_intensity_,   // [0..x]
                            const intensity_t       max_intensity_) -> bool ok :  // [x..intensity_steps_]
                    {
                        ok = (min_intensity_ <= max_intensity_);

                        if (ok) {

                            intensity_steps = intensity_steps_;

                            min_intensity = (intensity_t) in_range_signed ((signed) min_intensity_, DEFAULT_DARK_INTENSITY, intensity_steps);
                            max_intensity = (intensity_t) in_range_signed ((signed) max_intensity_, DEFAULT_DARK_INTENSITY, intensity_steps);

                            frequency_Hz = frequency_Hz_;

                            if (max_intensity == min_intensity) { // No INC_ONE_UP or INC_ONE_DOWN of sensitivity
                                do_next_intensity_at_intervals = false;
                                if_pwm.set_LED_intensity (frequency_Hz, intensity_steps, max_intensity, transition_pwm);
                            } else if (not do_next_intensity_at_intervals) {
                                do_next_intensity_at_intervals = true;
                                tmr :> timeout; // immediate timeout
                            } else { // do_next_intensity_at_intervals already
                                // No code
                                // Don't disturb running timerafter
                            }
                        } else {
                            // No code, no warning! Not according to protocol
                        }

                        // Printing disturbs update messages above, so it will appear to "blink"
                        debug_print ("%u set_LED_intensity steps %u (%u, %d) min %u now %d max %u \n",
                                     id_task,                    intensity_steps, do_next_intensity_at_intervals, inc_steps, min_intensity, now_intensity, max_intensity);
                    } break;

                    case if_softblinker.set_LED_period_linear_ms (
                            const unsigned         period_ms_, // See Comment in the header file
                            const start_LED_at_e   start_LED_at,
                            const transition_pwm_e transition_pwm_,
                            const const synch_e    do_synchronization_) -> bool ok_running : {

                        // It seems like linear is ok for softblinking of a LED, ie. "softblink" is soft
                        // I have not tried any other, like sine. I would assume it would feel like dark_LED longer

                        unsigned period_ms;
                        const bool ok_running = do_next_intensity_at_intervals;

                        if (ok_running) {
                            // Normalise to set period
                            //
                            const unsigned    period_ms_            = in_range_signed (period_ms_, SOFTBLINK_PERIOD_MIN_MS, SOFTBLINK_PERIOD_MAX_MS);
                            const intensity_t range_intensity_steps = max_intensity - min_intensity;
                            //
                            period_ms  = (period_ms_ * intensity_steps) / range_intensity_steps; // Now as range decreases, period increases

                            if (start_LED_at == dark_LED) {
                                now_intensity = DEFAULT_DARK_INTENSITY;
                            } else if (start_LED_at == full_LED) {
                                now_intensity = intensity_steps;
                            } else {
                                // continuous_LED, no code
                            }

                            one_step_at_intervals_ticks = period_ms_to_one_step_ticks (period_ms, intensity_steps);
                            transition_pwm = transition_pwm_;

                            do_synchronization = do_synchronization_;

                            // Printing disturbs update messages above, so it will appear to "blink"
                            debug_print ("%u set_LED_period_linear_ms %u (%u, %d) min %u now %d max %u\n",
                                    id_task, period_ms, do_next_intensity_at_intervals, inc_steps, min_intensity, now_intensity, max_intensity);
                        } else {
                            // No user code
                            debug_print ("%u set_LED_period_linear_ms do_next_intensity_at_intervals false\n", id_task);
                        }
                    } break;
                    case if_barrier.allow (void) : {} break; // TODO
                    case if_barrier.synchronized (void) : {} break; // TODO
                }
            }
        }
    #elif (CONFIG_BARRIER==2)

        [[combinable]]
        void softblinker_task (
                const unsigned        id_task, // For printing only
                client pwm_if         if_pwm,
                server softblinker_if if_softblinker,
                out buffered port:1   out_port_toggle_on_direction_change, // Toggle when LED max
                chanend               c_barrier)
        {
            debug_print ("%u softblinker_task started\n", id_task);

            // --- softblinker_context_t for softblinker_pwm_for_LED_task
            timer             tmr;
            time32_t          timeout;
            bool              do_next_intensity_at_intervals;
            unsigned          one_step_at_intervals_ticks;
            signed            now_intensity;
            intensity_t       max_intensity;
            intensity_t       min_intensity;
            signed            inc_steps;
            transition_pwm_e  transition_pwm;
            intensity_steps_e intensity_steps;
            unsigned          frequency_Hz;
            synch_e           do_synchronization;
            start_LED_at_e    start_LED_at;
            // ---

            do_next_intensity_at_intervals = false;
            now_intensity                  = DEFAULT_FULL_INTENSITY;
            max_intensity                  = DEFAULT_FULL_INTENSITY;
            min_intensity                  = DEFAULT_DARK_INTENSITY;
            inc_steps                      = DEC_ONE_DOWN;
            transition_pwm                 = DEFAULT_TRANSITION_PWM;
            intensity_steps                = DEFAULT_INTENSITY_STEPS;
            frequency_Hz                   = DEFAULT_PWM_FREQUENCY_HZ;
            start_LED_at                   = continuous_LED;
            do_synchronization             = DEFAULT_SYNCH;

            one_step_at_intervals_ticks = period_ms_to_one_step_ticks (DEFAULT_SOFTBLINK_PERIOD_MS, intensity_steps);

            tmr :> timeout;
            timeout += one_step_at_intervals_ticks;

            while (1) {
                select {
                    case (do_next_intensity_at_intervals) => tmr when timerafter(timeout) :> void: {

                        timeout += one_step_at_intervals_ticks;
                        // Both min_intensity, now_intensity and max_intensity are set outside this block
                        // That's why both tests include "above" (>) and "below" (<)

                        if (now_intensity >= max_intensity) {
                            inc_steps = DEC_ONE_DOWN;
                            now_intensity = max_intensity;
                            if (do_synchronization == synch_active) { // First this..
                                #if (DO_PULSE_ON_START_SYNCH_MS > 0)
                                    #warning DO_PULSE_ON_START_SYNCH_MS
                                    out_port_toggle_on_direction_change <: 0; // ..then this
                                    delay_milliseconds (DO_PULSE_ON_START_SYNCH_MS);
                                    out_port_toggle_on_direction_change <: 1; // ..then this
                                #endif
                                blocking_chan_barrier_synchronize (c_barrier, null);
                                tmr :> timeout; // restart timer
                                timeout += one_step_at_intervals_ticks;
                            } else {}
                            out_port_toggle_on_direction_change <: 0; // ..then this
                        } else if (now_intensity <= min_intensity) {
                            inc_steps = INC_ONE_UP;
                            now_intensity = min_intensity;
                            if (do_synchronization == synch_active) { // First this.
                                #if (DO_PULSE_ON_START_SYNCH_MS > 0)
                                    out_port_toggle_on_direction_change <: 1; // ..then this
                                    delay_milliseconds (DO_PULSE_ON_START_SYNCH_MS);
                                    out_port_toggle_on_direction_change <: 0; // ..then this
                                #endif
                                blocking_chan_barrier_synchronize (c_barrier, null);
                                 tmr :> timeout; // restart timer
                                 timeout += one_step_at_intervals_ticks;
                             } else {}
                            out_port_toggle_on_direction_change <: 1; // ..then this
                        } else {}

                        now_intensity += inc_steps;

                        // [1..100] [99..0] (Example for steps_0100)

                        if_pwm.set_LED_intensity (frequency_Hz, intensity_steps, (intensity_t) now_intensity, transition_pwm);

                    } break;

                    case if_softblinker.set_LED_intensity_range (
                            const unsigned          frequency_Hz_,    // 0 -> actives port
                            const intensity_steps_e intensity_steps_, // [1..]
                            const intensity_t       min_intensity_,   // [0..x]
                            const intensity_t       max_intensity_) -> bool ok :  // [x..intensity_steps_]
                    {
                        ok = (min_intensity_ <= max_intensity_);

                        if (ok) {

                            intensity_steps = intensity_steps_;

                            min_intensity = (intensity_t) in_range_signed ((signed) min_intensity_, DEFAULT_DARK_INTENSITY, intensity_steps);
                            max_intensity = (intensity_t) in_range_signed ((signed) max_intensity_, DEFAULT_DARK_INTENSITY, intensity_steps);

                            frequency_Hz = frequency_Hz_;

                            if (max_intensity == min_intensity) { // No INC_ONE_UP or INC_ONE_DOWN of sensitivity
                                do_next_intensity_at_intervals = false;
                                if_pwm.set_LED_intensity (frequency_Hz, intensity_steps, max_intensity, transition_pwm);
                            } else if (not do_next_intensity_at_intervals) {
                                do_next_intensity_at_intervals = true;
                                tmr :> timeout; // immediate timeout
                            } else { // do_next_intensity_at_intervals already
                                // No code
                                // Don't disturb running timerafter
                            }
                        } else {
                            // No code, no warning! Not according to protocol
                        }

                        // Printing disturbs update messages above, so it will appear to "blink"
                        debug_print ("%u set_LED_intensity steps ok %u steps %u (n %u, i %d) min %u now %d max %u \n",
                                     id_task,                    ok, intensity_steps, do_next_intensity_at_intervals, inc_steps, min_intensity_, now_intensity, max_intensity_);
                    } break;

                    case if_softblinker.set_LED_period_linear_ms (
                            const unsigned         period_ms_, // See Comment in the header file
                            const start_LED_at_e   start_LED_at_,
                            const transition_pwm_e transition_pwm_,
                            const const synch_e    do_synchronization_) -> bool ok_running : {

                        // It seems like linear is ok for softblinking of a LED, ie. "softblink" is soft
                        // I have not tried any other, like sine. I would assume it would feel like dark_LED longer

                        unsigned period_ms;
                        const bool ok_running = do_next_intensity_at_intervals;

                        if (ok_running) {
                            // Normalise to set period
                            //
                            const unsigned    period_ms_            = in_range_signed (period_ms_, SOFTBLINK_PERIOD_MIN_MS, SOFTBLINK_PERIOD_MAX_MS);
                            const intensity_t range_intensity_steps = max_intensity - min_intensity;
                            //
                            period_ms = (period_ms_ * intensity_steps) / range_intensity_steps; // Now as range decreases, period increases

                            start_LED_at = start_LED_at_;

                            if (start_LED_at == dark_LED) {
                                now_intensity = DEFAULT_DARK_INTENSITY;
                            } else if (start_LED_at == full_LED) {
                                now_intensity = intensity_steps;
                            } else {
                                // continuous_LED, no code
                            }

                            one_step_at_intervals_ticks = period_ms_to_one_step_ticks (period_ms, intensity_steps);
                            transition_pwm = transition_pwm_;

                            do_synchronization = do_synchronization_;

                            // Printing disturbs update messages above, so it will appear to "blink"
                            debug_print ("%u set_LED_period_linear_ms %u->%u (ticks %u) (%u, %d) min %u now %d max %u\n",
                                    id_task, period_ms_, period_ms, one_step_at_intervals_ticks, do_next_intensity_at_intervals, inc_steps, min_intensity, now_intensity, max_intensity);
                        } else {
                            // No user code
                            debug_print ("%u set_LED_period_linear_ms do_next_intensity_at_intervals false\n", id_task);
                        }
                    } break;
                }
            }
        }
    #endif

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
        timer             tmr;
        time32_t          timeout;
        intensity_t       intensity_port_activated; // Normalised to intensity_steps (allways ON when intensity_port_activated == intensity_steps)
        intensity_t       intensity_unit_ticks;     // Normalised to intensity_steps (so many ticks == one step)
        intensity_steps_e intensity_steps;
        port_pin_sign_e   port_pin_sign;
        port_is_e         port_is;
        bool              pwm_running;
        // ---

        debug_print ("%u pwm_for_LED_task started\n", id_task);

        port_pin_sign = PWM_PORT_PIN_SIGN;
        pwm_running   = false;
        port_is       = activated;

        ACTIVATE_PORT(port_pin_sign);

        while (1) {
            // #pragma ordered // May be used if not [[combinable]] to assure priority of the PWM, if that is wanted
            #pragma xta endpoint "start"
            select {
                case (pwm_running) => tmr when timerafter(timeout) :> void: {
                    if (port_is == deactivated) {
                        #pragma xta endpoint "stop"
                        ACTIVATE_PORT(port_pin_sign);
                        timeout += (intensity_port_activated * intensity_unit_ticks);
                        port_is  = activated;
                    } else {
                        DEACTIVATE_PORT(port_pin_sign);
                        timeout += ((intensity_steps - intensity_port_activated) * intensity_unit_ticks);
                        port_is  = deactivated;;
                    }
                } break;

                case if_pwm.set_LED_intensity (
                        const unsigned          frequency_Hz, // 0 -> actives port
                        const intensity_steps_e intensity_steps_,
                        const intensity_t       intensity, // Normalised to intensity_steps (always ON when intensity == intensity_steps_)
                        const transition_pwm_e  transition_pwm) : {

                    intensity_steps = intensity_steps_;

                    intensity_port_activated = intensity;

                    if (frequency_Hz == 0) {
                        pwm_running = false;
                        ACTIVATE_PORT(port_pin_sign);
                    } else if (transition_pwm == slide_transition_pwm) {
                        pwm_running = true;
                        // else lock_transition_pwm:
                    } else if (intensity_port_activated == intensity_steps) { // No need to involve any timerafter and get a short "off" blip
                        pwm_running = false;
                        ACTIVATE_PORT(port_pin_sign);
                    } else if (intensity_port_activated == DEFAULT_DARK_INTENSITY) { // No need to involve any timerafter and get a short "on" blink
                        pwm_running = false;
                        DEACTIVATE_PORT(port_pin_sign);
                    } else if (not pwm_running) {
                        pwm_running = true;
                        tmr :> timeout; // immediate timeout
                    } else { // pwm_running already
                        // No code
                        // Don't disturb running timerafter, just let it use the new intensity_port_activated when it gets there
                    }

                    if (pwm_running) {
                        #define XTA_TEST_SET_LED_INTENSITY 0 // USE 0. Values from version 0023 (below)

                        #if (XTA_TEST_SET_LED_INTENSITY == 0)
                            // Pass with 14 unknowns, Num Paths: 7, Slack: 470.0 ns, Required: 1.0 us, Worst: 530.0 ns, Min Core Frequency: 265 MHz
                            intensity_unit_ticks = (XS1_TIMER_MHZ * 1000000U) / (frequency_Hz * intensity_steps);
                        #elif (XTA_TEST_SET_LED_INTENSITY == 1)
                            // Pass with 14 unknowns, Num Paths: 7, Slack: 250.0 ns, Required: 1.0 us, Worst: 750.0 ns, Min Core Frequency: 375 MHz
                            const unsigned period_us_ticks = (XS1_TIMER_MHZ * 1000000U) / frequency_Hz; // 1M/f us and * for ticks
                            intensity_unit_ticks = period_us_ticks / intensity_steps;
                        #else
                            #error XTA_TEST_SET_LED_INTENSITY value
                        #endif
                    } else {}

                } break;
            }
        }
    }

#endif // CONFIG_NUM_TASKS_PER_LED

typedef struct pwm_context_t {
    timer           tmr;
    time32_t        timeout;
    port_pin_sign_e port_pin_sign;
    unsigned        intensity_unit_ticks;
    time32_t        intensity_port_activated;
    bool            pwm_running;
    port_is_e       port_is;
} pwm_context_t;

typedef struct softblinker_context_t {
    timer        tmr;
    time32_t     timeout;
    bool         do_next_intensity_at_intervals;
    unsigned     one_step_at_intervals_ticks;
    signed       now_intensity;
    intensity_t  max_intensity;
    intensity_t  min_intensity;
    signed       inc_steps;
} softblinker_context_t;


#if (CONFIG_NUM_TASKS_PER_LED==1)

    void set_LED_intensity (
            pwm_context_t       &pwm_context,
            out buffered port:1 out_port_LED,
            const intensity_t   intensity)
    {
        pwm_context.intensity_port_activated = intensity;

        if (pwm_context.intensity_port_activated == 100) { // No need to involve any timerafter and get a short off blip
            pwm_context.pwm_running = false;
            ACTIVATE_PORT(pwm_context.port_pin_sign);
        } else if (pwm_context.intensity_port_activated == 0) { // No need to involve any timerafter and get a short on blink
            pwm_context.pwm_running = false;
            DEACTIVATE_PORT(pwm_context.port_pin_sign);
        } else if (not pwm_context.pwm_running) {
            pwm_context.pwm_running = true;
            pwm_context.tmr :> pwm_context.timeout; // immediate timeout
        } else { // pwm_running already
            // No code
            // Don't disturb running timerafter, just let it use the new intensity_port_activated when it gets there
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

    }
#endif // CONFIG_NUM_TASKS_PER_LED

