#ifndef __INTRA_PRED_H__
#define __INTRA_PRED_H__

#include "common.h"
#include "mode_pred.h"
#include <inttypes.h>

void Intra_4x4_Dispatch(frame *f, mode_pred_info *mpi, int x, int y, int luma4x4BlkIdx);
void Intra_16x16_Dispatch(frame *f, mode_pred_info *mpi, int mode, int x, int y, int constrained_intra_pred);
void Intra_Chroma_Dispatch(frame *f, mode_pred_info *mpi, int mode, int x, int y, int constrained_intra_pred);

uint32_t pack_luma_x(frame *f, int bx, int by, int x, int y);
uint32_t pack_luma_y(frame *f, int bx, int by, int x, int y);
uint32_t pack_cr_x(frame *f, int bx, int by, int x, int y);
uint32_t pack_cr_y(frame *f, int bx, int by, int x, int y);
uint32_t pack_cb_x(frame *f, int bx, int by, int x, int y);
uint32_t pack_cb_y(frame *f, int bx, int by, int x, int y);
void rx_intra_packet(uint32_t identifier, frame *f, int bx, int by, int type);
uint32_t send_luma_intra_packet_2(int size, frame *f, int bx, int by, int blkIdx_test, uint64_t intra_request, int identifier);
void Intra_Chroma_Dispatch_2(frame *f, int mode, int x, int y, uint32_t x_avail, uint32_t y_avail);




#define TYPE_LUMA 0
#define TYPE_CB   1
#define TYPE_CR   2

#endif /*__INTRA_PRED_H__*/
