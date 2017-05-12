#ifndef __H264_H__
#define __H264_H__

typedef struct __frame {
  int Lwidth,Lheight,Lpitch;
  int Cwidth,Cheight,Cpitch;
  unsigned char *L, *C[2];
} frame;

#define L_pixel(f,x,y)   (f->L[(y)*f->Lpitch+(x)])
#define Cr_pixel(f,x,y) (f->C[1][(y)*f->Cpitch+(x)])
#define Cb_pixel(f,x,y) (f->C[0][(y)*f->Cpitch+(x)])
#define C_pixel(f,iCbCr,x,y) (f->C[iCbCr][(y)*f->Cpitch+(x)])

#define H264_WIDTH(info)  ((info)&0xFFFF)
#define H264_HEIGHT(info) ((info)>>16)

int h264_open(char *filename);
frame *h264_decode_frame(int verbose);
void h264_rewind();
void h264_close();

inline int h264_frame_no();

#endif /*__H264_H__*/
