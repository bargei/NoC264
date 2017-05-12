
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include "noc_control.h"
#include "hps_0.h"
#include <sys/mman.h> 

#define REG_BASE 0xFF200000
#define REG_SPAN 0x00200000













static buffer the_buffer;
int fd;
static int total_flits = 0;

void noc_init()
{
    printf("initializing network!\n");
    fd=open("/dev/mem",(O_RDWR|O_SYNC));
    base_addr=mmap(NULL,REG_SPAN,(PROT_READ|PROT_WRITE),MAP_SHARED,fd,REG_BASE);
    printf("got memory map!\n");
    
    int i;
    for(i = 0; i < MAX_PACKETS; i++){
        the_buffer.the_packets[i].num_flits = 0;
        the_buffer.the_packets[i].identifier = 0;
    }
    
    printf("init'd buffer\n");
    WR_PIO(NOC_CTRL_BASE, NOC_RESET);

    usleep(100);
    
    WR_PIO(NOC_CTRL_BASE, 0);
    
    printf("done!\n");
}

void send_flit(uint32_t dest, uint32_t word0, uint32_t word1, uint32_t set_tail)
{    
   
    //this function is for compatibility with previous noc control hw
    //only send in mode 2
    WR_PIO(TX_0_BASE, word0);
    WR_PIO(TX_1_BASE, word1);
    
    //set control values
    int ncv = (dest<<16) | (set_tail?TAIL_FLIT_BIT:0) | CPU_TX_REQ | FORMAT_2;
    
    no_data_send(ncv);
    
}

void no_data_send(uint32_t format_code){
    //sends data assuming it has already been written to PIOs
    //wait for ack to go low
    while(RD_PIO(NOC_STS_BASE) & TX_ACK_BIT);
    //set control values
    WR_PIO(NOC_CTRL_BASE, format_code);
    //wait for ack to go high
    while((RD_PIO(NOC_STS_BASE) & TX_ACK_BIT) == 0);
    for(volatile int wait = 0; wait < 2; wait++);
    //clear ctrl value
    WR_PIO(NOC_CTRL_BASE, 0);
}


uint32_t get_buffer_rx_state()
{
    uint32_t state = RD_PIO(NOC_STS_BASE);
    return state & 0xFF;
}



uint32_t copy_to_buffer(uint32_t id)
{
    uint32_t packet_index = id;
    uint32_t flit_index   = the_buffer.the_packets[packet_index].num_flits;
    
    if(0 && (id < LUMA_MOCOMP_MAX) && (id >= LUMA_MOCOMP_MIN))
    {
    	WR_PIO(NOC_CTRL_BASE, PARSE_8_BIT_UNSIGNED);
    	//luma motion comp
    	//special attention should be payed to these packets since they are super common
    	//we really want to process these as fast as possible
    	uint8_t *data_stack = &(the_buffer.the_packets[packet_index].data.u_byte[flit_index]);
    	*(data_stack  ) = RD_PIO(RX_0_BASE);
    	*(data_stack+1) = RD_PIO(RX_1_BASE);
    	*(data_stack+2) = RD_PIO(RX_2_BASE);
    	*(data_stack+3) = RD_PIO(RX_3_BASE);
    	*(data_stack+4) = RD_PIO(RX_4_BASE);
    	*(data_stack+5) = RD_PIO(RX_5_BASE);
    	*(data_stack+6) = RD_PIO(RX_6_BASE);
    	*(data_stack+7) = RD_PIO(RX_7_BASE);
    	flit_index += 8;
    	the_buffer.the_packets[packet_index].num_flits          = flit_index;
		the_buffer.the_packets[packet_index].identifier         = id;
		the_buffer.the_packets[packet_index].src_addr           = 0;



    }else{
    	//default flit parser
    	WR_PIO(NOC_CTRL_BASE, PARSE_32_BIT_UNSIGNED);
        uint32_t flit_top    = RD_PIO(RX_0_BASE);
        uint32_t flit_bottom = RD_PIO(RX_1_BASE);
        uint64_t *flit_stack = &(the_buffer.the_packets[packet_index].data.flit[flit_index++]);
        *(uint32_t *)flit_stack                                 = flit_bottom;
        *(((uint32_t *)flit_stack)+1)                           = flit_top;
        the_buffer.the_packets[packet_index].num_flits          = flit_index;
        the_buffer.the_packets[packet_index].identifier         = id;
        the_buffer.the_packets[packet_index].src_addr           = 0;
    }


    WR_PIO(NOC_CTRL_BASE, 0);
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
    
    return 0;
}


void print_rx_buffer(){
	for(int i = 0; MAX_PACKETS; i++){
		printf("    packet[%d]\n", i);
		printf("    flits: %d\n",the_buffer.the_packets[i].num_flits);
		printf("    identifier: %d\n", the_buffer.the_packets[i].identifier);
		for(int j = 0; j < the_buffer.the_packets[i].num_flits; j++){
			printf("        %016llx\n", the_buffer.the_packets[i].data.flit[j]);
		}
	}
}

packet* get_packet_pointer_by_id(uint32_t id){
	if(the_buffer.the_packets[id].identifier == id){
		return &(the_buffer.the_packets[id]);
	}
	return (void *)0;
}

void remove_packet_with_id(int id){
	int move_packets = 0;

	the_buffer.the_packets[id].num_flits  = 0;
	the_buffer.the_packets[id].identifier = -1;

	return;
}

packet get_packet_by_id(uint32_t id){
    packet *requested_packet = get_packet_pointer_by_id(id);
    packet return_packet;
    if(requested_packet == (void *)0 ){
        return_packet.num_flits = 0;
        return return_packet;
    }
    return_packet = *requested_packet;
    remove_packet_with_id(id);
    return return_packet;
}

int _test_noc_control(int argc, char *argv[]){
    
}
