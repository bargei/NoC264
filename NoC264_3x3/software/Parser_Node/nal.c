#include "common.h"
#include "input.h"
#include "nal.h"

extern unsigned char nal_buf[NAL_BUF_SIZE];
extern unsigned char ring_buf[RING_BUF_SIZE];
extern int input_remain;
extern int input_pos;
extern int input_bit;
extern int ring_pos;
extern int nal_pos;
extern int nal_bit;
extern unsigned char *input_buf;


#define RING_MOD  ((RING_BUF_SIZE)-1)
#define HALF_RING ((RING_BUF_SIZE)/2)

#define gnn_advance() do { \
          ring_pos=(ring_pos+1)&RING_MOD; \
          --input_remain; \
          if(ring_pos==0) input_read(&ring_buf[HALF_RING],HALF_RING); \
          if(ring_pos==HALF_RING) input_read(&ring_buf[0],HALF_RING); \
        } while(0)

#define gnn_add_segment(end) do { \
          int size=end-segment_start; \
          if(size>0) { \
            memcpy(&nal_buf[nalu_size],&ring_buf[segment_start],size); \
            nalu_size+=size; \
          } \
          segment_start=end&RING_MOD; \
        } while(0)


int get_next_nal_unit(nal_unit *nalu) {
  int i,segment_start;
  int nalu_size=0;
  
  // search for the next NALU start
  for(;;) {
    if(input_remain<=4) return 0;
    if((!ring_buf[ring_pos]) &&
       (!ring_buf[(ring_pos+1)&RING_MOD]) &&
       (!ring_buf[(ring_pos+2)&RING_MOD]) &&
       ( ring_buf[(ring_pos+3)&RING_MOD]==1))
      break;
    gnn_advance();
  }
  for(i=0; i<4; ++i) gnn_advance();
  
  // add bytes to the NALU until the end is found
  segment_start=ring_pos;
  while(input_remain) {
    if((!ring_buf[ring_pos]) &&
       (!ring_buf[(ring_pos+1)&RING_MOD]) &&
       (!ring_buf[(ring_pos+2)&RING_MOD]))
      break;
    ring_pos=(ring_pos+1)&RING_MOD;
    --input_remain;
    if(ring_pos==0) {
      gnn_add_segment(RING_BUF_SIZE);
      input_read(&ring_buf[HALF_RING],HALF_RING);
    }
    if(ring_pos==HALF_RING) {
      gnn_add_segment(HALF_RING);
      input_read(&ring_buf[0],HALF_RING);
    }
  }
  gnn_add_segment(ring_pos);
  if(!nalu_size) return 0;
  
  // read the NAL unit
  nal_pos=0; nal_bit=0;
  nalu->forbidden_zero_bit=input_get_bits(1);
  nalu->nal_ref_idc=input_get_bits(2);
  nalu->nal_unit_type=input_get_bits(5);
  nalu->last_rbsp_byte=&nal_buf[nalu_size-1];
  nalu->NumBytesInNALunit=nalu_size;
  return 1;
}


int more_rbsp_data(nal_unit *nalu) {
  return &nal_buf[nal_pos]<=nalu->last_rbsp_byte;
}


char *_str_nal_unit_type(int type) {
  switch(type) {
    case  1: return "Coded slice of a non-IDR picture";
    case  2: return "Coded slice data partition A";
    case  3: return "Coded slice data partition B";
    case  4: return "Coded slice data partition C";
    case  5: return "Coded slice of an IDR picture";
    case  6: return "Supplemental enhancement information (SEI)";
    case  7: return "Sequence parameter set";
    case  8: return "Picture parameter set";
    case  9: return "Access unit delimiter";
    case 10: return "End of sequence";
    case 11: return "End of stream";
    case 12: return "Filler data";
    default:
      if(type && (type<24)) return "Reserved";
  }
  return "Unspecified";
}


///////////////////////////////////////////////////////////////////////////////

#ifdef BUILD_TESTS

int _test_nal(int argc, char *argv[]) {
  nal_unit unit;
  int count;

  if(!input_open("../streams/in.264")) return 1;

  for(count=1; get_next_nal_unit(&unit); ++count) {
    printf("%d: count=%d zero=%d ref_idc=%d type: %s\n",count,
      unit.NumBytesInNALunit,unit.forbidden_zero_bit,
      unit.nal_ref_idc,_str_nal_unit_type(unit.nal_unit_type));
  }
  
  input_close();
  return 0;
}

#endif
