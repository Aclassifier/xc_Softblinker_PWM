/*
 * _notes.h
 *
 *  Created on: 1. juli 2020
 *      Author: teig
 */

/*
 221: Constraints: C: 3 T: 3 C: 3 M:8472 S:1236 C:6392 D:844 (tile[0])
 212: Constraints: C: 2 T: 2 C: 3 M:7560 S:1036 C:5720 D:804 (tile[0])
 222: Constraints: C: 2 T: 2 C: 3 M:8200 S:1180 C:6184 D:836 (tile[0]) MY RUNNER UP
 223: Constraints: C: 5 T: 5 C: 7 M:7124 S:1128 C:5136 D:860 (tile[0])
 213: Constraints: C: 3 T: 3 C: 3 M:6812 S:1016 C:4984 D:812 (tile[0])
 113: Constraints: C: 2 T: 2 C: 2 M:6468 S:832 C:4868 D:768 (tile[0])
 224: Constraints: C:1 T:1 C:0 M:7800 S:924 C:6092 D:784 (tile[0]) MY FAVOURITE
 214: Constraints: C:1 T:1 C:0 M:7216 S:828 C:5636 D:752 (tile[0])
 */

#ifndef NOTES_H_
#define NOTES_H_*

// 221 from main.xc

par {
    on tile[0]: {
        [[combine]]
        par {
            Softblinker_pwm_button_client_task (if_buttons, if_softblinker);
            Button_Task (IOF_BUTTON_LEFT, inP_button_left, if_buttons[IOF_BUTTON_LEFT]);
            Button_Task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]);
            Button_Task (IOF_BUTTON_RIGHT, inP_button_right, if_buttons[IOF_BUTTON_RIGHT]); // [[combinable]]
        }
    }
    par {
        on tile[0].core[6]: pwm_for_LED_task (if_pwm[0], yellow_LED);
        on tile[0].core[6]: softblinker_task (if_pwm[0], if_softblinker[0]);
        on tile[0].core[7]: pwm_for_LED_task (if_pwm[1], red_LED);
        on tile[0].core[7]: softblinker_task (if_pwm[1], if_softblinker[1]);
    }

// 221 from generated main.xi
    par {
        on tile[0]: {
            [[combine]]
            par {
                Softblinker_pwm_button_client_task (if_buttons, if_softblinker);
                Button_Task (0, inP_button_left, if_buttons[0]);
                Button_Task (1, inP_button_center, if_buttons[1]);
                Button_Task (2, inP_button_right, if_buttons[2]);
            }
        }
        par {
            on tile[0].core[6]: pwm_for_LED_task (if_pwm[0], outP1_external_yellow_led);
            on tile[0].core[6]: softblinker_task (if_pwm[0], if_softblinker[0]);
            on tile[0].core[7]: pwm_for_LED_task (if_pwm[1], outP1_external_red_led);
            on tile[0].core[7]: softblinker_task (if_pwm[1], if_softblinker[1]);
        }
    }

// 212
    par {
        on tile[0]: {
            [[combine]]
            par {
                Softblinker_pwm_button_client_task (if_buttons, if_softblinker);
                Button_Task (0, inP_button_left, if_buttons[0]);
                Button_Task (1, inP_button_center, if_buttons[1]);
                Button_Task (2, inP_button_right, if_buttons[2]);
            }
        }
        par {
            on tile[0].core[6]: softblinker_pwm_for_LED_task (if_softblinker[0], outP1_external_yellow_led);
            on tile[0].core[6]: softblinker_pwm_for_LED_task (if_softblinker[1], outP1_external_red_led);
        }
    }

// 223 from generated main.xi
    par {
        on tile[0]: {
            [[combine]]
            par {
                Softblinker_pwm_button_client_task (if_buttons, if_softblinker);

                Button_Task (0, inP_button_left, if_buttons[0]);
                Button_Task (1, inP_button_center, if_buttons[1]);
                Button_Task (2, inP_button_right, if_buttons[2]);
            }
        }
        par {
            on tile[0]: pwm_for_LED_task (if_pwm[0], outP1_external_yellow_led);
            on tile[0]: softblinker_task (if_pwm[0], if_softblinker[0]);
            on tile[0]: pwm_for_LED_task (if_pwm[1], outP1_external_red_led);
            on tile[0]: softblinker_task (if_pwm[1], if_softblinker[1]);
        }
    }

// 224 from generated main.xi
    par {
        on tile[0]: {
            [[combine]]
            par {
                Softblinker_pwm_button_client_task (if_buttons, if_softblinker);
                Button_Task (0, inP_button_left, if_buttons[0]);
                Button_Task (1, inP_button_center, if_buttons[1]);
                Button_Task (2, inP_button_right, if_buttons[2]);
                pwm_for_LED_task (if_pwm[0], outP1_external_yellow_led);
                softblinker_task (if_pwm[0], if_softblinker[0]);
                pwm_for_LED_task (if_pwm[1], outP1_external_red_led);
                softblinker_task (if_pwm[1], if_softblinker[1]);
            }
        }
    }

// 214 from generated main.xi
    par {
        on tile[0]: {
            [[combine]]
            par {
                Softblinker_pwm_button_client_task (if_buttons, if_softblinker);
                Button_Task (0, inP_button_left, if_buttons[0]);
                Button_Task (1, inP_button_center, if_buttons[1]);
                Button_Task (2, inP_button_right, if_buttons[2]);
                softblinker_pwm_for_LED_task (if_softblinker[0], outP1_external_yellow_led);
                softblinker_pwm_for_LED_task (if_softblinker[1], outP1_external_red_led);
            }
        }
    }

#endif /* NOTES_H_ */
