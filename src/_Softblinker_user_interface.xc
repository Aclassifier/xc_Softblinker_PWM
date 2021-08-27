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
    #include "pwm_softblinker.h"

    #include "_Softblinker_user_interface.h"
#endif

#define DEBUG_PRINT_TEST 1
#define debug_print(fmt, ...) do { if((DEBUG_PRINT_TEST==1) and (DEBUG_PRINT_GLOBAL_APP==1)) printf(fmt, __VA_ARGS__); } while (0)

// SIMULATE BUTTONS AT POWER UP
//
#define DO_BUTTONS_POWER_UP_SIMULATE_ACTIONS 1
//
#define NUM_BUTTONS_POWER_UP_SIMULATE_ACTIONS 16
//
const int iof_buttons [NUM_BUTTONS_POWER_UP_SIMULATE_ACTIONS] =
{
                                          // state_red_LED_default
    IOF_BUTTON_CENTER, IOF_BUTTON_CENTER, // state_all_LEDs_stable_intensity
    IOF_BUTTON_LEFT,   IOF_BUTTON_LEFT,
    IOF_BUTTON_LEFT,   IOF_BUTTON_LEFT,
    IOF_BUTTON_LEFT,   IOF_BUTTON_LEFT,
    IOF_BUTTON_LEFT,   IOF_BUTTON_LEFT,
    IOF_BUTTON_LEFT,   IOF_BUTTON_LEFT,
    IOF_BUTTON_LEFT,   IOF_BUTTON_LEFT,
    IOF_BUTTON_LEFT,   IOF_BUTTON_LEFT
};
//
const button_action_t button_actions [NUM_BUTTONS_POWER_UP_SIMULATE_ACTIONS] =
{
                                                          // state_red_LED_default
    BUTTON_ACTION_PRESSED, BUTTON_ACTION_PRESSED_FOR_LONG,// state_all_LEDs_stable_intensity
    BUTTON_ACTION_PRESSED, BUTTON_ACTION_RELEASED,        // 90% light
    BUTTON_ACTION_PRESSED, BUTTON_ACTION_RELEASED,        // 80% light
    BUTTON_ACTION_PRESSED, BUTTON_ACTION_RELEASED,        // 70% light
    BUTTON_ACTION_PRESSED, BUTTON_ACTION_RELEASED,        // 60% light
    BUTTON_ACTION_PRESSED, BUTTON_ACTION_RELEASED,        // 50% light
    BUTTON_ACTION_PRESSED, BUTTON_ACTION_RELEASED,        // 40% light
    BUTTON_ACTION_PRESSED, BUTTON_ACTION_RELEASED         // 30% light
};
//
#define BUTTONS_POWER_UP_SIMULATE_MS 100
//
const pre_button_action_delay_ms [NUM_BUTTONS_POWER_UP_SIMULATE_ACTIONS] =
{
    DEFAULT_SOFTBLINK_PERIOD_MS, // 10 secs. Observe one period
    BUTTONS_POWER_UP_SIMULATE_MS, DEFAULT_SOFTBLINK_PERIOD_MS/10,
    BUTTONS_POWER_UP_SIMULATE_MS, DEFAULT_SOFTBLINK_PERIOD_MS/10,
    BUTTONS_POWER_UP_SIMULATE_MS, DEFAULT_SOFTBLINK_PERIOD_MS/10,
    BUTTONS_POWER_UP_SIMULATE_MS, DEFAULT_SOFTBLINK_PERIOD_MS/10,
    BUTTONS_POWER_UP_SIMULATE_MS, DEFAULT_SOFTBLINK_PERIOD_MS/10,
    BUTTONS_POWER_UP_SIMULATE_MS, DEFAULT_SOFTBLINK_PERIOD_MS/10,
    BUTTONS_POWER_UP_SIMULATE_MS, DEFAULT_SOFTBLINK_PERIOD_MS/10,
    BUTTONS_POWER_UP_SIMULATE_MS
};

