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

// Code proper:

// This task does not have any "global_resign_barrier" since we have assured at user level that if "synch_active"
// then a real termination to "synch_none" is not done before acknowledge (ie. started and completed)
//
[[combinable]]
void barrier_do_chan_task (
        chanend             c_barrier[CONFIG_NUM_SOFTBLIKER_LEDS], // Send and receive id_task_t
        out buffered port:1 outP_external_blue_led_high)           // led_on_high_t
{

    bool num_synched = 0;

    id_task_t id_task [CONFIG_NUM_SOFTBLIKER_LEDS];

    for (unsigned ix=0; ix<CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
        id_task[ix] = CONFIG_NUM_SOFTBLIKER_LEDS; // No such id
    }

    while(1) {
        select  {
            case c_barrier [int iof_client] :> id_task[iof_client]: { // query
                num_synched++;
                debug_print ("%s%u c_barrier num %u\n", (num_synched==1) ? "\n" : "", iof_client, num_synched); // Empty line above if 1
                if (num_synched == CONFIG_NUM_SOFTBLIKER_LEDS) {
                    for (unsigned ix=0; ix<CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                        debug_print ("%u ack\n", ix);
                        c_barrier[ix] <: id_task[ix]; // acknowledge, (ie. started and completed)
                        id_task[ix] = CONFIG_NUM_SOFTBLIKER_LEDS; // No such id
                        debug_print ("%u ack'ed\n", ix);
                    }
                    num_synched = 0;
                }
                outP_external_blue_led_high <: (num_synched > 0); // On while barrier is used
            } break;
        }
    }
}

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


typedef struct synch_context_t {
    bool    do_next_intensity_at_intervals_pending; // To avoid it start again when ordered stopped
    synch_e do_multipart_synch;
    synch_e do_multipart_synch_pending; // To avoid it deadlock on the barrier. ALL barrier parts must finish synch!
    bool    awaiting_synchronized;
} synch_context_t; // Introducing a context struct seems to build less code

void start_synch_chan_barrier (
        const id_task_t     id_task,
        synch_context_t     &sync_ct,
        const extremals_e   extremals,
        chanend             c_barrier,
        out buffered port:1 out_port_toggle_on_direction_change)
{
    // If period_ms differ then the longest period will rule.
    // The shortest will get its PWM done, then wait.
    // For the longest this waiting could last
    // (SOFTBLINK_PERIOD_MAX_MS - SOFTBLINK_PERIOD_MIN_MS)/2 = 4.9 seconds?)

    if (extremals == is_anywhere) {
        c_barrier <: id_task;
        // sync_ct.do_multipart_synch_pending will be set later
        // Leave ports undefined, since they are
    } else if (extremals == is_max) {
        #if (DO_PULSE_ON_START_SYNCH == 1)
            #if (WARNINGS==1)
                #warning DO_PULSE_ON_START_SYNCH
            #endif
            out_port_toggle_on_direction_change <: pin_low;
            c_barrier <: id_task;
            out_port_toggle_on_direction_change <: pin_high;
        #else
            c_barrier <: id_task;
        #endif
        sync_ct.do_multipart_synch_pending = synch_active; // may be set to synch_none in set_LED_period_linear_ms
    } else if (extremals == is_min) {
        #if (DO_PULSE_ON_START_SYNCH == 1)
            out_port_toggle_on_direction_change <: pin_high;
            c_barrier <: id_task;
            out_port_toggle_on_direction_change <: pin_low;
        #else
            c_barrier <: id_task;
        #endif
        sync_ct.do_multipart_synch_pending = synch_active; // may be set to synch_none in set_LED_period_linear_ms
    }
    sync_ct.do_next_intensity_at_intervals_pending = true; // may be set to false in      set_LED_intensity_range
    sync_ct.awaiting_synchronized                  = true;
}

typedef struct softblinker_context_t {
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
} softblinker_context_t; // Introducing a context struct seems to build less code

