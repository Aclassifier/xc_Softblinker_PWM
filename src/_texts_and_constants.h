/*
 * _texts_and_constants.h
 *
 *  Created on: 28. nov. 2016
 *      Author: teig
 */

#ifndef TEXTS_AND_CONSTANTS_H_
#define TEXTS_AND_CONSTANTS_H_

#define CHAR_UP_ARROW_STR      {CHAR_UP_ARROW,0}    // ‚Üë
#define CHAR_DOWN_ARROW_STR    {CHAR_DOWN_ARROW,0}  // ‚Üì
#define CHAR_RIGHT_ARROW_STR   {CHAR_RIGHT_ARROW,0} // →
#define CHAR_LEFT_ARROW_STR    {CHAR_LEFT_ARROW,0}  // ←
#define CHAR_SMILEY_STR        {CHAR_SMILEY,0}
#define CHAR_PLUS_MINUS_STR    {CHAR_PLUS_MINUS,0}  // ¬±
#define DEGC_CIRCLE_STR        {CHAR_CIRCLE,0}      // ¬∞
#define CHAR_AA_STR            {CHAR_AA,0}
#define CHAR_aa_STR            {CHAR_aa,0}
#define CHAR_OE_STR            {CHAR_OE,0}
#define CHAR_TRIPLE_BAR_STR    {CHAR_TRIPLE_BAR,0}  // ‚â°
#define CHAR_LEADING_SPACE_STR "        "

// ALL ..._LEN include terminating NUL (\0) CHAR! I try to call the others .._NUM etc. (NULL is used for void pointer)

#define GENERIC_DEGC_TEXT_LEN 5 // "25.0" with space for NUL
#define GENERIC_TEXT_DEGC          "??.?"
#define GENERIC_TEXT_NO_DATA_DEGC  "...."

#define INNER_TEMPERATURE_MAX_DEGC        99     // Think of it also as "undefined" (read not successful)
#define INNER_TEMPERATURE_MIN_DEGC        0
#define INNER_TEMPERATURE_DEGC_TEXT_LEN   GENERIC_DEGC_TEXT_LEN
#define INNER_TEMPERATURE_ERROR_TEXT      "Feil" // INNER_TEMPERATURE_DEGC_TEXT_LEN also includes NUL at the end
#define INNER_TEMPERATURE_OFFSET_DEGC_DP1 18     // 1.8 degC is 18 mV too high
                                                 // TC1047A data sheet says 25.0 degC is 730-770 mV with 750 mV nominal
                                                 // Observe that we also have subtracted OFFSET_ADC_INPUTS_STARTKIT

#define INNER_RR_12V_24V_MAX_VOLTS     99        // Think of it also as "undefined" (read not successful)
#define INNER_RR_12V_24V_MIN_VOLTS     0
#define INNER_RR_12V_24V_TEXT_LEN      5         // "12.0" with space for NUL
#define INNER_RR_12V_24V_ERROR_TEXT   "??.?"     // INNER_12V_24V_ERROR_TEXT also includes NUL at the end

#define SSD1306_TS1_LINE_CHAR_NUM     21 // ABCDEFGHIJKLMNOPQRSTU with TextSize 1 (small, 4 lines in the display)
#define SSD1306_TS1_LINE_NUMS          4
#define SSD1306_TS1_NEWLINE_CHARS_NUMS (SSD1306_TS1_LINE_NUMS-1) // 3
#define SSD1306_TS1_DISPLAY_VISIBLE_CHAR_NUM (SSD1306_TS1_LINE_CHAR_NUM * SSD1306_TS1_LINE_NUMS) // 84
#define SSD1306_TS2_DISPLAY_VISIBLE_CHAR_NUM (SSD1306_TS1_DISPLAY_VISIBLE_CHAR_NUM/2)
#define SSD1306_TS1_DISPLAY_VISIBLE_CHAR_LEN (SSD1306_TS1_DISPLAY_VISIBLE_CHAR_NUM + 1) // sprintf overflows flat out without space for NUL. But snprintf is too expensive (12.6KB)
                                                                                        // Filling "/n" in the string works, but it fills up one char position that's not visible. Rather use this:
#define SSD1306_TS1_DISPLAY_ALL_CHAR_LEN (SSD1306_TS1_DISPLAY_VISIBLE_CHAR_LEN + SSD1306_TS1_NEWLINE_CHARS_NUMS) // Spave for three "/n"

#define SSD1306_TS1_LINE_CHAR_NUM_TS2  10 // TextSize 2: "01234567890123456789" fills both lines
#define SSD1306_TS1_LINE_NUMS_TS2       2 // TextSize 2 has space for two lines

#define INNER_MAX_LUX         99 // Used for both "err" and max light (if max light then "ok==false" is not returned)
#define INNER_MIN_LUX         0
#define INNER_LUX_TEXT_LEN    3   // "12" with space for NUL
#define INNER_LUX_ERROR_TEXT "??" // INNER_RR_FLUX_ERROR_TEXT also includes NUL at the end

#define EXTERNAL_TEMPERATURE_MAX_ONETENTHDEGC 999    // 99.9 degC Think of it also as "undefined" (read not successful)
#define EXTERNAL_TEMPERATURE_MIN_ONETENTHDEGC 0      // Got below zero temp from chip
#define EXTERNAL_TEMPERATURE_DEGC_TEXT_LEN    GENERIC_DEGC_TEXT_LEN
#define EXTERNAL_TEMPERATURE_ERROR_TEXT       "Feil" // EXTERNAL_TEMPERATURE_DEGC_TEXT_LEN also includes NUL at the end

// Depending of now_regulating_at_t
#define REGULATING_AT_NUMS          8
#define REGULATING_AT_STRINGS_LENGTH 2 // One char plus NUL at the end
typedef char now_regulating_at_char_t [REGULATING_AT_NUMS][REGULATING_AT_STRINGS_LENGTH];
// ? REGULATING_AT_INIT
// 2 REGULATING_AT_BOILING
// 1 REGULATING_AT_SIMMERING
// = REGULATING_AT_TEMP_REACHED
// H REGULATING_AT_HOTTER_AMBIENT ("H" means "hot" for kitchen stoves, i.e. "Het" in Norwegian)
// - REGULATING_AT_MINUS
// 0 HEAT_CABLE_FORCED_OFF_BY_WATCHDOG
// ? HEAT_CABLE_ERROR
#define NOW_REGULATING_AT_CHAR_TEXTS {"#", "2", "1", "=", "H", "-", "0", "?"}

#else
    #error Nested include "_texts_and_constants.h"
#endif
