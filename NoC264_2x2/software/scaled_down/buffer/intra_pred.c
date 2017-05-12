#include "common.h"
#include "intra_pred.h"
#include <stdint.h>
#include "noc_control.h"
#include <inttypes.h>

//uint32_t send_luma_intra_packet(int size, frame *f, mode_pred_info *mpi, int mode, int bx, int by, int constrained_intra_pred, int blkIdx);
//uint32_t send_chroma_intra_packet(int size, frame *f, mode_pred_info *mpi, int mode, int bx, int by, int x_avail, int y_avail, int select_cb);
void rx_intra_packet(uint32_t identifier, frame *f, int bx, int by, int type);
void print_block(frame *f, int bx, int by, int size);


#define r(x,y)  Cr_pixel(f,bx+(x),by+(y))
#define b(x,y)  Cb_pixel(f,bx+(x),by+(y))
#define p(x,y)  L_pixel(f,bx+(x),by+(y))

#define left(y) ref[3-(y)]
#define top(x)  ref[5+(x)]

#define HW_ENABLE_4x4     1
#define HW_ENABLE_16x16   1
#define HW_ENABLE_CHROMA  1

#define ICDCsumL(chan,offs) chan(-1,offs)+chan(-1,offs+1)+chan(-1,offs+2)+chan(-1,offs+3)
#define ICDCsumT(chan,offs) chan(offs,-1)+chan(offs+1,-1)+chan(offs+2,-1)+chan(offs+3,-1)
#define ICDCfill(offx,offy,valr,valb) \
  do { \
    int sy,vr=valr,vb=valb; \
    for(sy=0; sy<4; ++sy) { \
      memset(&r(offx,offy+sy),vr,4); \
      memset(&b(offx,offy+sy),vb,4); \
    } \
  } while(0)

static inline void Intra_4x4_Vertical(frame *f, int *ref, int bx, int by) {
  int x,y;
  //printf("sw result: \n");
  for(y=0; y<4; ++y){
    for(x=0; x<4; ++x){
      p(x,y)=top(x);
      //printf("%02X ", p(x,y));
    }
    //printf("\n");
  }
}

static inline void Intra_4x4_Horizontal(frame *f, int *ref, int bx, int by) {
  int x,y;
  for(y=0; y<4; ++y)
    for(x=0; x<4; ++x)
      p(x,y)=left(y);
}

static inline void Intra_4x4_DC(frame *f, int x_avail, int y_avail, int x, int y) {
  int i, sum=0, count=0;
  if(x_avail)
    for(i=0; i<4; ++i, ++count)
      sum+=L_pixel(f,x-1,y+i);
  if(y_avail)
    for(i=0; i<4; ++i, ++count)
      sum+=L_pixel(f,x+i,y-1);
  if(count==8) sum=(sum+4)>>3; else
  if(count==4) sum=(sum+2)>>2; else
               sum=128;
  sum=Clip(sum);
  for(i=0; i<4; ++i)
    memset(&L_pixel(f,x,y+i),sum,4);
}

static inline void Intra_4x4_Diagonal_Down_Left(frame *f, int *ref, int bx, int by) {
  int x,y,i;
  for(y=0; y<4; ++y)
    for(x=0; x<4; ++x) {
      if((x&y)==3) i=top(6)+3*top(7)+2;
      else         i=top(x+y)+2*top(x+y+1)+top(x+y+2)+2;
      p(x,y)=i>>2;
    }
}

static inline void Intra_4x4_Diagonal_Down_Right(frame *f, int *ref, int bx, int by) {
  int x,y,i;
  for(y=0; y<4; ++y)
    for(x=0; x<4; ++x) {
           if(x>y) i=top(x-y-2)+2*top(x-y-1)+top(x-y)+2;
      else if(x<y) i=left(y-x-2)+2*left(y-x-1)+left(y-x)+2;
      else         i=top(0)+2*top(-1)+left(0)+2;
      p(x,y)=i>>2;
    }
}

static inline void Intra_4x4_Vertical_Right(frame *f, int *ref, int bx, int by) {
  int x,y,i,zVR;
  for(y=0; y<4; ++y)
    for(x=0; x<4; ++x) {
      zVR=2*x-y;
           if(zVR<-1) i=left(y-1)+2*left(y-2)+left(y-3)+2;
      else if(zVR<0)  i=left(0)+2*left(-1)+top(-1)+2;
      else if(zVR&1)  i=top(x-(y>>1)-2)+2*top(x-(y>>1)-1)+top(x-(y>>1))+2;
      else            i=2*top(x-(y>>1)-1)+2*top(x-(y>>1))+2;
      p(x,y)=i>>2;
    }
}

static inline void Intra_4x4_Horizontal_Down(frame *f, int *ref, int bx, int by) {
  int x,y,i,zHD;
  for(y=0; y<4; ++y)
    for(x=0; x<4; ++x) {
      zHD=2*y-x;
           if(zHD<-1) i=top(x-1)+2*top(x-2)+top(x-3)+2;
      else if(zHD<0)  i=left(0)+2*left(-1)+top(0)+2;
      else if(zHD&1)  i=left(y-(x>>1)-2)+2*left(y-(x>>1)-1)+left(y-(x>>1))+2;
      else            i=2*left(y-(x>>1)-1)+2*left(y-(x>>1))+2;
      p(x,y)=i>>2;
    }
}

static inline void Intra_4x4_Vertical_Left(frame *f, int *ref, int bx, int by) {
  int x,y,i;
  for(y=0; y<4; ++y)
    for(x=0; x<4; ++x) {
      if(y&1) i=top(x+(y>>1))+2*top(x+(y>>1)+1)+top(x+(y>>1)+2)+2;
      else    i=2*top(x+(y>>1))+2*top(x+(y>>1)+1)+2;
      p(x,y)=i>>2;
    }
}

static inline void Intra_4x4_Horizontal_Up(frame *f, int *ref, int bx, int by) {
  int x,y,i,zHU;
  for(y=0; y<4; ++y)
    for(x=0; x<4; ++x) {
      zHU=x+2*y;
           if(zHU>5)  i=4*left(3);
      else if(zHU==5) i=left(2)+3*left(3)+2;
      else if(zHU&1)  i=left(y+(x>>1))+2*left(y+(x>>1)+1)+left(y+(x>>1)+2)+2;
      else            i=2*left(y+(x>>1))+2*left(y+(x>>1)+1)+2;
      p(x,y)=i>>2;
    }
}

