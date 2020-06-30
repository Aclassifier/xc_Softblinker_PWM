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
    #include "pwm_softblinker.h"

    #include "_Softblinker_PWM.h"
#endif

#define DEBUG_PRINT_TEST 1
#define debug_print(fmt, ...) do { if((DEBUG_PRINT_TEST==1) and (DEBUG_PRINT_GLOBAL_APP==1)) printf(fmt, __VA_ARGS__); } while (0)

// For set_one_percent_ms and set_sofblink_percentages
#define SOFTBLINK_RESTARTED_ONE_PERCENT_MS        1 //  1 ms goes to 100 in 0.1 seconds -> 5 blinks per second
#define SOFTBLINK_RESTARTED_UNIT_MAX_PERCENTAGE 100
#define SOFTBLINK_RESTARTED_UNIT_MIN_PERCENTAGE   0
//
#define SOFTBLINK_DARK_DISPLAY_ONE_PERCENT_MS    30 // 30 ms goes to 100 in 3.0 seconds
#define SOFTBLINK_DARK_DISPLAY_MAX_PERCENTAGE    40
#define SOFTBLINK_DARK_DISPLAY_MIN_PERCENTAGE    10
//
#define SOFTBLINK_LIT_DISPLAY_ONE_PERCENT_MS     10 // 10 ms goes to 100 in 1.0 seconds
#define SOFTBLINK_LIT_DISPLAY_MAX_PERCENTAGE     80
#define SOFTBLINK_LIT_DISPLAY_MIN_PERCENTAGE     10

#define NUM_TIMEOUTS_PER_SECOND 2

[[combinable]]
void Softblinker_pwm_button_client_task (
        server button_if      i_buttons_in[BUTTONS_NUM_CLIENTS],
        client softblinker_if if_softblinker[SOFTBLINKER_SOFTBLINKER_PWM_NUM_CLIENTS])
{
    timer    tmr;
    time32_t time_ticks; // Ticks to 100 in 1 us

    // STARTUP
    unsigned const params_onepercent_max_min [SOFTBLINKER_SOFTBLINKER_PWM_NUM_CLIENTS][3] = PARAMS_ONEPERCENTMILLIS_MAXPRO_MINPRO;

    for (unsigned ix = 0; ix < SOFTBLINKER_SOFTBLINKER_PWM_NUM_CLIENTS; ix++) {
        if_softblinker[ix].set_one_percent_ms       (params_onepercent_max_min[ix][0]);
        if_softblinker[ix].set_sofblink_percentages (params_onepercent_max_min[ix][1], params_onepercent_max_min[ix][2]);
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

                   // HANDLE BUTTONS (button_states_t not needed)

                   const bool pressed_now      = (button_action == BUTTON_ACTION_PRESSED);
                   const bool pressed_for_long = (button_action == BUTTON_ACTION_PRESSED_FOR_LONG); // Not used
                   const bool released_now     = (button_action == BUTTON_ACTION_RELEASED);

                   if (pressed_now) {

                       switch (iof_button) {
                           case IOF_BUTTON_LEFT: {
                               // ..
                           } break;
                           case IOF_BUTTON_CENTER: {
                               // ..
                           } break;
                           case IOF_BUTTON_RIGHT: {
                               // ..
                           } break;
                       } // Outer switch
                   } else {
                       // Not pressed_now, no code
                   }
               } break; // select i_buttons_in
           }
       }
}
