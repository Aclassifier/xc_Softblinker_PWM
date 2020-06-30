/*
 * _version.h
 *
 *  Created on: 15. aug. 2018
 *      Author: teig
 */

#ifndef VERSION_H_
#define VERSION_H_

// SHOULD THE LENGTH OF THESE NEED TO CHANGE THEN THE STRING THEY ARE COPIED INTO MUST BE MODIFIED
//
#define XTIMECOMPOSER_VERSION_STR "14.4.1"

#define AUDIOMUX_VERSION_STR "0.0.4"
#define AUDIOMUX_VERSION_NUM   0004

// 0004     30Jun2020           softblinker_context_t and pwm_context_t work!!
// 0003     30Jun2020           Save before next, really
// 0002     28Jun2020  PWM=001  To get xflash to work:
//                              XCORE-200-EXPLORER.xn (xTIMEcomposer 14.4.1)
//                              See https://www.teigfam.net/oyvind/home/technology/098-my-xmos-notes/#ticket_xflash_1441_of_xcore-200_explorer_board_warnings
//                                  <Device NodeId="0" Tile="0" Class="SQIFlash" Name="bootFlash" Type="S25LQ016B" PageSize="256" SectorSize="4096" NumPages="8192">
//                                  replaced with
//                                  <Device NodeId="0" Tile="0" Class="SQIFlash" Name="bootFlash" Type="S25LQ016B">
// 0001     28Jun2020           Initial

#endif /* VERSION_H_ */

