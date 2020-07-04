/*
 * main.xc
 *
 *  Created on: 28. jun. 2020
 *      Author: teig
 */

#define INCLUDES
#ifdef INCLUDES
    #include <xs1.h>
    #include <platform.h> // slice
    #include <timer.h>    // delay_milliseconds(200), XS1_TIMER_HZ etc
    #include <stdint.h>   // uint8_t
    #include <stdio.h>    // printf
    #include <string.h>   // memcpy
    #include <xccompat.h> // REFERENCE_PARAM(my_app_ports_t, my_app_ports) -> my_app_ports_t &my_app_ports
    #include <iso646.h>   // not etc.

    #include "_version.h" // First this..
    #include "_globals.h" // ..then this

    #include "_texts_and_constants.h"
    #include "button_press.h"
    #include "pwm_softblinker.h"

    #include "_Softblinker_PWM.h"
#endif

#define DEBUG_PRINT_RFM69 1
#define debug_print(fmt, ...) do { if((DEBUG_PRINT_RFM69==1) and (DEBUG_PRINT_GLOBAL_APP==1)) printf(fmt, __VA_ARGS__); } while (0)

// Observe that I have no control of the ports during xTIMEcomposer downloading
// I have observed a 700-800 ms low on signal pins before my code starts

// ---
// 1 BIT PORT TARGET_XCORE-XA-MODULE
// ---

#if (IS_MYTARGET == IS_MYTARGET_XCORE_XA_MODULE)
    out buffered port:1 outP1_d4_led      = on tile[0]: XS1_PORT_1F; // xCORE XA J1 D13 XCORE-XA-MODULE LED D4 (LOW IS ON)
    //
    in  buffered port:1 inP_button_left   = on tile[0]: XS1_PORT_1K; // External xCORE XA J9 P34. XCORE-XA-MODULE EXTERNAL BUTTON1
    in  buffered port:1 in  P_button_center = on tile[0]: XS1_PORT_1O; // External xCORE XA J9 P38. XCORE-XA-MODULE EXTERNAL BUTTON2
    in  buffered port:1 inP_button_right  = on tile[0]: XS1_PORT_1P; // External xCORE XA J9 P39. XCORE-XA-MODULE EXTERNAL BUTTON3

    #define red_LED outP1_d4_led

#elif (IS_MYTARGET == IS_MYTARGET_XCORE_200_EXPLORER)

    out buffered port:4 outP4_rgb_leds = on tile[0]: XS1_PORT_4F; // xCORE-200 explorerKIT GPIO J1 P5, P3, P1. HIGH IS ON

    #define BOARD_LEDS_INIT           0x00
    #define BOARD_LED_MASK_GREEN_ONLY 0x01 // BIT0
    #define BOARD_LED_MASK_RGB_BLUE   0x02 // BIT1
    #define BOARD_LED_MASK_RGB_GREEN  0x04 // BIT2
    #define BOARD_LED_MASK_RGB_RED    0x08 // BIT3

    #define BOARD_LED_MASK_MAX_1 (BOARD_LED_MASK_GREEN_ONLY)
    #define BOARD_LED_MASK_MAX_2 (BOARD_LED_MASK_RGB_BLUE  bitor BOARD_LED_MASK_MAX_1)
    #define BOARD_LED_MASK_MAX_3 (BOARD_LED_MASK_RGB_GREEN bitor BOARD_LED_MASK_MAX_2)
    #define BOARD_LED_MASK_MAX_4 (BOARD_LED_MASK_RGB_RED   bitor BOARD_LED_MASK_MAX_3)

    #define BOARD_LED_MASK_MAX BOARD_LED_MASK_MAX_4 // _1, _2, _3 or _4

    in buffered port:1 inP_button_left   = on tile[0]: XS1_PORT_1M; // External GPIO-PIN63 With pull-up of 9.1k
    in buffered port:1 inP_button_center = on tile[0]: XS1_PORT_1N; // External GPIO-PIN61 With pull-up of 9.1k
    in buffered port:1 inP_button_right  = on tile[0]: XS1_PORT_1O; // External GPIO-PIN59 With pull-up of 9.1k

    out buffered port:1 outP1_external_red_led    = on tile[0]: XS1_PORT_1F; // External GPIO-PIN37 LED 470R to 3V3. LOW IS ON
    out buffered port:1 outP1_external_yellow_led = on tile[0]: XS1_PORT_1E; // External GPIO-PIN39 LED 470R to 3V3. LOW IS ON

    #define red_LED    outP1_external_red_led
    #define yellow_LED outP1_external_yellow_led
