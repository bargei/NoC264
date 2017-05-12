#ifndef __INTRA_PRED_H__
#define __INTRA_PRED_H__

#include "common.h"
#include <inttypes.h>

void rx_intra_packet(uint32_t identifier, frame *f, int bx, int by, int type);
uint32_t send_luma_intra_packet_2(int size, frame *f, int bx, int by, int blkIdx_test, uint64_t intra_request, int identifier);
void Intra_Chroma_Dispatch_2(frame *f, int mode, int x, int y, uint32_t x_avail, uint32_t y_avail);




#define TYPE_LUMA 0
#define TYPE_CB   1
#define TYPE_CR   2

#endif /*__INTRA_PRED_H__*/
