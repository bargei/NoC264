#include "common.h"
#include "input.h"
#include "nal.h"
#include "cavlc.h"
#include "params.h"

void decode_seq_parameter_set(seq_parameter_set *sps) {
  int i;
  memset((void*)sps,0,sizeof(seq_parameter_set));
  sps->profile_idc                           =input_get_bits(8);
  sps->constraint_set0_flag                  =input_get_one_bit();
  sps->constraint_set1_flag                  =input_get_one_bit();
  sps->constraint_set2_flag                  =input_get_one_bit();
  sps->reserved_zero_5bits                   =input_get_bits(5);
  sps->level_idc                             =input_get_bits(8);
  sps->seq_parameter_set_id                  =get_unsigned_exp_golomb();
  sps->log2_max_frame_num                    =get_unsigned_exp_golomb()+4;
  sps->MaxFrameNum=1<<sps->log2_max_frame_num;
  sps->pic_order_cnt_type                    =get_unsigned_exp_golomb();
  if(sps->pic_order_cnt_type==0) {
    sps->log2_max_pic_order_cnt_lsb          =get_unsigned_exp_golomb()+4;
    sps->MaxPicOrderCntLsb=1<<sps->log2_max_pic_order_cnt_lsb;
  }
  else if(sps->pic_order_cnt_type==1) {
    sps->delta_pic_order_always_zero_flag    =input_get_one_bit();
    sps->offset_for_non_ref_pic              =get_signed_exp_golomb();
    sps->offset_for_top_to_bottom_field      =get_signed_exp_golomb();
    sps->num_ref_frames_in_pic_order_cnt_cycle=get_unsigned_exp_golomb();
    for(i=0; i<sps->num_ref_frames_in_pic_order_cnt_cycle; ++i)
      sps->offset_for_ref_frame[i]           =get_signed_exp_golomb();
  }
  sps->num_ref_frames                        =get_unsigned_exp_golomb();
  sps->gaps_in_frame_num_value_allowed_flag  =input_get_one_bit();
  sps->PicWidthInMbs                         =get_unsigned_exp_golomb()+1;
  sps->PicWidthInSamples=sps->PicWidthInMbs*16;
  sps->PicHeightInMapUnits                   =get_unsigned_exp_golomb()+1;
  sps->PicSizeInMapUnits=sps->PicWidthInMbs*sps->PicHeightInMapUnits;
  sps->frame_mbs_only_flag                   =input_get_one_bit();
  sps->FrameHeightInMbs=(2-sps->frame_mbs_only_flag)*sps->PicHeightInMapUnits;
  sps->FrameHeightInSamples=16*sps->FrameHeightInMbs;
  if(!sps->frame_mbs_only_flag)
    sps->mb_adaptive_frame_field_flag        =input_get_one_bit();
  sps->direct_8x8_inference_flag             =input_get_one_bit();
  sps->frame_cropping_flag                   =input_get_one_bit();
  if(sps->frame_cropping_flag) {
    sps->frame_crop_left_offset              =get_unsigned_exp_golomb();
    sps->frame_crop_right_offset             =get_unsigned_exp_golomb();
    sps->frame_crop_top_offset               =get_unsigned_exp_golomb();
    sps->frame_crop_bottom_offset            =get_unsigned_exp_golomb();
  }
  sps->vui_parameters_present_flag           =input_get_one_bit();
}

///////////////////////////////////////////////////////////////////////////////

void decode_pic_parameter_set(pic_parameter_set *pps) {
  int i;
  memset((void*)pps,0,sizeof(pic_parameter_set));
  pps->pic_parameter_set_id                  =get_unsigned_exp_golomb();
  pps->seq_parameter_set_id                  =get_unsigned_exp_golomb();
  pps->entropy_coding_mode_flag              =input_get_one_bit();
  pps->pic_order_present_flag                =input_get_one_bit();
  pps->num_slice_groups                      =get_unsigned_exp_golomb()+1;
  if(pps->num_slice_groups>1) {
    pps->slice_group_map_type                =get_unsigned_exp_golomb();
    if(pps->slice_group_map_type==0)
      for(i=0; i<pps->num_slice_groups; ++i)
        pps->run_length[i]                   =get_unsigned_exp_golomb();
    else if(pps->slice_group_map_type==2)
      for(i=0; i<pps->num_slice_groups; ++i) {
        pps->top_left[i]                     =get_unsigned_exp_golomb();
        pps->bottom_right[i]                 =get_unsigned_exp_golomb();
      }
    else if((pps->slice_group_map_type>=3) && (pps->slice_group_map_type<=5)) {
      pps->slice_group_change_direction_flag =input_get_one_bit();
      pps->SliceGroupChangeRate              =get_unsigned_exp_golomb()+1;
    } else if(pps->slice_group_map_type==6) {
      pps->pic_size_in_map_units             =get_unsigned_exp_golomb()+1;
      for(i=0; i<pps->pic_size_in_map_units; ++i)
        pps->slice_group_id[i]               =get_unsigned_exp_golomb();
    }
  }    
  pps->num_ref_idx_l0_active                 =get_unsigned_exp_golomb()+1;
  pps->num_ref_idx_l1_active                 =get_unsigned_exp_golomb()+1;
  pps->weighted_pred_flag                    =input_get_one_bit();
  pps->weighted_bipred_idc                   =input_get_bits(2);
  pps->pic_init_qp                           =get_signed_exp_golomb()+26;
  pps->pic_init_qs                           =get_signed_exp_golomb()+26;
  pps->chroma_qp_index_offset                =get_signed_exp_golomb();
  pps->deblocking_filter_control_present_flag=input_get_one_bit();
  pps->constrained_intra_pred_flag           =input_get_one_bit();
  pps->redundant_pic_cnt_present_flag        =input_get_one_bit();
}

