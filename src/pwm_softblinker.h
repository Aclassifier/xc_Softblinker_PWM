/*
 * pwm_softblinker.h
 *
 *  Created on: 22. juni 2020
 *      Author: teig
 */

#ifndef PWM_SOFTBLINKER_H_
    #define PWM_SOFTBLINKER_H_


    typedef unsigned percentage_t; // [0..100]
    typedef enum {scan_none, scan_continuous} scan_type_e;
    typedef enum {active_high, active_low} port_pin_sign_e;

    typedef interface softblinker_if {              //  FULLY
        void set_sofblink_percentages (             // ON  OFF (oppostie if port_pin_sign_e set opposite)
                const percentage_t max_percentage,  // 100   0
                const percentage_t min_percentage); // 100   0
        void set_one_percent_ms (const unsigned ms);
    } softblinker_if;

    #define SOFTBLINK_DEFAULT_ONE_PERCENT_MS 30 // 30 ms goes to 100 in 3.0 seconds, when this is the timing:

    #define PWM_ONE_PERCENT_TICS \
       (100 * XS1_TIMER_MHZ)
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

    #define SOFTBLINK_DEFAULT_MAX_PERCENTAGE 100
    #define SOFTBLINK_DEFAULT_MIN_PERCENTAGE   0

    // XMOS not raised TICKET (as of 23Jun2020): No matter how much I tweeaked the code, if this was set as
    // a parameter into any of the tasks in pwm_softblinker, I had to touch that file to have it recompiled
    // See code 0178, 0179, 0180, 0181
    #define PWM_PORT_PIN_SIGN active_low // active_low/1  and 100,100 = LED ON
                                         // active_high/0 and 100,100 = LED OFF

    typedef interface pwm_if {
        void set_percentage (const percentage_t percentage);
    } pwm_if;

    // Only used when CONFIG_NUM_TASKS_PER_LED==2
    [[combinable]]
    void softblinker_task (
            client pwm_if         if_pwm,
            server softblinker_if if_softblinker);

    // Only used when CONFIG_NUM_TASKS_PER_LED==2
    [[combinable]]
    void pwm_for_LED_task (
            server pwm_if       if_pwm,
            out buffered port:1 outP1);

    // Only used when CONFIG_NUM_TASKS_PER_LED==1
    [[combinable]]
    void softblinker_pwm_for_LED_task (
            server softblinker_if if_softblinker,
            out buffered port:1   outP1);

#else
    #error Nested include PWM_SOFTBLINKER_H_
#endif /* PWM_SOFTBLINKER_H_ */
