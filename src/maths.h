/*
 * maths.h
 *
 *  Created on: 13. juni 2020
 *      Author: teig
 */


#ifndef MATHS_H_
#define MATHS_H_

int8_t               in_range_int8               (const int8_t value, const int8_t lowest, const int8_t highest);
{int8_t, bool, bool} in_range_int8_min_max_set   (const int8_t value, const int8_t lowest, const int8_t highest);
signed               in_range_signed             (const signed value, const signed lowest, const signed highest);
{signed, bool, bool} in_range_signed_min_max_set (const signed value, const signed lowest, const signed highest);

#else
    #error Nested include MATHS_H_
#endif
