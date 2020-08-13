/*
 * _Softblinker_PWM.h
 *
 *  Created on: 28. juni 2020
 *      Author: teig
 */


#ifndef SOFTBLINKER_PWM_H_

    #define IOF_YELLOW_LED 0 // To CONFIG_NUM_SOFTBLIKER_LEDS
    #define IOF_RED_LED    1 // To CONFIG_NUM_SOFTBLIKER_LEDS

typedef enum {beep_off = 0, beep_now = 1} beep_high_e; // Must be {0,1} like this! Using boolean expression on it

    [[combinable]]
    void softblinker_pwm_button_client_task (
            server button_if      i_buttons_in[BUTTONS_NUM_CLIENTS],
            client softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS],
            out buffered port:1   outP1_beeper_high);

#else
    #error Nested include _Softblinker_PWM.h
#endif /* SOFTBLINKER_PWM_H_ */
