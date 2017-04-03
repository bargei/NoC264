#include "common.h"
#include "input.h"

FILE *input_fd=NULL;

extern int input_size;
extern int input_remain;
extern int ring_pos;
extern unsigned char ring_buf[RING_BUF_SIZE];

int input_open(char *filename) {
  if(input_fd) {
    fprintf(stderr,"input_open: file already opened\n");
    return 0;
  }
  input_fd=fopen(filename,"rb");

  const int in_buff_size = 4000000;
  char *out_buf[in_buff_size];
  setvbuf(input_fd, out_buf, _IOFBF, in_buff_size);


  if(!input_fd) {
    perror("input_open: cannot open file");
    return 0;
  }
  fseek(input_fd,0,SEEK_END);
  input_size=ftell(input_fd);
  input_rewind();
  return input_size;
}

int input_read(unsigned char *dest, int size) {
  int count=fread(dest,1,size,input_fd);
  input_remain+=count;
  return count;
}

void input_rewind() {
  if(!input_fd) {
    fprintf(stderr,"input_rewind called, but no file opened!\n");
    return;
  }
  fseek(input_fd,0,SEEK_SET);
  input_remain=0;
  input_read(ring_buf,RING_BUF_SIZE);
  ring_pos=0;
}

void input_close() {
  if(!input_fd) return;
  fclose(input_fd);
  input_size=0;
  input_fd=NULL;
}