#if (CONFIG_NUM_SOFTBLIKER_LEDS==2)
    #define LED_START_DARK_FULL {dark_LED, full_LED} // of start_LED_at_e with CONFIG_NUM_SOFTBLIKER_LEDS elements
    #define LED_START_DARK_DARK {dark_LED, dark_LED} // --"--
#elif (CONFIG_NUM_SOFTBLIKER_LEDS==1)
    #error Meaningless, this is coded for three buttons and two LED strips
    // Some value, to limit compiler errors to the one above only
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

// 2May2021:
typedef enum {
    state_red_LED_default,           // 0 beeep
    state_all_LEDs_stable_intensity, // 1 beeep beep .. plus some extra beeps on 0, 10 and 100% intensity ++. PWM=012 stops here at 30%
    state_red_LED_steps_0012,        // 2 beeep beep beep                     steps_0012
    state_red_LED_steps_0100,        // 3 beeep beep beep beep                steps_0100
    state_red_LED_steps_0256,        // 4 beeep beep beep beep beep           steps_0256 (steps_1000 is default)
    state_red_LED_half_range,        // 5 beeep beep beep beep beep beep beep
    state_all_LEDs_synched,          // 6 beeep beeeep + BLUE LED WHEN IN BARRIER
    NUM_RED_LED_STATES // ==7 those above
    //
} state_LED_views_e;