#endif


#if (CONFIG_NUM_TASKS_PER_LED==1)
    int main() {

        button_if      if_buttons    [BUTTONS_NUM_CLIENTS];
        softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS];

        par {
            #if (CONFIG_PAR_ON_CORES==4)
                on tile[0]: {
                    [[combine]]
                    par {
                        softblinker_pwm_button_client_task (if_buttons, if_softblinker);

                        button_task (IOF_BUTTON_LEFT,   inP_button_left,   if_buttons[IOF_BUTTON_LEFT]);   // [[combinable]]
                        button_task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]); // [[combinable]]
                        button_task (IOF_BUTTON_RIGHT,  inP_button_right,  if_buttons[IOF_BUTTON_RIGHT]);  // [[combinable]]

                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            softblinker_pwm_for_LED_task (if_softblinker[0], yellow_LED);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            softblinker_pwm_for_LED_task (if_softblinker[0], yellow_LED);
                            softblinker_pwm_for_LED_task (if_softblinker[1], red_LED);
                        #endif
                    }
                }
            #else
                on tile[0]: {
                    [[combine]]
                    par {
                        softblinker_pwm_button_client_task (if_buttons, if_softblinker);

                        button_task (IOF_BUTTON_LEFT,   inP_button_left,   if_buttons[IOF_BUTTON_LEFT]);   // [[combinable]]
                        button_task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]); // [[combinable]]
                        button_task (IOF_BUTTON_RIGHT,  inP_button_right,  if_buttons[IOF_BUTTON_RIGHT]);  // [[combinable]]
                    }
                }
                #if (CONFIG_PAR_ON_CORES==1)
                    #error USE CONFIG_PAR_ON_CORES==2
                #elif (CONFIG_PAR_ON_CORES==2)
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            on tile[0].core[6]: softblinker_pwm_for_LED_task (if_softblinker[0], yellow_LED);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            on tile[0].core[6]: softblinker_pwm_for_LED_task (if_softblinker[0], yellow_LED);
                            on tile[0].core[6]: softblinker_pwm_for_LED_task (if_softblinker[1], red_LED);
                        #endif
                    }
                #elif (CONFIG_PAR_ON_CORES==3)
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            on tile[0]: softblinker_pwm_for_LED_task (if_softblinker[0], yellow_LED);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            on tile[0]: softblinker_pwm_for_LED_task (if_softblinker[0], yellow_LED);
                            on tile[0]: softblinker_pwm_for_LED_task (if_softblinker[1], red_LED);
                        #endif
                    }
                #elif (CONFIG_PAR_ON_CORES==5)
                    #error not defined
                #endif
            #endif
        }

        return 0;
    }
