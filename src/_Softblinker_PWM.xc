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

// For set_LED_period_ms and set_LED_intensity
#define SOFTBLINK_RESTARTED_PERIOD_MS           200 //   200 ms (max to max or min to min)
#define SOFTBLINK_RESTARTED_UNIT_MIN_PERCENTAGE   0
#define SOFTBLINK_RESTARTED_UNIT_MAX_PERCENTAGE 100
//
#define SOFTBLINK_DARK_DISPLAY_PERIOD_MS       6000 // 6 secs
#define SOFTBLINK_DARK_DISPLAY_MIN_PERCENTAGE    10
#define SOFTBLINK_DARK_DISPLAY_MAX_PERCENTAGE    40
//
#define SOFTBLINK_LIT_DISPLAY_PERIOD_MS        2000 // 2 secs
#define SOFTBLINK_LIT_DISPLAY_MIN_PERCENTAGE     10
#define SOFTBLINK_LIT_DISPLAY_MAX_PERCENTAGE     80

#define NUM_TIMEOUTS_PER_SECOND 2

[[combinable]]
void softblinker_pwm_button_client_task (
        server button_if      i_buttons_in[BUTTONS_NUM_CLIENTS],
        client softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS])
{
    timer    tmr;
    time32_t time_ticks; // Ticks to 100 in 1 us

    // STARTUP
    unsigned const params_periodms_minpro_maxpro [CONFIG_NUM_SOFTBLIKER_LEDS][3] = PARAMS_PERIODMS_MINPRO_MAXPRO;

    for (unsigned ix = 0; ix < CONFIG_NUM_SOFTBLIKER_LEDS; ix++) {
        if_softblinker[ix].set_LED_period_ms       (params_periodms_minpro_maxpro[ix][0]);
        if_softblinker[ix].set_LED_intensity_range (params_periodms_minpro_maxpro[ix][1], params_periodms_minpro_maxpro[ix][2]);
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
