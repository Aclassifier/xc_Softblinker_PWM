/*
 * button_press.xc
 *
 *  Created on: 18. mars 2015
 *      Author: teig
 */
#define INCLUDES
#ifdef INCLUDES
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <iso646.h>
#include <xccompat.h> // REFERENCE_PARAM

#include "_version.h" // First this..
#include "_globals.h" // ..then this
#include "button_press.h"
#endif

#define DEBUG_PRINT_BUTTON_PRESS 0
#define debug_print(fmt, ...) do { if((DEBUG_PRINT_BUTTON_PRESS==1) and (DEBUG_PRINT_GLOBAL_APP==1)) printf(fmt, __VA_ARGS__); } while (0)


#define DEBOUNCE_TIMEOUT_50_MS 50

[[combinable]]
void button_task (
        const unsigned     button_n,
        in buffered port:1 p_button,
        client button_if   i_button_out // See http://www.teigfam.net/oyvind/home/technology/141-xc-is-c-plus-x/#the_combined_code_6_to_zero_channels
        )
{
    // From XMOS-Programming-Guide.
    int      current_val = BUTTON_PRESSED;
    bool     is_stable   = true;
    timer    tmr;
    time32_t timeout;
    time32_t current_time;

    // ¯yvind's matters:
    bool initial_released_stopped = false; // Since it would do BUTTON_ACTION_RELEASED always after start
    bool pressed_but_not_released = false;

    debug_print("inP_button_task[%u] started\n", button_n);

    while(1) {
        select {
            // If the button is "stable", react when the I/O pin changes value
            case is_stable => p_button when pinsneq(current_val) :> current_val: {
                if (current_val == BUTTON_PRESSED) {
                    debug_print(": Button %u pressed\n", button_n);
                } else {
                    debug_print(": Button %u released\n", button_n);
                }

                pressed_but_not_released = false;
                is_stable = false;

                tmr :> current_time;
                // Calculate time to event after debounce period
                // note that XS1_TIMER_HZ is defined in timer.h
                timeout = current_time + (DEBOUNCE_TIMEOUT_50_MS * XS1_TIMER_KHZ);
                // If the button is not stable (i.e. bouncing around) then select
                // when we the timer reaches the timeout to reenter a stable period
            } break;

            case (pressed_but_not_released or (is_stable == false)) => tmr when timerafter(timeout) :> void: {
                if (is_stable == false) {
                    if (current_val == BUTTON_PRESSED) {
                        initial_released_stopped = true; // Not if BUTTON_ACTION_PRESSED was sent first
                        pressed_but_not_released = true; // ONLY PLACE IT'S SET

                        i_button_out.button (BUTTON_ACTION_PRESSED); // Button down
                        debug_print(" BUTTON_ACTION_PRESSED %u sent\n", button_n);
                        tmr :> current_time;
                        timeout = current_time + (BUTTON_ACTION_PRESSED_FOR_LONG_TIMEOUT_MS * XS1_TIMER_KHZ);
                    } else {
                        if (initial_released_stopped == false) { // Also after BUTTON_ACTION_PRESSED_FOR_LONG
                            initial_released_stopped = true;
                            debug_print(" Button %u filtered away\n", button_n);
                        } else {
                            pressed_but_not_released = false;
                            i_button_out.button (BUTTON_ACTION_RELEASED);
                            debug_print(" BUTTON_ACTION_RELEASED %u sent\n", button_n);
                        }
                    }
                    is_stable = true;
                } else { // == pressed_but_not_released (is_stable == true, so pinsneq would have stopped it)
                    // xTIMEcomposer 14.2.4 works fine
                    // xTIMEcomposer 14.3.0 does 880997 times in 30 seconds with DEBUG_PRINT_BUTTON_PRESS==0, yields about 30000 per second probably livelocked (but printed in receiver)
                    pressed_but_not_released = false;
                    initial_released_stopped = false; // To avoid BUTTON_ACTION_RELEASED when it's released (RFM69=003)
                    i_button_out.button (BUTTON_ACTION_PRESSED_FOR_LONG);
                    debug_print(" BUTTON_ACTION_PRESSED_FOR_LONG %u sent\n", button_n);
                }
            } break;
        }
    }
}
