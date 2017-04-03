#include <system.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include "noc_control.h"
#include <altera_avalon_pio_regs.h>

static void *base_addr;
static buffer the_buffer;

static int total_flits = 0;

void noc_init()
{
    printf("initializing network!\n");
    
    the_buffer.top_of_stack = 0;
    int i;
    for(i = 0; i < MAX_PACKETS; i++){
        the_buffer.the_packets[i].num_flits = 0;
    }
    

    WR_PIO(NOC_CTRL_BASE, NOC_RESET);

    usleep(100);
    
    WR_PIO(NOC_CTRL_BASE, 0);
}

void send_flit(uint32_t dest, uint32_t word0, uint32_t word1, uint32_t set_tail)
{
    //wait for ack to go low
    while(RD_PIO(NOC_STS_BASE) & TX_ACK_BIT);
    
    //THIS IS A LEGACY FUNCTION
    //only send in mode 2
    WR_PIO(TX_0_BASE, word0);
    WR_PIO(TX_1_BASE, word1);
    
    //set control values
    int ncv = (dest<<16) | (set_tail?TAIL_FLIT_BIT:0) | CPU_TX_REQ | FORMAT_2;

    no_data_send(ncv);

    for(volatile int wait = 0; wait < 24; wait++);

}

void no_data_send(uint32_t format_code){
    //sends data assuming it has already been written to PIOs

    //wait for ack to go low
    while(RD_PIO(NOC_STS_BASE) & TX_ACK_BIT);

    //set control values
    WR_PIO(NOC_CTRL_BASE, format_code);

    //wait for ack to go high
    while((RD_PIO(NOC_STS_BASE) & TX_ACK_BIT) == 0);

    //clear ctrl value
    WR_PIO(NOC_CTRL_BASE, 0);
}

uint32_t get_id_of_top_packet(){
	return the_buffer.the_packets[the_buffer.top_of_stack-1].identifier;
}


uint32_t get_buffer_rx_state()
{
    uint32_t state = RD_PIO(NOC_STS_BASE);
    return state & 0xFF;
}



uint32_t copy_to_buffer(uint32_t id)
{
    uint32_t packet_index = the_buffer.top_of_stack;
    uint32_t flit_index   = the_buffer.the_packets[packet_index].num_flits;
    
    uint32_t flit_top    = RD_PIO(RX_0_BASE);
    uint32_t flit_bottom = RD_PIO(RX_1_BASE);
    
    uint64_t *flit_stack = &(the_buffer.the_packets[packet_index].data.flit[flit_index++]);
    *(uint32_t *)flit_stack                                 = flit_bottom;
    *(((uint32_t *)flit_stack)+1)                           = flit_top;
    the_buffer.the_packets[packet_index].num_flits          = flit_index;
    the_buffer.the_packets[packet_index].identifier         = id;
    the_buffer.the_packets[packet_index].src_addr           = 0;

    return 1;
}

void set_cpu_read_flag(int value)
{
    uint32_t noc_ctrl_value = RD_PIO(NOC_CTRL_BASE);
    if( value != 0)
    {
    	noc_ctrl_value |= CPU_RX_CTRL;
    }
    else
    {
    	noc_ctrl_value &= (~CPU_RX_CTRL);
    }
    WR_PIO(NOC_CTRL_BASE, noc_ctrl_value);
}

uint32_t get_identifier()
{
    return RD_PIO(RX_1_BASE) & 0xFF;
}

uint32_t buffers_loop(uint32_t packet_count)
{
    uint32_t id = 0;
    uint32_t packets_rxd = 0;
    uint32_t packets_rxd_next = 0;
    uint32_t next_packet = the_buffer.top_of_stack;
    uint32_t infinite_loops = (packet_count==0)?1:0;
    
    
    while(infinite_loops || (packets_rxd < packet_count))
    {
    	int the_state = get_buffer_rx_state();
    	switch(the_state){
    	case BUFFER_IDLE:
    		packets_rxd = packets_rxd_next;
    		break;
    	case BUFFER_ADDR_RST:
    		set_cpu_read_flag(1);
    		packets_rxd = packets_rxd_next;
    		while(get_buffer_rx_state() != BUFFER_START_READ);
    		break;
    	case BUFFER_START_READ:
    		id = get_identifier();
    		the_buffer.top_of_stack = next_packet;
    		next_packet += 1;
    		packets_rxd_next += 1;
    		set_cpu_read_flag(0);
    		break;
    	case BUFFER_RXD:
    		copy_to_buffer(id);
    		set_cpu_read_flag(1);
    		break;
    	case BUFFER_WAIT_CPU:
    		set_cpu_read_flag(0);
    		break;
    	case BUFFER_SEL_VC:
    		break;
    	case BUFFER_DEQUEUE:
    		break;
    	case BUFFER_WAIT_FLITS:
    		break;
    	default:
    		break;
    	}
    }
    
    the_buffer.top_of_stack = next_packet;
    
    return 0;
}

packet peak_rx_buffer(){
    if(the_buffer.top_of_stack>0){
        return the_buffer.the_packets[the_buffer.top_of_stack-1];
    }else{
        return the_buffer.the_packets[0];
    }
}

void peak_rx_buffer2(packet *return_packet){
    
    *return_packet = peak_rx_buffer();
}


void pop_rx_buffer(){
    
    if(the_buffer.top_of_stack>0){
        the_buffer.the_packets[the_buffer.top_of_stack-1].num_flits  = 0;
        the_buffer.the_packets[the_buffer.top_of_stack-1].src_addr   = 0;
        the_buffer.the_packets[the_buffer.top_of_stack-1].identifier = 0;
        the_buffer.top_of_stack -= 1;
    }
}

uint32_t get_num_packets(){
    return the_buffer.top_of_stack;
}

void print_rx_buffer(){
	printf("number of packets: %d\n", the_buffer.top_of_stack);
	for(int i = 0; i< the_buffer.top_of_stack; i++){
		printf("    packet[%d]\n", i);
		printf("    flits: %d\n",the_buffer.the_packets[i].num_flits);
		printf("    identifier: %d\n", the_buffer.the_packets[i].identifier);
		for(int j = 0; j < the_buffer.the_packets[i].num_flits; j++){
			printf("        %016llx\n", the_buffer.the_packets[i].data.flit[j]);
		}
	}
}

packet get_packet_by_id(uint32_t id){
	packet return_packet;
	return_packet.num_flits = 0;
	int move_packets = 0;

	for(int i = 0; i < the_buffer.top_of_stack; i++)
	{
		if(id == the_buffer.the_packets[i].identifier){
			return_packet = the_buffer.the_packets[i];
			move_packets = 1;
		}

		if(move_packets){
			the_buffer.the_packets[i] = the_buffer.the_packets[i+1];
		}
	}

	if(move_packets){
		the_buffer.top_of_stack--;
	}

	return return_packet;
}
