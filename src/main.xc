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

    #include "barrier.h"
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
    out buffered port:1 outP_d4_led      = on tile[0]: XS1_PORT_1F; // xCORE XA J1 D13 XCORE-XA-MODULE LED D4 (LOW IS ON)
    //
    in  buffered port:1 inP_button_left   = on tile[0]: XS1_PORT_1K; // External xCORE XA J9 P34. XCORE-XA-MODULE EXTERNAL BUTTON1
    in  buffered port:1 inP_button_center = on tile[0]: XS1_PORT_1O; // External xCORE XA J9 P38. XCORE-XA-MODULE EXTERNAL BUTTON2
    in  buffered port:1 inP_button_right  = on tile[0]: XS1_PORT_1P; // External xCORE XA J9 P39. XCORE-XA-MODULE EXTERNAL BUTTON3

    #define red_LED outP_d4_led

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


    // ALL TILE/SLICE-0 1-BIT PORTS ON THE XCORE-200-EXPLORER (4,8,16 and 32 bit ports, see manual)
    //                                                                                ### Availability remarks
    //                                                   on tile[0]: XS1_PORT_1A; // (*0) FLASH only, MISO
    //                                                   on tile[0]: XS1_PORT_1B; // (*0) FLASH only, CS
    //                                                   on tile[0]: XS1_PORT_1C; // (*0) FLASH only, CLK
    //                                                   on tile[0]: XS1_PORT_1D; // (*0) MOSI
    //                                                   on tile[0]: XS1_PORT_1E; // (*1) GPIO-J1.PIN39
    //                                                   on tile[0]: XS1_PORT_1F; // (*2) GPIO-J1.PIN37
    out buffered port:1 outP_external_yellow_led       = on tile[0]: XS1_PORT_1G; //      GPIO-J1.PIN35 LED 470R to 3V3. LOW IS ON
    out buffered port:1 outP_external_red_led          = on tile[0]: XS1_PORT_1H; //      GPIO-J1.PIN33 LED 470R to 3V3. LOW IS ON
    out buffered port:1 outP_external_yellow_dirchange = on tile[0]: XS1_PORT_1I; //      GPIO-J1.PIN23 Only for the scope!
    out buffered port:1 outP_external_red_dirchange    = on tile[0]: XS1_PORT_1J; //      GPIO-J1.PIN21 Only for the scope!
    //                                                   on tile[0]: XS1_PORT_1K; //      GPIO-J1.PIN19
    out buffered port:1 outP_external_blue_led_high    = on tile[0]: XS1_PORT_1L; //      GPIO-J1.PIN17 LED_high_e. 1k to blue LED
    in buffered port:1  inP_button_left                = on tile[0]: XS1_PORT_1M; // (*3) GPIO-J1.PIN63 (B1)
    in buffered port:1  inP_button_center              = on tile[0]: XS1_PORT_1N; // (*3) GPIO-J1.PIN61 (B3)
    in buffered port:1  inP_button_right               = on tile[0]: XS1_PORT_1O; //      GPIO-J1.PIN59 (B2)
    out buffered port:1 outP_beeper_high               = on tile[0]: XS1_PORT_1P; //      GPIO-J1.PIN57 beep_high_e Beeps when line is high 3V3. 310 uA and 1k in series
    //
    // (*0) SPI pins NOT avaiable on any header, reserved for system usage
    // (*1) and (*2)
    //      SCK and SDA for I2C use by on-board sensors. May be disconnected by removing R52 and R49 _underneath_ the board.
    //      But the BMG1160 3-axis gyroscope and the FXOS8700CQ 3D accelerometer plus magnetometer don't seem to care if I don't remove R52 and R49.
    //      Perhaps it's because I only wrote to the ports?
    // (*3) Open button 3V3 pull-up with 10k, pushed button takes that line via 1k to GND

    // ALL TILE/SLICE-1 1-BIT PORTS ON THE XCORE-200-EXPLORER (4,8,16 and 32 bit ports, see manual)
    //                                                                                 ### Availability remarks
    //                                                    on tile[1]: XS1_PORT_1A; //      GPIO-J3.PIN40
    //                                                    on tile[1]: XS1_PORT_1B; //      GPIO-J3.PIN42
    //                                                    on tile[1]: XS1_PORT_1C; // (*0) MDIO
    //                                                    on tile[0]: XS1_PORT_1D; // (*0) MDC
    //                                                    on tile[1]: XS1_PORT_1L; //      GPIO-J3.PIN2
    //                                                    on tile[1]: XS1_PORT_1M; // (*0) INT
    //                                                    on tile[0]: XS1_PORT_1D; // (*0) PHY_RSTn
    //                                                    on tile[1]: XS1_PORT_1O; //      GPIO-J3.PIN3
    //                                                    on tile[0]: XS1_PORT_1P; //      GPIO-J3.PIN6
    // (*0) Used by Ethernet RGMII for RJ45

    #define yellow_LED outP_external_yellow_led
    #define red_LED    outP_external_red_led

    #define yellow_DIRCHANGE outP_external_yellow_dirchange // period
    #define red_DIRCHANGE    outP_external_red_dirchange    // period

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

                        button_task (IOF_BUTTON_LEFT,   inP_button_left,   if_buttons[IOF_BUTTON_LEFT]);
                        button_task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]);
                        button_task (IOF_BUTTON_RIGHT,  inP_button_right,  if_buttons[IOF_BUTTON_RIGHT]);

                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            softblinker_pwm_for_LED_task (IOF_YELLOW_LED, if_softblinker[IOF_YELLOW_LED], yellow_LED, yellow_DIRCHANGE);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            // xta: (214) error: Failed to find route with id:
                            softblinker_pwm_for_LED_task (IOF_YELLOW_LED, if_softblinker[IOF_YELLOW_LED], yellow_LED, yellow_DIRCHANGE);
                            softblinker_pwm_for_LED_task (IOF_RED_LED,    if_softblinker[IOF_RED_LED],    red_LED,    red_DIRCHANGE);
                        #endif
                    }
                }
            #else
                on tile[0]: {
                    [[combine]]
                    par {
                        softblinker_pwm_button_client_task (if_buttons, if_softblinker);

                        button_task (IOF_BUTTON_LEFT,   inP_button_left,   if_buttons[IOF_BUTTON_LEFT]);
                        button_task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]);
                        button_task (IOF_BUTTON_RIGHT,  inP_button_right,  if_buttons[IOF_BUTTON_RIGHT]);
                    }
                }
                #if (CONFIG_PAR_ON_CORES==1)
                    #error USE CONFIG_PAR_ON_CORES==2
                #elif (CONFIG_PAR_ON_CORES==2)
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            on tile[0].core[6]: softblinker_pwm_for_LED_task (IOF_YELLOW_LED, if_softblinker[IOF_YELLOW_LED], yellow_LED, yellow_DIRCHANGE);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            // xta: (212) error: Failed to find route with id:
                            on tile[0].core[6]: softblinker_pwm_for_LED_task (IOF_YELLOW_LED, if_softblinker[IOF_YELLOW_LED], yellow_LED, yellow_DIRCHANGE);
                            on tile[0].core[6]: softblinker_pwm_for_LED_task (IOF_RED_LED,    if_softblinker[IOF_RED_LED],    red_LED,    red_DIRCHANGE);
                        #endif
                    }
                #elif (CONFIG_PAR_ON_CORES==3)
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            // xta: (113) warning: route(0)     Fail (timing violation) with 22 unknowns, Num Paths: 320, Violation: 40.0 ns, Required: 1.0 us, Worst: 1.0 us, Min Core Frequency: 520 MHz
                            on tile[0]: softblinker_pwm_for_LED_task (IOF_YELLOW_LED, if_softblinker[IOF_YELLOW_LED], yellow_LED, yellow_DIRCHANGE);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            // xta: (213) warning: route(0)     Pass with 22 unknowns, Num Paths: 320, Slack: 0.0 ns, Required: 1.0 us, Worst: 1.0 us, Min Core Frequency: 500 MHz
                            on tile[0]: softblinker_pwm_for_LED_task (IOF_YELLOW_LED, if_softblinker[IOF_YELLOW_LED], yellow_LED, yellow_DIRCHANGE);
                            on tile[0]: softblinker_pwm_for_LED_task (IOF_RED_LED,    if_softblinker[IOF_RED_LED],    red_LED,    red_DIRCHANGE);
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

        #if (CONFIG_BARRIER==1)
            barrier_do_if   if_do_barrier  [CONFIG_NUM_SOFTBLIKER_LEDS];
            barrier_done_if if_done_barrier[CONFIG_NUM_SOFTBLIKER_LEDS];
        #elif (CONFIG_BARRIER==2)
            chan c_barrier[CONFIG_NUM_SOFTBLIKER_LEDS];
        #endif

        par {
            #if (CONFIG_PAR_ON_CORES==5) // Almost the same as CONFIG_PAR_ON_CORES==3, but this is explicit
                on tile[0]: {
                    [[combine]]
                    par {
                        softblinker_pwm_button_client_task (if_buttons, if_softblinker);

                        button_task (IOF_BUTTON_LEFT,   inP_button_left,   if_buttons[IOF_BUTTON_LEFT]);
                        button_task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]);
                        button_task (IOF_BUTTON_RIGHT,  inP_button_right,  if_buttons[IOF_BUTTON_RIGHT]);
                    }
                }
                par { // Not [[combine]]
                    #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                        // xta: (125) warning: route(0)     Pass with 14 unknowns, Num Paths: 12, Slack: 750.0 ns, Required: 1.0 us, Worst: 250.0 ns, Min Core Frequency: 125 MHz
                        on tile[0].core[4]: pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                        on tile[0].core[5]: softblinker_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE);
                    #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                        // xta: (225) warning: route(0)     Pass with 14 unknowns, Num Paths: 12, Slack: 760.0 ns, Required: 1.0 us, Worst: 240.0 ns, Min Core Frequency: 120 MHz
                        on tile[0].core[4]: pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                        on tile[0].core[5]: softblinker_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE);
                        on tile[0].core[6]: pwm_for_LED_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    red_LED);
                        on tile[0].core[7]: softblinker_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    if_softblinker[IOF_RED_LED], red_DIRCHANGE);
                    #endif
                }
            #elif (CONFIG_PAR_ON_CORES==4)
                on tile[0]: {
                    [[combine]]
                    par {
                        softblinker_pwm_button_client_task (if_buttons, if_softblinker);

                        button_task (IOF_BUTTON_LEFT,   inP_button_left,   if_buttons[IOF_BUTTON_LEFT]);
                        button_task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]);
                        button_task (IOF_BUTTON_RIGHT,  inP_button_right,  if_buttons[IOF_BUTTON_RIGHT]);
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            // xta: (124) error: Failed to find route with id: -
                            pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                            softblinker_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            // xta: (224) error: Failed to find route with id:
                            pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                            softblinker_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE);
                            pwm_for_LED_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    red_LED);
                            softblinker_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    if_softblinker[IOF_RED_LED], red_DIRCHANGE);
                        #endif
                    }
                }
            #else
                #if (CONFIG_PAR_ON_CORES==8)
                    #if (CONFIG_BARRIER==1)

                        on tile[0]: {
                            [[combine]]
                            par {
                                // Not time-critical, sll share one core:
                                softblinker_pwm_button_client_task (if_buttons, if_softblinker, outP_beeper_high, outP_external_blue_led_high);

                                button_task (IOF_BUTTON_LEFT,   inP_button_left,   if_buttons[IOF_BUTTON_LEFT]);
                                button_task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]);
                                button_task (IOF_BUTTON_RIGHT,  inP_button_right,  if_buttons[IOF_BUTTON_RIGHT]);
                            }
                        }
                        on tile[0]: {
                            // [[combine]] error: `c_barrier' used between two combined tasks
                            [[combine]] // Ok when interface
                            par {
                                barrier_if_server_task      (if_do_barrier, if_done_barrier);
                                softblinker_task_if_barrier (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE, if_do_barrier [IOF_YELLOW_LED], if_done_barrier [IOF_YELLOW_LED]);
                                softblinker_task_if_barrier (IOF_RED_LED,    if_pwm[IOF_RED_LED],    if_softblinker[IOF_RED_LED],    red_DIRCHANGE,    if_do_barrier [IOF_RED_LED],    if_done_barrier [IOF_RED_LED]);
                            }
                        }
                    #elif (CONFIG_BARRIER==2)

                        on tile[0]: {
                            [[combine]]
                            par {
                                // Not time-critical, sll share one core:
                                softblinker_pwm_button_client_task (if_buttons, if_softblinker, outP_beeper_high, outP_external_blue_led_high);

                                button_task (IOF_BUTTON_LEFT,   inP_button_left,   if_buttons[IOF_BUTTON_LEFT]);
                                button_task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]);
                                button_task (IOF_BUTTON_RIGHT,  inP_button_right,  if_buttons[IOF_BUTTON_RIGHT]);
                            }
                        }
                        on tile[0]: {
                            // [[combine]] error: `c_barrier' used between two combined tasks
                            par {
                                barrier_donehan_task             (c_barrier);
                                softblinker_task_chan_barrier (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE, c_barrier [IOF_YELLOW_LED]);
                                softblinker_task_chan_barrier (IOF_RED_LED,    if_pwm[IOF_RED_LED],    if_softblinker[IOF_RED_LED],    red_DIRCHANGE,    c_barrier [IOF_RED_LED]);
                            }
                        }
                    #endif
                #else
                    on tile[0]: {
                        [[combine]]
                        par {
                            softblinker_pwm_button_client_task (if_buttons, if_softblinker);

                            button_task (IOF_BUTTON_LEFT,   inP_button_left,   if_buttons[IOF_BUTTON_LEFT]);
                            button_task (IOF_BUTTON_CENTER, inP_button_center, if_buttons[IOF_BUTTON_CENTER]);
                            button_task (IOF_BUTTON_RIGHT,  inP_button_right,  if_buttons[IOF_BUTTON_RIGHT]);
                        }
                    }
                #endif

                #if (CONFIG_PAR_ON_CORES==1)
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            // xta: (121) error: Failed to find route with id: -
                            on tile[0].core[6]: pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                            on tile[0].core[6]: softblinker_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            // xta: (221) error: Failed to find route with id:
                            on tile[0].core[6]: pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                            on tile[0].core[6]: softblinker_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE);
                            on tile[0].core[7]: pwm_for_LED_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    red_LED);
                            on tile[0].core[7]: softblinker_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    if_softblinker[IOF_RED_LED], red_DIRCHANGE);
                        #endif
                    }
                #elif (CONFIG_PAR_ON_CORES==2)
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            // xta: (122) error: Failed to find route with id: -
                            on tile[0].core[6]: pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                            on tile[0].core[6]: softblinker_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            // xta: (222) error: Failed to find route with id:
                            on tile[0].core[6]: pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                            on tile[0].core[6]: softblinker_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE);
                            on tile[0].core[6]: pwm_for_LED_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    red_LED);
                            on tile[0].core[6]: softblinker_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    if_softblinker[IOF_RED_LED], red_DIRCHANGE);
                        #endif
                    }
                #elif (CONFIG_PAR_ON_CORES==6)
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            // xta: (226) warning: route(0)     Pass with 14 unknowns, Num Paths: 12, Slack: 760.0 ns, Required: 1.0 us, Worst: 240.0 ns, Min Core Frequency: 120 MHz
                            on tile[0].core[4]: pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                            on tile[0].core[5]: softblinker_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE);
                            on tile[0].core[6]: pwm_for_LED_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    red_LED);
                            on tile[0].core[7]: softblinker_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    if_softblinker[IOF_RED_LED], red_DIRCHANGE);
                        #else
                            #error No such combination
                        #endif
                    }
                #elif (CONFIG_PAR_ON_CORES==7)
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            // xta: (227) warning: route(0)     Pass with 14 unknowns, Num Paths: 12, Slack: 760.0 ns, Required: 1.0 us, Worst: 240.0 ns, Min Core Frequency: 120 MHz
                            // Time-critical, one core each
                            on tile[0].core[5]: pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                            on tile[0].core[6]: pwm_for_LED_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    red_LED);
                            // Not time-critical, share a core:
                            on tile[0].core[7]: softblinker_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE);
                            on tile[0].core[7]: softblinker_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    if_softblinker[IOF_RED_LED], red_DIRCHANGE);
                        #else
                            #error No such combination
                        #endif
                    }
                #elif (CONFIG_PAR_ON_CORES==8)
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            // xta:(228) warning: route(0)     Pass with 14 unknowns, Num Paths: 12, Slack: 760.0 ns, Required: 1.0 us, Worst: 240.0 ns, Min Core Frequency: 120 MHz
                            // Time-critical, one core each (BEST?)
                            on tile[0].core[6]: pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                            on tile[0].core[7]: pwm_for_LED_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    red_LED);
                        #else
                            #error No such combination
                        #endif
                    }
                #elif (CONFIG_PAR_ON_CORES==3) // Almost the same as CONFIG_PAR_ON_CORES==5, but this is implicit
                    par { // replicated par not possible since neither port nor on tile or on port may be indexed
                        #if (CONFIG_NUM_SOFTBLIKER_LEDS==1)
                            // xta: (123) warning: route(0)     Pass with 14 unknowns, Num Paths: 12, Slack: 760.0 ns, Required: 1.0 us, Worst: 240.0 ns, Min Core Frequency: 120 MHz
                            on tile[0]: pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                            on tile[0]: softblinker_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE);
                        #elif (CONFIG_NUM_SOFTBLIKER_LEDS==2)
                            // xta: (223) warning: route(0)     Pass with 14 unknowns, Num Paths: 12, Slack: 760.0 ns, Required: 1.0 us, Worst: 240.0 ns, Min Core Frequency: 120 MHz
                            on tile[0]: pwm_for_LED_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], yellow_LED);
                            on tile[0]: softblinker_task (IOF_YELLOW_LED, if_pwm[IOF_YELLOW_LED], if_softblinker[IOF_YELLOW_LED], yellow_DIRCHANGE);
                            on tile[0]: pwm_for_LED_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    red_LED);
                            on tile[0]: softblinker_task (IOF_RED_LED,    if_pwm[IOF_RED_LED],    if_softblinker[IOF_RED_LED], red_DIRCHANGE);
                        #endif
                    }
                #endif
            #endif
        }

        return 0;
    }
#endif