#if (CONFIG_BARRIER == 0)
    [[combinable]]
    void softblinker_task (
            const id_task_t       id_task,
            client pwm_if         if_pwm,
            server softblinker_if if_softblinker,
            out buffered port:1   out_port_toggle_on_direction_change) // Toggle when LED max

    {
        debug_print ("%u softblinker_task started\n", id_task);

        softblinker_context_t soft_ct;
        // ---

        soft_ct.do_next_intensity_at_intervals = false;

        soft_ct.now_intensity   = DEFAULT_FULL_INTENSITY;
        soft_ct.max_intensity   = DEFAULT_FULL_INTENSITY;
        soft_ct.min_intensity   = DEFAULT_DARK_INTENSITY;
        soft_ct.inc_steps       = DEC_ONE_DOWN;
        soft_ct.transition_pwm  = DEFAULT_TRANSITION_PWM;
        soft_ct.intensity_steps = DEFAULT_INTENSITY_STEPS;
        soft_ct.frequency_Hz    = DEFAULT_PWM_FREQUENCY_HZ;


        soft_ct.one_step_at_intervals_ticks = period_ms_to_one_step_ticks (DEFAULT_SOFTBLINK_PERIOD_MS, soft_ct.intensity_steps);

        soft_ct.tmr :> soft_ct.timeout;
        soft_ct.timeout += soft_ct.one_step_at_intervals_ticks;

        while (1) {
            select {
                case (soft_ct.do_next_intensity_at_intervals) => soft_ct.tmr when timerafter(soft_ct.timeout) :> void: {

                    soft_ct.timeout += soft_ct.one_step_at_intervals_ticks;
                    // Both min_intensity, now_intensity and max_intensity are set outside this block
                    // That's why both tests include "above" (>) and "below" (<)

                    if (soft_ct.now_intensity >= soft_ct.max_intensity) {
                        soft_ct.inc_steps = DEC_ONE_DOWN;
                        soft_ct.now_intensity = soft_ct.max_intensity;
                        out_port_toggle_on_direction_change <: pin_low;
                    } else if (soft_ct.now_intensity <= soft_ct.min_intensity) {
                        soft_ct.inc_steps = INC_ONE_UP;
                        soft_ct.now_intensity = soft_ct.min_intensity;
                        out_port_toggle_on_direction_change <: pin_high;
                    } else {}

                    soft_ct.now_intensity += soft_ct.inc_steps;

                    // [1..100] [99..0] (Example for steps_0100)

                    if_pwm.set_LED_intensity (
                            soft_ct.frequency_Hz,
                            soft_ct.intensity_steps,
                            (intensity_t) soft_ct.now_intensity,
                            soft_ct.transition_pwm);

                } break; // timerafter

                case if_softblinker.set_LED_intensity_range (
                        const unsigned          frequency_Hz,               // 0 -> actives port
                        const intensity_steps_e intensity_steps,            // [1..]
                        const intensity_t       min_intensity,              // [0..x]
                        const intensity_t       max_intensity) -> bool ok : // [x..intensity_steps_]
                {
                    ok = (min_intensity <= max_intensity);

                    if (ok) {

                        soft_ct.intensity_steps = intensity_steps;

                        soft_ct.min_intensity = (intensity_t) in_range_signed ((signed) min_intensity, DEFAULT_DARK_INTENSITY, soft_ct.intensity_steps);
                        soft_ct.max_intensity = (intensity_t) in_range_signed ((signed) max_intensity, DEFAULT_DARK_INTENSITY, soft_ct.intensity_steps);

                        soft_ct.frequency_Hz = frequency_Hz;

                        if (soft_ct.max_intensity == soft_ct.min_intensity) { // No INC_ONE_UP or INC_ONE_DOWN of sensitivity

                            soft_ct.do_next_intensity_at_intervals = false;
                            soft_ct.now_intensity = soft_ct.max_intensity;
                            if_pwm.set_LED_intensity (soft_ct.frequency_Hz, soft_ct.intensity_steps, soft_ct.max_intensity, soft_ct.transition_pwm);

                        } else if (soft_ct.do_next_intensity_at_intervals == false) { // Not running, make it run:

                            soft_ct.do_next_intensity_at_intervals = true;
                            soft_ct.tmr :> soft_ct.timeout; // immediate timeout

                        } else { // do_next_intensity_at_intervals already
                            // No code
                            // Don't disturb running timerafter
                        }
                    } else {
                        // No code, no warning! Not according to protocol
                    }

                    // Printing disturbs update messages above, so it will appear to "blink"
                    debug_print ("%u set_LED_intensity steps ok %u steps %u (n %u, i %d) min %u now %d max %u freq %u\n",
                                 id_task, //                    ##       ##    ##    ##      ##     ##     ##      ##
                                                                ok,
                                                                         soft_ct.intensity_steps,
                                                                               soft_ct.do_next_intensity_at_intervals,
                                                                                     soft_ct.inc_steps,
                                                                                             soft_ct.min_intensity,
                                                                                                     soft_ct.now_intensity,
                                                                                                            soft_ct.max_intensity,
                                                                                                                    soft_ct.frequency_Hz);
                } break;

                case if_softblinker.set_LED_period_linear_ms (
                        const unsigned         period_ms_, // See Comment in the header file
                        const start_LED_at_e   start_LED_at,
                        const transition_pwm_e transition_pwm,
                        const const synch_e    do_multipart_synch_not_used) : {

                    // It seems like linear is ok for softblinking of a LED, ie. "softblink" is soft
                    // I have not tried any other, like sine. I would assume it would feel like dark_LED longer

                    const bool ok_running = soft_ct.do_next_intensity_at_intervals;
                    unsigned   period_ms;

                    if (ok_running) {
                        // Normalise to set period
                        //
                        const unsigned    period_ms__           = in_range_signed (period_ms_, SOFTBLINK_PERIOD_MIN_MS, SOFTBLINK_PERIOD_MAX_MS);
                        const intensity_t range_intensity_steps = soft_ct.max_intensity - soft_ct.min_intensity;

                        period_ms = (period_ms__ * soft_ct.intensity_steps) / range_intensity_steps; // Now as range decreases, period increases

                        if (start_LED_at == dark_LED) {
                            soft_ct.now_intensity = DEFAULT_DARK_INTENSITY;
                        } else if (start_LED_at == full_LED) {
                            soft_ct.now_intensity = soft_ct.intensity_steps;
                        } else {
                            // continuous_LED, no code
                        }

                        soft_ct.one_step_at_intervals_ticks = period_ms_to_one_step_ticks (period_ms, soft_ct.intensity_steps);
                        soft_ct.transition_pwm = transition_pwm;
                    } else {
                        period_ms = 0; // Just some value, for printing
                    }

                    // Printing disturbs update messages above, so it will appear to "blink"
                    debug_print ("%u set_LED_period_linear_ms period %u->%u (ticks %u) (%u, %d) min %u now %d max %u\n",
                                 id_task, //                               ##  ##        ##   ##  ##      ##     ##     ##
                                                                           period_ms_,
                                                                               period_ms,
                                                                                         soft_ct.one_step_at_intervals_ticks,
                                                                                              soft_ct.do_next_intensity_at_intervals,
                                                                                                  soft_ct.inc_steps,
                                                                                                          soft_ct.min_intensity,
                                                                                                                 soft_ct.now_intensity,
                                                                                                                        soft_ct.max_intensity);
                } break;
            }
        }
    }
