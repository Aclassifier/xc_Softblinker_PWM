/*
 * maths.h
 *
 *  Created on: 13. juni 2020
 *      Author: teig
 */


#ifndef MATHS_H_
#define MATHS_H_

int8_t in_range_int8   (const int8_t value, const int8_t lowest, const int8_t highest);
signed in_range_signed (const signed value, const signed lowest, const signed highest);

{   int8_t, // new value [lowest..highest]
    bool,   // min_set is true when one below lowest
    bool    // max_set is true when one above highest
} in_range_int8_min_max_set (const int8_t value, const int8_t lowest, const int8_t highest);

unsigned in_range_unsigned_inc_dec (const unsigned value, const unsigned lowest, const unsigned highest, const signed inc_dec_by);

{   signed, // new value [lowest..highest]
    bool,   // min_set is true when one below lowest
    bool    // max_set is true when one above highest
} in_range_signed_min_max_set (const signed value, const signed lowest, const signed highest);

#else
    #error Nested include MATHS_H_
#endif