static inline void Intra_16x16_Vertical(frame *f, int bx, int by) {
  int x,y;
  for(y=0; y<16; ++y)
    for(x=0; x<16; ++x)
      p(x,y)=p(x,-1);
}

static inline void Intra_16x16_Horizontal(frame *f, int bx, int by) {
  int x,y;
  for(y=0; y<16; ++y)
    for(x=0; x<16; ++x)
      p(x,y)=p(-1,y);
}

static inline void Intra_16x16_DC(frame *f, int x_avail, int y_avail, int bx, int by) {
  int i, sum=0, count=0;
  if(x_avail)
    for(i=0; i<16; ++i, ++count)
      sum+=p(-1,i);
  if(y_avail)
    for(i=0; i<16; ++i, ++count)
      sum+=p(i,-1);
  if(count==32) sum=(sum+16)>>5; else
  if(count==16) sum=(sum+8)>>4;  else
                sum=128;
  sum=Clip(sum);
  for(i=0; i<16; ++i)
    memset(&p(0,i),sum,16);
}

static inline void Intra_16x16_Plane(frame *f, int bx, int by) {
  int a,b,c,H,V,x,y;
  for(x=0, H=0; x<8; ++x) H+=(x+1)*(p(8+x,-1)-p(6-x,-1));
  for(y=0, V=0; y<8; ++y) V+=(y+1)*(p(-1,8+y)-p(-1,6-y));
  a=16*(p(-1,15)+p(15,-1));
  b=(5*H+32)>>6; c=(5*V+32)>>6;
  for(y=0; y<16; ++y) for(x=0; x<16; ++x)
    p(x,y)=Clip((a+b*(x-7)+c*(y-7)+16)>>5);
}



#if 1
//////////////////////////////////////////////////// INTRA_4X4 PREDICTION /////





void Intra_4x4_Dispatch(frame *f, int mode, int x_avail, int y_avail, int x, int y, int luma4x4BlkIdx_check) {
    //static uint32_t noc_initd = 0;
    //if(noc_initd == 0){
        //noc_init();
        //noc_initd = 1;
    //}


        int ref[13];
        if(mode!=2) {
          int i;
          if(x>0) {
            for(i=0; i<4; ++i) left(i)=L_pixel(f,x-1,y+i);
            if(y>0) left(-1)=L_pixel(f,x-1,y-1);
          }
          if(y>0) {
            for(i=0; i<4; ++i) top(i)=L_pixel(f,x+i,y-1);
            if(luma4x4BlkIdx_check)
              for(i=4; i<8; ++i) top(i)=top(3);
            else
              for(i=4; i<8; ++i) top(i)=L_pixel(f,x+i,y-1);
          }
        }

        switch(mode) {
            case 0: Intra_4x4_Vertical(f,ref,x,y); break;
            case 1: Intra_4x4_Horizontal(f,&ref[0],x,y); break;
            case 2: Intra_4x4_DC(f,x_avail, y_avail,x,y); break;
            case 3: Intra_4x4_Diagonal_Down_Left(f,&ref[0],x,y); break;
            case 4: Intra_4x4_Diagonal_Down_Right(f,&ref[0],x,y); break;
            case 5: Intra_4x4_Vertical_Right(f,&ref[0],x,y); break;
            case 6: Intra_4x4_Horizontal_Down(f,&ref[0],x,y); break;
            case 7: Intra_4x4_Vertical_Left(f,&ref[0],x,y); break;
            case 8: Intra_4x4_Horizontal_Up(f,&ref[0],x,y); break;
            default: printf("unsupported Intra4x4PredMode %d at %d,%d!\n",mode,x,y);
        }
}

#undef p
#undef top
#undef left


////////////////////////////////////////////////// INTRA_16X16 PREDICTION /////

#define p(x,y)  L_pixel(f,bx+(x),by+(y))


void print_block(frame *f, int bx, int by, int size){
    int x,y;
    for(y=-1; y<size; y++)
    {
        for (x=-1; x<size; x++)
        {
            printf("%02X ", p(x,y));
        }
        if(y==-1 &&( size == 4 || size == 8)){
            for(;x < 2*size; x++){
                printf("%02X ", p(x,y));
            }
        }
        printf("\n");
    }
}

void print_cr_block(frame *f, int bx, int by, int size){
    int x,y;
    for(y=-1; y<size; y++)
    {
        for (x=-1; x<size; x++)
        {
            printf("%02X ", r(x,y));
        }
        if(y==-1 &&( size == 4 || size == 8)){
            for(;x < 2*size; x++){
                printf("%02X ", r(x,y));
            }
        }
        printf("\n");
    }
}

void print_cb_block(frame *f, int bx, int by, int size){
    int x,y;
    for(y=-1; y<size; y++)
    {
        for (x=-1; x<size; x++)
        {
            printf("%02X ", b(x,y));
        }
        if(y==-1 &&( size == 4 || size == 8)){
            for(;x < 2*size; x++){
                printf("%02X ", b(x,y));
            }
        }
        printf("\n");
    }
}


#endif
uint32_t pack_luma_x(frame *f, int bx, int by, int x, int y){

    return ((uint32_t)p(x+3,y))      |\
           ((uint32_t)p(x+2,y)) <<8  |\
           ((uint32_t)p(x+1,y)) <<16 |\
           ((uint32_t)p(x+0,y)) <<24;
}

uint32_t pack_luma_y(frame *f, int bx, int by, int x, int y){

    return ((uint32_t)p(x,y+3))      |\
           ((uint32_t)p(x,y+2)) <<8  |\
           ((uint32_t)p(x,y+1)) <<16 |\
           ((uint32_t)p(x,y+0)) <<24;
}

uint32_t pack_cr_x(frame *f, int bx, int by, int x, int y){

    return ((uint32_t)r(x+3,y))      |\
           ((uint32_t)r(x+2,y)) <<8  |\
           ((uint32_t)r(x+1,y)) <<16 |\
           ((uint32_t)r(x+0,y)) <<24;
}

