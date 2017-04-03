#include "common.h"
#include "noc_control.h"
#include <inttypes.h>

#ifndef DEBLOCKING_FILTER_HEADER
#define DEBLOCKING_FILTER_HEADER

int send_deblocking_packet(frame *this, int x_inc, int y_inc, int x_pos, int y_pos, uint8_t qp, uint8_t bS, uint8_t LCrCb);
void rx_deblocking_packet(int id, frame *this, int x_inc, int y_inc, int x_pos, int y_pos, int LCrCb);


#endif
