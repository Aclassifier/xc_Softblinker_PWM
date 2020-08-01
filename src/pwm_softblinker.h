/*
 * pwm_softblinker.h
 *
 *  Created on: 22. juni 2020
 *      Author: teig
 */

#ifndef PWM_SOFTBLINKER_H_
    #define PWM_SOFTBLINKER_H_

    #define NUM_INTENSITY_STEPS 5
    typedef enum { // ZEROES NOT COUNTED:
        steps_0010 =   10,
        steps_0100 =  100,
        steps_0255 =  255, // (*)
        steps_0500 =  500,
        steps_1000 = 1000
        // NUM_INTENSITY_STEPS (see above)
    } intensity_steps_e;

    // (*) Like 8-bit grayscale intensity or 8-bit for each of RGB for 24-bit pixels, or 8-bit alpha-channel transparence
    //     Even if a PWM "intensity" is not a continous current but pulse-width modulation

    #define INTENSITY_STEPS_LIST {steps_0010, steps_0100, steps_0255, steps_0500, steps_1000}

    #define DEFAULT_INTENSITY_STEPS     steps_1000
    #define DEFAULT_DARK_INTENSITY      0
    #define DEFAULT_FULL_INTENSITY      DEFAULT_INTENSITY_STEPS
    #define DEFAULT_SOFTBLINK_PERIOD_MS 200 // 5 blinks per second

    typedef unsigned intensity_t; // [DEFAULT_DARK_INTENSITY..intensity_steps_e]

    typedef enum {scan_none, scan_continuous}         scan_type_e;
    typedef enum {active_high, active_low}            port_pin_sign_e; // Must be {0,1} like this! Use of XOR is dependent on it!
    typedef enum {continuous_LED, dark_LED, full_LED} start_LED_at_e;

    typedef enum {
        slide_transition_pwm, // PWM pulses will slide with respect to period pulse like yellow_DIRCHANGE
        lock_transition_pwm   // PWM pulses are locked --"--
    } transition_pwm_e;

    #define SOFTBLINK_DEFAULT_PERIOD_MS 3 // So with steps_1000 it would take 3 seconds DARK_TO_FULL

    #define DEFAULT_PWM_FREQUENCY_HZ 222
    //                               222 Hz no flickering (Should cause no "unperceived neurological effects"). Same as aquarium
    //                               100 Hz quite nice
    //                                60 Hz show the effect quite well
    //                                30 Hz terrible

    #define SOFTBLINK_PERIOD_MIN_MS   200 // TODO replace with dark_LED  200 ms (5 blinks per second (100% up and 100% down in 1ms resolution))
    #define SOFTBLINK_PERIOD_MAX_MS 10000 // TODO replace with full_LED 10000 ms

    typedef interface softblinker_if {

        void set_LED_intensity_range (
                const intensity_steps_e intensity_steps,
                const intensity_t       min_intensity,
                const intensity_t       max_intensity);

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

        void set_LED_intensity (
                const unsigned          frequency_Hz,
                const intensity_steps_e intensity_steps,
                const intensity_t       intensity, // Normalised to intensity_steps (allways ON when intensity == intensity_steps)
                const transition_pwm_e  transition_pwm);
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