#elif (CONFIG_NUM_TASKS_PER_LED==2)
    int main() {

        button_if      if_buttons    [BUTTONS_NUM_CLIENTS];
        pwm_if         if_pwm        [CONFIG_NUM_SOFTBLIKER_LEDS];
        softblinker_if if_softblinker[CONFIG_NUM_SOFTBLIKER_LEDS];

        par {
            #if (CONFIG_PAR_ON_CORES==5) // Almost the same as CONFIG_PAR_ON_CORES==3, but this is explicit
                on tile[0]: {
                    [[combine]]
                    par {
                        softblinker_pwm_button_client_task (if_buttons, if_softblinker);

                        button_task (IOF_BUTTON_LEFT,   inP_button_left,   if_buttons[IOF_BUTTON_LEFT]);   // [[combinable]]
                        button_task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]); // [[combinable]]
                        button_task (IOF_BUTTON_RIGHT,  inP_button_right,  if_buttons[IOF_BUTTON_RIGHT]);  // [[combinable]]
                    }
                }
                par { // Not [[combine]]
                    #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                        on tile[0].core[4]: pwm_for_LED_task (if_pwm[0], yellow_LED);
                        on tile[0].core[5]: softblinker_task (if_pwm[0], if_softblinker[0]);
                    #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                        on tile[0].core[4]: pwm_for_LED_task (if_pwm[0], yellow_LED);
                        on tile[0].core[5]: softblinker_task (if_pwm[0], if_softblinker[0]);
                        on tile[0].core[6]: pwm_for_LED_task (if_pwm[1], red_LED);
                        on tile[0].core[7]: softblinker_task (if_pwm[1], if_softblinker[1]);
                    #endif
                }
            #elif (CONFIG_PAR_ON_CORES==4)
                on tile[0]: {
                    [[combine]]
                    par {
                        softblinker_pwm_button_client_task (if_buttons, if_softblinker);

                        button_task (IOF_BUTTON_LEFT,   inP_button_left,   if_buttons[IOF_BUTTON_LEFT]);   // [[combinable]]
                        button_task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]); // [[combinable]]
                        button_task (IOF_BUTTON_RIGHT,  inP_button_right,  if_buttons[IOF_BUTTON_RIGHT]);  // [[combinable]]
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            pwm_for_LED_task (if_pwm[0], yellow_LED);
                            softblinker_task (if_pwm[0], if_softblinker[0]);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            pwm_for_LED_task (if_pwm[0], yellow_LED);
                            softblinker_task (if_pwm[0], if_softblinker[0]);
                            pwm_for_LED_task (if_pwm[1], red_LED);
                            softblinker_task (if_pwm[1], if_softblinker[1]);
                        #endif
                    }
                }
            #else
                on tile[0]: {
                    [[combine]]
                    par {
                        softblinker_pwm_button_client_task (if_buttons, if_softblinker);

                        button_task (IOF_BUTTON_LEFT,   inP_button_left,   if_buttons[IOF_BUTTON_LEFT]);   // [[combinable]]
                        button_task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]); // [[combinable]]
                        button_task (IOF_BUTTON_RIGHT,  inP_button_right,  if_buttons[IOF_BUTTON_RIGHT]);  // [[combinable]]
                    }
                }
                #if (CONFIG_PAR_ON_CORES==1)
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            on tile[0].core[6]: pwm_for_LED_task (if_pwm[0], yellow_LED);
                            on tile[0].core[6]: softblinker_task (if_pwm[0], if_softblinker[0]);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            on tile[0].core[6]: pwm_for_LED_task (if_pwm[0], yellow_LED);
                            on tile[0].core[6]: softblinker_task (if_pwm[0], if_softblinker[0]);
                            on tile[0].core[7]: pwm_for_LED_task (if_pwm[1], red_LED);
                            on tile[0].core[7]: softblinker_task (if_pwm[1], if_softblinker[1]);
                        #endif
                    }
                #elif (CONFIG_PAR_ON_CORES==2)
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            on tile[0].core[6]: pwm_for_LED_task (if_pwm[0], yellow_LED);
                            on tile[0].core[6]: softblinker_task (if_pwm[0], if_softblinker[0]);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            on tile[0].core[6]: pwm_for_LED_task (if_pwm[0], yellow_LED);
                            on tile[0].core[6]: softblinker_task (if_pwm[0], if_softblinker[0]);
                            on tile[0].core[6]: pwm_for_LED_task (if_pwm[1], red_LED);
                            on tile[0].core[6]: softblinker_task (if_pwm[1], if_softblinker[1]);
                        #endif
                    }
                #elif (CONFIG_PAR_ON_CORES==3) // Almost the same as CONFIG_PAR_ON_CORES==5, but this is implicit
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            on tile[0]: pwm_for_LED_task (if_pwm[0], yellow_LED);
                            on tile[0]: softblinker_task (if_pwm[0], if_softblinker[0]);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            on tile[0]: pwm_for_LED_task (if_pwm[0], yellow_LED);
                            on tile[0]: softblinker_task (if_pwm[0], if_softblinker[0]);
                            on tile[0]: pwm_for_LED_task (if_pwm[1], red_LED);
                            on tile[0]: softblinker_task (if_pwm[1], if_softblinker[1]);
                        #endif
                    }
                #endif
            #endif
        }

        return 0;
    }
#endif
