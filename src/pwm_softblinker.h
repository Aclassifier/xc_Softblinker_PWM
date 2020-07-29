/*
 * pwm_softblinker.h
 *
 *  Created on: 22. juni 2020
 *      Author: teig
 */

#ifndef PWM_SOFTBLINKER_H_
    #define PWM_SOFTBLINKER_H_

    typedef unsigned                                  percentage_t; // [0..100]
    typedef enum {scan_none, scan_continuous}         scan_type_e;
    typedef enum {active_high, active_low}            port_pin_sign_e; // Must be {0,1} like this! Use of XOR is dependent on it!
    typedef enum {continuous_LED, dark_LED, full_LED} start_LED_at_e;

    typedef enum {
        slide_transition_pwm, // PWM pulses will slide with respect to period pulse like yellow_DIRCHANGE
        lock_transition_pwm   // PWM pulses are locked --"--
    } transition_pwm_e;

                                           // PWM=005 flickering is because 100 intensity levels are not enough!
    #define SOFTBLINK_DEFAULT_PERIOD_MS 30 // 30 ms goes to 100 in 3.0 seconds, when this is the timing. 10 makes no difference
                                           // ##
    #define PWM_ONE_PERCENT_US 100         // 30  100 ->  10 pulses per 0_TO_100 ( 10 NEW percentage steps): flickers at low intensity. Not nice
                                           // 30   50  -> 20 pulses per 0-TO_100 ( 20 NEW percentage steps): flickers som at low intensity. Borderline
                                           // 30   25  -> 40 pulses per 0-TO_100 ( 40 NEW percentage steps): flickers som at low intensity. Better
                                           // 30   10 -> 100 pulses per 0_TO_100 (100 NEW percentage steps): no flickering at low intensity. OK

    #define SOFTBLINK_DEFAULT_MIN_PERCENTAGE   0
    #define SOFTBLINK_DEFAULT_MAX_PERCENTAGE 100

    #define PWM_ONE_PERCENT_TICS \
       (PWM_ONE_PERCENT_US * XS1_TIMER_MHZ) // 100 us 1% on is a pulse of 100 us every 10 ms 100 Hz
    // ####
    // #### AMUX=002 analysis:
    // #### Observe that the number of timeouts ....... _DOES_ .. depend on this value (but the XCORE is "made for" this)
    // 1000 us 1% on is a pulse of   1 ms every 100 ms  10  Hz shows on/off that's going between the two percentages, softblink is completely gone
    //  500 us 1% on is a pulse of 500 us every  50 ms  20  Hz shows visible blink when I move the box or my head,    softblink is gone
    //  300 us 1% on is a pulse of 300 us every  30 ms  33  Hz shows visible blink when I move the box or my head,    fair softblink
    //  200 us 1% on is a pulse of 200 us every  20 ms  50  Hz works fine, no blinking, some effect when box moves,   ok softblink
    //  100 us 1% on is a pulse of 100 us every  10 ms 100  Hz works fine, no blinking,                               perfect softblink
    //   10 us 1% on is a pulse of  10 us every  1 ms    1 kHz works fine, no blinking,                               perfect softblink

    #define SOFTBLINK_PERIOD_MIN_MS   200 //   200 ms (5 blinks per second (100% up and 100% down in 1ms resolution))
    #define SOFTBLINK_PERIOD_MAX_MS 10000 // 10000 ms

    typedef interface softblinker_if {
        //  FULLY
        void set_LED_intensity_range (              // ON  OFF (opposite if port_pin_sign_e set opposite)
                const percentage_t min_percentage,  // 100   0     [0..100] = [SOFTBLINK_DEFAULT_MIN_PERCENTAGE..SOFTBLINK_DEFAULT_MAX_PERCENTAGE]
                const percentage_t max_percentage); // 100   0     [0..100] = [SOFTBLINK_DEFAULT_MIN_PERCENTAGE..SOFTBLINK_DEFAULT_MAX_PERCENTAGE]

        void set_LED_period_linear_ms (
                const unsigned         period_ms, // [SOFTBLINK_PERIOD_MIN_MS..SOFTBLINK_PERIOD_MAX_MS] between two max or two min
                const start_LED_at_e   start_LED_at,
                const transition_pwm_e transition_pwm);

    } softblinker_if;

    // XMOS not raised TICKET (as of 23Jun2020): No matter how much I tweeaked the code, if this was set as
    // a parameter into any of the tasks in pwm_softblinker, I had to touch that file to have it recompiled
    // See code 0178, 0179, 0180, 0181
    #define PWM_PORT_PIN_SIGN active_high // active_low when LED pulled down from 3Vs
                                          // active_high when LED or LED strip drivedn by buffer transistor

    #define SET_LED_INTENSITY_CONTINUOUS_MODE 0

    typedef interface pwm_if {
        void set_LED_intensity (const percentage_t percentage, const transition_pwm_e transition_pwm); // [0..100] = [SOFTBLINK_DEFAULT_MIN_PERCENTAGE..SOFTBLINK_DEFAULT_MAX_PERCENTAGE]
    } pwm_if;

    #if (CONFIG_NUM_TASKS_PER_LED==2)

        [[combinable]]
        void softblinker_task (
                const unsigned        id_task, // For printing only
                client pwm_if         if_pwm,
                server softblinker_if if_softblinker,
                out buffered port:1   out_port_toggle_on_direction_change); // Toggle when LED max

        // Only used when CONFIG_NUM_TASKS_PER_LED==2
        [[combinable]]
        void pwm_for_LED_task (
                const unsigned      id_task, // For printing only
                server pwm_if       if_pwm,
                out buffered port:1 out_port_LED);  // LED
    #endif

    #if (CONFIG_NUM_TASKS_PER_LED==1)
        [[combinable]]
        void softblinker_pwm_for_LED_task (
                const unsigned        id_task, // For printing only
                server softblinker_if if_softblinker,
                out buffered port:1   out_port_LED,  // LED
                out buffered port:1   out_port_toggle_on_direction_change); // Toggle when LED max
    #endif

#else
    #error Nested include PWM_SOFTBLINKER_H_
#endif /* PWM_SOFTBLINKER_H_ */