typedef struct {
    unsigned          iOf_intensity_steps_list_red_LED;
    unsigned          stable_intensity_steps_1000;
    state_LED_views_e state_LED_views;
    signed            state_all_LEDs_stable_intensity_inc_dec_by;
    bool              inhibit_next_button_released_now_left;
    bool              inhibit_next_button_released_now_right;
    bool              halt_left;
    bool              halt_right;
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

#define STABLE_INTENSITY_STEPS_DEFAULT steps_1000

void set_states_LED_views_to_default (
        params_t           params [CONFIG_NUM_SOFTBLIKER_LEDS],
        states_LED_views_t &states_LED_views,
        synch_e            &synch_all) {

    states_LED_views.iOf_intensity_steps_list_red_LED           = 0; // First, pointing to steps_0012
    states_LED_views.state_LED_views                            = state_red_LED_default;
    states_LED_views.stable_intensity_steps_1000                = STABLE_INTENSITY_STEPS_DEFAULT;
    states_LED_views.state_all_LEDs_stable_intensity_inc_dec_by = 0;
    states_LED_views.inhibit_next_button_released_now_left      = false;
    states_LED_views.inhibit_next_button_released_now_right     = false;
    states_LED_views.halt_left                                  = false;
    states_LED_views.halt_right                                 = false;
    synch_all                                                   = DEFAULT_SYNCH;

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

typedef struct ui_context_t {
    button_action_t    buttons_action [BUTTONS_NUM_CLIENTS];
    params_t           params         [CONFIG_NUM_SOFTBLIKER_LEDS];
    LED_phase_e        LED_phase;
    bool               a_side_button_pressed_while_center;
    states_LED_views_t states_LED_views;
    synch_e            synch_all; // Single value to reflect that ALL LEDs or NO LED must be synched, else deadlock!
    unsigned           period_ms_list             [PERIOD_MS_LIST_LEN];        // was const
    intensity_steps_e  intensity_steps_list_short [NUM_INTENSITY_STEPS_SHORT]; // was const
} ui_context_t; // PWM=011

void handle_button (const int iof_button,
        const button_action_t button_action,
        ui_context_t          &ctx,
        client softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS],
        out buffered port:1   outP_beeper_high)
{

    bool write_LEDs_intensity_and_period = false;
    bool button_taken_left               = false;
    bool button_taken_right              = false;

    // 2May2021: (in _Softblinker_user_interface.xc)
    // ---------------------------------------------------------------------------------------------------------------------------------------
    // BUTTONS          | LEFT                                | CENTER                                 | RIGHT
    // ---------------------------------------------------------------------------------------------------------------------------------------
    // pressed_now      | if also CENTER set red/right period | ...                                    | if also CENTER set yellow/left period
    //                  | else next yellow/left period        | ...                                    | else next red/right period
    // -----------------------------------------------------------------------------------------------------------------------------
    // released_now     | if steady light LEDs less but       | if LEFT or RIGHT pressed_now handle it | if steady light LEDs more but
    //                  | if also RIGHT either halt the       | else swap phase and start black/full   | if also RIGHT either halt the
    //                  | LED or below 1% down                |                                        | LED or below 1% down
    // --------------------------------------------------------------------------------------------------------------------------------------
    // pressed_for_long |                                     | Increase state_LED_views_e             | ...
    // ======================================================================================================================================
    // pressed_for_long | LEFT       | if LEFT and RIGHT: clear to init state, but arbitrary starts    | RIGHT
    // --------------------------------------------------------------------------------------------------------------------------------------
    // Beeping as some pattern to distinguish button actions. If no beeping then that press has been disabled by previous press to
    // avoid some present state becoming changed when not wanted. See inhibit_next_button_released_now_.. (some pressed_now must not
    // be overwritten by released_now)

    ctx.buttons_action[iof_button] = button_action;

    debug_print ("\nBUTTON [%u]=%u\n", iof_button, button_action);

    const bool pressed_now      = (button_action == BUTTON_ACTION_PRESSED);          // 1
    const bool pressed_for_long = (button_action == BUTTON_ACTION_PRESSED_FOR_LONG); // 2
    const bool released_now     = (button_action == BUTTON_ACTION_RELEASED);         // 3 Not after BUTTON_ACTION_PRESSED_FOR_LONG

    const bool pressed_right = (ctx.buttons_action[IOF_BUTTON_RIGHT] == BUTTON_ACTION_PRESSED);
    const bool pressed_left  = (ctx.buttons_action[IOF_BUTTON_LEFT]  == BUTTON_ACTION_PRESSED);
    const bool long_right    = (ctx.buttons_action[IOF_BUTTON_RIGHT] == BUTTON_ACTION_PRESSED_FOR_LONG);
    const bool long_left     = (ctx.buttons_action[IOF_BUTTON_LEFT]  == BUTTON_ACTION_PRESSED_FOR_LONG);

    if (pressed_now) {
        unsigned iof_LED;

        switch (iof_button) {
            case IOF_BUTTON_LEFT: {

                iof_LED = IOF_LEFT_YELLOW_LED;
                button_taken_left = true;

            } break;

            case IOF_BUTTON_CENTER: {
                // No code
                // IOF_BUTTON_CENTER handled at released_now, not pressed_now so that it's not taken before pressed_for_long
            } break;

            case IOF_BUTTON_RIGHT: {

                iof_LED = IOF_RIGHT_RED_LED;
                button_taken_right = true;

            } break;

            default: {} break; // won't happen, but no need to crash
        } // Outer switch

        if (button_taken_left or button_taken_right) {

            if (ctx.buttons_action[IOF_BUTTON_CENTER] == BUTTON_ACTION_PRESSED) { // double button action

                beep (outP_beeper_high, 0, 100);
                ctx.a_side_button_pressed_while_center = true;

                if (iof_LED == IOF_RIGHT_RED_LED) {
                    ctx.params[IOF_LEFT_YELLOW_LED].period_ms = ctx.params[IOF_RIGHT_RED_LED].period_ms; // set the other
                } else if (iof_LED == IOF_LEFT_YELLOW_LED) {
                    ctx.params[IOF_RIGHT_RED_LED].period_ms = ctx.params[IOF_LEFT_YELLOW_LED].period_ms; // set the other
                } else {}

                write_LEDs_intensity_and_period = true;

            } else { // Standard
                if (ctx.states_LED_views.state_LED_views == state_all_LEDs_stable_intensity) {

                    // No code, no handling of these buttons in this state here. However, the fact that they are pressed
                    // is tested on (later).
                    // Therefore no write_LEDs_intensity_and_period here (don't need to first write the old value here, then the new)

                } else { // not state_all_LEDs_stable_intensity
                    beep (outP_beeper_high, 0, 100);

                    unsigned iof_period_ms = ctx.params[iof_LED].iof_period_ms_list;

                    iof_period_ms = (iof_period_ms + 1) % PERIOD_MS_LIST_LEN;

                    if (iof_period_ms == (PERIOD_MS_LIST_LEN - 1)) {
                        beep (outP_beeper_high, 50, 50); // Extra beep at end of list
                    }

                    ctx.params[iof_LED].period_ms = ctx.period_ms_list[iof_period_ms];
                    ctx.params[iof_LED].iof_period_ms_list = iof_period_ms;

                    write_LEDs_intensity_and_period = true;
                }
            }
        } else {} // not button_left_or_right_taken

    } else if (released_now) {
        switch (iof_button) {
            case IOF_BUTTON_LEFT: {
                button_taken_left = true;
            } break;

            case IOF_BUTTON_CENTER: {
                if (ctx.a_side_button_pressed_while_center) {
                    ctx.a_side_button_pressed_while_center = false;
                } else {

                    beep (outP_beeper_high, 0, 100);
                    write_LEDs_intensity_and_period = true;

                    if (ctx.LED_phase == OUT_OF_PHASE) {
                        const start_LED_at_e start_LED_at_now [CONFIG_NUM_SOFTBLIKER_LEDS] = LED_START_DARK_FULL; // This and..
                        for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                            ctx.params[ix].start_LED_at   = start_LED_at_now[ix];
                            ctx.params[ix].transition_pwm = slide_transition_pwm; // LEDs out of phase, and sliding PWM: ok combination
                        }
                        ctx.LED_phase = IN_PHASE;
                    } else if (ctx.LED_phase == IN_PHASE) {
                        const start_LED_at_e start_LED_at_now [CONFIG_NUM_SOFTBLIKER_LEDS] = LED_START_DARK_DARK; // .. this are "180 degrees" out of phase
                        for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                            ctx.params[ix].start_LED_at   = start_LED_at_now[ix];
                            ctx.params[ix].transition_pwm = lock_transition_pwm; // LEDs in phase and locked PWM: also ok combination
                        }
                        ctx.LED_phase = OUT_OF_PHASE;
                    } else {}
                }
            } break;

            case IOF_BUTTON_RIGHT: {
                button_taken_right = true;
            } break;

            default: {} break; // won't happen, but no need to crash
        } // switch

        if (button_taken_left or button_taken_right) {
            if (ctx.states_LED_views.state_LED_views == state_all_LEDs_stable_intensity) {

                if (button_taken_left and ctx.states_LED_views.inhibit_next_button_released_now_left) {
                    ctx.states_LED_views.inhibit_next_button_released_now_left = false;
                } else if (button_taken_right and ctx.states_LED_views.inhibit_next_button_released_now_right) {
                    ctx.states_LED_views.inhibit_next_button_released_now_right = false;
                } else {
                    beep (outP_beeper_high, 0, 50);

                    ctx.states_LED_views.inhibit_next_button_released_now_left  = false;
                    ctx.states_LED_views.inhibit_next_button_released_now_right = false;

                    const unsigned steps_10_percent = STABLE_INTENSITY_STEPS_DEFAULT/10;
                    const unsigned steps_01_percent = STABLE_INTENSITY_STEPS_DEFAULT/100;

                    bool   do_steps_0001 = false;
                    signed inc_dec_by;

                    if (button_taken_left) { // if steady light LEDs less
                        if (ctx.states_LED_views.stable_intensity_steps_1000 <= steps_01_percent) {
                            if (pressed_right or long_right) {
                                inc_dec_by = -(STABLE_INTENSITY_STEPS_DEFAULT/1000);
                                // [10,9,8,7,6,5,4,3,2,1,0]
                                do_steps_0001 = true;
                                ctx.states_LED_views.inhibit_next_button_released_now_right = true;
                            } else {
                                // '<=' in test gives [1000..200,100,90,80,70,60,50,40,30,20,10,0]
                                inc_dec_by = -(STABLE_INTENSITY_STEPS_DEFAULT/100);
                            }
                        } else if (ctx.states_LED_views.stable_intensity_steps_1000 <= steps_10_percent) {
                            // '<=' in test gives [1000..200,100,90,80,70,60,50,40,30,20,10,0]
                            inc_dec_by = -(STABLE_INTENSITY_STEPS_DEFAULT/100);
                        } else {
                            inc_dec_by = -(STABLE_INTENSITY_STEPS_DEFAULT/10);
                        }
                    } else if (button_taken_right) { // if steady light LEDs more
                        if (ctx.states_LED_views.stable_intensity_steps_1000 <= steps_01_percent) {
                            if (pressed_left or long_left) {
                                inc_dec_by = (STABLE_INTENSITY_STEPS_DEFAULT/1000);
                                // [0,1,2,3,4,5,6,7,8,9,10]
                                do_steps_0001 = true;
                                ctx.states_LED_views.inhibit_next_button_released_now_left = true;
                            } else {
                                // '<' in test gives [0,10,20,30,40,50,60,70,80,90,100,200..1000]
                                inc_dec_by = (STABLE_INTENSITY_STEPS_DEFAULT/100);
                            }
                        } else if (ctx.states_LED_views.stable_intensity_steps_1000 < steps_10_percent) {
                            // '<' in test gives [0,10,20,30,40,50,60,70,80,90,100,200..1000]
                            inc_dec_by = (STABLE_INTENSITY_STEPS_DEFAULT/100);
                        } else {
                            inc_dec_by = (STABLE_INTENSITY_STEPS_DEFAULT/10);
                        }
                    } else {
                        inc_dec_by = 0;
                    }

                    const bool inc_dec_by_changed_sgn = (sgn(ctx.states_LED_views.state_all_LEDs_stable_intensity_inc_dec_by) != sgn(inc_dec_by));
                    const bool halt_right             = button_taken_left  and (pressed_right or long_right);
                    const bool halt_left              = button_taken_right and (pressed_left  or long_left);
                    const bool halt_change            = (halt_right != ctx.states_LED_views.halt_right) or (halt_left != ctx.states_LED_views.halt_left);

                    ctx.states_LED_views.state_all_LEDs_stable_intensity_inc_dec_by = inc_dec_by; // Would not have been allowed in occam! (since there is a const derived from it in scope)

                    if (inc_dec_by_changed_sgn or halt_change) { // First this..
                        // Set old value into all in case inhibit is used, because then we would not want the halted value
                        // to to get an increment as a side effect from the first inhibit. Usually this will be overwritten by new value.
                        for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                            ctx.params[ix].max_intensity = ctx.states_LED_views.stable_intensity_steps_1000;
                            ctx.params[ix].min_intensity = ctx.states_LED_views.stable_intensity_steps_1000;
                        }
                    } else {}

                    if (not do_steps_0001) {
                        //  Clean-up after single-values like 45 -> 40. 101 -> 100 etc.
                        ctx.states_LED_views.stable_intensity_steps_1000 = (ctx.states_LED_views.stable_intensity_steps_1000 / 10) * 10;
                    } else {}

                    ctx.states_LED_views.stable_intensity_steps_1000 = // ..then this
                            in_range_unsigned_inc_dec (ctx.states_LED_views.stable_intensity_steps_1000, 0, STABLE_INTENSITY_STEPS_DEFAULT, inc_dec_by);

                    if (inc_dec_by_changed_sgn) {
                        beep (outP_beeper_high, 50, 50);
                    } else if (ctx.states_LED_views.stable_intensity_steps_1000 == 0) {
                        beep (outP_beeper_high, 200, 250);
                    } else if (ctx.states_LED_views.stable_intensity_steps_1000 == steps_01_percent) {
                        beep (outP_beeper_high, 50, 150);
                    } else if (ctx.states_LED_views.stable_intensity_steps_1000 == steps_10_percent) {
                        beep (outP_beeper_high, 50, 200);
                    } else if (ctx.states_LED_views.stable_intensity_steps_1000 == STABLE_INTENSITY_STEPS_DEFAULT) {
                        beep (outP_beeper_high, 200, 250);
                    } else if (do_steps_0001) {
                        beep (outP_beeper_high, 100, 50);
                    } else {}

                    // Now the other button may be used to halt that side's increment or decrement
                    //
                    if (do_steps_0001) {
                        // Set both LEDS when either left or right button is pressed
                        for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                            ctx.params[ix].max_intensity = ctx.states_LED_views.stable_intensity_steps_1000;
                            ctx.params[ix].min_intensity = ctx.states_LED_views.stable_intensity_steps_1000;
                        }
                    } else if (halt_right) {
                        // Only set left LED when right button is held for inhibit
                        ctx.params[IOF_LEFT_YELLOW_LED].max_intensity = ctx.states_LED_views.stable_intensity_steps_1000;
                        ctx.params[IOF_LEFT_YELLOW_LED].min_intensity = ctx.states_LED_views.stable_intensity_steps_1000;

                        ctx.states_LED_views.inhibit_next_button_released_now_right = true;
                        ctx.states_LED_views.halt_right = true;
                        beep (outP_beeper_high, 50, 25);
                    } else if (halt_left) {
                        // Only set right LED when left button is held for inhibit
                        ctx.params[IOF_RIGHT_RED_LED].max_intensity = ctx.states_LED_views.stable_intensity_steps_1000;
                        ctx.params[IOF_RIGHT_RED_LED].min_intensity = ctx.states_LED_views.stable_intensity_steps_1000;

                        ctx.states_LED_views.inhibit_next_button_released_now_left = true;
                        ctx.states_LED_views.halt_left = true;
                        beep (outP_beeper_high, 50, 25);
                    } else { // same as do_steps_0001
                        // Set both LEDS when either left or right button is pressed
                        for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                            ctx.params[ix].max_intensity = ctx.states_LED_views.stable_intensity_steps_1000;
                            ctx.params[ix].min_intensity = ctx.states_LED_views.stable_intensity_steps_1000;
                        }
                    }

                    write_LEDs_intensity_and_period = true;
                }

                // OBSERVE THAT LEDs will BLINK "RANDOMLY" UNTIL SETTLED if DEBUG_PRINT_GLOBAL_APP == 1
            } else {
                // No code. No handling of these buttons if not state_all_LEDs_stable_intensity
            }
        } else {
           // No code. No handling of IOF_BUTTON_CENTER
        }

    } else if (pressed_for_long) {

        // since released_now will never happen:
        ctx.states_LED_views.inhibit_next_button_released_now_left  = false;
        ctx.states_LED_views.inhibit_next_button_released_now_right = false;

        switch (iof_button) {

            case IOF_BUTTON_LEFT: {
                // no code, as long_left catches it
            } break;

            case IOF_BUTTON_CENTER: { // IOF_RIGHT_RED_LED:
                beep (outP_beeper_high, 0, 200);

                ctx.states_LED_views.state_LED_views = (ctx.states_LED_views.state_LED_views + 1) % NUM_RED_LED_STATES;

                // No extra beep for 0 or the last, but then 1, 2 .. extra beeps
                if (ctx.states_LED_views.state_LED_views < (NUM_RED_LED_STATES-1)) {
                    for (unsigned ix=0; ix < ctx.states_LED_views.state_LED_views; ix++) {
                        beep (outP_beeper_high, 100, 50);
                    }
                }

                debug_print ("state_LED_views %u (%u)\n", ctx.states_LED_views.state_LED_views, NUM_RED_LED_STATES);

                switch (ctx.states_LED_views.state_LED_views) {
                    case state_red_LED_default: {
                        beep (outP_beeper_high, 50, 100);

                        set_params_to_default (ctx.params);
                        set_states_LED_views_to_default (ctx.params, ctx.states_LED_views, ctx.synch_all);
                    } break;

                    case state_all_LEDs_stable_intensity: {

                        ctx.synch_all = DEFAULT_SYNCH; // Set to all at write_LEDs_intensity_and_period

                        ctx.states_LED_views.inhibit_next_button_released_now_left  = false;
                        ctx.states_LED_views.inhibit_next_button_released_now_right = false;

                        ctx.states_LED_views.stable_intensity_steps_1000 = STABLE_INTENSITY_STEPS_DEFAULT;

                        for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                            ctx.params[ix].period_ms       = DEFAULT_SOFTBLINK_PERIOD_MS; // Would not matter since it's stable anyhow
                            ctx.params[ix].intensity_steps = STABLE_INTENSITY_STEPS_DEFAULT;
                            ctx.params[ix].max_intensity   = STABLE_INTENSITY_STEPS_DEFAULT;
                            ctx.params[ix].min_intensity   = STABLE_INTENSITY_STEPS_DEFAULT;
                        }

                    } break;

                    // #pragma fallthrough (for xTIMEcomposer 14.3.3)
                    case state_red_LED_steps_0012: {
                        // Clean-up after state_all_LEDs_stable_intensity:
                        for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                            ctx.params[ix].min_intensity   = DEFAULT_DARK_INTENSITY;
                            ctx.params[ix].max_intensity   = DEFAULT_FULL_INTENSITY;
                            ctx.params[ix].intensity_steps = DEFAULT_INTENSITY_STEPS;
                        }

                        // The effect of changing intensity_steps is best seen at slow periods:
                        for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                            ctx.params[ix].period_ms = SOFTBLINK_PERIOD_MAX_MS; // PWM=008
                        }
                    } [[fallthrough]];
                    case state_red_LED_steps_0100:
                    case state_red_LED_steps_0256: {
                        ctx.params[IOF_RIGHT_RED_LED].intensity_steps               = ctx.intensity_steps_list_short[ctx.states_LED_views.iOf_intensity_steps_list_red_LED];
                        ctx.states_LED_views.iOf_intensity_steps_list_red_LED = (ctx.states_LED_views.iOf_intensity_steps_list_red_LED + 1) % NUM_INTENSITY_STEPS_SHORT; // For next time
                    } break;

                    case state_red_LED_half_range: {
                        ctx.params[IOF_RIGHT_RED_LED].min_max_intensity_offset_divisor = OFFSET_DIVISOR_4;
                    } break;

                    case state_all_LEDs_synched: {
                        ctx.params[IOF_RIGHT_RED_LED].min_max_intensity_offset_divisor = OFFSET_DIVISOR_INFIN;
                        beep (outP_beeper_high, 100, 300); // Loong extra beep for the last
                        ctx.synch_all = synch_active;
                    } break;

                    default : {} break; // Never here, no need to crash
                } // switch

                write_LEDs_intensity_and_period = true;

            } break;

            case IOF_BUTTON_RIGHT: {
                // no code, as long_right catches it
            } break;

            default: {} break; // won't happen, but no need to crash
        }; // switch

        if (long_left and long_right) {
            // Both pressed for long

            beep (outP_beeper_high,  0, 200);
            beep (outP_beeper_high, 50, 300);

            set_params_to_default (ctx.params);
            set_states_LED_views_to_default (ctx.params, ctx.states_LED_views, ctx.synch_all);
            write_LEDs_intensity_and_period = true;
        } else {
            // Code. A single one of these may be pressed for long and that would be ok
        }

    } else {
       // No code, no pressed action
    } // end of pressed_now, released_now and pressed_for_long list. I wish I had a folding editor!

    if (write_LEDs_intensity_and_period) {
        // All tasks must be set to the same synch pattern, equal to avoid deadlock:
        for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
            ctx.params[ix].synch = ctx.synch_all;
        }
        write_to_pwm_softblinker (if_softblinker, ctx.params);
    } else {}
}


