#ifndef __NAL_H__
#define __NAL_H__

typedef struct _nal_unit {
  int NumBytesInNALunit;
  int forbidden_zero_bit;
  int nal_ref_idc;
  int nal_unit_type;
  unsigned char *last_rbsp_byte;
} nal_unit;

int get_next_nal_unit(nal_unit *nalu);

int more_rbsp_data(nal_unit *nalu);

char *_str_nal_unit_type(int type);

#endif /*__NAL_H__*/
