/*
 * _version.h
 *
 *  Created on: 15. aug. 2018
 *      Author: teig
 */

#ifndef VERSION_H_
#define VERSION_H_

// SHOULD THE LENGTH OF THESE NEED TO CHANGE THEN THE STRING THEY ARE COPIED INTO MUST BE MODIFIED (MAY APPLY)
//
#define XTIMECOMPOSER_VERSION_STR "14.4.1"

#define AUDIOMUX_VERSION_STR "0.4.6" // Not used
#define AUDIOMUX_VERSION_NUM   0046  // Not used either

// 0046 14Aug2020          Now left button for long clears all state to init
// 0045 14Aug2020          state_red_LED_e new changed, half_range is now not taken into next state. Compiled as (222) plus CONFIG_BARRIER==2 (channels)
//                         Constraints: C:8/6 T:10/6 C:32/11 M:11096 S:1532 C:8600 D:964
// 0044 14Aug2020          outP_external_blue_led_high is new, it's on when synch_active
// 0043 13Aug2020          Now starting with 10 seconds period. Much nicer!
// 0042 13Aug2020          Have tested a lot, with scope, and needed to reset to synch_none as well. Should probably have a LED when synched
// 0041 13Aug2020          Flashed
// 0040 13Aug2020 PWM=009  IOF_BUTTON_CENTER handled at released_now, not pressed_now so that it's not taken before pressed_for_long
// 0039 13Aug2020 PWM=008  state_red_LED_steps_0012 now starts with SOFTBLINK_PERIOD_MAX_MS
// 0038 13Aug2020 PWM=007  reset long button red LED state done in a different state. Explained by state_red_LED_e
// 0036 12Aug2020          A beep-beep moved to correct state
// 0036 12Aug2020 PWM=006  reset long button red LED state done in a different state
// 0035 11Aug2020          After set_states_red_LED_to_default also resets to DEFAULT_INTENSITY_STEPS
// 0034 11Aug2020          PERIOD_MS_LIST now gives concrete period_ms values, better for control of te new beeper
// 0033 11Aug2020          init_params_t_instance is new. state_red_LED now seems to work
// 0032 11Aug2020          Last version with init of array of struct as
//                         const mystruct array[NUM] = {{0,1,200,3},{0,200,1,3}} since it's not safe
// 0031 10Aug2020          states_red_LED_t and handling. Not tested
// 0029 09Aug2020          synchronize and barrier_task works with CONFIG_BARRIER==2
// 0028 09Aug2020          CONFIG_BARRIER==2 this compiles with
//                         Constraints: C:8/6 T:10/6 C:32/11 M:9544 S:1404 C:7196 D:944
//                         warning: route(0)     Pass with 14 unknowns, Num Paths: 8, Slack: 208.0 ns, Required: 1.0 us, Worst: 792.0 ns, Min Core Frequency: 396 MHz
// 0027 09Aug2020          Working with softblinker_task and CONFIG_BARRIER==1. Becomes very complex, especially with state needed to avoid deadlock
//                         during on to off and allowing [[combinable]]. Not finished. Trying chan in next version
//                         Constraints: C:8/3 T:10/3 C:32/5 M:11336 S:1596 C:8764 D:976
// 0026 08Aug2020          Interesting: Error: select on notification within combinable function select case
// 0025 08Aug2020          Interesting: warning: `c_barrier' not used in two parallel statements (byte range 0..4) [-Wunusual-code]
//                         TODO: ON/OFF for the two LED are sliding somewhat
// 0024 02Aug2020          Frequency and period now seems to work
// 0023 01Aug2020          XTA_TEST_SET_LED_INTENSITY introduced
// 0022 01Aug2020          First version of PWM period introduced
//                         warning: route(0)     Pass with 14 unknowns, Num Paths: 7, Slack: 250.0 ns, Required: 1.0 us, Worst: 750.0 ns, Min Core Frequency: 375 MHz
// 0021 01Aug2020          Just a snapshot before introducing PWM period
// 0020 29Jul2020 PWM=005  My concept og percent ie 100 levels of intensity causes clickering at low levels!
//                         This version with LEFT_BUUTON presses increases intensity from 0 by 1% per press
//                         Each step is easily seen and it's got to show up as fliceking when soft-blinking soft
//                         I will rebuild to allow 1000 intensity steps in the next version
// 0019 28Jul2020          Better now
// 0018 28Jul2020 PWM=004  IOF_BUTTON_CENTER pressed and non of the others pressed now makes sense
// 0017 14Jul2020 PWM=003  Correct period so that 200.00 ms is 200.00 ms!
// 0016 14Jul2020          More experimenting with XTA in pwm_for_LED_task, just for the keeps
// 0015 13Jul2020          More experimenting with XTA in pwm_for_LED_task, just for the keeps
// 0014 13Jul2020          Experimenting with XTA in pwm_for_LED_task, just for the keeps
//                         set_LED_period_ms -> set_LED_period_linear_ms is a better name, to show that others are possible
//                         PORTS yellow_PERIOD and red_PERIOD for the scope are new
//                         ALLOW_REUSE_OF_ONBOARD_PORTS removed again. Made an 1-bit prt overview instead. See main.xc
// 0013 12Jul2020          ALLOW_REUSE_OF_ONBOARD_PORTS is new. Now using value 0. COMPILED WITH (228)
// 0012 10Jul2020          All xta:(xyz) analysis done with this version. COMPILED WITH (228)
// 0011 09Jul2020          toggle_LED_phase is new
// 0010 09Jul2020          Buttons are handled
//                         warning: route(0)     Pass with 14 unknowns, Num Paths: 12, Slack: 760.0 ns, Required: 1.0 us, Worst: 240.0 ns, Min Core Frequency: 120 MHz
// 0008 04Jul2020          Changed some names. These are much more descriptive: set_LED_intensity_range, set_LED_period_linear_ms and set_LED_intensity
// 0007 02Jul2020          First release at https://www.teigfam.net/oyvind/blog_notes/209/code/_softblinker_pwm.zip.
// 0006 01Jul2020          Only using in pwm_context_t and softblinker_context_t in softblinker_pwm_for_LED_task. Better readability
// 0005 01Jul2020 PWM=002  CONFIG_NUM_SOFTBLIKER_LEDS, CONFIG_NUM_TASKS_PER_LED, CONFIG_PAR_ON_CORES overview done. FANTASTIC!
// 0004 30Jun2020          softblinker_context_t and pwm_context_t work!!
// 0003 30Jun2020          Save before next, really
// 0002 28Jun2020 PWM=001  To get xflash to work:
//                         XCORE-200-EXPLORER.xn (xTIMEcomposer 14.4.1)
//                         See https://www.teigfam.net/oyvind/home/technology/098-my-xmos-notes/#ticket_xflash_1441_of_xcore-200_explorer_board_warnings
//                             <Device NodeId="0" Tile="0" Class="SQIFlash" Name="bootFlash" Type="S25LQ016B" PageSize="256" SectorSize="4096" NumPages="8192">
//                             replaced with
//                             <Device NodeId="0" Tile="0" Class="SQIFlash" Name="bootFlash" Type="S25LQ016B">
// 0001 28Jun2020          Initial

#endif /* VERSION_H_ */

