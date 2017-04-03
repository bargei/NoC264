#ifndef __CAVLC_H__
#define __CAVLC_H__

typedef struct _code_table_item {
  unsigned int code;
  int bits;
  int data;
} code_table_item;

typedef struct _code_table {
  int count;
  code_table_item *items;
} code_table;

code_table *init_code_table(code_table_item *items);
int get_code(code_table *table);

int get_unsigned_exp_golomb();
int get_signed_exp_golomb();

#endif /*__CAVLC_H__*/
