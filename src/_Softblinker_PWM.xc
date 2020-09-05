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
    unsigned          iof_period_ms_list;
} params_t;

typedef enum {
    state_red_LED_default,           // 0 beeep
    state_all_LEDs_stable_intensity, // 1 beeep beep
    state_red_LED_steps_0012,        // 2 beeep beep beep                     steps_0012
    state_red_LED_steps_0100,        // 3 beeep beep beep beep                steps_0100
    state_red_LED_steps_0256,        // 4 beeep beep beep beep beep           steps_0256
    state_red_LED_steps_1000,        // 5 beeep beep beep beep beep beep      steps_1000 -> now done all NUM_INTENSITY_STEPS
    state_red_LED_half_range,        // 6 beeep beep beep beep beep beep beep
    state_all_LEDs_synched,          // 7 beeep beeeep + BLUE LED ON!
    NUM_RED_LED_STATES // ==8 those above
    //
} state_LED_views_e;

typedef struct {
    unsigned          iOf_intensity_steps_list_red_LED;
    unsigned          stable_intensity_steps_0100;
    state_LED_views_e state_LED_views;
    //
} states_LED_views_t;

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
        params[ix].iof_period_ms_list               = 0;
    }
}


void set_states_LED_views_to_default (
        params_t           params [CONFIG_NUM_SOFTBLIKER_LEDS],
        states_LED_views_t &states_LED_views,
        synch_e            &synch_all) {

    states_LED_views.iOf_intensity_steps_list_red_LED = 0; // First, pointing to steps_0012
    states_LED_views.state_LED_views                  = state_red_LED_default;
    states_LED_views.stable_intensity_steps_0100      = steps_0100;
    synch_all                                         = DEFAULT_SYNCH;

    for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
        params[ix].synch = synch_all;
    }
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


// Since the task that uses this has no time-critical functions it's ok that this
// is not a separate task, and this ok that it then blocks the user
//
void beep (
        out buffered port:1 outP_beeper_high,
        unsigned const       ms_pre,
        unsigned const       ms_pulse)
{
    const beep_high_e beep_port = beep_now;

    delay_milliseconds (ms_pre);

    outP_beeper_high <: beep_port;
    delay_milliseconds (ms_pulse);
    outP_beeper_high <: not beep_port;
}


