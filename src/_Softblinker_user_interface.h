/*
 * _Softblinker_PWM.h
 *
 *  Created on: 28. juni 2020
 *      Author: teig
 */


#ifndef SOFTBLINKER_PWM_H_

    #if !defined CONFIG_NUM_SOFTBLIKER_LEDS
        #error CONFIG_NUM_SOFTBLIKER_LEDS not defined
    #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
        #define IOF_LEFT_YELLOW_LED 0 // To CONFIG_NUM_SOFTBLIKER_LEDS
        #define IOF_RIGHT_RED_LED   1 // To CONFIG_NUM_SOFTBLIKER_LEDS
    #elif (CONFIG_NUM_SOFTBLIKER_LEDS==1)
        // Some value, to limit compiler errors
        #define IOF_LEFT_YELLOW_LED 0
        #define IOF_RIGHT_RED_LED   0
    #endif

    [[combinable]]
    void softblinker_user_interface_task (
            server button_if      i_buttons_in[BUTTONS_NUM_CLIENTS],
            client softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS],
            out buffered port:1   outP_beeper_high);

#else
    #error Nested include _Softblinker_PWM.h
#endif /* SOFTBLINKER_PWM_H_ */
