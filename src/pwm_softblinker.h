/*
 * pwm_softblinker.h
 *
 *  Created on: 22. juni 2020
 *      Author: teig
 */

#ifndef PWM_SOFTBLINKER_H_
    #define PWM_SOFTBLINKER_H_

    typedef unsigned                          percentage_t; // [0..100]
    typedef enum {scan_none, scan_continuous} scan_type_e;
    typedef enum {active_high, active_low}    port_pin_sign_e;

    typedef enum {cont, dark, full} LED_start_at_e;

    #define PERCENTAGE_US          1000                            // 1000
    #define PERCENTAGE_MS          (PERCENTAGE_US          / 1000) //    1
    #define PERCENTAGE_0_TO_100_MS (PERCENTAGE_MS          *  100) //  100
    #define PERIOD_MS              (PERCENTAGE_0_TO_100_MS *   2)  //  200 A period is * 2

    #define PWM_ONE_PERCENT_TICS \
       (100 * XS1_TIMER_MHZ)        // 100 us 1% on is a pulse of 100 us every 10 ms 100 Hz
    // ####
    // #### AMUX=002 analysis:
    // #### Observe that the number of timeouts ....... _DOES_ .. depend on this value (but the XCORE is "made for" this)
    // 1000 us 1% on is a pulse of   1 ms every 100 ms  10  Hz shows on/off that's going between the two percentages, softblink is completely gone
    //  500 us 1% on is a pulse of 500 us every  50 ms  20  Hz shows visible blink when I move the box or my head,    softblink is gone
    //  300 us 1% on is a pulse of 300 us every  30 ms  33  Hz shows visible blink when I move the box or my head,    fair softblink
    //  200 us 1% on is a pulse of 200 us every  20 ms  50  Hz works fine, no blinking, some effect when box moves,   ok softblink
    //  100 us 1% on is a pulse of 100 us every  10 ms 100  Hz works fine, no blinking,                               perfect softblink
    //   10 us 1% on is a pulse of  10 us every  1 ms    1 kHz works fine, no blinking,                               perfect softblink
    //   10 us I scoped this

    #define SOFTBLINK_PERIOD_MIN_MS (PERIOD_MS) // 200 ms = 5 blinks per second (100% up and 100% down in 1ms resolution)
    #define SOFTBLINK_PERIOD_MAX_MS  10000      // 10 seconds, not related to anything else than _MS

    typedef interface softblinker_if {
        //  FULLY
        void set_LED_intensity_range (              // ON  OFF (opposite if port_pin_sign_e set opposite)
                const percentage_t min_percentage,  // 100   0     [0..100] = [SOFTBLINK_DEFAULT_MIN_PERCENTAGE..SOFTBLINK_DEFAULT_MAX_PERCENTAGE]
                const percentage_t max_percentage); // 100   0     [0..100] = [SOFTBLINK_DEFAULT_MIN_PERCENTAGE..SOFTBLINK_DEFAULT_MAX_PERCENTAGE]

        void set_LED_period_linear_ms (
                const unsigned       period_ms, // [SOFTBLINK_PERIOD_MIN_MS..SOFTBLINK_PERIOD_MAX_MS] between two max or two min
                const LED_start_at_e LED_start_at);

    } softblinker_if;

    #define SOFTBLINK_DEFAULT_PERIOD_MS 30 // 30 ms goes to 100 in 3.0 seconds, when this is the timing:

    #define SOFTBLINK_DEFAULT_MIN_PERCENTAGE   0
    #define SOFTBLINK_DEFAULT_MAX_PERCENTAGE 100

    // XMOS not raised TICKET (as of 23Jun2020): No matter how much I tweeaked the code, if this was set as
    // a parameter into any of the tasks in pwm_softblinker, I had to touch that file to have it recompiled
    // See code 0178, 0179, 0180, 0181
    #define PWM_PORT_PIN_SIGN active_low // active_low/1  and 100,100 = LED ON
                                         // active_high/0 and 100,100 = LED OFF

#define XTA_001 0

    typedef interface pwm_if {
        void set_LED_intensity            (const percentage_t percentage); // [0..100] = [SOFTBLINK_DEFAULT_MIN_PERCENTAGE..SOFTBLINK_DEFAULT_MAX_PERCENTAGE]
        #if (XTA_001 == 1)
            void set_LED_intensity_allow_stop (const percentage_t percentage); // [0..100] = [SOFTBLINK_DEFAULT_MIN_PERCENTAGE..SOFTBLINK_DEFAULT_MAX_PERCENTAGE]
        #endif
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
