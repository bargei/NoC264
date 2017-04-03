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

core_block hadamard(core_block coeff) {
  CONST core_block transform={{1,1,1,1,1,1,-1,-1,1,-1,-1,1,1,-1,1,-1}};
  return core_block_multiply(transform,core_block_multiply(coeff,transform));
}
