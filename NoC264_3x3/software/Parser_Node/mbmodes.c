#include "common.h"
#include "slicehdr.h"
#include "mbmodes.h"

static int ISliceMbModes[][4]={
  {Intra_4x4,   NA, NA, NA},
  {Intra_16x16,  0,  0,  0},
  {Intra_16x16,  1,  0,  0},
  {Intra_16x16,  2,  0,  0},
  {Intra_16x16,  3,  0,  0},
  {Intra_16x16,  0,  1,  0},
  {Intra_16x16,  1,  1,  0},
  {Intra_16x16,  2,  1,  0},
  {Intra_16x16,  3,  1,  0},
  {Intra_16x16,  0,  2,  0},
  {Intra_16x16,  1,  2,  0},
  {Intra_16x16,  2,  2,  0},
  {Intra_16x16,  3,  2,  0},
  {Intra_16x16,  0,  0, 15},
  {Intra_16x16,  1,  0, 15},
  {Intra_16x16,  2,  0, 15},
  {Intra_16x16,  3,  0, 15},
  {Intra_16x16,  0,  1, 15},
  {Intra_16x16,  1,  1, 15},
  {Intra_16x16,  2,  1, 15},
  {Intra_16x16,  3,  1, 15},
  {Intra_16x16,  0,  2, 15},
  {Intra_16x16,  1,  2, 15},
  {Intra_16x16,  2,  2, 15},
  {Intra_16x16,  3,  2, 15},
  {NA, NA, NA, NA} // I_PCM
};

static int PSliceMbModes[][5]={
  {1, Pred_L0, NA,      16, 16},
  {2, Pred_L0, Pred_L0, 16,  8},
  {2, Pred_L0, Pred_L0,  8, 16},
  {4, NA,      NA,       8,  8},
  {4, NA,      NA,       8,  8},
  {1, Pred_L0, NA,      16, 16}  // P_Skip
};

static int PSliceSubMbModes[][4]={
  {1, Pred_L0, 8, 8},
  {2, Pred_L0, 8, 4},
  {2, Pred_L0, 4, 8},
  {4, Pred_L0, 4, 4},
};

int CodedBlockPatternMapping_Intra4x4[]={
  47,31,15, 0,23,27,29,30, 7,11,13,14,39,43,45,46,
  16, 3, 5,10,12,19,21,26,28,35,37,42,44, 1, 2, 4,
   8,17,18,20,24, 6, 9,22,25,32,33,34,36,40,38,41
};
int CodedBlockPatternMapping_Inter[]={
   0,16, 1, 2, 4, 8,32, 3, 5,10,12,15,47, 7,11,13,
  14, 6, 9,31,35,37,42,44,33,34,36,40,39,43,45,46,
  17,18,20,24,19,21,26,28,23,27,29,30,22,25,38,41
};


void decode_mb_mode(mb_mode *mb, int slice_type, int raw_mb_type) {
  #define INVALID_MB do { memset(mb,0xFF,sizeof(mb_mode)); return; } while(0)
  if(slice_type==I_SLICE) {
    if(raw_mb_type>25) INVALID_MB;
    mb->mb_type=raw_mb_type+5;
    mb->NumMbPart=1;
    mb->MbPartPredMode[0]=ISliceMbModes[raw_mb_type][0];
    mb->MbPartPredMode[1]=NA;
    mb->Intra16x16PredMode=ISliceMbModes[raw_mb_type][1];
    mb->MbPartWidth=16;
    mb->MbPartHeight=16;
    mb->CodedBlockPatternChroma=ISliceMbModes[raw_mb_type][2];
    mb->CodedBlockPatternLuma=ISliceMbModes[raw_mb_type][3];
  } else if(slice_type==P_SLICE) {
    if(raw_mb_type>4)
      decode_mb_mode(mb,I_SLICE,raw_mb_type-5);
    else {
      mb->mb_type=raw_mb_type;
      mb->NumMbPart=PSliceMbModes[raw_mb_type][0];
      mb->MbPartPredMode[0]=PSliceMbModes[raw_mb_type][1];
      mb->MbPartPredMode[1]=PSliceMbModes[raw_mb_type][2];
      mb->Intra16x16PredMode=NA;
      mb->MbPartWidth=PSliceMbModes[raw_mb_type][3];
      mb->MbPartHeight=PSliceMbModes[raw_mb_type][4];
      mb->CodedBlockPatternChroma=NA;
      mb->CodedBlockPatternLuma=NA;
    }
  } else
    INVALID_MB;
}