uint32_t pack_cr_y(frame *f, int bx, int by, int x, int y){

    return ((uint32_t)r(x,y+3))      |\
           ((uint32_t)r(x,y+2)) <<8  |\
           ((uint32_t)r(x,y+1)) <<16 |\
           ((uint32_t)r(x,y+0)) <<24;
}

uint32_t pack_cb_x(frame *f, int bx, int by, int x, int y){

    return ((uint32_t)b(x+3,y))      |\
           ((uint32_t)b(x+2,y)) <<8  |\
           ((uint32_t)b(x+1,y)) <<16 |\
           ((uint32_t)b(x+0,y)) <<24;
}

uint32_t pack_cb_y(frame *f, int bx, int by, int x, int y){

    return ((uint32_t)b(x,y+3))      |\
           ((uint32_t)b(x,y+2)) <<8  |\
           ((uint32_t)b(x,y+1)) <<16 |\
           ((uint32_t)b(x,y+0)) <<24;
}

static inline void Intra_Chroma_DC(frame *f, int x_avail, int y_avail, int bx, int by) {
  int i;
  int left=1, top=1;
  int l0r=512,l0b=512,l4r=512,l4b=512;
  int t0r=512,t0b=512,t4r=512,t4b=512;

  if(!x_avail) left=0;
  if(left) {
    l0r=ICDCsumL(r,0); l0b=ICDCsumL(b,0);
    l4r=ICDCsumL(r,4); l4b=ICDCsumL(b,4);
  }

  if(!y_avail) top=0;
  if(top) {
    t0r=ICDCsumT(r,0); t0b=ICDCsumT(b,0);
    t4r=ICDCsumT(r,4); t4b=ICDCsumT(b,4);
  }

  if(top) {
    if(left)    ICDCfill(0,0,(l0r+t0r+4)>>3,(l0b+t0b+4)>>3);
        else    ICDCfill(0,0,(t0r+2)>>2,(t0b+2)>>2);
  } else {
    if(left)    ICDCfill(0,0,(l0r+2)>>2,(l0b+2)>>2);
        else    ICDCfill(0,0,128,128);
  }

       if(top)  ICDCfill(4,0,(t4r+2)>>2,(t4b+2)>>2);
  else if(left) ICDCfill(4,0,(l0r+2)>>2,(l0b+2)>>2);
  else          ICDCfill(4,0,128,128);

       if(left) ICDCfill(0,4,(l4r+2)>>2,(l4b+2)>>2);
  else if(top)  ICDCfill(0,4,(t0r+2)>>2,(t0b+2)>>2);
  else          ICDCfill(0,4,128,128);

  if(top) {
    if(left)    ICDCfill(4,4,(l4r+t4r+4)>>3,(l4b+t4b+4)>>3);
        else    ICDCfill(4,4,(t4r+2)>>2,(t4b+2)>>2);
  } else {
    if(left)    ICDCfill(4,4,(l4r+2)>>2,(l4b+2)>>2);
        else    ICDCfill(4,4,128,128);
  }
}

void Intra_Chroma_Horizontal(frame *f, int bx, int by) {
  int x,y;
  for(y=0; y<8; ++y)
    for(x=0; x<8; ++x) {
      r(x,y)=r(-1,y);
      b(x,y)=b(-1,y);
    }
}

void Intra_Chroma_Vertical(frame *f, int bx, int by) {
  int x,y;
  for(y=0; y<8; ++y)
    for(x=0; x<8; ++x) {
      r(x,y)=r(x,-1);
      b(x,y)=b(x,-1);
    }
}

void Intra_Chroma_Plane(frame *f, int bx, int by) {
  int A,B,C,H,V,x,y;
  // Intra_Chroma_Plane prediction for Cr channel
  for(x=0, H=0; x<4; ++x) H+=(x+1)*(r(4+x,-1)-r(2-x,-1));
  for(y=0, V=0; y<4; ++y) V+=(y+1)*(r(-1,4+y)-r(-1,2-y));
  A=16*(r(-1,7)+r(7,-1));
  B=(17*H+16)>>5; C=(17*V+16)>>5;
  for(y=0; y<8; ++y) for(x=0; x<8; ++x)
    r(x,y)=Clip((A+B*(x-3)+C*(y-3)+16)>>5);
  // Intra_Chroma_Plane prediction for Cr channel
  for(x=0, H=0; x<4; ++x) H+=(x+1)*(b(4+x,-1)-b(2-x,-1));
  for(y=0, V=0; y<4; ++y) V+=(y+1)*(b(-1,4+y)-b(-1,2-y));
  A=16*(b(-1,7)+b(7,-1));
  B=(17*H+16)>>5; C=(17*V+16)>>5;
  for(y=0; y<8; ++y) for(x=0; x<8; ++x)
    b(x,y)=Clip((A+B*(x-3)+C*(y-3)+16)>>5);
}

