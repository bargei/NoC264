#include "common.h"
#include "input.h"
#include "nal.h"
#include "cavlc.h"
#include "params.h"
#include "slicehdr.h"

static void skip_ref_pic_list_reordering() {
  int reordering_of_pic_nums_idc;
  int abs_diff_pic_num;
  int long_term_pic_num;
  fprintf(stderr,"Warning: I do not support reference picture list reordering.\n"
                 "         Watch out for decoding errors!\n");
  do {
    reordering_of_pic_nums_idc=get_unsigned_exp_golomb();
    if(reordering_of_pic_nums_idc==0 || reordering_of_pic_nums_idc==1)
      abs_diff_pic_num=get_unsigned_exp_golomb()+1;
    else if(reordering_of_pic_nums_idc==2)
      long_term_pic_num=get_unsigned_exp_golomb();
  } while(reordering_of_pic_nums_idc!=3);
}

static void skip_adaptive_ref_pic_marking() {
  int memory_management_control_operation;
  int difference_of_pic_nums;
  int long_term_pic_num;
  int long_term_frame_idx;
  int max_long_term_frame_idx;
  fprintf(stderr,"Warning: I do not support adaptive reference picture marking.\n"
                 "         Watch out for decoding errors!\n");
  do {
    memory_management_control_operation=get_unsigned_exp_golomb();
    if(memory_management_control_operation==1 || memory_management_control_operation==3)
      difference_of_pic_nums=get_unsigned_exp_golomb()+1;
    if(memory_management_control_operation==2)
      long_term_pic_num=get_unsigned_exp_golomb();
    if(memory_management_control_operation==3 || memory_management_control_operation==6)
      long_term_frame_idx=get_unsigned_exp_golomb();
    if(memory_management_control_operation==4)
      max_long_term_frame_idx=get_unsigned_exp_golomb()-1;
  } while(memory_management_control_operation!=0);
}


void decode_slice_header(slice_header *sh,
                         seq_parameter_set *sps,
                         pic_parameter_set *pps,
                         nal_unit *nalu) {
  memset((void*)sh,0,sizeof(slice_header));
  sh->first_mb_in_slice                      =get_unsigned_exp_golomb();
  sh->slice_type                             =get_unsigned_exp_golomb()%5;
  sh->pic_parameter_set_id                   =get_unsigned_exp_golomb();
  sh->frame_num                              =input_get_bits(sps->log2_max_frame_num);
  if(!sps->frame_mbs_only_flag) {
    sh->field_pic_flag                       =input_get_one_bit();
    if(sh->field_pic_flag)
      sh->bottom_field_flag                  =input_get_one_bit();
  }
  sh->MbaffFrameFlag=(sps->mb_adaptive_frame_field_flag && !sh->field_pic_flag);
  sh->PicHeightInMbs=sps->FrameHeightInMbs/(1+sh->field_pic_flag);
  sh->PicHeightInSamples=(sh->PicHeightInMbs)<<4;
  sh->PicSizeInMbs=sps->PicWidthInMbs*sh->PicHeightInMbs;
  if(nalu->nal_unit_type==5)
    sh->idr_pic_id                           =get_unsigned_exp_golomb();
  if(sps->pic_order_cnt_type==0) {
    sh->pic_order_cnt_lsb                    =input_get_bits(sps->log2_max_pic_order_cnt_lsb);
    if(pps->pic_order_present_flag && !sh->field_pic_flag)
      sh->delta_pic_order_cnt_bottom         =get_signed_exp_golomb();
  }
  if(sps->pic_order_cnt_type==1 && !sps->delta_pic_order_always_zero_flag) {
    sh->delta_pic_order_cnt[0]               =get_signed_exp_golomb();
    if(pps->pic_order_present_flag && !sh->field_pic_flag)
      sh->delta_pic_order_cnt[1]             =get_signed_exp_golomb();
  }
  if(pps->redundant_pic_cnt_present_flag)
    sh->redundant_pic_cnt                    =get_unsigned_exp_golomb();
  if(sh->slice_type==B_SLICE)
    sh->direct_spatial_mv_pred_flag          =input_get_one_bit();
  if(sh->slice_type==P_SLICE || sh->slice_type==B_SLICE || sh->slice_type==SP_SLICE) {
    sh->num_ref_idx_active_override_flag     =input_get_one_bit();
    if(sh->num_ref_idx_active_override_flag) {
      sh->num_ref_idx_l0_active              =get_unsigned_exp_golomb()+1;
      if(sh->slice_type==B_SLICE)
        sh->num_ref_idx_l1_active            =get_unsigned_exp_golomb()+1;
    }
  }
  // ref_pic_list_reordering()
  if(sh->slice_type!=I_SLICE && sh->slice_type!=SI_SLICE) {
    sh->ref_pic_list_reordering_flag_l0      =input_get_one_bit();
    if(sh->ref_pic_list_reordering_flag_l0)
      skip_ref_pic_list_reordering();
  }
  if(sh->slice_type==B_SLICE) {
    sh->ref_pic_list_reordering_flag_l1      =input_get_one_bit();
    if(sh->ref_pic_list_reordering_flag_l1)
      skip_ref_pic_list_reordering();
  }
  if((pps->weighted_pred_flag && (sh->slice_type==P_SLICE || sh->slice_type==SP_SLICE)) ||
     (pps->weighted_bipred_idc==1 && sh->slice_type==B_SLICE)) {
    fprintf(stderr,"sorry, I _really_ do not support weighted prediction!\n");
    exit(1);
  }
  if(nalu->nal_ref_idc!=0) {
    // dec_ref_pic_marking()
    if(nalu->nal_unit_type==5) {
      sh->no_output_of_prior_pics_flag       =input_get_one_bit();
      sh->long_term_reference_flag           =input_get_one_bit();
    } else {
      sh->adaptive_ref_pic_marking_mode_flag =input_get_one_bit();
      if(sh->adaptive_ref_pic_marking_mode_flag)
        skip_adaptive_ref_pic_marking();
    }
  }
  if(pps->entropy_coding_mode_flag && sh->slice_type!=I_SLICE && sh->slice_type!=SI_SLICE)
    sh->cabac_init_idc                       =get_unsigned_exp_golomb();
  sh->slice_qp_delta                         =get_signed_exp_golomb();
  sh->SliceQPy=pps->pic_init_qp+sh->slice_qp_delta;
  if(sh->slice_type==SP_SLICE || sh->slice_type==SI_SLICE) {
    if(sh->slice_type==SP_SLICE)
      sh->sp_for_switch_flag                 =input_get_one_bit();
    sh->slice_qs_delta                       =get_signed_exp_golomb();
  }
  if(pps->deblocking_filter_control_present_flag) {
    sh->disable_deblocking_filter_idc        =get_unsigned_exp_golomb();
    if(sh->disable_deblocking_filter_idc!=1) {
      sh->slice_alpha_c0_offset_div2         =get_signed_exp_golomb();
      sh->slice_beta_offset_div2             =get_signed_exp_golomb();
    }
  }
  if(pps->num_slice_groups>1 && pps->slice_group_map_type>=3 && pps->slice_group_map_type<=5)
    sh->slice_group_change_cycle             =get_unsigned_exp_golomb();
}

