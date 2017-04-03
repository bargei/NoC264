#ifndef __MODE_PRED_H__
#define __MODE_PRED_H__

#define MV_NA 0x80808080

typedef struct _mv {
  int x,y;
  int available;  // i.e. inside the image
  int valid;      // i.e. usable for prediction
} mv;

typedef struct _mode_pred_info {
  // per-macroblock information     (16x16)
  int MbWidth, MbHeight, MbPitch;
  int *MbMode;
  // per-chroma block information    (8x8)
  int CbWidth, CbHeight, CbPitch;
  int *TotalCoeffC[2];
  // per-transform block information (4x4)
  int TbWidth, TbHeight, TbPitch;
  int *TotalCoeffL;
  int *Intra4x4PredMode;
  int *MVx,*MVy;
} mode_pred_info;

#define ModePredInfo_MbMode(mpi,x,y) (mpi->MbMode[(y)*mpi->MbPitch+(x)])
#define ModePredInfo_TotalCoeffC(mpi,x,y,iCbCr) (mpi->TotalCoeffC[iCbCr][(y)*mpi->CbPitch+(x)])
#define ModePredInfo_TotalCoeffL(mpi,x,y) (mpi->TotalCoeffL[(y)*mpi->TbPitch+(x)])
#define ModePredInfo_Intra4x4PredMode(mpi,x,y) (mpi->Intra4x4PredMode[(y)*mpi->TbPitch+(x)])
#define ModePredInfo_MVx(mpi,x,y) (mpi->MVx[(y)*mpi->TbPitch+(x)])
#define ModePredInfo_MVy(mpi,x,y) (mpi->MVy[(y)*mpi->TbPitch+(x)])

mode_pred_info *alloc_mode_pred_info(int width, int height);
void clear_mode_pred_info(mode_pred_info *mpi);
void free_mode_pred_info(mode_pred_info *mpi);

int get_mb_mode(mode_pred_info *mpi, int mb_x, int mb_y);

int get_luma_nC(mode_pred_info *mpi, int x, int y);
int get_chroma_nC(mode_pred_info *mpi, int x, int y, int iCbCr);

int get_predIntra4x4PredMode(mode_pred_info *mpi, int x, int y);

mv PredictMV(mode_pred_info *mpi, int org_x, int org_y, int width, int height);
mv Predict_P_Skip_MV(mode_pred_info *mpi, int org_x, int org_y);
void FillMVs(mode_pred_info *mpi, int org_x, int org_y, int width, int height,
             int mvx, int mvy);
void DeriveMVs(mode_pred_info *mpi,   int org_x, int org_y,
               int width, int height, int mvdx, int mvdy);
void Derive_P_Skip_MVs(mode_pred_info *mpi, int org_x, int org_y);

#endif /*__MODE_PRED_H__*/