#if 0
uint32_t send_luma_intra_packet(int size, frame *f, mode_pred_info *mpi, int mode, int bx, int by, int constrained_intra_pred, int blkIdx)
{
	INTRA_INC
    uint32_t identifier = 0xFFFFFFFF;
    uint32_t data_0     = 0xFFFFFFFF;
    uint32_t data_1     = 0xFFFFFFFF;
    uint32_t data_2     = 0xFFFFFFFF;
    uint32_t data_3     = 0xFFFFFFFF;
    uint32_t data_4     = 0xFFFFFFFF;
    uint32_t data_5     = 0xFFFFFFFF;
    uint32_t data_6     = 0xFFFFFFFF;
    uint32_t data_7     = 0xFFFFFFFF;
    uint32_t data_8     = 0xFFFFFFFF;

    uint32_t availible_mask_x = 0xFFFF0000;
    uint32_t availible_mask_y = 0x0000FFFF;

    if(size == 16)
    {   int i = get_mb_mode(mpi,(bx>>4)-1,by>>4);
        availible_mask_x = ((i==NA) || (IsInter(i) && constrained_intra_pred))?0:0xFFFF0000;
        i=get_mb_mode(mpi,bx>>4,(by>>4)-1);
        availible_mask_y = ((i==NA) || (IsInter(i) && constrained_intra_pred))?0:0x0000FFFF;
        data_0 = pack_luma_x(f, bx, by, -1, -1);
        data_1 = pack_luma_x(f, bx, by, 3, -1);
        data_2 = pack_luma_x(f, bx, by, 7,  -1);
        data_3 = pack_luma_x(f, bx, by, 11, -1);
        data_4 = (uint32_t) p(15, -1);
        data_5 = pack_luma_y(f, bx, by, -1, 0);
        data_6 = pack_luma_y(f, bx, by, -1, 4);
        data_7 = pack_luma_y(f, bx, by, -1, 8);
        data_8 = pack_luma_y(f, bx, by, -1, 12);
    }
    else{
        data_0 = pack_luma_x(f, bx, by, -1, -1);  //x pixels -1, 0, 1, 2
        data_1 = pack_luma_x(f, bx, by, 3, -1);   //x pixels 3, 4, 5, 6
        data_2 = pack_luma_x(f, bx, by, 7,  -1);  //x pixels 7, 8, 9, 10
        data_5 = pack_luma_y(f, bx, by, -1, 0);
        data_6 = pack_luma_y(f, bx, by, -1, 4);
        availible_mask_x = (bx>0 && ModePredInfo_Intra4x4PredMode(mpi,(bx>>2)-1,by>>2)>=0)?0xFFFF0000:0;
        availible_mask_y = (by>0 && ModePredInfo_Intra4x4PredMode(mpi,bx>>2,(by>>2)-1)>=0)?0x0000FFFF:0;
        if((blkIdx&3)==3 || blkIdx==13 || (blkIdx==5 && bx>=f->Lwidth-4)){
            data_1 &= 0xFF000000;
            data_1 =  data_1 | (data_1>>8) | (data_1>>16) | (data_1>>24);
            data_2 =  data_1;
        }
    }


    uint8_t cmd       = 0x01;
    uint8_t wr_addr   = 0x00;

    // write data 0
    uint32_t word1    = data_0<<16 | wr_addr<<8 | cmd;
    uint32_t word0    = 0xFFFF0000 | data_0>>16;
    send_flit(3, word0, word1, 1);

    // write data 1
    wr_addr  = 1;
    word1    = data_1<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_1>>16;
    send_flit(3, word0, word1, 1);

    // write data 2
    wr_addr  = 2;
    word1    = data_2<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_2>>16;
    send_flit(3, word0, word1, 1);

    // write   data 5
    wr_addr  = 5;
    word1    = data_5<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_5>>16;
    send_flit(3, word0, word1, 1);

    // write   data 6
    wr_addr  = 6;
    word1    = data_6<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_6>>16;
    send_flit(3, word0, word1, 1);

    if(size == 16){
        // write data 3
        wr_addr  = 3;
        word1    = data_3<<16 | wr_addr<<8 | cmd;
        word0    = 0xFFFF0000 | data_3>>16;
        send_flit(3, word0, word1, 1);

        // write   data 4
        wr_addr  = 4;
        word1    = data_4<<16 | wr_addr<<8 | cmd;
        word0    = 0xFFFF0000 | data_4>>16;
        send_flit(3, word0, word1, 1);

        // write   data 7
        wr_addr  = 7;
        word1    = data_7<<16 | wr_addr<<8 | cmd;
        word0    = 0xFFFF0000 | data_7>>16;
        send_flit(3, word0, word1, 1);

        // write   data 8
        wr_addr  = 8;
        word1    = data_8<<16 | wr_addr<<8 | cmd;
        word0    = 0xFFFF0000 | data_8>>16;
        send_flit(3, word0, word1, 1);
    }

    //send a intra prediction request
    cmd                      = 2;
    uint32_t  availible_mask = availible_mask_x | availible_mask_y;
    identifier     = rand()%256;

    word1 = availible_mask<<24 | mode<<16 | size<<8 | cmd;
    word0 = identifier<<24     | availible_mask>>8;

    send_flit(3, word0, word1, 1);

    return identifier;
}

#endif

