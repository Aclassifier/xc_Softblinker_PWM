/*
 * button_press.h
 *
 *  Created on: 18. mars 2015
 *      Author: teig
 */

#ifndef BUTTON_PRESS_H_
#define BUTTON_PRESS_H_

typedef enum {
    BUTTON_ACTION_VOID,
    BUTTON_ACTION_PRESSED,
    BUTTON_ACTION_PRESSED_FOR_LONG, // BUTTON_ACTION_PRESSED_FOR_LONG_TIMEOUT_MS
    BUTTON_ACTION_RELEASED          // Not after BUTTON_ACTION_PRESSED_FOR_LONG
} button_action_t;

typedef interface button_if {
    // caused the potentially recursive call to cause error from the linker:
    // Error: Meta information. Error: lower bound could not be calculated (function is recursive?).
    //
    //[[guarded]] void button (const button_action_t button_action); // timerafter-driven
    void button (const button_action_t button_action); // timerafter-driven

} button_if;

#define BUTTON_ACTION_PRESSED_FOR_LONG_TIMEOUT_MS 4000 // 20 seconds. Max 2exp31 = 2147483648 = 21.47483648 seconds (not one less)

#define IOF_BUTTON_LEFT   0
#define IOF_BUTTON_CENTER 1
#define IOF_BUTTON_RIGHT  2

#define BUTTONS_NUM_CLIENTS 3


typedef struct {
    bool pressed_now;           // Set by BUTTON_ACTION_PRESSED, cleared by BUTTON_ACTION_RELEASED
    bool pressed_for_long;      // Set by BUTTON_ACTION_PRESSED_FOR_LONG, cleared by BUTTON_ACTION_RELEASED
    bool inhibit_released_once; // Only IOF_BUTTON_RIGHT used, since it's the only that takes long pushes
} button_states_t;

[[combinable]]
void button_task (
        const unsigned     button_n,
        in buffered port:1 p_button,
        client button_if   if_button_out);

#else
    #error Nested include BUTTON_PRESS_H_
#endif
