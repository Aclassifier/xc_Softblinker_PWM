/*
 * _Softblinker_PWM.xc
 *
 *  Created on: 28. juni 2020
 *      Author: teig
 */

#define INCLUDES
#ifdef INCLUDES
    #include <xs1.h>
    #include <platform.h> // slice
    #include <timer.h>    // delay_milliseconds(200), XS1_TIMER_HZ etc
    #include <stdint.h>   // uint8_t
    #include <stdio.h>    // printf
    #include <string.h>   // memcpy
    #include <xccompat.h> // REFERENCE_PARAM(my_app_ports_t, my_app_ports) -> my_app_ports_t &my_app_ports
    #include <iso646.h>   // not etc.
    #include <limits.h>   // MAX_INT

    #include "_version.h" // First this..
    #include "_globals.h" // ..then this

    #include "_texts_and_constants.h"
    #include "button_press.h"
    #include "maths.h"
    #include "barrier.h"
    #include "pwm_softblinker.h"

    #include "_Softblinker_PWM.h"
#endif

#define DEBUG_PRINT_TEST 1
#define debug_print(fmt, ...) do { if((DEBUG_PRINT_TEST==1) and (DEBUG_PRINT_GLOBAL_APP==1)) printf(fmt, __VA_ARGS__); } while (0)

#define NUM_TIMEOUTS_PER_SECOND 2

#if (CONFIG_NUM_SOFTBLIKER_LEDS==2)
    #define LED_START_DARK_FULL {dark_LED, full_LED} // of start_LED_at_e with CONFIG_NUM_SOFTBLIKER_LEDS elements
    #define LED_START_DARK_DARK {dark_LED, dark_LED} // --"--
#elif (CONFIG_NUM_SOFTBLIKER_LEDS==1)
    #define LED_START_DARK_FULL {dark_LED} // of start_LED_at_e with CONFIG_NUM_SOFTBLIKER_LEDS elements
    #define LED_START_DARK_DARK {full_LED} // --"--
#endif

typedef enum {
    IN_PHASE,
    OUT_OF_PHASE
} LED_phase_e;

typedef struct params_t {
    unsigned          period_ms;
    intensity_steps_e intensity_steps;
    intensity_t       min_intensity;
    intensity_t       max_intensity;
    unsigned          frequency_Hz;
    transition_pwm_e  transition_pwm;
    synch_e           synch;
    start_LED_at_e    start_LED_at;
    unsigned          min_max_intensity_offset_divisor;
} params_t;

typedef enum {
    state_red_LED_default,                                    // 0
    state_red_LED_steps_0012,                                 // 1 steps_0012
    state_red_LED_steps_0100,                                 // 2 steps_0100
    state_red_LED_steps_0256,                                 // 3 steps_0256
    state_red_LED_steps_1000,                                 // 4 steps_1000 -> now done all NUM_INTENSITY_STEPS
    state_red_LED_half_intensity_range,                       // 5
    state_red_LED_half_intensity_range_and_both_synchronized, // 6
    NUM_RED_LED_STATES // ==7 those above
    //
} state_red_LED_e;

typedef struct {
    unsigned        iOf_intensity_steps_list_red_LED;
    state_red_LED_e state_red_LED;
    //
} states_red_LED_t;

#define OFFSET_DIVISOR_INFIN INT_MAX // 1/° = 0
#define OFFSET_DIVISOR_4     4       // 1/4 offset down from max and up from min


void set_params_to_default (params_t params [CONFIG_NUM_SOFTBLIKER_LEDS]) {

    // C has no way to safely init a constant array of structs. Values are dependent on placement.
    // Last version with that solution was 0032 commit 75ae5ad

    for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
        // Init them
        params[ix].period_ms                        = DEFAULT_SOFTBLINK_PERIOD_MS; // From "pwm_softblinker.h"
        params[ix].intensity_steps                  = DEFAULT_INTENSITY_STEPS;     // --"--
        params[ix].min_intensity                    = DEFAULT_DARK_INTENSITY;      // --"--
        params[ix].max_intensity                    = DEFAULT_FULL_INTENSITY;      // --"--
        params[ix].frequency_Hz                     = DEFAULT_PWM_FREQUENCY_HZ;    // --"--
        params[ix].transition_pwm                   = DEFAULT_TRANSITION_PWM;      // --"--
        params[ix].synch                            = DEFAULT_SYNCH;               // --"-- All equal to avoid deadlock
        params[ix].start_LED_at                     = continuous_LED;
        params[ix].min_max_intensity_offset_divisor = OFFSET_DIVISOR_INFIN;
    }
}


