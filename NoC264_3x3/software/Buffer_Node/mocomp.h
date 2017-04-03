#ifndef __MOCOMP_H__
#define __MOCOMP_H__

#include "common.h"
#include "mode_pred.h"

void MotionCompensateTB(frame *this, frame *ref, int org_x, int org_y,
                        int mvx, int mvy);

void MotionCompensateMB(frame *this, frame *ref, mode_pred_info *mpi,
                        int org_x, int org_y);

void MotionCompensateMB_2(frame *this,
		                  frame *ref,
                          int mvx[16],
						  int mvy[16],
                          int org_x,
                          int org_y
                          );


#endif /*__MOCOMP_H__*/
