#include "common.h"
#include "coretrans.h"

core_block core_block_multiply(core_block a, core_block b) {
  int i,j,k;
  int sum;
  core_block res;
  
  for(i=0; i<4; ++i)
    for(j=0; j<4; ++j) {
      sum=0;
      for(k=0; k<4; ++k)
        sum+=CoreBlock(a,i,k)*CoreBlock(b,k,j);
      CoreBlock(res,i,j)=sum;
    }
  return res;
}

core_block forward_core_transform(core_block original) {
  CONST core_block transform0={{1,1,1,1,2,1,-1,-2,1,-1,-1,1,1,-2,2,-1}};
  CONST core_block transformT={{1,2,1,1,1,1,-1,-2,1,-1,-1,2,1,-2,1,-1}};

  core_block temp=core_block_multiply(transform0,original);
  return core_block_multiply(temp,transformT);
}

#define QP0   13107,8066,13107,8066, 8066,5243,8066,5243
#define QP1   11916,7490,11916,7490, 7490,4660,7490,4660
#define QP2   10082,6554,10082,6554, 6554,4194,6554,4194
#define QP3    9362,5825, 9352,5825, 5825,3647,5825,3647
#define QP4    8192,5243, 8192,5243, 5243,3355,5243,3355
#define QP5    7282,4559, 7282,4559, 4559,2893,4559,2893

core_block forward_quantize(core_block raw, int quantizer, int rounding_mode) {
  CONST core_block factors[6]={{{QP0,QP0}},{{QP1,QP1}},{{QP2,QP2}},
                               {{QP3,QP3}},{{QP4,QP4}},{{QP5,QP5}}};
  int qbits=(quantizer/6)+15;
  int table=(quantizer%6);
  int round_adjust=(1<<qbits)/rounding_mode;
  int l;
  core_block res;

  for(l=0; l<16; ++l) {
    int value=raw.items[l];
    res.items[l]=CombineSign(ExtractSign(value),
                 (abs(value)*factors[table].items[l]+round_adjust)>>qbits);
  }
  return res;
}

#define DQP0  10,13,10,13, 13,16,13,16
#define DQP1  11,14,11,14, 14,18,14,18
#define DQP2  13,16,13,16, 16,20,16,20
#define DQP3  14,18,14,18, 18,23,18,23
#define DQP4  16,20,16,20, 20,25,20,25
#define DQP5  18,23,18,23, 23,29,23,29

core_block inverse_quantize(core_block quantized, int quantizer, int without_dc) {
  CONST core_block factors[6]={{{DQP0,DQP0}},{{DQP1,DQP1}},{{DQP2,DQP2}},
                               {{DQP3,DQP3}},{{DQP4,DQP4}},{{DQP5,DQP5}}};
  int qbits=quantizer/6;
  int table=quantizer%6;
  int l;
  core_block res;

  if(without_dc) res.items[0]=quantized.items[0];
  for(l=without_dc; l<16; ++l) {
    int value=quantized.items[l];
    res.items[l]=CombineSign(ExtractSign(value),
                 (abs(value)*factors[table].items[l])<<qbits);
  }
  return res;
}

core_block inverse_core_transform_slow(core_block coeff) {
	printf("inverse_core_transform_slow\n");
  CONST core_block transform0={{2,2,2,1,2,1,-2,-2,2,-1,-2,2,2,-2,2,-1}};
  CONST core_block transformT={{2,2,2,2,2,1,-1,-2,2,-2,-2,2,1,-2,2,-1}};

  core_block temp=core_block_multiply(transform0,coeff);
  core_block scaled=core_block_multiply(temp,transformT);
  int l;
  for(l=0; l<16; ++l) {
    scaled.items[l]=(scaled.items[l]+128)>>8;
  }
  return scaled;
}


core_block inverse_core_transform_fast(core_block coeff) {
	printf("inverse_core_transform_fast\n");
  core_block temp=coeff;
  int i,e0,e1,e2,e3,*l=&temp.items[0];
  for(i=0;i<4;++i) {
    e0=l[0]+l[2];
    e1=l[0]-l[2];
    e2=(l[1]>>1)-l[3];
    e3=l[1]+(l[3]>>1);
    *l++=e0+e3;
    *l++=e1+e2;
    *l++=e1-e2;
    *l++=e0-e3;
  }
  for(i=0;i<4;++i) {
    l=&temp.items[i];
    e0=l[0]+l[8];
    e1=l[0]-l[8];
    e2=(l[4]>>1)-l[12];
    e3=l[4]+(l[12]>>1);
    l[0] =(e0+e3+32)>>6;
    l[4] =(e1+e2+32)>>6;
    l[8] =(e1-e2+32)>>6;
    l[12]=(e0-e3+32)>>6;
  }
  return temp;
}

