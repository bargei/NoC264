#ifndef __CORETRANS_H__
#define __CORETRANS_H__

#include "common.h"

typedef struct _core_block {
  int items[16];
} core_block;

#define CoreBlock(b,i,j) (b).items[(j)|((i)<<2)]


#define IntraRoundingMode  3
#define InterRoundingMode  6

#define inverse_core_transform inverse_core_transform_fast

core_block forward_core_transform(core_block original);
core_block forward_quantize(core_block raw, int quantizer, int rounding_mode);
core_block inverse_quantize(core_block quantized, int quantizer, int without_dc);
core_block inverse_core_transform_slow(core_block coeff);
core_block inverse_core_transform_fast(core_block coeff);
core_block hadamard(core_block coeff);

void direct_ict(core_block coeff, unsigned char *img, int pitch, int *test);

void _dump_core_block(core_block block);

#endif /*__CORETRANS_H__*/
