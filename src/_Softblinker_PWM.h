/*
 * _Softblinker_PWM.h
 *
 *  Created on: 28. juni 2020
 *      Author: teig
 */


#ifndef SOFTBLINKER_PWM_H_

    #if (CONFIG_NUM_SOFTBLIKER_LEDS==2)
        #define LED_START_DARK_FULL {dark_LED, full_LED} // of start_LED_at_e with CONFIG_NUM_SOFTBLIKER_LEDS elements
        #define LED_START_DARK_DARK {dark_LED, dark_LED} // --"--
    #elif (CONFIG_NUM_SOFTBLIKER_LEDS==1)
        #define LED_START_DARK_FULL {dark_LED} // of start_LED_at_e with CONFIG_NUM_SOFTBLIKER_LEDS elements
        #define LED_START_DARK_DARK {full_LED} // --"--
    #endif

    #define IOF_YELLOW_LED 0 // To CONFIG_NUM_SOFTBLIKER_LEDS
    #define IOF_RED_LED    1 // To CONFIG_NUM_SOFTBLIKER_LEDS

    [[combinable]]
    void softblinker_pwm_button_client_task (
            server button_if      i_buttons_in[BUTTONS_NUM_CLIENTS],
            client softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS]);

#else
    #error Nested include _Softblinker_PWM.h
#endif /* SOFTBLINKER_PWM_H_ */