static inline void enter(unsigned char *ptr, int q_delta) {
  register int i=*ptr+((q_delta+32)>>6);
#ifdef USE_X86_ASM
  asm(" \
    cdq;              \
    notl %%edx;       \
    andl %%edx,%%eax; \
    subl $256, %%eax; \
    cdq;              \
    notl %%edx;       \
    orl  %%edx,%%eax; \
  ":"=a"(i):"a"(i):"%edx");
  *ptr=i;
#else
  *ptr=Clip(i);
#endif
}

void direct_ict(core_block coeff, unsigned char *img, int pitch, int *test) {
  //printf("pitch: %d\n", pitch);

  core_block temp=coeff;
  int i,e0,e1,e2,e3,*l =&temp.items[0];

  int testd[16];

  for(i=0;i<4;++i) {
	//l=&temp.items[i];
    e0=l[0]+l[2];
    e1=l[0]-l[2];
    e2=(l[1]>>1)-l[3];
    e3=l[1]+(l[3]>>1);
    *l    =e0+e3;
    *(l+1)=e1+e2;
    *(l+2)=e1-e2;
    *(l+3)=e0-e3;

    l+=4;
  }
  for(i=0;i<4;++i) {
    l=&temp.items[i];
    e0=l[0]+l[8];
    e1=l[0]-l[8];
    e2=(l[4]>>1)-l[12];
    e3=l[4]+(l[12]>>1);
//    enter(&img[0]       ,e0+e3);
//    enter(&img[pitch]   ,e1+e2);
//    enter(&img[pitch<<1],e1-e2);
//    enter(&img[pitch*3] ,e0-e3);
//    ++img;
    testd[i]      = e0+e3;
    testd[i + 4]  = e1+e2;
    testd[i + 8]  = e1-e2;
    testd[i + 12] = e0-e3;

  }

  for(i=0; i < 4; i++){
	  enter(&img[0       ], testd[i]);
	  enter(&img[pitch   ], testd[i+4]);
	  enter(&img[pitch<<1], testd[i+8]);
	  enter(&img[pitch*3 ], testd[i+12]);
	  img++;
  }

  //img-=4;

//  int match = 1;
//  for(int i = 0; i < 16; i++)
//  {
//	  if(test[i] != noc_res[i])
//	  {
//		  match = 0;
//	  }
//  }
//
//  if(match == 0){
//	  printf("\n----------------\n");
//	  printf("not from noc: ");
//	  for(int i = 0; i < 16; i++){
//		  printf("%d ", (test[i]+32)>>6);
//	  }
//
//  }
//  return match;
//
//  int hold_on_a_minute = 0;
//  for(int i= 0; i < 16; i++)
//  {
//	  printf("%d ", ((testd[i]+32)>>6) - test[i]);
//	  if(abs(((testd[i]+32)>>6) - test[i])> 10)
//	  {
//		  hold_on_a_minute = 1;
//	  }
//  }
//
//  while(hold_on_a_minute){}
//
//  printf("|");
//  for(int i= 0; i < 16; i++)
//    {
//  	  printf("%d ", ((testd[i]+32)>>6));
//    }
//
//
//  printf("\n");
}

core_block hadamard(core_block coeff) {
  CONST core_block transform={{1,1,1,1,1,1,-1,-1,1,-1,-1,1,1,-1,1,-1}};
  return core_block_multiply(transform,core_block_multiply(coeff,transform));
}


////////////////////////////////////////////////////////////////////////////////

void _dump_core_block(core_block block) {
  int i,j;
  for(i=0; i<4; ++i) {
    for(j=0; j<4; ++j)
      printf("%5d",CoreBlock(block,i,j));
    printf("\n");
  }
  printf("\n");
}

#ifdef BUILD_TESTS

int _test_coretrans(int argc, char *argv[]) {

  core_block test_block={{5,11,8,10,9,8,4,12,1,10,11,4,19,6,15,7}};
  int quantizer=10;
  int mode=IntraRoundingMode;
  
  core_block temp;  
  printf("Original block:\n");
  _dump_core_block(test_block);
  temp=forward_core_transform(test_block);
  printf("Forward core transform:\n");
  _dump_core_block(temp);
  temp=forward_quantize(temp,quantizer,mode);
  printf("Forward quantizer:\n");
  _dump_core_block(temp);
  temp=inverse_quantize(temp,quantizer,0);
  printf("Inverse quantizer:\n");
  _dump_core_block(temp);
  temp=inverse_core_transform(temp);
  printf("Inverse core transform:\n");
  _dump_core_block(temp);
  
  return 0;
}

#endif