[[combinable]]
void softblinker_pwm_button_client_task (
        server button_if      i_buttons_in[BUTTONS_NUM_CLIENTS],
        client softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS],
        out buffered port:1   outP_beeper_high,
        out buffered port:1   outP_external_blue_led_high)
{
    beep (outP_beeper_high, 0, 250);

    timer              tmr;
    time32_t           time_ticks; // Ticks to 100 in 1 us
    button_action_t    buttons_action [BUTTONS_NUM_CLIENTS];
    params_t           params         [CONFIG_NUM_SOFTBLIKER_LEDS];
    LED_phase_e        LED_phase                          = IN_PHASE;
    bool               a_side_button_pressed_while_center = false;
    states_LED_views_t states_LED_views;
    synch_e            synch_all; // Single value to reflect that ALL LEDs or NO LED must be synched, else deadlock!

    const unsigned          period_ms_list       [PERIOD_MS_LIST_LEN]  = PERIOD_MS_LIST;
    const intensity_steps_e intensity_steps_list [NUM_INTENSITY_STEPS] = INTENSITY_STEPS_LIST;


    for (unsigned ix = 0; ix < BUTTONS_NUM_CLIENTS; ix++) {
        buttons_action[ix] = BUTTON_ACTION_VOID;
    }

    set_params_to_default (params);

    write_to_pwm_softblinker (if_softblinker, params);

    set_states_LED_views_to_default (params, states_LED_views, synch_all);

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
                bool write_LEDs_intensity_and_period = false;

                // -----------------------------------------------------------------------------------------------------------------------------
                // BUTTONS          | LEFT                          | CENTER                                 | RIGHT
                // -----------------------------------------------------------------------------------------------------------------------------
                // pressed_now      | if also CENTER set red period | ...                                    | if also CENTER set yellow period
                //                  | else next yellow/left period. | ...                                    | else next red/right period.
                //                  | if steady light LEDs less     | ...                                    | if steady light LEDs more
                // ----------------------------------------------------...----------------------------------------------------------------------
                // released_now     | ...                           | if LEFT or RIGHT pressed_now handle it | ...
                //                  | ...                           | else swap phase and start black/full   | ...
                // -----------------------------------------------------------------------------------------------------------------------------
                // pressed_for_long | Clear to init state, but      | Increase state_LED_views_e             | ...
                //                  | arbitrary starts              | ...                                    | ...
                // -----------------------------------------------------------------------------------------------------------------------------

                buttons_action[iof_button] = button_action;

                debug_print ("\nBUTTON [%u]=%u\n", iof_button, button_action);

                const bool pressed_now      = (button_action == BUTTON_ACTION_PRESSED);          // 1
                const bool pressed_for_long = (button_action == BUTTON_ACTION_PRESSED_FOR_LONG); // 2
                const bool released_now     = (button_action == BUTTON_ACTION_RELEASED);         // 3 Not after BUTTON_ACTION_PRESSED_FOR_LONG

                if (pressed_now) {
                    unsigned iof_LED;
                    bool     button_left_taken = false;
                    bool     button_right_taken = false;

                    switch (iof_button) {
                        case IOF_BUTTON_LEFT: {

                            iof_LED = IOF_YELLOW_LED;
                            button_left_taken = true;

                        } break;

                        case IOF_BUTTON_CENTER: {
                            // No code
                            // IOF_BUTTON_CENTER handled at released_now, not pressed_now so that it's not taken before pressed_for_long
                        } break;

                        case IOF_BUTTON_RIGHT: {

                            iof_LED = IOF_RED_LED;
                            button_right_taken = true;

                        } break;

                        default: {} break; // won't happen, but no need to crash
                    } // Outer switch

                    if (button_left_taken or button_right_taken) {
                        beep (outP_beeper_high, 0, 100);

                        if (buttons_action[IOF_BUTTON_CENTER] == BUTTON_ACTION_PRESSED) { // double button action
                            a_side_button_pressed_while_center = true;
                            #if (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                                if (iof_LED == IOF_RED_LED) {
                                    params[IOF_YELLOW_LED].period_ms = params[IOF_RED_LED].period_ms; // set the other
                                } else if (iof_LED == IOF_YELLOW_LED) {
                                    params[IOF_RED_LED].period_ms = params[IOF_YELLOW_LED].period_ms; // set the other
                                } else {}
                            #elif (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                                // No code, meaningless
                            #endif
                        } else { // Standard
                            if (states_LED_views.state_LED_views == state_all_LEDs_stable_intensity) {

                                const unsigned steps_10_percent = steps_0100/10;
                                signed inc_dec_by;

                                if (button_left_taken) { // if steady light LEDs less
                                    if (states_LED_views.stable_intensity_steps_0100 <= steps_10_percent) {
                                        // '<=' in test gives [100..20,10,9,8,7,6,5,4,3,2,1,0]
                                        inc_dec_by = -1;
                                    } else {
                                        inc_dec_by = -10;
                                    }
                                } else if (button_right_taken) { // if steady light LEDs more
                                    if (states_LED_views.stable_intensity_steps_0100 < steps_10_percent) {
                                        // '<' in test gives [0,1,2,3,4,5,6,7,8,9,10,20..100]
                                        inc_dec_by = 1;
                                    } else {
                                        inc_dec_by = 10;
                                    }
                                } else {
                                    inc_dec_by = 0;
                                }

                                states_LED_views.stable_intensity_steps_0100 =
                                        in_range_unsigned_inc_dec (states_LED_views.stable_intensity_steps_0100, 0, steps_0100, inc_dec_by);

                                if (states_LED_views.stable_intensity_steps_0100 == 0) {
                                    beep (outP_beeper_high, 50, 50);
                                } else if (states_LED_views.stable_intensity_steps_0100 == steps_10_percent) {
                                    beep (outP_beeper_high, 50, 100);
                                } else if (states_LED_views.stable_intensity_steps_0100 == steps_0100) {
                                    beep (outP_beeper_high, 50, 200);
                                } else {}

                                for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                                    params[ix].max_intensity = states_LED_views.stable_intensity_steps_0100;
                                    params[ix].min_intensity = params[ix].max_intensity;
                                }

                                // OBSERVE THAT LEDs will BLINK "RANDOMLY" UNTIL SETTLED if DEBUG_PRINT_GLOBAL_APP == 1

                            } else { // not state_all_LEDs_stable_intensity
                                unsigned iof_period_ms = params[iof_LED].iof_period_ms_list;

                                iof_period_ms = (iof_period_ms + 1) % PERIOD_MS_LIST_LEN;

                                if (iof_period_ms == (PERIOD_MS_LIST_LEN - 1)) {
                                    beep (outP_beeper_high, 50, 50); // Extra beep at end of list
                                }

                                params[iof_LED].period_ms = period_ms_list[iof_period_ms];
                                params[iof_LED].iof_period_ms_list = iof_period_ms;
                            }
                        }

                        write_LEDs_intensity_and_period = true;

                    } else {} // not button_left_or_right_taken

                } else if (released_now) {
                    switch (iof_button) {
                        case IOF_BUTTON_LEFT: {
                            // No code, no handling
                        } break;

                        case IOF_BUTTON_CENTER: {
                            if (a_side_button_pressed_while_center) {
                                a_side_button_pressed_while_center = false;
                            } else {

                                beep (outP_beeper_high, 0, 100);
                                write_LEDs_intensity_and_period = true;

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
                            }
                        } break;

                        case IOF_BUTTON_RIGHT: {
                            // No code, no handling
                        } break;

                        default: {} break; // won't happen, but no need to crash
                    } // switch

                } else if (pressed_for_long) {
                    switch (iof_button) {

                        case IOF_BUTTON_LEFT: {
                            beep (outP_beeper_high,  0, 200);
                            beep (outP_beeper_high, 50, 100);

                            set_params_to_default (params);
                            set_states_LED_views_to_default (params, states_LED_views, synch_all);
                            write_LEDs_intensity_and_period = true;
                        } break;

                        case IOF_BUTTON_CENTER: { // IOF_RED_LED:
                            beep (outP_beeper_high, 0, 200);

                            states_LED_views.state_LED_views = (states_LED_views.state_LED_views + 1) % NUM_RED_LED_STATES;

                            // No extra beep for 0 or the last, but then 1, 2 .. extra beeps
                            if (states_LED_views.state_LED_views < (NUM_RED_LED_STATES-1)) {
                                for (unsigned ix=0; ix < states_LED_views.state_LED_views; ix++) {
                                    beep (outP_beeper_high, 100, 50);
                                }
                            }

                            debug_print ("state_LED_views %u (%u)\n", states_LED_views.state_LED_views, NUM_RED_LED_STATES);

                            switch (states_LED_views.state_LED_views) {
                                case state_red_LED_default: {
                                    beep (outP_beeper_high, 50, 100);

                                    set_params_to_default (params);
                                    set_states_LED_views_to_default (params, states_LED_views, synch_all);
                                } break;

                                case state_all_LEDs_stable_intensity: {

                                    synch_all = DEFAULT_SYNCH; // Set to all at write_LEDs_intensity_and_period

                                    for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                                        params[ix].period_ms       = DEFAULT_SOFTBLINK_PERIOD_MS; // Would not matter since it's stable anyhow
                                        params[ix].intensity_steps = steps_0100;
                                        params[ix].max_intensity   = states_LED_views.stable_intensity_steps_0100;
                                        params[ix].min_intensity   = params[ix].max_intensity;
                                    }

                                } break;

                                // #pragma fallthrough (for xTIMEcomposer 14.3.3)
                                case state_red_LED_steps_0012: {
                                    // Clean-up after state_all_LEDs_stable_intensity:
                                    for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                                        params[ix].min_intensity   = DEFAULT_DARK_INTENSITY;
                                        params[ix].max_intensity   = DEFAULT_FULL_INTENSITY;
                                        params[ix].intensity_steps = DEFAULT_INTENSITY_STEPS;
                                    }

                                    // The effect of changing intensity_steps is best seen at slow periods:
                                    for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                                        params[ix].period_ms = SOFTBLINK_PERIOD_MAX_MS; // PWM=008
                                    }
                                } [[fallthrough]];
                                case state_red_LED_steps_0100:
                                case state_red_LED_steps_0256:
                                case state_red_LED_steps_1000: {
                                    params[IOF_RED_LED].intensity_steps               = intensity_steps_list[states_LED_views.iOf_intensity_steps_list_red_LED];
                                    states_LED_views.iOf_intensity_steps_list_red_LED = (states_LED_views.iOf_intensity_steps_list_red_LED + 1) % NUM_INTENSITY_STEPS; // For next time
                                    write_LEDs_intensity_and_period                   = true;
                                } break;

                                case state_red_LED_half_range: {
                                    params[IOF_RED_LED].min_max_intensity_offset_divisor = OFFSET_DIVISOR_4;
                                } break;

                                case state_all_LEDs_synched: {
                                    params[IOF_RED_LED].min_max_intensity_offset_divisor = OFFSET_DIVISOR_INFIN;
                                    beep (outP_beeper_high, 100, 300); // Loong extra beep for the last
                                    synch_all = synch_active;
                                } break;

                                default : {} break; // Never here, no need to crash
                            } // switch

                            write_LEDs_intensity_and_period = true;

                        } break;

                        case IOF_BUTTON_RIGHT: {
                            // No code, no handling
                        } break;

                        default: {} break; // won't happen, but no need to crash
                    }; // switch

                } else {
                   // No code, no pressed action
                } // end of pressed_now, released_now and pressed_for_long list. I wish I had a folding editor!

                if (write_LEDs_intensity_and_period) {
                    // All tasks must be set to the same synch pattern, equal to avoid deadlock:
                    for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                        params[ix].synch = synch_all;
                    }
                    outP_external_blue_led_high <: (synch_all == synch_active);
                    write_to_pwm_softblinker (if_softblinker, params);
                } else {}


            } break; // select i_buttons_in
        }
    }
}