void decode_sub_mb_mode(sub_mb_mode *sub, int slice_type, int raw_sub_mb_type) {
  #define INVALID_SUB do { memset(sub,0xFF,sizeof(sub_mb_mode)); return; } while(0)
  if(slice_type==P_SLICE) {
    if(raw_sub_mb_type>3) INVALID_SUB;
    sub->sub_mb_type=raw_sub_mb_type;
    sub->NumSubMbPart=PSliceSubMbModes[raw_sub_mb_type][0];
    sub->SubMbPredMode=PSliceSubMbModes[raw_sub_mb_type][1];
    sub->SubMbPartWidth=PSliceSubMbModes[raw_sub_mb_type][2];
    sub->SubMbPartHeight=PSliceSubMbModes[raw_sub_mb_type][3];
  } else
    INVALID_SUB;
}

///////////////////////////////////////////////////////////////////////////////

char *_str_mb_type(int mb_type) {
  switch(mb_type) {
    case P_L0_16x16: return "P_L0_16x16";
    case P_L0_L0_16x8: return "P_L0_L0_16x8";
    case P_L0_L0_8x16: return "P_L0_L0_8x16";
    case P_8x8: return "P_8x8";
    case P_8x8ref0: return "P_8x8ref0";
    case I_4x4: return "I_4x4";
    case I_16x16_0_0_0: return "I_16x16_0_0_0";
    case I_16x16_1_0_0: return "I_16x16_1_0_0";
    case I_16x16_2_0_0: return "I_16x16_2_0_0";
    case I_16x16_3_0_0: return "I_16x16_3_0_0";
    case I_16x16_0_1_0: return "I_16x16_0_1_0";
    case I_16x16_1_1_0: return "I_16x16_1_1_0";
    case I_16x16_2_1_0: return "I_16x16_2_1_0";
    case I_16x16_3_1_0: return "I_16x16_3_1_0";
    case I_16x16_0_2_0: return "I_16x16_0_2_0";
    case I_16x16_1_2_0: return "I_16x16_1_2_0";
    case I_16x16_2_2_0: return "I_16x16_2_2_0";
    case I_16x16_3_2_0: return "I_16x16_3_2_0";
    case I_16x16_0_0_1: return "I_16x16_0_0_1";
    case I_16x16_1_0_1: return "I_16x16_1_0_1";
    case I_16x16_2_0_1: return "I_16x16_2_0_1";
    case I_16x16_3_0_1: return "I_16x16_3_0_1";
    case I_16x16_0_1_1: return "I_16x16_0_1_1";
    case I_16x16_1_1_1: return "I_16x16_1_1_1";
    case I_16x16_2_1_1: return "I_16x16_2_1_1";
    case I_16x16_3_1_1: return "I_16x16_3_1_1";
    case I_16x16_0_2_1: return "I_16x16_0_2_1";
    case I_16x16_1_2_1: return "I_16x16_1_2_1";
    case I_16x16_2_2_1: return "I_16x16_2_2_1";
    case I_16x16_3_2_1: return "I_16x16_3_2_1";
    case I_PCM: return "I_PCM";
    case P_Skip: return "P_Skip";
    default: return "n/a";
  }
}

char *_str_sub_mb_type(int sub_mb_type) {
  switch(sub_mb_type) {
    case P_L0_8x8: return "P_L0_8x8";
    case P_L0_8x4: return "P_L0_8x4";
    case P_L0_4x8: return "P_L0_4x8";
    case P_L0_4x4: return "P_L0_4x4";
    default: return "n/a";
  }
}

char *_str_pred_mode(int pred_mode) {
  switch(pred_mode) {
    case Intra_4x4: return "Intra_4x4";
    case Intra_16x16: return "Intra_16x16";
    case Pred_L0: return "Pred_L0";
    case Pred_L1: return "Pred_L1";
    case BiPred: return "BiPred";
    case Direct: return "Direct";
    default: return "n/a";
  }
}

void _dump_mb_mode(mb_mode *mb) {
  printf("MB: %s, %d parts %dx%d [%s,%s], i16=%d, cbp: C=%d L=%d\n",
         _str_mb_type(mb->mb_type),mb->NumMbPart,
         mb->MbPartWidth,mb->MbPartHeight,
         _str_pred_mode(mb->MbPartPredMode[0]),
         _str_pred_mode(mb->MbPartPredMode[1]),
         mb->Intra16x16PredMode,
         mb->CodedBlockPatternChroma,mb->CodedBlockPatternLuma);
}

#ifdef BUILD_TESTS

int _test_mbmodes(int argc, char *argv[]) {
  mb_mode mb;
  decode_mb_mode(&mb,I_SLICE,7); _dump_mb_mode(&mb);
  decode_mb_mode(&mb,P_SLICE,17);_dump_mb_mode(&mb);
  decode_mb_mode(&mb,P_SLICE,2); _dump_mb_mode(&mb);
  return 0;
}

#endif
