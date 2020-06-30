/*
 * _Softblinker_PWM.h
 *
 *  Created on: 28. juni 2020
 *      Author: teig
 */


#ifndef SOFTBLINKER_PWM_H_

    #define SOFTBLINKER_SOFTBLINKER_PWM_NUM_CLIENTS 2

    #if (SOFTBLINKER_SOFTBLINKER_PWM_NUM_CLIENTS==1)
        #define PARAMS_ONEPERCENTMILLIS_MAXPRO_MINPRO {{40,80,10}}
    #elif (SOFTBLINKER_SOFTBLINKER_PWM_NUM_CLIENTS==2)
        #define PARAMS_ONEPERCENTMILLIS_MAXPRO_MINPRO {{40,80,10},{30,100,0}}
    #endif

    [[combinable]]
    void Softblinker_pwm_button_client_task (
            server button_if      i_buttons_in[BUTTONS_NUM_CLIENTS],
            client softblinker_if if_softblinker[SOFTBLINKER_SOFTBLINKER_PWM_NUM_CLIENTS]);

#else
    #error Nested include _Softblinker_PWM.h
#endif /* SOFTBLINKER_PWM_H_ */
