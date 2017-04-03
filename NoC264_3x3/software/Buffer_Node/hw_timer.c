#include "hw_timer.h"
static uint64_t counters[11] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

uint64_t read_timer(){

	static uint32_t last_read = 0;
	static uint32_t overflow_count = 0;

	uint32_t timer_read = RD_PIO(TIMER_REG);
	int is_overflow = (last_read > timer_read)?1:0;
	overflow_count += is_overflow;

	last_read = timer_read;

	return (uint64_t)timer_read + (((uint64_t)overflow_count)<<32);
}

void add_time(int counter_select, uint64_t counts){
	counters[counter_select] += counts;
}

void print_counts(){
	printf("TOTAL_DECODE_COUNTS    %f\n", 1.0 * counters[TOTAL_DECODE_COUNTS] / 50000000.0);
	printf("TOTAL_INTRA_COUNTS     %f\n", 1.0 * counters[TOTAL_INTRA_COUNTS ] / 50000000.0);
	printf("TOTAL_INTER_COUNTS     %f\n", 1.0 * counters[TOTAL_INTER_COUNTS ] / 50000000.0);
	printf("TOTAL_DB_COUNTS        %f\n", 1.0 * counters[TOTAL_DB_COUNTS    ] / 50000000.0);
	printf("TOTAL_VGA_COUNTS       %f\n", 1.0 * counters[TOTAL_VGA_COUNTS   ] / 50000000.0);
	printf("HW_INTRA_COUNTS        %f\n", 1.0 * counters[HW_INTRA_COUNTS    ] / 50000000.0);
	printf("HW_INTER_COUNTS        %f\n", 1.0 * counters[HW_INTER_COUNTS    ] / 50000000.0);
	printf("HW_DB_COUNTS           %f\n", 1.0 * counters[HW_DB_COUNTS       ] / 50000000.0);
	printf("PARSER_COUNTS          %f\n", 1.0 * counters[PARSER_COUNTS      ] / 50000000.0);
	printf("NOC_SEND_COUNTS        %f\n", 1.0 * counters[NOC_SEND_COUNTS    ] / 50000000.0);
	printf("NOC_RECEIVE_COUNTS     %f\n", 1.0 * counters[NOC_RECEIVE_COUNTS ] / 50000000.0);
}