uint32_t send_luma_intra_packet_2(int size, frame *f, int bx, int by, int blkIdx_test, uint64_t intra_request, int identifier)
{
    uint32_t data_0     = 0xFFFFFFFF;
    uint32_t data_1     = 0xFFFFFFFF;
    uint32_t data_2     = 0xFFFFFFFF;
    uint32_t data_3     = 0xFFFFFFFF;
    uint32_t data_4     = 0xFFFFFFFF;
    uint32_t data_5     = 0xFFFFFFFF;
    uint32_t data_6     = 0xFFFFFFFF;
    uint32_t data_7     = 0xFFFFFFFF;
    uint32_t data_8     = 0xFFFFFFFF;

    if(size == 16)
    {
        data_0 = pack_luma_x(f, bx, by, -1, -1);
        data_1 = pack_luma_x(f, bx, by, 3, -1);
        data_2 = pack_luma_x(f, bx, by, 7,  -1);
        data_3 = pack_luma_x(f, bx, by, 11, -1);
        data_4 = (uint32_t) p(15, -1);
        data_5 = pack_luma_y(f, bx, by, -1, 0);
        data_6 = pack_luma_y(f, bx, by, -1, 4);
        data_7 = pack_luma_y(f, bx, by, -1, 8);
        data_8 = pack_luma_y(f, bx, by, -1, 12);
    }
    else{
        data_0 = pack_luma_x(f, bx, by, -1, -1);  //x pixels -1, 0, 1, 2
        data_1 = pack_luma_x(f, bx, by, 3, -1);   //x pixels 3, 4, 5, 6
        data_2 = pack_luma_x(f, bx, by, 7,  -1);  //x pixels 7, 8, 9, 10
        data_5 = pack_luma_y(f, bx, by, -1, 0);
        data_6 = pack_luma_y(f, bx, by, -1, 4);
        if(blkIdx_test){
            data_1 &= 0xFF000000;
            data_1 =  data_1 | (data_1>>8) | (data_1>>16) | (data_1>>24);
            data_2 =  data_1;
        }
    }


    uint8_t cmd       = 0x01;
    uint8_t wr_addr   = 0x00;

    // write data 0
    uint32_t word1    = data_0<<16 | wr_addr<<8 | cmd;
    uint32_t word0    = 0xFFFF0000 | data_0>>16;
    send_flit(3, word0, word1, 1);

    // write data 1
    wr_addr  = 1;
    word1    = data_1<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_1>>16;
    send_flit(3, word0, word1, 1);

    // write data 2
    wr_addr  = 2;
    word1    = data_2<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_2>>16;
    send_flit(3, word0, word1, 1);

    // write   data 5
    wr_addr  = 5;
    word1    = data_5<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_5>>16;
    send_flit(3, word0, word1, 1);

    // write   data 6
    wr_addr  = 6;
    word1    = data_6<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_6>>16;
    send_flit(3, word0, word1, 1);

    if(size == 16){
        // write data 3
        wr_addr  = 3;
        word1    = data_3<<16 | wr_addr<<8 | cmd;
        word0    = 0xFFFF0000 | data_3>>16;
        send_flit(3, word0, word1, 1);

        // write   data 4
        wr_addr  = 4;
        word1    = data_4<<16 | wr_addr<<8 | cmd;
        word0    = 0xFFFF0000 | data_4>>16;
        send_flit(3, word0, word1, 1);

        // write   data 7
        wr_addr  = 7;
        word1    = data_7<<16 | wr_addr<<8 | cmd;
        word0    = 0xFFFF0000 | data_7>>16;
        send_flit(3, word0, word1, 1);

        // write   data 8
        wr_addr  = 8;
        word1    = data_8<<16 | wr_addr<<8 | cmd;
        word0    = 0xFFFF0000 | data_8>>16;
        send_flit(3, word0, word1, 1);
    }

    //send a intra prediction request

    uint64_t word_0 = intra_request>>32;
    uint64_t word_1 = intra_request&0xFFFFFFFF;

    send_flit(3, (uint32_t)word_0, (uint32_t)word_1, 1);

    return identifier;
}

#if 0
uint32_t send_chroma_intra_packet(int size, frame *f, mode_pred_info *mpi, int mode, int bx, int by, int x_avail, int y_avail, int select_cb)
{
	INTRA_INC
    uint32_t identifier = 0xFFFFFFFF;
    uint32_t data_0     = 0xFFFFFFFF;
    uint32_t data_1     = 0xFFFFFFFF;
    uint32_t data_2     = 0xFFFFFFFF;
    uint32_t data_3     = 0xFFFFFFFF;
    uint32_t data_4     = 0xFFFFFFFF;
    uint32_t data_5     = 0xFFFFFFFF;
    uint32_t data_6     = 0xFFFFFFFF;
    uint32_t data_7     = 0xFFFFFFFF;
    uint32_t data_8     = 0xFFFFFFFF;

    uint32_t availible_mask_x = x_avail?0xFFFF0000:0;
    uint32_t availible_mask_y = y_avail?0x0000FFFF:0;


    if (select_cb){
        data_0 = pack_cb_x(f, bx, by, -1, -1);
        data_1 = pack_cb_x(f, bx, by, 3, -1);
        data_2 = pack_cb_x(f, bx, by, 7,  -1);
        data_3 = pack_cb_x(f, bx, by, 11, -1);
        data_4 = (uint32_t) b(15, -1);
        data_5 = pack_cb_y(f, bx, by, -1, 0);
        data_6 = pack_cb_y(f, bx, by, -1, 4);
        data_7 = pack_cb_y(f, bx, by, -1, 8);
        data_8 = pack_cb_y(f, bx, by, -1, 12);
    }
    else{
        data_0 = pack_cr_x(f, bx, by, -1, -1);
        data_1 = pack_cr_x(f, bx, by, 3, -1);
        data_2 = pack_cr_x(f, bx, by, 7,  -1);
        data_3 = pack_cr_x(f, bx, by, 11, -1);
        data_4 = (uint32_t) r(15, -1);
        data_5 = pack_cr_y(f, bx, by, -1, 0);
        data_6 = pack_cr_y(f, bx, by, -1, 4);
        data_7 = pack_cr_y(f, bx, by, -1, 8);
        data_8 = pack_cr_y(f, bx, by, -1, 12);
    }


    uint8_t cmd       = 0x01;
    uint8_t wr_addr   = 0x00;

    // write data 0
    uint32_t word1    = data_0<<16 | wr_addr<<8 | cmd;
    uint32_t word0    = 0xFFFF0000 | data_0>>16;
    send_flit(3, word0, word1, 1);

    // write data 1
    wr_addr  = 1;
    word1    = data_1<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_1>>16;
    send_flit(3, word0, word1, 1);

    // write data 2
    wr_addr  = 2;
    word1    = data_2<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_2>>16;
    send_flit(3, word0, word1, 1);

    // write   data 5
    wr_addr  = 5;
    word1    = data_5<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_5>>16;
    send_flit(3, word0, word1, 1);

    // write   data 6
    wr_addr  = 6;
    word1    = data_6<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_6>>16;
    send_flit(3, word0, word1, 1);

    // write data 3
    wr_addr  = 3;
    word1    = data_3<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_3>>16;
    send_flit(3, word0, word1, 1);

    // write   data 4
    wr_addr  = 4;
    word1    = data_4<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_4>>16;
    send_flit(3, word0, word1, 1);

    // write   data 7
    wr_addr  = 7;
    word1    = data_7<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_7>>16;
    send_flit(3, word0, word1, 1);

    // write   data 8
    wr_addr  = 8;
    word1    = data_8<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_8>>16;
    send_flit(3, word0, word1, 1);

    //send a intra prediction request
    cmd                      = 2;
    uint32_t  availible_mask = availible_mask_x | availible_mask_y;
    identifier     = rand()%256;

    word1 = availible_mask<<24 | mode<<16 | size<<8 | cmd;
    word0 = identifier<<24     | availible_mask>>8;

    send_flit(3, word0, word1, 1);

    return identifier;
}
#endif

