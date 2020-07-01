/*
 * _Softblinker_PWM.h
 *
 *  Created on: 28. juni 2020
 *      Author: teig
 */


#ifndef SOFTBLINKER_PWM_H_
    //
    #define CONFIG_NUM_SOFTBLIKER_LEDS 2 // 2 2 2 2 2 1 2 2 (1=yellow_LED, 2+=red_LED)
    #define CONFIG_NUM_TASKS_PER_LED   2 // 2 1 2 2 1 1 2 1
    #define CONFIG_PAR_ON_CORES        1 // 1 2 2 3 3 3 4 4                   8-cores  10-timers 32-chanends
                                         // #               221: Constraints: C:  3    T:  3     C:  3      M:8472  S:1236  C:6392  D:844  (tile[0])
                                         //   #             212: Constraints: C: 2     T: 2      C:  3      M:7560  S:1036  C:5720  D:804  (tile[0])
                                         //     #           222: Constraints: C: 2     T: 2      C:  3      M:8200  S:1180  C:6184  D:836  (tile[0]) MY RUNNER UP
                                         //       #         223: Constraints: C:    5  T:    5   C:      7  M:7124  S:1128  C:5136  D:860  (tile[0])
                                         //         #       213: Constraints: C:  3    T:  3     C:   3     M:6812  S:1016  C:4984  D:812  (tile[0])
                                         //           #     113: Constraints: C: 2     T: 2      C:  2      M:6468  S:832   C:4868  D:768  (tile[0])
                                         //             #   224: Constraints: C:1      T:1       C:0        M:7800  S:924   C:6092  D:784  (tile[0]) MY FAVOURITE
                                         //               # 214: Constraints: C:1      T:1       C:0        M:7216  S:828   C:5636  D:752  (tile[0])

    #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
        #define PARAMS_ONEPERCENTMILLIS_MAXPRO_MINPRO {{40,80,10}}
    #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
        #define PARAMS_ONEPERCENTMILLIS_MAXPRO_MINPRO {{40,80,10},{30,100,0}}
    #endif

    [[combinable]]
    void Softblinker_pwm_button_client_task (
            server button_if      i_buttons_in[BUTTONS_NUM_CLIENTS],
            client softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS]);

#else
    #error Nested include _Softblinker_PWM.h
#endif /* SOFTBLINKER_PWM_H_ */
