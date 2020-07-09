/*
 * _Softblinker_PWM.h
 *
 *  Created on: 28. juni 2020
 *      Author: teig
 */


#ifndef SOFTBLINKER_PWM_H_
    //
    #define CONFIG_NUM_SOFTBLIKER_LEDS 2 // 2 2 2 2 2 2 2 1 1 2 (1=yellow_LED, 2+=red_LED)
    #define IOF_YELLOW_LED             0
    #define IOF_RED_LED                1
    #define CONFIG_NUM_TASKS_PER_LED   2 // 2 2 2 2 1 1 1 1 2 2
    #define CONFIG_PAR_ON_CORES        3 // 1 2 3 4 2 3 4 3 3 5                  8-cores  10-timers 32-chanends
                                         // #                   221: Constraints: C:  3    T:  3     C:  3      M:8432  S:1220  C:6368  D:844  (tile[0])
                                         //   #                 222: Constraints: C: 2     T: 2      C:  3      M:8160  S:1164  C:6160  D:836  (tile[0]) MY RUNNER UP
                                         //     #               223: Constraints: C:    5  T:    5   C:      7  M:7124  S:1128  C:5140  D:856  (tile[0])
                                         //       #             224: Constraints: C:1      T:1       C:0        M:7760  S:908   C:6068  D:784  (tile[0]) MY FAVOURITE
                                         //         #           212: Constraints: C: 2     T: 2      C:  3      M:7560  S:1036  C:5720  D:804  (tile[0])
                                         //           #         213: Constraints: C:  3    T:  3     C:   3     M:6812  S:1016  C:4984  D:812  (tile[0])
                                         //             #       214: Constraints: C:1      T:1       C:0        M:7216  S:828   C:5636  D:752  (tile[0])
                                         //               #     113: Constraints: C: 2     T: 2      C:  2      M:6468  S:832   C:4868  D:768  (tile[0])
                                         //                 #   123: Constraints: C:  3    T:  3     C:    4    M:6636  S:888   C:4956  D:792  (tile[0])
                                         //                   # 225: Constraints: C:    5  T:    5   C:       7 M:7120  S:1124  C:5140  D:856  (tile[0])

    // First param minimum is SOFTBLINK_PERIOD_MIN_MS
    #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
        #define PARAMS_PERIODMS_MINPRO_MAXPRO {{8000,10,80}}             // period_ms, min_percentage, max_percentage
    #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
        #define PARAMS_PERIODMS_MINPRO_MAXPRO {{1000,0,100},{6000,0,100}} // period_ms, min_percentage, max_percentage times CONFIG_NUM_SOFTBLIKER_LEDS
        //                                      200                       // 5 blinks per second
        //                                          0,15                     0,10 not visible when light room, 0,15 barely visible, 0,20 quite visible
    #endif

    [[combinable]]
    void softblinker_pwm_button_client_task (
            server button_if      i_buttons_in[BUTTONS_NUM_CLIENTS],
            client softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS]);

#else
    #error Nested include _Softblinker_PWM.h
#endif /* SOFTBLINKER_PWM_H_ */
