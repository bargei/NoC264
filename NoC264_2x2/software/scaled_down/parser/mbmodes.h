#ifndef __MBMODES_H__
#define __MBMODES_H__

#define NA             -1

#define Intra_4x4       0
#define Intra_16x16     1
#define Pred_L0         2
#define Pred_L1         3
#define BiPred          4
#define Direct          5

#define P_L0_16x16      0
#define P_L0_L0_16x8    1
#define P_L0_L0_8x16    2
#define P_8x8           3
#define P_8x8ref0       4
#define I_4x4           5
#define I_16x16_0_0_0   6
#define I_16x16_1_0_0   7
#define I_16x16_2_0_0   8
#define I_16x16_3_0_0   9
#define I_16x16_0_1_0  10
#define I_16x16_1_1_0  11
#define I_16x16_2_1_0  12
#define I_16x16_3_1_0  13
#define I_16x16_0_2_0  14
#define I_16x16_1_2_0  15
#define I_16x16_2_2_0  16
#define I_16x16_3_2_0  17
#define I_16x16_0_0_1  18
#define I_16x16_1_0_1  19
#define I_16x16_2_0_1  20
#define I_16x16_3_0_1  21
#define I_16x16_0_1_1  22
#define I_16x16_1_1_1  23
#define I_16x16_2_1_1  24
#define I_16x16_3_1_1  25
#define I_16x16_0_2_1  26
#define I_16x16_1_2_1  27
#define I_16x16_2_2_1  28
#define I_16x16_3_2_1  29
#define I_PCM          30
#define P_Skip       0xFF

#define P_L0_8x8       0
#define P_L0_8x4       1
#define P_L0_4x8       2
#define P_L0_4x4       3
#define B_Direct_8x8   4

#define IsInter(m)  (((m)>=0 && (m)<5) || (m)==P_Skip)
#define IsIntra(m)  ((m)>=5 && (m)<=I_PCM)


typedef struct _mb_mode {
  int mb_type;
  int NumMbPart;
  int MbPartPredMode[2];
  int Intra16x16PredMode;
  int MbPartWidth;
  int MbPartHeight;
  int CodedBlockPatternChroma;
  int CodedBlockPatternLuma;
} mb_mode;

typedef struct _sub_mb_mode {
  int sub_mb_type;
  int NumSubMbPart;
  int SubMbPredMode;
  int SubMbPartWidth;
  int SubMbPartHeight;
} sub_mb_mode;

void decode_mb_mode(mb_mode *mb, int slice_type, int raw_mb_type);
void decode_sub_mb_mode(sub_mb_mode *sub, int slice_type, int raw_sub_mb_type);

char *_str_mb_type(int mb_type);
char *_str_sub_mb_type(int sub_mb_type);
char *_str_pred_mode(int pred_mode);
void _dump_mb_mode(mb_mode *mb);

#endif /*__MBMODES_H__*/