char *_str_slice_type(int type) {
  switch(type) {
    case  P_SLICE: case  P_SLICE+5: return "P-Slice";
    case  B_SLICE: case  B_SLICE+5: return "B-Slice";
    case  I_SLICE: case  I_SLICE+5: return "I-Slice";
    case SP_SLICE: case SP_SLICE+5: return "SP-Slice";
    case SI_SLICE: case SI_SLICE+5: return "SI-Slice";
  }
  return "Illegal Slice";
}

///////////////////////////////////////////////////////////////////////////////

#ifdef BUILD_TESTS

int _test_slicehdr(int argc, char *argv[]) {
  nal_unit unit;
  seq_parameter_set sps;
  pic_parameter_set pps;
  slice_header sh;
  int count;

  if(!input_open("../streams/nemo_simple.264")) return 1;

  for(count=1; get_next_nal_unit(&unit); ++count)
    switch(unit.nal_unit_type) {
      case 7: decode_seq_parameter_set(&sps); break;
      case 8: decode_pic_parameter_set(&pps); break;
      case 1: case 5:
        decode_slice_header(&sh,&sps,&pps,&unit);
        printf("%s at unit #%d (frame_num=%d)\n",
               _str_slice_type(sh.slice_type),count,sh.frame_num);
        printf("  RefID=0x%08X first_mb_in_slice=%d field_pic=%d\n",
               sh.pic_parameter_set_id,sh.first_mb_in_slice,sh.field_pic_flag);
        printf("  MbaffFrameFlag=%d PicSizeInSamples=%dx%d\n",
               sh.MbaffFrameFlag,sps.PicWidthInSamples,sh.PicHeightInSamples);
        printf("  idr_pic_id=0x%04X pic_order_cnt_lsb=%d redundant_pic_cnt=%d\n",
               sh.idr_pic_id,sh.pic_order_cnt_lsb,sh.redundant_pic_cnt);
        printf("  direct_spatial_mv_pred=%d num_ref_idx_active_override=%d\n",
               sh.direct_spatial_mv_pred_flag,sh.num_ref_idx_active_override_flag);
        printf("  ref_pic_list_reordering=%d/%d adaptive_ref_pic_marking=%d\n",
               sh.ref_pic_list_reordering_flag_l0,sh.ref_pic_list_reordering_flag_l1,
               sh.adaptive_ref_pic_marking_mode_flag);
        printf("  slice_qp_delta=%d slice_qs_delta=%d\n",
               sh.slice_qp_delta,sh.slice_qs_delta);
        break;
    }

  input_close();
  return 0;
}

#endif
