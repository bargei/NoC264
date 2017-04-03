#ifndef __SLICEHDR_H__
#define __SLICEHDR_H__

#include "params.h"
#include "nal.h"

#define  P_SLICE  0
#define  B_SLICE  1
#define  I_SLICE  2
#define SP_SLICE  3
#define SI_SLICE  4

typedef struct _slice_header {
  int first_mb_in_slice;
  int slice_type;
  int pic_parameter_set_id;
  int frame_num;
  int field_pic_flag;
  int MbaffFrameFlag;
  int PicHeightInMbs;
  int PicHeightInSamples;
  int PicSizeInMbs;
  int bottom_field_flag;
  int idr_pic_id;
  int pic_order_cnt_lsb;
  int delta_pic_order_cnt_bottom;
  int delta_pic_order_cnt[2];
  int redundant_pic_cnt;
  int direct_spatial_mv_pred_flag;
  int num_ref_idx_active_override_flag;
  int num_ref_idx_l0_active;
  int num_ref_idx_l1_active;
  int ref_pic_list_reordering_flag_l0;
  int ref_pic_list_reordering_flag_l1;
// <dec_ref_pic_marking>
  int no_output_of_prior_pics_flag;
  int long_term_reference_flag;
  int adaptive_ref_pic_marking_mode_flag;
// </dec_ref_pic_marking>
  int cabac_init_idc;
  int slice_qp_delta;
  int SliceQPy;
  int sp_for_switch_flag;
  int slice_qs_delta;
  int disable_deblocking_filter_idc;
  int slice_alpha_c0_offset_div2;
  int slice_beta_offset_div2;
  int slice_group_change_cycle;
} slice_header;

void decode_slice_header(slice_header *sh,
                         seq_parameter_set *sps,
                         pic_parameter_set *pps,
                         nal_unit *nalu);

char *_str_slice_type(int type);

#endif /*__SLICEHDR_H__*/