uint32_t send_chroma_intra_packet_2(int size, frame *f, int mode, int bx, int by, int x_avail, int y_avail, int select_cb)
{
    uint32_t identifier = 0xFFFFFFFF;
    uint32_t data_0     = 0xFFFFFFFF;
    uint32_t data_1     = 0xFFFFFFFF;
    uint32_t data_2     = 0xFFFFFFFF;
    uint32_t data_3     = 0xFFFFFFFF;
    uint32_t data_4     = 0xFFFFFFFF;
    uint32_t data_5     = 0xFFFFFFFF;
    uint32_t data_6     = 0xFFFFFFFF;
    uint32_t data_7     = 0xFFFFFFFF;
    uint32_t data_8     = 0xFFFFFFFF;

    uint32_t availible_mask_x = x_avail?0xFFFF0000:0;
    uint32_t availible_mask_y = y_avail?0x0000FFFF:0;


    if (select_cb){
        data_0 = pack_cb_x(f, bx, by, -1, -1);
        data_1 = pack_cb_x(f, bx, by, 3, -1);
        data_2 = pack_cb_x(f, bx, by, 7,  -1);
        data_3 = pack_cb_x(f, bx, by, 11, -1);
        data_4 = (uint32_t) b(15, -1);
        data_5 = pack_cb_y(f, bx, by, -1, 0);
        data_6 = pack_cb_y(f, bx, by, -1, 4);
        data_7 = pack_cb_y(f, bx, by, -1, 8);
        data_8 = pack_cb_y(f, bx, by, -1, 12);
    }
    else{
        data_0 = pack_cr_x(f, bx, by, -1, -1);
        data_1 = pack_cr_x(f, bx, by, 3, -1);
        data_2 = pack_cr_x(f, bx, by, 7,  -1);
        data_3 = pack_cr_x(f, bx, by, 11, -1);
        data_4 = (uint32_t) r(15, -1);
        data_5 = pack_cr_y(f, bx, by, -1, 0);
        data_6 = pack_cr_y(f, bx, by, -1, 4);
        data_7 = pack_cr_y(f, bx, by, -1, 8);
        data_8 = pack_cr_y(f, bx, by, -1, 12);
    }


    uint8_t cmd       = 0x01;
    uint8_t wr_addr   = 0x00;

    // write data 0
    uint32_t word1    = data_0<<16 | wr_addr<<8 | cmd;
    uint32_t word0    = 0xFFFF0000 | data_0>>16;
    send_flit(3, word0, word1, 1);

    // write data 1
    wr_addr  = 1;
    word1    = data_1<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_1>>16;
    send_flit(3, word0, word1, 1);

    // write data 2
    wr_addr  = 2;
    word1    = data_2<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_2>>16;
    send_flit(3, word0, word1, 1);

    // write   data 5
    wr_addr  = 5;
    word1    = data_5<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_5>>16;
    send_flit(3, word0, word1, 1);

    // write   data 6
    wr_addr  = 6;
    word1    = data_6<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_6>>16;
    send_flit(3, word0, word1, 1);

    // write data 3
    wr_addr  = 3;
    word1    = data_3<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_3>>16;
    send_flit(3, word0, word1, 1);

    // write   data 4
    wr_addr  = 4;
    word1    = data_4<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_4>>16;
    send_flit(3, word0, word1, 1);

    // write   data 7
    wr_addr  = 7;
    word1    = data_7<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_7>>16;
    send_flit(3, word0, word1, 1);

    // write   data 8
    wr_addr  = 8;
    word1    = data_8<<16 | wr_addr<<8 | cmd;
    word0    = 0xFFFF0000 | data_8>>16;
    send_flit(3, word0, word1, 1);

    //send a intra prediction request
    cmd                      = 2;
    uint32_t  availible_mask = availible_mask_x | availible_mask_y;
    identifier     = rand()%32 + 129;

    word1 = availible_mask<<24 | mode<<16 | size<<8 | cmd;
    word0 = identifier<<24     | availible_mask>>8;

    send_flit(3, word0, word1, 1);

    return identifier;
}


