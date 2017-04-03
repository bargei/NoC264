#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "perf.h"

#define HASH_OFFSET 0x13375EED

#define HASH_SIZE (1<<(PERF_HASH_BITS))
#define HASH_MOD ((HASH_SIZE)-1)

typedef struct _perf_entry {
  char *name;
  INT64 clocks;
} perf_entry;

perf_entry *perf_data=NULL;
perf_entry *perf_current=NULL;
INT64 perf_last_clock;


void perf_enable() {
  perf_data=calloc(HASH_SIZE,sizeof(perf_entry));
  perf_last_clock=0L;
}

void perf_enter(char *section) {
  INT64 now; 
  if(!perf_data) return;

#ifdef PERF_METHOD_x86
  asm(".byte 0x0f, 0x31":
    "=a" (((unsigned int *)(&now))[0]),
    "=d" (((unsigned int *)(&now))[1]));
#else
  now=0;
#endif

  if(perf_current) perf_current->clocks+=now-perf_last_clock;
  perf_current=&perf_data[(((unsigned int)section)+HASH_OFFSET)&HASH_MOD];
  perf_current->name=section;
  perf_last_clock=now;
}

void perf_summarize() {
  INT64 total;
  int i;
  perf_entry *e;
  if(!perf_data) return;

  perf_enter(NULL);
  for(e=perf_data, i=HASH_SIZE, total=0; i; --i)
    total+=(e++)->clocks;
  for(e=perf_data, i=HASH_SIZE; i; --i, ++e)
    if(e->name)
      printf("%20.0f |%6.2f%% | %s\n",(double)e->clocks,(100.0*e->clocks/total),e->name);
}


///////////////////////////////////////////////////////////////////////////////

#ifdef BUILD_TESTS

#include <unistd.h>

int _test_perf(int argc, char *argv[]) {
  perf_enable();
  perf_enter("2 sec. sleep"); sleep(2);
  perf_enter("1 sec. sleep"); sleep(1);
  perf_summarize();
  return 0;
}

#endif