#elif (CONFIG_BARRIER == 1)
    [[combinable]]
    void softblinker_task_chan_barrier (
            const id_task_t       id_task,
            client pwm_if         if_pwm,
            server softblinker_if if_softblinker,
            out buffered port:1   out_port_toggle_on_direction_change, // Toggle when LED max
            chanend               c_barrier)

    {
        debug_print ("%u softblinker_task_chan_barrier started\n", id_task);

        softblinker_context_t soft_ct;
        synch_context_t       sync_ct;
        // ---

        soft_ct.do_next_intensity_at_intervals = false;

        soft_ct.now_intensity   = DEFAULT_FULL_INTENSITY;
        soft_ct.max_intensity   = DEFAULT_FULL_INTENSITY;
        soft_ct.min_intensity   = DEFAULT_DARK_INTENSITY;
        soft_ct.inc_steps       = DEC_ONE_DOWN;
        soft_ct.transition_pwm  = DEFAULT_TRANSITION_PWM;
        soft_ct.intensity_steps = DEFAULT_INTENSITY_STEPS;
        soft_ct.frequency_Hz    = DEFAULT_PWM_FREQUENCY_HZ;

        sync_ct.do_next_intensity_at_intervals_pending = soft_ct.do_next_intensity_at_intervals;
        sync_ct.do_multipart_synch                     = DEFAULT_SYNCH;
        sync_ct.do_multipart_synch_pending             = DEFAULT_SYNCH;
        sync_ct.awaiting_synchronized                  = false;

        soft_ct.one_step_at_intervals_ticks = period_ms_to_one_step_ticks (DEFAULT_SOFTBLINK_PERIOD_MS, soft_ct.intensity_steps);

        soft_ct.tmr :> soft_ct.timeout;
        soft_ct.timeout += soft_ct.one_step_at_intervals_ticks;

        while (1) {
            select {
                case (soft_ct.do_next_intensity_at_intervals) => soft_ct.tmr when timerafter(soft_ct.timeout) :> void: {

                    soft_ct.timeout += soft_ct.one_step_at_intervals_ticks;
                    // Both min_intensity, now_intensity and max_intensity are set outside this block
                    // That's why both tests include "above" (>) and "below" (<)

                    if (soft_ct.now_intensity >= soft_ct.max_intensity) {
                        soft_ct.inc_steps = DEC_ONE_DOWN;
                        soft_ct.now_intensity = soft_ct.max_intensity;
                        if (sync_ct.do_multipart_synch == synch_active) {
                            start_synch_chan_barrier (id_task, sync_ct, is_max, c_barrier, out_port_toggle_on_direction_change);
                            soft_ct.do_next_intensity_at_intervals = false;
                        } else {}
                        out_port_toggle_on_direction_change <: pin_low;
                    } else if (soft_ct.now_intensity <= soft_ct.min_intensity) {
                        soft_ct.inc_steps = INC_ONE_UP;
                        soft_ct.now_intensity = soft_ct.min_intensity;
                        if (sync_ct.do_multipart_synch == synch_active) {
                            start_synch_chan_barrier (id_task, sync_ct, is_min, c_barrier, out_port_toggle_on_direction_change);
                            soft_ct.do_next_intensity_at_intervals = false;
                         } else {}
                        out_port_toggle_on_direction_change <: pin_high;
                    } else {}

                    soft_ct.now_intensity += soft_ct.inc_steps;

                    // [1..100] [99..0] (Example for steps_0100)

                    if_pwm.set_LED_intensity (
                            soft_ct.frequency_Hz,
                            soft_ct.intensity_steps,
                            (intensity_t) soft_ct.now_intensity,
                            soft_ct.transition_pwm);

                } break; // timerafter

                case if_softblinker.set_LED_intensity_range (
                        const unsigned          frequency_Hz,               // 0 -> actives port
                        const intensity_steps_e intensity_steps,            // [1..]
                        const intensity_t       min_intensity,              // [0..x]
                        const intensity_t       max_intensity) -> bool ok : // [x..intensity_steps_]
                {
                    ok = (min_intensity <= max_intensity);

                    if (ok) {

                        soft_ct.intensity_steps = intensity_steps;

                        soft_ct.min_intensity = (intensity_t) in_range_signed ((signed) min_intensity, DEFAULT_DARK_INTENSITY, soft_ct.intensity_steps);
                        soft_ct.max_intensity = (intensity_t) in_range_signed ((signed) max_intensity, DEFAULT_DARK_INTENSITY, soft_ct.intensity_steps);

                        soft_ct.frequency_Hz = frequency_Hz;

                        if (soft_ct.max_intensity == soft_ct.min_intensity) { // No INC_ONE_UP or INC_ONE_DOWN of sensitivity

                            if (sync_ct.awaiting_synchronized) {
                                sync_ct.do_next_intensity_at_intervals_pending = false;
                            } else {
                                soft_ct.do_next_intensity_at_intervals = false;
                            }
                            soft_ct.now_intensity = soft_ct.max_intensity;
                            if_pwm.set_LED_intensity (soft_ct.frequency_Hz, soft_ct.intensity_steps, soft_ct.max_intensity, soft_ct.transition_pwm);

                        } else if (soft_ct.do_next_intensity_at_intervals == false) { // Not running, make it run:

                            if (sync_ct.awaiting_synchronized) {
                                sync_ct.do_next_intensity_at_intervals_pending = true; // later
                            } else {
                                soft_ct.do_next_intensity_at_intervals = true;
                                soft_ct.tmr :> soft_ct.timeout; // immediate timeout
                            }

                        } else { // do_next_intensity_at_intervals already
                            // No code
                            // Don't disturb running timerafter
                        }
                    } else {
                        // No code, no warning! Not according to protocol
                    }

                    // Printing disturbs update messages above, so it will appear to "blink"
                    debug_print ("%u set_LED_intensity steps ok %u sync %u steps %u (n %u, i %d) min %u now %d max %u freq %u\n",
                                 id_task, //                    ##      ##       ##    ##    ##      ##     ##     ##      ##
                                                                ok,     sync_ct.awaiting_synchronized,
                                                                                 soft_ct.intensity_steps,
                                                                                       sync_ct.awaiting_synchronized ? sync_ct.do_next_intensity_at_intervals_pending : soft_ct.do_next_intensity_at_intervals,
                                                                                             soft_ct.inc_steps,
                                                                                                     soft_ct.min_intensity,
                                                                                                             soft_ct.now_intensity,
                                                                                                                    soft_ct.max_intensity,
                                                                                                                            soft_ct.frequency_Hz);
                } break;

                case if_softblinker.set_LED_period_linear_ms (
                        const unsigned         period_ms_, // See Comment in the header file
                        const start_LED_at_e   start_LED_at,
                        const transition_pwm_e transition_pwm,
                        const const synch_e    do_multipart_synch) : {

                    // It seems like linear is ok for softblinking of a LED, ie. "softblink" is soft
                    // I have not tried any other, like sine. I would assume it would feel like dark_LED longer

                    const bool ok_running = soft_ct.do_next_intensity_at_intervals;
                    unsigned   period_ms;

                    if (ok_running) {
                        // Normalise to set period
                        //
                        const unsigned    period_ms__           = in_range_signed (period_ms_, SOFTBLINK_PERIOD_MIN_MS, SOFTBLINK_PERIOD_MAX_MS);
                        const intensity_t range_intensity_steps = soft_ct.max_intensity - soft_ct.min_intensity;

                        period_ms = (period_ms__ * soft_ct.intensity_steps) / range_intensity_steps; // Now as range decreases, period increases

                        if (start_LED_at == dark_LED) {
                            soft_ct.now_intensity = DEFAULT_DARK_INTENSITY;
                        } else if (start_LED_at == full_LED) {
                            soft_ct.now_intensity = soft_ct.intensity_steps;
                        } else {
                            // continuous_LED, no code
                        }

                        soft_ct.one_step_at_intervals_ticks = period_ms_to_one_step_ticks (period_ms, soft_ct.intensity_steps);
                        soft_ct.transition_pwm = transition_pwm;
                    } else {
                        period_ms = 0; // Just some value, for printing
                    }

                    unsigned branch = 0; // For log

                    if (sync_ct.awaiting_synchronized) {
                        sync_ct.do_multipart_synch_pending = do_multipart_synch; // later
                    } else if ((sync_ct.do_multipart_synch == synch_active) and (do_multipart_synch == synch_none)) {
                        // Ending synch, clean up
                        // Starting synch here is just to save time. It could take several seconds before is_min or is:max is reached
                        start_synch_chan_barrier (id_task, sync_ct, is_anywhere, c_barrier, out_port_toggle_on_direction_change);
                        soft_ct.do_next_intensity_at_intervals = false;
                        sync_ct.do_multipart_synch_pending = synch_none; // later
                        branch = 1;
                    } else {
                        sync_ct.do_multipart_synch = do_multipart_synch; // now
                        branch = 2;
                    }

                    // Printing disturbs update messages above, so it will appear to "blink"
                    debug_print ("%u set_LED_period_linear_ms sync %u:%u branch %u period %u->%u (ticks %u) (%u, %d) min %u now %d max %u\n",
                                 id_task, //                       ## ##        ##        ##  ##        ##   ##  ##      ##     ##     ##
                                                                   sync_ct.awaiting_synchronized,
                                                                      sync_ct.awaiting_synchronized ? sync_ct.do_multipart_synch_pending : sync_ct.do_multipart_synch,
                                                                                branch,
                                                                                          period_ms_,
                                                                                              period_ms,
                                                                                                        soft_ct.one_step_at_intervals_ticks,
                                                                                                             soft_ct.do_next_intensity_at_intervals,
                                                                                                                 soft_ct.inc_steps,
                                                                                                                         soft_ct.min_intensity,
                                                                                                                               soft_ct.now_intensity,
                                                                                                                                      soft_ct.max_intensity);
                } break;

                case c_barrier :> id_task_t id_task_ : {
                    debug_print ("%u/%u synchronized synch %u cont %u\n", id_task, id_task_, sync_ct.do_multipart_synch_pending, sync_ct.do_next_intensity_at_intervals_pending);

                    sync_ct.awaiting_synchronized          = false;
                    sync_ct.do_multipart_synch             = sync_ct.do_multipart_synch_pending;
                    soft_ct.do_next_intensity_at_intervals = sync_ct.do_next_intensity_at_intervals_pending;

                    if (soft_ct.do_next_intensity_at_intervals) {
                        soft_ct.tmr :> soft_ct.timeout; // restart timer
                        soft_ct.timeout += soft_ct.one_step_at_intervals_ticks;
                    } else {
                        // do_next_intensity_at_intervals is false
                        // No code, do not "override" do_next_intensity_at_intervals_pending
                    }
                } break;
            }
        }
    }