void rx_intra_packet(uint32_t identifier, frame *f, int bx, int by, int type){
    //printf("parsing intra packet!\n");
//    packet intra_packet;
//    do{
//        //printf("locating packet %d...\n", identifier);
//        peak_rx_buffer2(&intra_packet);
//        //printf("packet %d is at top of rx stack\n", intra_packet.identifier);
//    }while(intra_packet.identifier != identifier);
//    pop_rx_buffer();



	packet *intra_packet = (void *)0;
	while(intra_packet == (void *)0){
		intra_packet = get_packet_pointer_by_id(identifier);
		if(intra_packet == (void *)0){
			buffers_loop(1);
		}
	}

	//printf("found the intra packet!\n");

//    int i;
//    printf("the packet:\n");
//    for(i = 0; i < intra_packet.num_flits; i++){
//        printf("\t%016" PRIx64  "\n", intra_packet.flit[i]);
//    }



    //printf("starting packet parsing...\n");
    uint32_t block_size  = (uint32_t)(intra_packet->data.flit[0]>>32);

    if(block_size == 0){
        printf("block size was 0 setting to 4\n");
        block_size = 4;
    }


    //printf("block_size %d\n", block_size);
    uint64_t *data_flits = &intra_packet->data.flit[1];
    //printf("found data flits pointer\n");
    uint32_t data_len    = intra_packet->num_flits - 1;
    //printf("data_len: %d\n",  data_len);
    uint32_t row_len     = data_len/block_size;
    //printf("row_len: %d\n", row_len);



    //if((type == TYPE_CR) || (type == TYPE_CB)){
    //    printf("CHROMA RX: (x,y) = (%d,%d)\n", bx, by);
    //    printf("           size  = %d\n", block_size);
    //    printf("           flits = %d\n", intra_packet.num_flits);
    //}


    int x, y;
    const int samples_per_flit = 8;
    for(x = 0; x < block_size; x += 8){
        for( y = 0; y < block_size; y++){
            int flit_index = x/samples_per_flit + y * row_len;
            uint64_t the_data = data_flits[flit_index];

            if(type == TYPE_LUMA)
            {
                p(x,y)   = (uint8_t)((the_data & 0xFF00000000000000ULL)>>56);
                p(x+1,y) = (uint8_t)((the_data & 0x00FF000000000000ULL)>>48);
                p(x+2,y) = (uint8_t)((the_data & 0x0000FF0000000000ULL)>>40);
                p(x+3,y) = (uint8_t)((the_data & 0x000000FF00000000ULL)>>32);
                if(block_size > 4){
                    p(x+4,y) = (uint8_t)((the_data & 0x00000000FF000000ULL)>>24);
                    p(x+5,y) = (uint8_t)((the_data & 0x0000000000FF0000ULL)>>16);
                    p(x+6,y) = (uint8_t)((the_data & 0x000000000000FF00ULL)>>8);
                    p(x+7,y) = (uint8_t)((the_data & 0x00000000000000FFULL));
                }
            }
            if(type == TYPE_CR)
            {
                r(x,y)   = (uint8_t)((the_data & 0xFF00000000000000ULL)>>56);
                r(x+1,y) = (uint8_t)((the_data & 0x00FF000000000000ULL)>>48);
                r(x+2,y) = (uint8_t)((the_data & 0x0000FF0000000000ULL)>>40);
                r(x+3,y) = (uint8_t)((the_data & 0x000000FF00000000ULL)>>32);
                if(block_size > 4){
                    r(x+4,y) = (uint8_t)((the_data & 0x00000000FF000000ULL)>>24);
                    r(x+5,y) = (uint8_t)((the_data & 0x0000000000FF0000ULL)>>16);
                    r(x+6,y) = (uint8_t)((the_data & 0x000000000000FF00ULL)>>8);
                    r(x+7,y) = (uint8_t)((the_data & 0x00000000000000FFULL));
                }
                //printf(".");
            }
            if(type == TYPE_CB)
            {
                b(x,y)   = (uint8_t)((the_data & 0xFF00000000000000ULL)>>56);
                b(x+1,y) = (uint8_t)((the_data & 0x00FF000000000000ULL)>>48);
                b(x+2,y) = (uint8_t)((the_data & 0x0000FF0000000000ULL)>>40);
                b(x+3,y) = (uint8_t)((the_data & 0x000000FF00000000ULL)>>32);
                if(block_size > 4){
                    b(x+4,y) = (uint8_t)((the_data & 0x00000000FF000000ULL)>>24);
                    b(x+5,y) = (uint8_t)((the_data & 0x0000000000FF0000ULL)>>16);
                    b(x+6,y) = (uint8_t)((the_data & 0x000000000000FF00ULL)>>8);
                    b(x+7,y) = (uint8_t)((the_data & 0x00000000000000FFULL));
                }
                //printf("-");
            }
        }
    }



    remove_packet_with_id(identifier);
    //printf("parsing done\n");
}

void Intra_16x16_Dispatch(frame *f, int x_avail, int y_avail, int mode, int x, int y) {

  static int mode_0    = 0;
  static int mode_1    = 0;
  static int mode_2    = 0;
  static int mode_3    = 0;
  int        last_mode = 0;
  int        nocd      = 0;

        switch(mode) {
            case 0: Intra_16x16_Vertical(f,x,y); break;
            case 1: Intra_16x16_Horizontal(f,x,y); break;
            case 2: Intra_16x16_DC(f,x_avail,y_avail,x,y); break;
            case 3: Intra_16x16_Plane(f,x,y); break;
            default: printf("unsupported Intra16x16PredMode %d at %d,%d!\n",mode,x,y);
        }
}

#if 0


#undef p

///////////////////////////////////////////////// INTRA_CHROMA PREDICTION /////




