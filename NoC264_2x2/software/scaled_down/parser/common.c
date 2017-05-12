#include "common.h"
#include "params.h"
#include "main.h"

frame *alloc_frame(int width, int height) {
  frame *f=calloc(1,sizeof(frame));
  f->Lwidth=f->Lpitch=width;
  f->Lheight=height;
  f->L=malloc(width*height);
  f->Cwidth=f->Cpitch=width>>1;
  f->Cheight=height>>1;
  f->C[0]=malloc(width*height/4);
  f->C[1]=malloc(width*height/4);
  return f;
}

void free_frame(frame *f) {
  if(!f) return;
  if(f->L) free(f->L);
  if(f->C[0]) free(f->C[0]);
  if(f->C[0]) free(f->C[1]);
  free(f);
}
