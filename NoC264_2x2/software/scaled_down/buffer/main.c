#include "common.h"
#include "noc_control.h"
#include <time.h>
#include "Buffer_Node_Sim.h"
#include "noc_control.h"

int main(void){
	noc_init();

	while(get_buffer_rx_state()){
		buffers_loop(1);
	}

	noc_init();

	while(1){
		simulate_buffer_node();
		//buffer_comm_test();
	}
}
