#ifndef HW_TIMER_H
#define HW_TIMER_H

#include <inttypes.h>
#include <altera_avalon_pio_regs.h>
#include <system.h>
#include "noc_control.h"

#define TIMER_REG RX_2_BASE

#define TOTAL_DECODE_COUNTS 0
#define TOTAL_INTRA_COUNTS  1
#define TOTAL_INTER_COUNTS  2
#define TOTAL_DB_COUNTS     3
#define TOTAL_VGA_COUNTS    4
#define HW_INTRA_COUNTS     5
#define HW_INTER_COUNTS     6
#define HW_DB_COUNTS        7
#define PARSER_COUNTS       8
#define NOC_SEND_COUNTS     9
#define NOC_RECEIVE_COUNTS  10

uint64_t read_timer();
void add_time(int counter_select, uint64_t counts);
void print_counts();

#endif
