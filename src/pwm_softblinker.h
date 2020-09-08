/*
 * pwm_softblinker.h
 *
 *  Created on: 22. juni 2020
 *      Author: teig
 */

#ifndef PWM_SOFTBLINKER_H_
    #define PWM_SOFTBLINKER_H_

    typedef enum {  // Div by 4 ok  // Including zero
        steps_0012          =   12, //   13 values
        steps_0100          =  100, //  101 values
        steps_0256          =  256, //  257 values (*)
        steps_1000          = 1000, // 1001 values
        NUM_INTENSITY_STEPS = 4 // Those above
    } intensity_steps_e;

    // (*) Almost like 8-bit grayscale intensity or 8-bit for each of RGB for 24-bit pixels, or 8-bit alpha-channel transparence
    //     Even if a PWM "intensity" is not a continous current but pulse-width modulation
    //     0..256 gives 257 values, but I use it because 256 division by 4 is possible

    #define INTENSITY_STEPS_LIST       {steps_0012, steps_0100, steps_0256, steps_1000}

    #define NUM_INTENSITY_STEPS_SHORT (NUM_INTENSITY_STEPS-1)
    #define INTENSITY_STEPS_LIST_SHORT {steps_0012, steps_0100, steps_0256} // NUM_INTENSITY_STEPS_SHORT

    #define DEFAULT_INTENSITY_STEPS     steps_1000
    #define DEFAULT_DARK_INTENSITY      0
    #define DEFAULT_FULL_INTENSITY      DEFAULT_INTENSITY_STEPS
    #define DEFAULT_SYNCH               synch_none // From "barrier.h"

    typedef unsigned intensity_t; // [DEFAULT_DARK_INTENSITY..intensity_steps_e]

    typedef enum {scan_none, scan_continuous}         scan_type_e;
    typedef enum {active_high = 0, active_low = 1}    port_pin_sign_e; // Must be {0,1} like this! Use of XOR is dependent on it!
    typedef enum {continuous_LED, dark_LED, full_LED} start_LED_at_e;
    typedef enum {is_anywhere, is_min, is_max}        extremals_e;

    typedef enum {
        slide_transition_pwm, // PWM pulses will slide with respect to period pulse like yellow_DIRCHANGE
        lock_transition_pwm   // PWM pulses are locked --"--
    } transition_pwm_e;

    #define DEFAULT_TRANSITION_PWM slide_transition_pwm

    #define DEFAULT_PWM_FREQUENCY_HZ 222
    //                               222 Hz no flickering (Should cause no "unperceived neurological effects"). Same as for my aquarium
    //                               100 Hz quite nice
    //                                60 Hz shows the effect quite well
    //                                30 Hz terrible

    #define SOFTBLINK_PERIOD_MIN_MS   (200) //   200 ms (5 blinks per second)
    #define SOFTBLINK_PERIOD_MAX_MS (10000) // 10000 ms

    #define DEFAULT_SOFTBLINK_PERIOD_MS SOFTBLINK_PERIOD_MAX_MS

    #define PERIOD_MS_LIST { \
                SOFTBLINK_PERIOD_MAX_MS,       /* 10000 */ \
                SOFTBLINK_PERIOD_MAX_MS / 2,   /*  5000 */ \
                SOFTBLINK_PERIOD_MAX_MS / 10,  /*  1000 */ \
                SOFTBLINK_PERIOD_MIN_MS * 2.5, /*   500 */ \
                SOFTBLINK_PERIOD_MIN_MS}       /*   200 */

    #define PERIOD_MS_LIST_LEN 5 // Above

    typedef interface softblinker_if {

        bool // max_intensity >= min_intensity
        set_LED_intensity_range ( // FIRST THIS..
                const unsigned          frequency_Hz,    // 0 -> actives port
                const intensity_steps_e intensity_steps, // [1..]
                const intensity_t       min_intensity,   // [0..x]
                const intensity_t       max_intensity);  // [x..intensity_steps_]

        void
        set_LED_period_linear_ms ( // ..THEN THIS
                const unsigned         period_ms, // (*)
                const start_LED_at_e   start_LED_at,
                const transition_pwm_e transition_pwm,
                const synch_e          do_multipart_synch);

        // (*) The period goes for any full DARK to FULL (INTENSITY STEPS) BUT IS NORMALISED TO ACTUAL RANGE!
        //     As the range is decreased, the time it takes to deliver out all port output decreases. Example:
        //     A full period of 20 seconds increases for 10 and decreases for 10 seconds. If it starts
        //     at 20% up and stops at 20% from the top its period is not longer 20 seconds, but 12 seconds.
        //     Following the same curve it would start 2 seconds later and reach the top 2 second earlier,
        //     taking 6 seconds to increase. Going down would also take 6 seconds. The sum = 12 seconds.
        //     We therefore normalise to set period

    } softblinker_if;

    // XMOS not raised TICKET (as of 23Jun2020): No matter how much I tweeaked the code, if this was set as
    // a parameter into any of the tasks in pwm_softblinker, I had to touch that file to have it recompiled
    // See code 0178, 0179, 0180, 0181
    #define PWM_PORT_PIN_SIGN active_high // active_low when LED pulled down from 3Vs
                                          // active_high when LED or LED strip drivedn by buffer transistor

    #define SET_LED_INTENSITY_CONTINUOUS_MODE 0

    typedef interface pwm_if {

        void set_LED_intensity (
                const unsigned          frequency_Hz, // 0 -> actives port
                const intensity_steps_e intensity_steps,
                const intensity_t       intensity,    // Normalised to intensity_steps (allways ON when intensity == intensity_steps)
                const transition_pwm_e  transition_pwm);
    } pwm_if;

    #define DO_PULSE_ON_START_SYNCH 1 // 0 or 1

    #if (CONFIG_NUM_TASKS_PER_LED==2)

        [[combinable]]
        void softblinker_task_chan_barrier (
                const id_task_t       id_task,
                client pwm_if         if_pwm,
                server softblinker_if if_softblinker,
                out buffered port:1   out_port_toggle_on_direction_change, // Toggle when LED max
                chanend               c_barrier);

        // Only used when CONFIG_NUM_TASKS_PER_LED==2
        // TODO This controls the DUTY CYCLE
        // TODO There is no deadband between the two LEDs, no period that removes overlap, not even when synchronized
        [[combinable]]
        void pwm_for_LED_task (
                const unsigned      id_task, // For printing only
                server pwm_if       if_pwm,
                out buffered port:1 out_port_LED);  // LED
    #endif

    #if (CONFIG_NUM_TASKS_PER_LED==1)
        [[combinable]]
        void softblinker_pwm_for_LED_task (
                const id_task_t       id_task, // For printing only
                server softblinker_if if_softblinker,
                out buffered port:1   out_port_LED,  // LED
                out buffered port:1   out_port_toggle_on_direction_change); // Toggle when LED max
    #endif

#else
    #error Nested include PWM_SOFTBLINKER_H_
#endif /* PWM_SOFTBLINKER_H_ */
