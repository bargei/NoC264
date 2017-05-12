#include "common.h"
#include "noc_control.h"
#include <inttypes.h>
#include "deblocking_filter.h"

int send_deblocking_packet(frame *this, int x_inc, int y_inc, int x_pos, int y_pos, uint8_t qp, uint8_t bS, uint8_t LCrCb){

    static int id = 37;
    id = rand()%32 + 97;
    
    //tables used are from broadway decoder project
    const uint8_t alpha_table[52] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,5,6,7,8,9,10,
    12,13,15,17,20,22,25,28,32,36,40,45,50,56,63,71,80,90,101,113,127,144,162,
    182,203,226,255,255};
    
    const uint8_t beta_table[52] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,3,3,3,3,4,4,
    4,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18};
    
    const uint8_t tc0_table[52][3] = {
        {0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},
        {0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},
        {0,0,0},{0,0,1},{0,0,1},{0,0,1},{0,0,1},{0,1,1},{0,1,1},{1,1,1},
        {1,1,1},{1,1,1},{1,1,1},{1,1,2},{1,1,2},{1,1,2},{1,1,2},{1,2,3},
        {1,2,3},{2,2,3},{2,2,4},{2,3,4},{2,3,4},{3,3,5},{3,4,6},{3,4,6},
        {4,5,7},{4,5,8},{4,6,9},{5,7,10},{6,8,11},{6,8,13},{7,10,14},{8,11,16},
        {9,12,18},{10,13,20},{11,15,23},{13,17,25}
    };
    
    uint8_t chroma = LCrCb?1:0;
    uint8_t tc0    = tc0_table[qp][bS-1];
    uint8_t alpha  = alpha_table[qp];
    uint8_t beta   = beta_table[qp];
    
    uint32_t samples[2];
    if(LCrCb == 0){
    	samples[0] = (L_pixel(this,x_pos,y_pos))                     |\
                    (L_pixel(this,x_pos+x_inc,y_pos+y_inc))<<8      |\
                    (L_pixel(this,x_pos+2*x_inc,y_pos+2*y_inc))<<16 |\
                    (L_pixel(this,x_pos+3*x_inc,y_pos+3*y_inc))<<24;
    	samples[1] = (L_pixel(this,x_pos-x_inc,y_pos-y_inc))         |\
                    (L_pixel(this,x_pos-2*x_inc,y_pos-2*y_inc))<<8  |\
                    (L_pixel(this,x_pos-3*x_inc,y_pos-3*y_inc))<<16 |\
                    (L_pixel(this,x_pos-4*x_inc,y_pos-4*y_inc))<<24;
    }else{
    	samples[0] = (C_pixel(this,LCrCb,x_pos,y_pos))                     |\
                    (C_pixel(this,LCrCb,x_pos+x_inc,y_pos+y_inc))<<8      |\
                    (C_pixel(this,LCrCb,x_pos+2*x_inc,y_pos+2*y_inc))<<16 |\
                    (C_pixel(this,LCrCb,x_pos+3*x_inc,y_pos+3*y_inc))<<24;
    	samples[1] = (C_pixel(this,LCrCb,x_pos-x_inc,y_pos-y_inc))         |\
                    (C_pixel(this,LCrCb,x_pos-2*x_inc,y_pos-2*y_inc))<<8  |\
                    (C_pixel(this,LCrCb,x_pos-3*x_inc,y_pos-3*y_inc))<<16 |\
                    (C_pixel(this,LCrCb,x_pos-4*x_inc,y_pos-4*y_inc))<<24;
    }

    uint32_t parameters[2];
    parameters[0] = (alpha<<24)  | (beta<<16) | (bS<<8)   | tc0;
    parameters[1] = (chroma<<16) | (id <<8);
    

    //printf("p_samples: %08x\n", p_samples);
    //printf("q_samples: %08x\n", q_samples);
    send_flit(5, parameters[0], parameters[1], 0);
    send_flit(5, samples[0], samples[1], 1);



    return id;
}

void rx_deblocking_packet(int id, frame *this, int x_inc, int y_inc, int x_pos, int y_pos, int LCrCb)
{
	packet *db_packet = (void *)0;
	while(db_packet == (void *)0){
		db_packet = get_packet_pointer_by_id(id);
		if(db_packet == (void *)0){
			buffers_loop(1);
		}
	}

	if(LCrCb == 0){
        L_pixel(this,x_pos+3*x_inc,y_pos+3*y_inc) = (uint8_t)((db_packet->data.flit[1]&0xFF00000000000000ull)>>56);
        L_pixel(this,x_pos+2*x_inc,y_pos+2*y_inc) = (uint8_t)((db_packet->data.flit[1]&0x00FF000000000000ull)>>48);
        L_pixel(this,x_pos+x_inc,y_pos+y_inc)     = (uint8_t)((db_packet->data.flit[1]&0x0000FF0000000000ull)>>40);
        L_pixel(this,x_pos,y_pos)                 = (uint8_t)((db_packet->data.flit[1]&0x000000FF00000000ull)>>32);
        L_pixel(this,x_pos-4*x_inc,y_pos-4*y_inc) = (uint8_t)((db_packet->data.flit[1]&0x00000000FF000000ull)>>24);
        L_pixel(this,x_pos-3*x_inc,y_pos-3*y_inc) = (uint8_t)((db_packet->data.flit[1]&0x0000000000FF0000ull)>>16);
        L_pixel(this,x_pos-2*x_inc,y_pos-2*y_inc) = (uint8_t)((db_packet->data.flit[1]&0x000000000000FF00ull)>>8 );
        L_pixel(this,x_pos-x_inc,y_pos-y_inc)     = (uint8_t)((db_packet->data.flit[1]&0x00000000000000FFull)>>0 );
    }else{
        C_pixel(this,LCrCb,x_pos+3*x_inc,y_pos+3*y_inc) = (uint8_t)((db_packet->data.flit[1]&0xFF00000000000000ull)>>56);
        C_pixel(this,LCrCb,x_pos+2*x_inc,y_pos+2*y_inc) = (uint8_t)((db_packet->data.flit[1]&0x00FF000000000000ull)>>48);
        C_pixel(this,LCrCb,x_pos+x_inc,y_pos+y_inc)     = (uint8_t)((db_packet->data.flit[1]&0x0000FF0000000000ull)>>40);
        C_pixel(this,LCrCb,x_pos,y_pos)                 = (uint8_t)((db_packet->data.flit[1]&0x000000FF00000000ull)>>32);
        C_pixel(this,LCrCb,x_pos-4*x_inc,y_pos-4*y_inc) = (uint8_t)((db_packet->data.flit[1]&0x00000000FF000000ull)>>24);
        C_pixel(this,LCrCb,x_pos-3*x_inc,y_pos-3*y_inc) = (uint8_t)((db_packet->data.flit[1]&0x0000000000FF0000ull)>>16);
        C_pixel(this,LCrCb,x_pos-2*x_inc,y_pos-2*y_inc) = (uint8_t)((db_packet->data.flit[1]&0x000000000000FF00ull)>>8 );
        C_pixel(this,LCrCb,x_pos-x_inc,y_pos-y_inc)     = (uint8_t)((db_packet->data.flit[1]&0x00000000000000FFull)>>0 );
    }
	remove_packet_with_id(id);
}
