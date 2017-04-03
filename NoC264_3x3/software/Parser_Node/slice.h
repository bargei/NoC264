#ifndef __SLICE_H__
#define __SLICE_H__

#include "params.h"
#include "nal.h"
#include "slicehdr.h"
#include "common.h"
#include "mode_pred.h"

int decode_slice_data(slice_header *sh,
                       seq_parameter_set *sps, pic_parameter_set *pps,
                       nal_unit *nalu,
                       frame *this, frame *ref,
                       mode_pred_info *mpi);

#endif /*__SLICE_H__*/
