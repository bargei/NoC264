#ifndef __BLOCK_H__
#define __BLOCK_H__

#include "common.h"
#include "coretrans.h"
#include "noc_control.h"

void transform_luma_dc(int *scan, int *out, int qp);
void transform_chroma_dc(int *scan, int qp);
int send_iqit_request(int *scan, int qp, int without_dc, int LCbCr, int x, int y);
void send_iqit(int *scan, int x, int y, int qp, int without_dc, int LCbCr);
core_block coeff_scan(int *scan);

#endif /*__BLOCK_H__*/