///////////////////////////////////////////////////////////////////////////////

int check_unsupported_features(seq_parameter_set *sps, pic_parameter_set *pps) {
  int unsupported_count=0;

  #define UNSUPPORTED(feature) \
    do { \
      printf("UNSUPPORTED FEATURE: %s\n",feature); \
      ++unsupported_count; \
    } while(0)

  if(sps->pic_order_cnt_type!=0)
    UNSUPPORTED("picture order count type != 0");
//  if(sps->num_ref_frames!=1)
//    UNSUPPORTED("long-term prediction");
  if(pps->num_ref_idx_l0_active>1)
    UNSUPPORTED("long-term prediction");
  if(!sps->frame_mbs_only_flag)
    UNSUPPORTED("interlaced video");
  if(sps->frame_cropping_flag)
    printf("UNSUPPORTED FEATURE: frame cropping (ignored)\n");
  if(pps->entropy_coding_mode_flag)
    UNSUPPORTED("CABAC");
  if(pps->pic_order_present_flag)
    UNSUPPORTED("picture reordering");
  if(pps->num_slice_groups>1)
    UNSUPPORTED(">1 slices per frame");
  if(pps->weighted_pred_flag || pps->weighted_bipred_idc)
    UNSUPPORTED("weighted prediction");
  
  return unsupported_count;
}

///////////////////////////////////////////////////////////////////////////////

#ifdef BUILD_TESTS

int _test_params(int argc, char *argv[]) {
  nal_unit unit;
  seq_parameter_set sps;
  pic_parameter_set pps;
  int count;

  if(!input_open("../streams/in.264")) return 1;

  for(count=1; get_next_nal_unit(&unit); ++count)
    if(unit.nal_unit_type==7) {
      decode_seq_parameter_set(&sps);
      printf("Sequence Parameter Set:\n  Profile %d Level %d Constraints %d%d%d\n",
        sps.profile_idc,sps.level_idc,sps.constraint_set0_flag,sps.constraint_set1_flag,sps.constraint_set2_flag);
      printf("  ID=0x%08X MaxFrameNum=%d pic_order_cnt_type=%d\n",
        sps.seq_parameter_set_id,sps.MaxFrameNum,sps.pic_order_cnt_type);
      printf("  num_ref_frames=%d gaps_in_frame_num_allowed=%d\n",
        sps.num_ref_frames,sps.gaps_in_frame_num_value_allowed_flag);
      printf("  Dimensions: %dx%d%s\n",
        sps.PicWidthInSamples,sps.FrameHeightInSamples,sps.frame_mbs_only_flag?"":"i");
    } else if(unit.nal_unit_type==8) {
      decode_pic_parameter_set(&pps);
      printf("Picture Parameter Set:\n  ID=0x%08x RefID=0x%08x\n",
        pps.pic_parameter_set_id,pps.seq_parameter_set_id);
      printf("  CABAC=%d pic_order_present=%d\n",
        pps.entropy_coding_mode_flag,pps.pic_order_present_flag);
      printf("  num_slice_groups=%d slice_group_map_type=%d\n",
        pps.num_slice_groups,pps.slice_group_map_type);
      printf("  num_ref_idx_l0_active=%d num_ref_idx_l1_active=%d\n",
        pps.num_ref_idx_l0_active,pps.num_ref_idx_l1_active);
      printf("  weighted_pred=%d weighted_bipred=%d\n",
        pps.weighted_pred_flag,pps.weighted_bipred_idc);
      printf("  pic_init_qp=%d pic_init_qs=%d chroma_qp_offset=%d\n",
        pps.pic_init_qp,pps.pic_init_qs,pps.chroma_qp_index_offset);
      printf("  deblocking_filter_control=%d constrained_intra_pred=%d redundant_pic_cnt=%d\n",
        pps.deblocking_filter_control_present_flag,pps.constrained_intra_pred_flag,pps.redundant_pic_cnt_present_flag);
    }
  
  input_close();
  return 0;
}

#endif