void Intra_Chroma_Dispatch(frame *f, mode_pred_info *mpi, int mode, int x, int y, int constrained_intra_pred) {

    //static uint32_t noc_initd = 0;
    //if(noc_initd == 0){
        //noc_init();
        //noc_initd = 1;
    //}

    static int mode_0    = 0;
    static int mode_1    = 0;
    static int mode_2    = 0;
    static int mode_3    = 0;
    int        last_mode = 0;
    int        nocd      = 0;

    int        conv_modes[] = {2, 1, 0, 3};
    int        block_size = mode==0?4:8;

    int bx = x;
    int by = y;

    if(HW_ENABLE_CHROMA && (mode != 0))
    {
        uint32_t id = send_chroma_intra_packet(block_size, f, mpi, conv_modes[mode], x, y, 1,1, 0);
        buffers_loop(1);
        rx_intra_packet(id, f, x, y, TYPE_CR);

        id = send_chroma_intra_packet(block_size, f, mpi, conv_modes[mode], x, y, 1,1, 1);
        buffers_loop(1);
        rx_intra_packet(id, f, x, y, TYPE_CB);
    }
    else if( HW_ENABLE_CHROMA && (mode == 0)){

        uint32_t x_avail = 1;
        uint32_t y_avail = 1;

        int i=get_mb_mode(mpi,(bx>>3)-1,by>>3);
        if((i==NA) || (IsInter(i) && constrained_intra_pred)){
            x_avail = 0;
        }

        i=get_mb_mode(mpi,bx>>3,(by>>3)-1);
        if((i==NA) || (IsInter(i) && constrained_intra_pred)){
            y_avail = 0;
        }

        //0,0
        uint32_t id = send_chroma_intra_packet(block_size, f, mpi, conv_modes[mode], x, y, x_avail, y_avail, 0);
        buffers_loop(1);
        rx_intra_packet(id, f, x, y, TYPE_CR);

        id = send_chroma_intra_packet(block_size, f, mpi, conv_modes[mode], x, y, x_avail, y_avail, 1);
        buffers_loop(1);
        rx_intra_packet(id, f, x, y, TYPE_CB);

        //4,0
        id = send_chroma_intra_packet(block_size, f, mpi, conv_modes[mode], x+4, y, 1, y_avail, 0);
        buffers_loop(1);
        rx_intra_packet(id, f, x+4, y, TYPE_CR);

        id = send_chroma_intra_packet(block_size, f, mpi, conv_modes[mode], x+4, y, 1, y_avail, 1);
        buffers_loop(1);
        rx_intra_packet(id, f, x+4, y, TYPE_CB);

        //0,4
        id = send_chroma_intra_packet(block_size, f, mpi, conv_modes[mode], x, y+4, x_avail, 1, 0);
        buffers_loop(1);
        rx_intra_packet(id, f, x, y+4, TYPE_CR);

        id = send_chroma_intra_packet(block_size, f, mpi, conv_modes[mode], x, y+4, x_avail, 1, 1);
        buffers_loop(1);
        rx_intra_packet(id, f, x, y+4, TYPE_CB);

        //4,4
        id = send_chroma_intra_packet(block_size, f, mpi, conv_modes[mode], x+4, y+4, 1,1, 0);
        buffers_loop(1);
        rx_intra_packet(id, f, x+4, y+4, TYPE_CR);

        id = send_chroma_intra_packet(block_size, f, mpi, conv_modes[mode], x+4, y+4, 1,1, 1);
        buffers_loop(1);
        rx_intra_packet(id, f, x+4, y+4, TYPE_CB);
    }
    else{
        switch(mode) {
            case 0: Intra_Chroma_DC(f,mpi,x,y,constrained_intra_pred); break;
            case 1: Intra_Chroma_Horizontal(f,x,y); break;
            case 2: Intra_Chroma_Vertical(f,x,y); break;
            case 3: Intra_Chroma_Plane(f,x,y); break;
            default: printf("unsupported IntraChromaPredMode %d at %d,%d!\n",mode,x<<1,y<<1);
        }
    }
}
#endif
void Intra_Chroma_Dispatch_2(frame *f, int mode, int x, int y, uint32_t x_avail, uint32_t y_avail) {

    //static uint32_t noc_initd = 0;
    //if(noc_initd == 0){
        //noc_init();
        //noc_initd = 1;
    //}

    static int mode_0    = 0;
    static int mode_1    = 0;
    static int mode_2    = 0;
    static int mode_3    = 0;
    int        last_mode = 0;
    int        nocd      = 0;

    int        conv_modes[] = {2, 1, 0, 3};
    int        block_size = mode==0?4:8;

    int bx = x;
    int by = y;

    if(HW_ENABLE_CHROMA && (mode != 0))
    {
        uint32_t id = send_chroma_intra_packet_2(block_size, f, conv_modes[mode], x, y, 1,1, 0);
        //buffers_loop(1);
        rx_intra_packet(id, f, x, y, TYPE_CR);

        id = send_chroma_intra_packet_2(block_size, f, conv_modes[mode], x, y, 1,1, 1);
        //buffers_loop(1);
        rx_intra_packet(id, f, x, y, TYPE_CB);
    }
    else if( HW_ENABLE_CHROMA && (mode == 0)){

        //0,0
        uint32_t id = send_chroma_intra_packet_2(block_size, f, conv_modes[mode], x, y, x_avail, y_avail, 0);
        //buffers_loop(1);
        rx_intra_packet(id, f, x, y, TYPE_CR);

        id = send_chroma_intra_packet_2(block_size, f, conv_modes[mode], x, y, x_avail, y_avail, 1);
        //buffers_loop(1);
        rx_intra_packet(id, f, x, y, TYPE_CB);

        //4,0
        id = send_chroma_intra_packet_2(block_size, f, conv_modes[mode], x+4, y, 1, y_avail, 0);
        //buffers_loop(1);
        rx_intra_packet(id, f, x+4, y, TYPE_CR);

        id = send_chroma_intra_packet_2(block_size, f, conv_modes[mode], x+4, y, 1, y_avail, 1);
        //buffers_loop(1);
        rx_intra_packet(id, f, x+4, y, TYPE_CB);

        //0,4
        id = send_chroma_intra_packet_2(block_size, f, conv_modes[mode], x, y+4, x_avail, 1, 0);
        //buffers_loop(1);
        rx_intra_packet(id, f, x, y+4, TYPE_CR);

        id = send_chroma_intra_packet_2(block_size, f, conv_modes[mode], x, y+4, x_avail, 1, 1);
        //buffers_loop(1);
        rx_intra_packet(id, f, x, y+4, TYPE_CB);

        //4,4
        id = send_chroma_intra_packet_2(block_size, f, conv_modes[mode], x+4, y+4, 1,1, 0);
        //buffers_loop(1);
        rx_intra_packet(id, f, x+4, y+4, TYPE_CR);

        id = send_chroma_intra_packet_2(block_size, f, conv_modes[mode], x+4, y+4, 1,1, 1);
        //buffers_loop(1);
        rx_intra_packet(id, f, x+4, y+4, TYPE_CB);
    }
    else{ //sw mode not supported for this version of chroma intra

    	printf("What are you doing in here?!?!\n");

//        switch(mode) {
//            case 0: Intra_Chroma_DC(f,mpi,x,y,constrained_intra_pred); break;
//            case 1: Intra_Chroma_Horizontal(f,x,y); break;
//            case 2: Intra_Chroma_Vertical(f,x,y); break;
//            case 3: Intra_Chroma_Plane(f,x,y); break;
//            default: printf("unsupported IntraChromaPredMode %d at %d,%d!\n",mode,x<<1,y<<1);
//        }
    }
}


void software_intra(frame *f, int size, int mode, int x, int y, uint32_t x_avail, uint32_t y_avail, int LCbCr, int luma4x4BlkIdx_check){
	if(LCbCr == 0){
		switch(size){
			case 4:  Intra_4x4_Dispatch(f, mode, x_avail, y_avail, x, y, luma4x4BlkIdx_check); break;
			case 16: Intra_16x16_Dispatch(f, x_avail, y_avail, mode, x, y); break;
			default: printf("bad intra prediction size (%d)!\n", size);
		}
	}
	else{
        switch(mode) {
            case 0: Intra_Chroma_DC(f, x_avail, y_avail, x, y); break;
            case 1: Intra_Chroma_Horizontal(f,x,y); break;
            case 2: Intra_Chroma_Vertical(f,x,y); break;
            case 3: Intra_Chroma_Plane(f,x,y); break;
            default: printf("unsupported IntraChromaPredMode %d at %d,%d!\n",mode,x<<1,y<<1);
        }
	}
}




#undef r
#undef b
#undef p
