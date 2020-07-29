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

    // First param minimum is SOFTBLINK_PERIOD_MIN_MS

     #define MINPRO   0
     #define MAXPRO 100

    #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
        #define PARAMS_PERIODMS_MINPRO_MAXPRO {1000,MINPRO,MAXPRO}}                     // period_ms, min_percentage, max_percentage
    #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
        #define PARAMS_PERIODMS_MINPRO_MAXPRO {{200,MINPRO,MAXPRO},{200,MINPRO,MAXPRO}} // period_ms, min_percentage, max_percentage times CONFIG_NUM_SOFTBLIKER_LEDS
        //                                      200                                     // 5 blinks per second
        //                                          0,     15           0,     10 not visible when light room, 0,15 barely visible, 0,20 quite visible
        // {{1000,0,100},{1000,0,100}} 2.4us 0044.png init
        // {{ 800,0,100},{ 800,0,100}} 2.4us same
        // {{ 600,0,100},{ 600,0,100}} 2.4us same
        // {{ 600,0,100},{ 600,0,100}} 2.4us same
        // {{ 400,0,100},{ 400,0,100}} 2.4us same
        // {{ 200,0,100},{ 200,0,100}} 2.4us same
        // After right button up up and to 200 again then center to synschronize, back to 2.4us
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
