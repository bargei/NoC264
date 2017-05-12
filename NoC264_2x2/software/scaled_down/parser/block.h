#ifndef __BLOCK_H__
#define __BLOCK_H__

#include "common.h"
#include "coretrans.h"
#include "noc_control.h"

void enter_luma_block(int *scan, frame *f, int x, int y, int qp, int without_dc);
void enter_chroma_block(int *scan, frame *f, int iCbCr, int x, int y, int qp, int without_dc);

void transform_luma_dc(int *scan, int *out, int qp);
void transform_chroma_dc(int *scan, int qp);
int send_iqit_request(int *scan, int qp, int without_dc, int LCbCr, int x, int y);
void rx_iqit_request(frame *f, int x, int y, int id, int LCbCr, int* test);
void send_iqit(int *scan, int x, int y, int qp, int without_dc, int LCbCr);
void rx_iqit_request_2(frame *f, packet the_packet);
core_block coeff_scan(int *scan);

#endif /*__BLOCK_H__*/
