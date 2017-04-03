#include "common.h"
#include "input.h"
#include "cavlc.h"


code_table *init_code_table(code_table_item *items) {
  code_table *res=malloc(sizeof(code_table));
  code_table_item *pos;
  int count=0;
  for(pos=items; pos && pos->code!=0xFFFFFFFF; ++pos) ++count;
  res->items=items;
  res->count=count;
  return res;
}

int get_code(code_table *table) {
  unsigned int code=input_peek_bits(24)<<8;
  int min=0, max=table->count;
  while(max-min>1) {
    int mid=(min+max)>>1;
    if(code>=table->items[mid].code) min=mid; else max=mid;
  }
  input_step_bits(table->items[min].bits);
  return table->items[min].data;
}


int get_unsigned_exp_golomb() {
  int exp;
  for(exp=0; !input_get_one_bit(); ++exp);
  if(exp) return (1<<exp)-1+input_get_bits(exp);
     else return 0;
}

int get_signed_exp_golomb() {
  int code=get_unsigned_exp_golomb();
  return (code&1) ? (code+1)>>1 : -(code>>1);
}
