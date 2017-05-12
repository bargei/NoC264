#include "common.h"
#include "mbmodes.h"
#include "mode_pred.h"

mode_pred_info *alloc_mode_pred_info(int width, int height) {
  mode_pred_info *mpi=calloc(1,sizeof(mode_pred_info));
  int x,y;
  // per-macroblock information     (16x16)
  x=mpi->MbWidth=mpi->MbPitch=width>>4;
  y=mpi->MbHeight=height>>4;
  mpi->MbMode=malloc(x*y*sizeof(int));
  // per-chroma block information    (8x8)
  x=mpi->CbWidth=mpi->CbPitch=width>>3;
  y=mpi->CbHeight=height>>3;
  mpi->TotalCoeffC[0]=malloc(x*y*sizeof(int));
  mpi->TotalCoeffC[1]=malloc(x*y*sizeof(int));
  // per-transform block information (4x4)
  x=mpi->TbWidth=mpi->TbPitch=width>>2;
  y=mpi->TbHeight=height>>2;
  mpi->TotalCoeffL=malloc(x*y*sizeof(int));
  mpi->Intra4x4PredMode=malloc(x*y*sizeof(int));
  mpi->MVx=malloc(x*y*sizeof(int));
  mpi->MVy=malloc(x*y*sizeof(int));
  return mpi;
}

void clear_mode_pred_info(mode_pred_info *mpi) {
  if(!mpi) return;
  if(mpi->MbMode)           memset(mpi->MbMode,0xFF,mpi->MbPitch*mpi->MbHeight*sizeof(int));
  if(mpi->TotalCoeffC[0])   memset(mpi->TotalCoeffC[0],0,mpi->CbPitch*mpi->CbHeight*sizeof(int));
  if(mpi->TotalCoeffC[1])   memset(mpi->TotalCoeffC[1],0,mpi->CbPitch*mpi->CbHeight*sizeof(int));
  if(mpi->TotalCoeffL)      memset(mpi->TotalCoeffL,0,mpi->TbPitch*mpi->TbHeight*sizeof(int));
  if(mpi->Intra4x4PredMode) memset(mpi->Intra4x4PredMode,0xFF,mpi->TbPitch*mpi->TbHeight*sizeof(int));
  if(mpi->MVx)              memset(mpi->MVx,MV_NA&0xFF,mpi->TbPitch*mpi->TbHeight*sizeof(int));
  if(mpi->MVy)              memset(mpi->MVy,MV_NA&0xFF,mpi->TbPitch*mpi->TbHeight*sizeof(int));
}

void free_mode_pred_info(mode_pred_info *mpi) {
  if(!mpi) return;
  if(mpi->MbMode)           free(mpi->MbMode);
  if(mpi->TotalCoeffC[0])   free(mpi->TotalCoeffC[0]);
  if(mpi->TotalCoeffC[1])   free(mpi->TotalCoeffC[1]);
  if(mpi->TotalCoeffL)      free(mpi->TotalCoeffL);
  if(mpi->Intra4x4PredMode) free(mpi->Intra4x4PredMode);
  if(mpi->MVx)              free(mpi->MVx);
  if(mpi->MVy)              free(mpi->MVy);
  free(mpi);
}


///// MbMode retrieval /////

int get_mb_mode(mode_pred_info *mpi, int mb_x, int mb_y) {
  if(mb_x<0 || mb_y<0) return -1;
  return ModePredInfo_MbMode(mpi,mb_x,mb_y);
}


///// nC / TotalCoeff stuff /////

static inline int get_luma_nN(mode_pred_info *mpi, int x, int y) {
  if(x<0 || y<0) return -1;
  return ModePredInfo_TotalCoeffL(mpi,x>>2,y>>2);
}

static inline int get_chroma_nN(mode_pred_info *mpi, int x, int y, int iCbCr) {
  if(x<0 || y<0) return -1;
  return ModePredInfo_TotalCoeffC(mpi,x>>3,y>>3,iCbCr);
}

int get_luma_nC(mode_pred_info *mpi, int x, int y) {
  int nA=get_luma_nN(mpi,x-4,y);
  int nB=get_luma_nN(mpi,x,y-4);
  if(nA<0  && nB<0)  return 0;
  if(nA>=0 && nB>=0) return (nA+nB+1)>>1;
  if(nA>=0) return nA;
       else return nB;
}

int get_chroma_nC(mode_pred_info *mpi, int x, int y, int iCbCr) {
  int nA=get_chroma_nN(mpi,x-8,y,iCbCr);
  int nB=get_chroma_nN(mpi,x,y-8,iCbCr);
  if(nA<0  && nB<0)  return 0;
  if(nA>=0 && nB>=0) return (nA+nB+1)>>1;
  if(nA>=0) return nA;
       else return nB;
}


///// Intra_4x4 Prediction Mode Prediction /////

