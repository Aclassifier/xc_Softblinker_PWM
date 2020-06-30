/*
 * maths.xc
 *
 *  Created on: 13. juni 2020
 *      Author: teig
 */

#include <platform.h> // core
#include <stdio.h>    // printf
#include <timer.h>    // delay_milliseconds(..), XS1_TIMER_HZ etc
#include <stdint.h>   // uint8_t
#include <iso646.h>   // readability

#include "_globals.h"

/*
 * IN RANGE CODE
 */
// FIRST SOME RESEARCH, FOR NEGATIVE VALUES:
//
// RANGE [0..-5]
// in_range
/*
#define MAX_DB (0)
#define MIN_DB (-5)
signed value =2;
for (unsigned index = 0; index < 10; index++) {
   debug_print ("%d ", value);
   if (value > MAX_DB) {
        debug_print ("%s","> MAX_DB " );
   } else if (value < MIN_DB){
       debug_print ("%s","< MIN_DB " );
   } else {
       debug_print ("%s","in range " );
   }
   debug_print (" [%d]%s",in_range_int8(value, MIN_DB, MAX_DB), "\n" );
   value--;
}
*/
// 2 > MAX_DB  [0]
// 1 > MAX_DB  [0]
// 0 in range  [0]
// -1 in range  [-1]
// -2 in range  [-2]
// -3 in range  [-3]
// -4 in range  [-4]
// -5 in range  [-5]
// -6 < MIN_DB  [-5]
// -7 < MIN_DB  [-5]

int8_t in_range_int8 ( const int8_t value, const int8_t lowest, const int8_t highest) {

    int8_t return_in_range_int8;

    if (value > highest) {
        return_in_range_int8 = highest;
    } else if (value < lowest) {
        return_in_range_int8 = lowest;
    } else {
        return_in_range_int8 = value;
    }
    return return_in_range_int8;
}

{int8_t, bool, bool} in_range_int8_min_max_set (const int8_t value, const int8_t lowest, const int8_t highest) {

    int8_t     return_in_range_int8;
    const bool return_min_set = (value < lowest);
    const bool return_max_set = (value > highest);

    if (return_max_set) {
        return_in_range_int8 = highest;
    } else if (return_min_set) {
        return_in_range_int8 = lowest;
    } else {
        return_in_range_int8 = value;
    }
    return {return_in_range_int8, return_min_set, return_max_set};
}

signed in_range_signed (const signed value, const signed lowest, const signed highest) {

    signed return_in_range;

    if (value > highest) {
        return_in_range = highest;
    } else if (value < lowest) {
        return_in_range = lowest;
    } else {
        return_in_range = value;
    }
    return return_in_range;
}

{signed, bool, bool} in_range_signed_min_max_set (const signed value, const signed lowest, const signed highest) {

    signed     return_in_range;
    const bool return_min_set = (value < lowest);
    const bool return_max_set = (value > highest);

    if (return_max_set) {
        return_in_range = highest;
    } else if (return_min_set) {
        return_in_range = lowest;
    } else {
        return_in_range = value;
    }
    return {return_in_range, return_min_set, return_max_set};
}
