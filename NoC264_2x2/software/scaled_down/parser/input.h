#ifndef __INPUT_H__
#define __INPUT_H__

#define NAL_BUF_SIZE  65536  // maximum NAL unit size
#define RING_BUF_SIZE  8192  // input ring buffer size, MUST be a power of two!

int input_open(char *filename);
void input_rewind();
int input_read(unsigned char *dest, int size);
void input_close();

int input_peek_bits(int bit_count);
void input_step_bits(int bit_count);
int input_get_bits(int bit_count);

int input_get_one_bit();

int input_byte_aligned();
void input_align_to_next_byte();
int input_get_byte();

#endif /*__INPUT_H__*/