void set_states_red_LED_to_default (states_red_LED_t &states_red_LED) {

    states_red_LED.iOf_intensity_steps_list_red_LED = 0; // First, pointing to steps_0012
    states_red_LED.state_red_LED                    = state_red_LED_default;
}


void write_to_pwm_softblinker (
        client softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS],
        params_t              params        [CONFIG_NUM_SOFTBLIKER_LEDS]) {

    for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {

        const unsigned offset = params[ix].intensity_steps / params[ix].min_max_intensity_offset_divisor;

        if_softblinker[ix].set_LED_intensity_range ( // FIRST THIS (or rather, these)..
                params[ix].frequency_Hz,
                params[ix].intensity_steps,
                params[ix].min_intensity + offset,
                params[ix].max_intensity - offset);
    }

    for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
        if_softblinker[ix].set_LED_period_linear_ms ( // ..THEN THIS (or rather, these)
                params[ix].period_ms,
                params[ix].start_LED_at,
                params[ix].transition_pwm,
                params[ix].synch);
    }
}


[[combinable]]
void softblinker_pwm_button_client_task (
        server button_if      i_buttons_in[BUTTONS_NUM_CLIENTS],
        client softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS])
{
    timer            tmr;
    time32_t         time_ticks; // Ticks to 100 in 1 us
    button_action_t  buttons_action [BUTTONS_NUM_CLIENTS];
    params_t         params         [CONFIG_NUM_SOFTBLIKER_LEDS];
    LED_phase_e      LED_phase                          = IN_PHASE;
    bool             a_side_button_pressed_while_center = false;
    bool             write_LEDs_intensity_and_period    = false;
    states_red_LED_t states_red_LED;

    const intensity_steps_e intensity_steps_list [NUM_INTENSITY_STEPS] = INTENSITY_STEPS_LIST;

    for (unsigned ix = 0; ix < BUTTONS_NUM_CLIENTS; ix++) {
        buttons_action[ix] = BUTTON_ACTION_VOID;
    }

    set_params_to_default (params);

    write_to_pwm_softblinker (if_softblinker, params);

    set_states_red_LED_to_default (states_red_LED);

    while (true) {
        select { // Each case passively waits on an event:

            // BUTTON ACTION (REPEAT: BUTTON HELD FOR SOME TIME) AT TIMEOUT
            //
            case tmr when timerafter (time_ticks) :> void : {
                time_ticks += (XS1_TIMER_HZ/NUM_TIMEOUTS_PER_SECOND);
                // No code (yet?)
            } break; // timerafter

            // BUTTON PRESSES
            //
            case i_buttons_in[int iof_button].button (const button_action_t button_action) : {

                buttons_action[iof_button] = button_action;

                debug_print ("\nBUTTON [%u]=%u\n", iof_button, button_action);

                const bool pressed_now      = (button_action == BUTTON_ACTION_PRESSED);          // 1
                const bool pressed_for_long = (button_action == BUTTON_ACTION_PRESSED_FOR_LONG); // 2
                const bool released_now     = (button_action == BUTTON_ACTION_RELEASED);         // 3 Not after BUTTON_ACTION_PRESSED_FOR_LONG

                if (pressed_for_long) {

                    if (iof_button == IOF_BUTTON_CENTER) { // IOF_RED_LED:

                        states_red_LED.state_red_LED = (states_red_LED.state_red_LED + 1) % NUM_RED_LED_STATES;

                        debug_print ("state_red_LED %u (%u)\n", states_red_LED.state_red_LED, NUM_RED_LED_STATES);

                        switch (states_red_LED.state_red_LED) {
                            case state_red_LED_default: {
                                set_params_to_default (params);
                                set_states_red_LED_to_default (states_red_LED);
                            } break;

                            case state_red_LED_steps_0012:
                            case state_red_LED_steps_0100:
                            case state_red_LED_steps_0256:
                            case state_red_LED_steps_1000: {
                                params[IOF_RED_LED].intensity_steps             = intensity_steps_list[states_red_LED.iOf_intensity_steps_list_red_LED];
                                states_red_LED.iOf_intensity_steps_list_red_LED = (states_red_LED.iOf_intensity_steps_list_red_LED + 1) % NUM_INTENSITY_STEPS; // For next time
                                write_LEDs_intensity_and_period = true;
                            } break;

                            case state_red_LED_half_intensity_range: {
                                params[IOF_RED_LED].min_max_intensity_offset_divisor = OFFSET_DIVISOR_4;
                            } break;

                            case state_red_LED_half_intensity_range_and_both_synchronized: {
                                // All equal to avoid deadlock:
                                for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                                    params[ix].synch = synch_active;
                                }

                            } break;

                            default : {} break; // Never here, no need to crash
                        }

                        write_LEDs_intensity_and_period = true;

                    } else {}

                } else if (released_now) {

                    if (iof_button == IOF_BUTTON_CENTER) {
                        if (a_side_button_pressed_while_center) {
                            a_side_button_pressed_while_center = false;
                        } else {
                            // Nothing happened, let's go on again, but now with toggle_LED_phase changed
                            write_LEDs_intensity_and_period = true;
                        }
                    } else {}

                } else if (pressed_now) {

                    unsigned iof_LED;
                    bool     button_taken = false;

                    switch (iof_button) {
                        case IOF_BUTTON_LEFT: {
                            iof_LED = IOF_YELLOW_LED;

                            if (buttons_action[IOF_BUTTON_CENTER] == BUTTON_ACTION_PRESSED) {
                                a_side_button_pressed_while_center = true;
                            } else if (params[iof_LED].period_ms < 1000) {
                                params[iof_LED].period_ms += SOFTBLINK_PERIOD_MIN_MS;
                            } else {
                                params[iof_LED].period_ms += 2000;
                            }

                            button_taken = true;

                            set_states_red_LED_to_default (states_red_LED); // Reset
                        } break;

                        case IOF_BUTTON_CENTER: {
                            if (LED_phase == OUT_OF_PHASE) {
                                const start_LED_at_e start_LED_at_now [CONFIG_NUM_SOFTBLIKER_LEDS] = LED_START_DARK_FULL; // This and..
                                for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                                    params[ix].start_LED_at   = start_LED_at_now[ix];
                                    params[ix].transition_pwm = slide_transition_pwm; // LEDs out of phase, and sliding PWM: ok combination
                                }

                                LED_phase = IN_PHASE;
                            } else if (LED_phase == IN_PHASE) {
                                const start_LED_at_e start_LED_at_now [CONFIG_NUM_SOFTBLIKER_LEDS] = LED_START_DARK_DARK; // .. this are "180 degrees" out of phase
                                for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                                    params[ix].start_LED_at   = start_LED_at_now[ix];
                                    params[ix].transition_pwm = lock_transition_pwm; // LEDs in phase and locked PWM: also ok combination
                                }
                                LED_phase = OUT_OF_PHASE;
                            } else {}

                        } break;

                        case IOF_BUTTON_RIGHT: {
                            iof_LED = IOF_RED_LED;

                            if (buttons_action[IOF_BUTTON_CENTER] == BUTTON_ACTION_PRESSED) {
                                a_side_button_pressed_while_center = true;
                            } else if (params[iof_LED].period_ms < 1000) {
                                params[iof_LED].period_ms += SOFTBLINK_PERIOD_MIN_MS;
                            } else {
                                params[iof_LED].period_ms += 2000;
                            }

                            button_taken = true;
                        } break;

                        default : {} break;
                    } // Outer switch


                    if (button_taken) {
                        bool min_set;
                        bool max_set;

                        {params[iof_LED].period_ms, min_set, max_set} =
                               in_range_signed_min_max_set (
                                       params[iof_LED].period_ms,
                                       SOFTBLINK_PERIOD_MIN_MS,
                                       SOFTBLINK_PERIOD_MAX_MS);
                        if (min_set) {
                            params[iof_LED].period_ms = SOFTBLINK_PERIOD_MAX_MS; // wrap
                        } else if (max_set) {
                            params[iof_LED].period_ms = SOFTBLINK_PERIOD_MIN_MS; // wrap
                        } else {}

                        // IOF_BUTTON_LEFT or IOF_BUTTON_RIGHT
                        if (buttons_action[IOF_BUTTON_CENTER] == BUTTON_ACTION_PRESSED) {
                            #if (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                                if (iof_LED == IOF_RED_LED) {
                                    params[IOF_YELLOW_LED].period_ms = params[IOF_RED_LED].period_ms; // set the other
                                } else if (iof_LED == IOF_YELLOW_LED) {
                                    params[IOF_RED_LED].period_ms = params[IOF_YELLOW_LED].period_ms; // set the other
                                } else {}
                            #elif (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                                // No code, meaningless
                            #endif
                        } else {}

                        write_LEDs_intensity_and_period = true;

                    } else {} // not button_taken

                } else {
                    // Not pressed_now, no code
                }

                if (write_LEDs_intensity_and_period) {
                    write_to_pwm_softblinker (if_softblinker, params);
                } else {}
            } break; // select i_buttons_in
        }
    }
}