#endif


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

typedef struct pwm_context_t {
    timer             tmr;
    time32_t          timeout;
    intensity_t       intensity_port_activated; // Normalised to intensity_steps (allways ON when intensity_port_activated == intensity_steps)
    intensity_t       intensity_unit_ticks;     // Normalised to intensity_steps (so many ticks == one step)
    intensity_steps_e intensity_steps;
    port_pin_sign_e   port_pin_sign;
    port_is_e         port_is;
    bool              pwm_running;
} pwm_context_t; // Introducing a context struct seems to build less code


[[combinable]]
void pwm_for_LED_task (
        const id_task_t     id_task, // For printing only
        server pwm_if       if_pwm,
        out buffered port:1 out_port_LED) // LED
{
    pwm_context_t pwm_ct;

    debug_print ("%u pwm_for_LED_task started\n", id_task);

    pwm_ct.port_pin_sign = PWM_PORT_PIN_SIGN;
    pwm_ct.pwm_running   = false;
    pwm_ct.port_is       = activated;

    ACTIVATE_PORT(pwm_ct.port_pin_sign);

    while (1) {
        // #pragma ordered // May be used if not [[combinable]] to assure priority of the PWM, if that is wanted
        #pragma xta endpoint "start"
        select {

            // THIS IS THE PWM. ALL THE REST IS JUST CONTROLLING IT
            case (pwm_ct.pwm_running) => pwm_ct.tmr when timerafter(pwm_ct.timeout) :> void: {
                if (pwm_ct.port_is == deactivated) {
                    #pragma xta endpoint "stop"
                    ACTIVATE_PORT(pwm_ct.port_pin_sign);
                    pwm_ct.timeout += (pwm_ct.intensity_port_activated * pwm_ct.intensity_unit_ticks);
                    pwm_ct.port_is  = activated;
                } else {
                    DEACTIVATE_PORT(pwm_ct.port_pin_sign);
                    pwm_ct.timeout += ((pwm_ct.intensity_steps - pwm_ct.intensity_port_activated) * pwm_ct.intensity_unit_ticks);
                    pwm_ct.port_is  = deactivated;;
                }
            } break;

            // THIS IS ALL THE REST: CONTROLLING THE PWM
            case if_pwm.set_LED_intensity (
                    const unsigned          frequency_Hz, // 0 -> actives port
                    const intensity_steps_e intensity_steps_,
                    const intensity_t       intensity, // Normalised to intensity_steps (always ON when intensity == intensity_steps_)
                    const transition_pwm_e  transition_pwm) : {

                pwm_ct.intensity_steps = intensity_steps_;

                pwm_ct.intensity_port_activated = intensity;

                if (frequency_Hz == 0) {
                    pwm_ct.pwm_running = false;
                    ACTIVATE_PORT(pwm_ct.port_pin_sign);
                } else if (pwm_ct.intensity_port_activated == pwm_ct.intensity_steps) { // (First this..) No need to involve any timerafter and get a short "off" blip
                    pwm_ct.pwm_running = false;
                    ACTIVATE_PORT(pwm_ct.port_pin_sign);
                } else if (transition_pwm == slide_transition_pwm) { // (..then this, since transition_pwm not set with set_LED_intensity_range)
                    pwm_ct.pwm_running = true;
                    // else lock_transition_pwm:
                } else if (pwm_ct.intensity_port_activated == DEFAULT_DARK_INTENSITY) { // No need to involve any timerafter and get a short "on" blink
                    pwm_ct.pwm_running = false;
                    DEACTIVATE_PORT(pwm_ct.port_pin_sign);
                } else if (not pwm_ct.pwm_running) {
                    pwm_ct.pwm_running = true;
                    pwm_ct.tmr :> pwm_ct.timeout; // immediate timeout
                } else { // pwm_running already
                    // No code
                    // Don't disturb running timerafter, just let it use the new intensity_port_activated when it gets there
                }

                if (pwm_ct.pwm_running) {
                    #define XTA_TEST_SET_LED_INTENSITY 0 // USE 0. Values from version 0023 (below)

                    #if (XTA_TEST_SET_LED_INTENSITY == 0)
                        // Pass with 14 unknowns, Num Paths: 7, Slack: 470.0 ns, Required: 1.0 us, Worst: 530.0 ns, Min Core Frequency: 265 MHz
                        pwm_ct.intensity_unit_ticks = (XS1_TIMER_MHZ * 1000000U) / (frequency_Hz * pwm_ct.intensity_steps);
                    #elif (XTA_TEST_SET_LED_INTENSITY == 1)
                        // Pass with 14 unknowns, Num Paths: 7, Slack: 250.0 ns, Required: 1.0 us, Worst: 750.0 ns, Min Core Frequency: 375 MHz
                        const unsigned period_us_ticks = (XS1_TIMER_MHZ * 1000000U) / pwm_ct.frequency_Hz; // 1M/f us and * for ticks
                        pwm_ct.intensity_unit_ticks = pwm_ct.period_us_ticks / pwm_ct.intensity_steps;
                    #else
                        #error XTA_TEST_SET_LED_INTENSITY value
                    #endif
                } else {}

            } break;
        }
    }
}