[[combinable]]
void softblinker_user_interface_task (
        server button_if      i_buttons_in[BUTTONS_NUM_CLIENTS],
        client softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS],
        out buffered port:1   outP_beeper_high)
{
    beep (outP_beeper_high, 0, 250);

    timer        tmr;
    time32_t     time_ticks; // Ticks to 100 in 1 us
    ui_context_t ctx; // PWM=011
    int          iof_buttons_power_up_simulate;

    #if (DO_BUTTONS_POWER_UP_SIMULATE_ACTIONS == 1)
        #if (WARNINGS==1)
            #warning Button simulation at power up
        #endif
        iof_buttons_power_up_simulate = 0;
    #else
        #if (WARNINGS==1)
            #warning No button simulation at power up
        #endif
        iof_buttons_power_up_simulate = NUM_BUTTONS_POWER_UP_SIMULATE_ACTIONS; // skip them
    #endif

    debug_print ("softblinker_user_interface_task sim_cnt=%u\n", iof_buttons_power_up_simulate);

    // INIT
    ctx.LED_phase                          = IN_PHASE;
    ctx.a_side_button_pressed_while_center = false;
    for (unsigned ix = 0; ix < BUTTONS_NUM_CLIENTS; ix++) {
        ctx.buttons_action[ix] = BUTTON_ACTION_VOID;
    }
    // INIT those that were const in 0066 (const'ness lost with ui_context_t)
    {
        const unsigned period_ms_list [PERIOD_MS_LIST_LEN] = PERIOD_MS_LIST;
        for (signed ix=0; ix < PERIOD_MS_LIST_LEN; ix++) {
            ctx.period_ms_list[ix] = period_ms_list[ix]; // const
        }
        const intensity_steps_e intensity_steps_list_short [NUM_INTENSITY_STEPS_SHORT] = INTENSITY_STEPS_LIST_SHORT;
        for (signed ix=0; ix < NUM_INTENSITY_STEPS_SHORT; ix++) {
            ctx.intensity_steps_list_short [ix] = intensity_steps_list_short[ix]; // const
        }
    }

    set_params_to_default (ctx.params);

    write_to_pwm_softblinker (if_softblinker, ctx.params);

    set_states_LED_views_to_default (ctx.params, ctx.states_LED_views, ctx.synch_all);

    tmr :> time_ticks;
    time_ticks += (XS1_TIMER_KHZ * pre_button_action_delay_ms[iof_buttons_power_up_simulate]);

    while (true) {
        select { // Each case passively waits on an event:

            // BUTTON ACTION (REPEAT: BUTTON HELD FOR SOME TIME) AT TIMEOUT
            //
            case (iof_buttons_power_up_simulate < NUM_BUTTONS_POWER_UP_SIMULATE_ACTIONS) => tmr when timerafter (time_ticks) :> void : {

                handle_button (
                        iof_buttons   [iof_buttons_power_up_simulate],
                        button_actions[iof_buttons_power_up_simulate],
                        ctx,
                        if_softblinker,
                        outP_beeper_high);

                iof_buttons_power_up_simulate++;
                if (iof_buttons_power_up_simulate < NUM_BUTTONS_POWER_UP_SIMULATE_ACTIONS) {
                    time_ticks += (XS1_TIMER_KHZ * pre_button_action_delay_ms[iof_buttons_power_up_simulate]);
                } else {}

            } break; // timerafter

            // BUTTON PRESSES
            //
            case i_buttons_in[int iof_button].button (const button_action_t button_action) : {

                if (iof_buttons_power_up_simulate == NUM_BUTTONS_POWER_UP_SIMULATE_ACTIONS){
                    handle_button (
                            iof_button,
                            button_action,
                            ctx,
                            if_softblinker,
                            outP_beeper_high);
                } else {}

            } break;
        }
    }
}
