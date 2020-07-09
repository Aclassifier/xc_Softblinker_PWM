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

    #include "_version.h" // First this..
    #include "_globals.h" // ..then this

    #include "_texts_and_constants.h"
    #include "button_press.h"
    #include "maths.h"
    #include "pwm_softblinker.h"

    #include "_Softblinker_PWM.h"
#endif

#define DEBUG_PRINT_TEST 0
#define debug_print(fmt, ...) do { if((DEBUG_PRINT_TEST==1) and (DEBUG_PRINT_GLOBAL_APP==1)) printf(fmt, __VA_ARGS__); } while (0)

#define NUM_TIMEOUTS_PER_SECOND 2

typedef struct params_t {
    unsigned     period_ms;
    percentage_t min_percentage;
    percentage_t max_percentage;
} params_t;

typedef struct softblinker_pwm_button_client_task_t {
    params_t params [CONFIG_NUM_SOFTBLIKER_LEDS];
} softblinker_pwm_button_client_task_t;

[[combinable]]
void softblinker_pwm_button_client_task (
        server button_if      i_buttons_in[BUTTONS_NUM_CLIENTS],
        client softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS])
{
    timer                                tmr;
    time32_t                             time_ticks; // Ticks to 100 in 1 us
    button_action_t                      buttons_action [BUTTONS_NUM_CLIENTS];
    bool                                 start_at_dark  [BUTTONS_NUM_CLIENTS];
    softblinker_pwm_button_client_task_t context;

    for (unsigned ix = 0; ix < BUTTONS_NUM_CLIENTS; ix++) {
        buttons_action[ix] = BUTTON_ACTION_VOID;
        start_at_dark[ix] = false;
    }

    {
        params_t const params [CONFIG_NUM_SOFTBLIKER_LEDS] = PARAMS_PERIODMS_MINPRO_MAXPRO; // {{200,0,100},{6000,0,100}}

        for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
            // Set them
            context.params[ix].period_ms      = params[ix].period_ms;
            context.params[ix].min_percentage = params[ix].min_percentage;
            context.params[ix].max_percentage = params[ix].max_percentage;
            // And use them
            if_softblinker[ix].set_LED_period_ms       (context.params[ix].period_ms, start_at_dark[ix]);
            if_softblinker[ix].set_LED_intensity_range (context.params[ix].min_percentage, context.params[ix].max_percentage);
        }
    }

    while (true) {

         select { // Each case passively waits on an event:

               // BUTTON ACTION (REPEAT: BUTTON HELD FOR SOME TIME) AT TIMEOUT
               //
               case tmr when timerafter (time_ticks) :> void : {
                   time_ticks += (XS1_TIMER_HZ/NUM_TIMEOUTS_PER_SECOND);
                   // ...
               } break; // timerafter

               // BUTTON PRESSES
               //
               case i_buttons_in[int iof_button].button (const button_action_t button_action) : {

                   buttons_action[iof_button] = button_action;

                   debug_print ("BUTTON [%u]=%u -> ", iof_button, button_action);

                   const bool pressed_now      = (button_action == BUTTON_ACTION_PRESSED);  // 1
                   const bool pressed_for_long = (button_action == BUTTON_ACTION_PRESSED_FOR_LONG); // 2 Not used
                   const bool released_now     = (button_action == BUTTON_ACTION_RELEASED); // 2

                   if (pressed_now) {

                       unsigned iof_LED;
                       bool     button_taken = false;

                       switch (iof_button) {
                           case IOF_BUTTON_LEFT: {
                               iof_LED = IOF_YELLOW_LED;
                               if (buttons_action[IOF_BUTTON_CENTER] == BUTTON_ACTION_PRESSED) {
                                   // No code, see below
                               } else if (context.params[iof_LED].period_ms < 1000) {
                                   context.params[iof_LED].period_ms += SOFTBLINK_PERIOD_MIN_MS;
                               } else {
                                   context.params[iof_LED].period_ms += 2000;
                               }
                               button_taken = true;
                           } break;

                           case IOF_BUTTON_CENTER: {
                               for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                                   if_softblinker[ix].set_LED_intensity_range (SOFTBLINK_DEFAULT_MIN_PERCENTAGE, SOFTBLINK_DEFAULT_MIN_PERCENTAGE); // OFF!
                                   start_at_dark[ix] = true;
                               }
                           } break;

                           case IOF_BUTTON_RIGHT: {
                               iof_LED = IOF_RED_LED;
                               if (buttons_action[IOF_BUTTON_CENTER] == BUTTON_ACTION_PRESSED) {
                                   // No code, see below
                               } else if (context.params[iof_LED].period_ms < 1000) {
                                   context.params[iof_LED].period_ms += SOFTBLINK_PERIOD_MIN_MS;
                               } else {
                                   context.params[iof_LED].period_ms += 2000;
                               }
                               button_taken = true;
                           } break;

                           default : {} break;
                       } // Outer switch

                       if (button_taken) {
                           bool min_set;
                           bool max_set;

                           {context.params[iof_LED].period_ms, min_set, max_set} =
                                   in_range_signed_min_max_set (
                                           context.params[iof_LED].period_ms,
                                           SOFTBLINK_PERIOD_MIN_MS,
                                           SOFTBLINK_PERIOD_MAX_MS);
                           if (min_set) {
                               context.params[iof_LED].period_ms = SOFTBLINK_PERIOD_MAX_MS; // wrap
                           } else if (max_set) {
                               context.params[iof_LED].period_ms = SOFTBLINK_PERIOD_MIN_MS; // wrap
                           } else {}

                           if (buttons_action[IOF_BUTTON_CENTER] == BUTTON_ACTION_PRESSED) {
                               if (iof_LED == IOF_RED_LED) {
                                   context.params[IOF_YELLOW_LED].period_ms = context.params[IOF_RED_LED].period_ms; // set the other
                               } else if (iof_LED == IOF_YELLOW_LED) {
                                   context.params[IOF_RED_LED].period_ms = context.params[IOF_YELLOW_LED].period_ms; // set the other
                               } else {}
                           } else {}

                           for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                               if_softblinker[ix].set_LED_period_ms (context.params[ix].period_ms, start_at_dark[ix]);
                               start_at_dark[ix] = false;
                           }
                           for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
                               // Needed since I use SOFTBLINK_DEFAULT_MIN_PERCENTAGE above
                               if_softblinker[ix].set_LED_intensity_range (context.params[ix].min_percentage, context.params[ix].max_percentage);
                           }
                       } else {}

                   } else {
                       // Not pressed_now, no code
                   }
               } break; // select i_buttons_in
           }
      }
}
