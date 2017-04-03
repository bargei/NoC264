#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
//#include <sys/mman.h>
#include <fcntl.h>

#include "common.h"
#include "input.h"

unsigned char nal_buf[NAL_BUF_SIZE];
unsigned char ring_buf[RING_BUF_SIZE];
int input_size;
int input_remain;
int ring_pos;
int nal_pos;
int nal_bit;


static inline int __peek_bits(int bit_count) {
  register unsigned int x=
    (nal_buf[nal_pos]<<24)|
    (nal_buf[nal_pos+1]<<16)|
    (nal_buf[nal_pos+2]<<8)|
     nal_buf[nal_pos+3];
  return (x>>(32-bit_count-nal_bit))&((1<<bit_count)-1);
}

static inline void __step_bits(int bit_count) {
  nal_bit+=bit_count;
  nal_pos+=nal_bit>>3;
  nal_bit&=7;
}

int input_peek_bits(int bit_count) {
  return __peek_bits(bit_count);
}

void input_step_bits(int bit_count) {
  __step_bits(bit_count);
}

int input_get_bits(int bit_count) {
  int res=__peek_bits(bit_count);
  __step_bits(bit_count);
  return res;
}

int input_get_one_bit() {
  int res=(nal_buf[nal_pos]>>(7-nal_bit))&1;
  if(++nal_bit>7) {
    ++nal_pos;
    nal_bit=0;
  }
  return res;
}

int input_byte_aligned() {
  return (!nal_bit);
}

void input_align_to_next_byte() {
  if(input_byte_aligned()) return;
  ++nal_pos;
  nal_bit=0;
}

int input_get_byte() {
  return nal_buf[nal_pos++];
}