static inline int get_Intra4x4PredModeN(mode_pred_info *mpi, int x, int y) {
  int i;
  if(x<0 || y<0) return -1;  // force Intra_4x4_DC
  i=ModePredInfo_Intra4x4PredMode(mpi,x>>2,y>>2);
  return i;
}

int get_predIntra4x4PredMode(mode_pred_info *mpi, int x, int y) {
  int A=get_Intra4x4PredModeN(mpi,x-4,y);
  int B=get_Intra4x4PredModeN(mpi,x,y-4);
  int mode=(A<B)?A:B;
  if(mode<0) mode=2;
  return mode;
}


///// Motion Vector Prediction /////

static inline mv get_MV(mode_pred_info *mpi, int x, int y) {
  mv res={0,0,0,0};
  x>>=2; y>>=2;
  if(x<0 || y<0 || x>=mpi->TbWidth || y>=mpi->TbHeight)
    return res;
  res.x=ModePredInfo_MVx(mpi,x,y);
  res.y=ModePredInfo_MVy(mpi,x,y);
  if(res.x==MV_NA) {
    res.x=0;
    res.y=0;
    if(IsIntra(ModePredInfo_MbMode(mpi,x>>2,y>>2)))
      res.available=1;
  } else {
    res.available=1;
    res.valid=1;
  }
  return res;
}

#define Max(a,b) ((a)>(b)?(a):(b))
#define Min(a,b) ((a)<(b)?(a):(b))
#define Median(a,b,c) Max(Min(a,b),Min(c,Max(a,b)))

mv PredictMV(mode_pred_info *mpi,
             int org_x, int org_y,
             int width, int height) {
  mv A,B,C,res;
  // derive candidate MVs
  A=get_MV(mpi,org_x-1,org_y);
  B=get_MV(mpi,org_x,org_y-1);
  C=get_MV(mpi,org_x+width,org_y-1);
  if(!C.available)
    C=get_MV(mpi,org_x-1,org_y-1);
/*
printf("PredictMV @ %d,%d + %dx%d:",org_x,org_y,width,height);if(A.valid)
printf(" A=%d,%d",A.x,A.y);if(B.valid) printf(" B=%d,%d",B.x,B.y);if(C.valid)
printf(" C/D=%d,%d",C.x,C.y);printf("\n");
*/
  // Directional segmentation prediction for 8x16 / 16x8 partitions
  if(width==16 && height==8) {
    if(org_y&8) { if(A.valid) return A; }
           else { if(B.valid) return B; }
  }
  if(width==8 && height==16) {
    if(org_x&8) { if(C.valid) return C; }
           else { if(A.valid) return A; }
  }
  // If one and only one of the candidate predictors is available and valid,
  // it is returned
              if(!B.valid && !C.valid) return A;
  if(!A.valid &&  B.valid && !C.valid) return B;
  if(!A.valid && !B.valid &&  C.valid) return C;
  // median prediction
  res.x=Median(A.x,B.x,C.x);
  res.y=Median(A.y,B.y,C.y);
  return res;
}

mv Predict_P_Skip_MV(mode_pred_info *mpi, int org_x, int org_y) {
  mv zero={0,0,0};
  if(org_x<=0 || org_y<=0) return zero;
  if(ModePredInfo_MVx(mpi,(org_x>>2)-1,org_y>>2)==0 &&
     ModePredInfo_MVy(mpi,(org_x>>2)-1,org_y>>2)==0) return zero;
  if(ModePredInfo_MVx(mpi,org_x>>2,(org_y>>2)-1)==0 &&
     ModePredInfo_MVy(mpi,org_x>>2,(org_y>>2)-1)==0) return zero;
  return PredictMV(mpi,org_x,org_y,16,16);
}

void FillMVs(mode_pred_info *mpi,
             int org_x, int org_y,
             int width, int height,
             int mvx, int mvy) {
  int x,y;
  org_x>>=2; org_y>>=2;
  width>>=2; height>>=2;
  for(y=org_y+height-1; y>=org_y; --y)
    for(x=org_x+width-1; x>=org_x; --x) {
      ModePredInfo_MVx(mpi,x,y)=mvx;
      ModePredInfo_MVy(mpi,x,y)=mvy;
    }
}

void DeriveMVs(mode_pred_info *mpi,
               int org_x, int org_y,
               int width, int height,
               int mvdx, int mvdy) {
  mv v=PredictMV(mpi,org_x,org_y,width,height);
//printf("MV @ %d,%d + %dx%d: pred=%d,%d diff=%d,%d\n",org_x,org_y,width,height,v.x,v.y,mvdx,mvdy);
  FillMVs(mpi,org_x,org_y,width,height,v.x+mvdx,v.y+mvdy);
}

void Derive_P_Skip_MVs(mode_pred_info *mpi, int org_x, int org_y) {
  mv v=Predict_P_Skip_MV(mpi,org_x,org_y);
//printf("P_Skip MV @ %d,%d: mv=%d,%d\n",org_x,org_y,v.x,v.y);
  FillMVs(mpi,org_x,org_y,16,16,v.x,v.y);
}
