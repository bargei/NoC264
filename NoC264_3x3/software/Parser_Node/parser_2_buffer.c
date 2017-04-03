#include "noc_control.h"
#include "mbmodes.h"
#include "block.h"
#include "parser_2_buffer.h"
#include "mode_pred.h"




void send_start_new_frame(int addr, int Qp){
    //wait for ack from previous command
    packet rx_packet;
    rx_packet.num_flits = 0;
    while(rx_packet.num_flits == 0){
		rx_packet = get_packet_by_id(0xFE);
		if(rx_packet.num_flits == 0){
			buffers_loop(1);
		}
	}


	send_flit(addr,0,(Qp<<16)|(DO_START_NEW_FRAME<<8)|0xFF, 1);


}

void send_alloc_frame(int addr, int width, int height){
	send_flit(addr,((width&0xFFFF)<<16)|(height&0xFFFF) ,(DO_ALLOC_FRAME<<8)|0xFF, 1);
    //this command does not wait for ack
}

void send_intra_info(int             addr,
                     mode_pred_info *mpi,
                     int             mode,
                     int             bx,
                     int             by,
                     int             constrained_intra_pred,
                     int             LCbCr_select,
                     int             luma4x4BlkIdx,
                     int             size,
                     int             Lwidth){
	int intra_cmd = 2;
	int availible_mask_x = 0xFFFF0000;
	int availible_mask_y = 0x0000FFFF;
	if(LCbCr_select == LUMA_SELECT){
		//luma
		if(size == 16){
			int i = get_mb_mode(mpi,(bx>>4)-1,by>>4);
			availible_mask_x = ((i==NA) || (IsInter(i) && \
								constrained_intra_pred))?0:0xFFFF0000;
			i=get_mb_mode(mpi,bx>>4,(by>>4)-1);
			availible_mask_y = ((i==NA) || (IsInter(i) && \
								constrained_intra_pred))?0:0x0000FFFF;
		}else{
			availible_mask_x = (bx>0 && ModePredInfo_Intra4x4PredMode(mpi,(bx>>2)-1,by>>2)>=0)?0xFFFF0000:0;
			availible_mask_y = (by>0 && ModePredInfo_Intra4x4PredMode(mpi,bx>>2,(by>>2)-1)>=0)?0x0000FFFF:0;
		}
	}else{
		int i=get_mb_mode(mpi,(bx>>3)-1,by>>3);
		if((i==NA) || (IsInter(i) && constrained_intra_pred)){
			availible_mask_x = 0;
		}

		i=get_mb_mode(mpi,bx>>3,(by>>3)-1);
		if((i==NA) || (IsInter(i) && constrained_intra_pred)){
			availible_mask_y = 0;
		}
	}

	uint32_t  availible_mask = availible_mask_x | availible_mask_y;
	int       identifier     = rand()%32 + 129;
    uint32_t  word1 = availible_mask<<24 | mode<<16 | size<<8 | intra_cmd;
    uint32_t  word0 = identifier<<24     | availible_mask>>8;


    //wait for ack from previous command
    packet rx_packet;
    rx_packet.num_flits = 0;
    while(rx_packet.num_flits == 0){
		rx_packet = get_packet_by_id(0xFE);
		if(rx_packet.num_flits == 0){
			buffers_loop(1);
		}
	}


    //send flit[0] cmd,id
    send_flit(addr, 0, (DO_INTRA<<8)|0xFF, 0);

    //send flit[1] bx, by, LCbCr_select, blk_idx_check
    int blk_idx_check = (luma4x4BlkIdx&3)==3 || luma4x4BlkIdx==13 || (luma4x4BlkIdx==5 && bx>=Lwidth-4);
    send_flit(addr, (bx&0xFFFF)<<16 | (by&0xFFFF),
                (LCbCr_select<<16) | blk_idx_check,0);

    //send flit[2] intra prediction request data
    send_flit(addr, word0, word1, 1);
    
    
#if 0
    printf("following sent to buffer node at ADDR = %d\n", addr);
    printf("    packet id        %d\n", 0xFF);
    printf("    bx               %d\n", bx            );
    printf("    by               %d\n", by            );
    printf("    LCbCr_select     %d\n", LCbCr_select  );
    printf("    blk_idx_check    %d\n", blk_idx_check );
    printf("    intra_cmd        0x%016llx\n", (((uint64_t)word0)<<32) | ((uint64_t)word1) );
    printf("    identifier       %d\n", identifier    );
    printf("    size             %d\n", size          );
#endif
    
}


void send_inter_info(int addr, mode_pred_info *mpi, int org_x, int org_y){

	int x,y;

	int32_t mv[32] = {0};

	for(y=0; y<4; ++y){
	    for(x=0; x<4; ++x){
	    	mv[x + y*4     ] = ModePredInfo_MVx(mpi,(org_x>>2)+x,(org_y>>2)+y);
	    	mv[x + y*4 + 16] = ModePredInfo_MVy(mpi,(org_x>>2)+x,(org_y>>2)+y);
	    }
	}


    //wait for ack from previous command
    packet rx_packet;
    rx_packet.num_flits = 0;
    while(rx_packet.num_flits == 0){
		rx_packet = get_packet_by_id(0xFE);
		if(rx_packet.num_flits == 0){
			buffers_loop(1);
		}
	}

	//send header flit
	send_flit(addr, 0, (DO_INTER<<8)|0xFF, 0);

	//send coords
	send_flit(addr, org_x, org_y, 0);

#if 0
	//debug
	printf("-motion-vectors-------------\n");
	for(int i = 0; i<16; i++){
		printf("mv(tx'd)[%d] = (%d, %d)\n",i, mv[i], mv[i+16]);
	}
#endif

	//send motion vector flits
	for(int i = 0; i < 8; i++){

		int j = 2*i;
		//send_flit(addr, (mv[j]<<16) | mv[j+16], (mv[j+1]<<16) | mv[j+17] , i==7?1:0);
		uint32_t tmp_a  = mv[j]    & 0xFFFF;
		uint32_t tmp_b  = mv[j+16] & 0xFFFF;
		uint32_t tmp_c  = mv[j+1]  & 0xFFFF;
		uint32_t tmp_d  = mv[j+17] & 0xFFFF;

		uint32_t word_0 = (tmp_a << 16) | tmp_b;
		uint32_t word_1 = (tmp_c << 16) | tmp_d;

		send_flit(addr, word_0, word_1, i==7?1:0);

	}
}

void send_direct_write(int addr,int x, int y, int width, int height, int LCbCr_select, uint8_t *bytes, int add_flag){
    //wait for ack from previous command
    packet rx_packet;
    rx_packet.num_flits = 0;
    while(rx_packet.num_flits == 0){
		rx_packet = get_packet_by_id(0xFE);
		if(rx_packet.num_flits == 0){
			buffers_loop(1);
		}
	}


	//send header
	uint32_t header_data_high = ((width&0xFF)<<24) | ((height&0xFF)<<16) | (add_flag<<8) | LCbCr_select;
	uint32_t header_data_low  = (DO_DIRECT_WRITE<<8) | 0xFF;
	send_flit(addr, header_data_high,header_data_low,0);

	//debug
	for(int i = 0; i < width*height; i++){
		printf("data[%d]: %d\n",i,  (int) (bytes[i]) );
	}



	//send data
	int remaining_data = width * height;
	while(remaining_data > 0){
		uint32_t data_low  = 0;
		uint32_t data_high = 0;
		for(int i = 0; i < 4; i++){
			if(remaining_data > 0){
				data_high = (data_high<<8) | bytes[width * height - remaining_data];
				if(remaining_data > 4){
					data_high = (data_low<<8) | bytes[width * height - remaining_data + 4];
					remaining_data--;
				}
				remaining_data--;
			}
		}
		send_flit(addr, data_high, data_low, 0);
	}

	//send coords
	send_flit(addr, x, y, 1);

}

void send_4x4_direct_write(int addr, int x_addr, int y_addr, uint8_t *row0, uint8_t *row1, uint8_t *row2, uint8_t *row3, int LCbCr_Select){
	//	tx_header_data   <= x_pass_thru_q & "00000" &sign_mask& "000" & LCbCr_pass_thru_q & y_pass_thru_q &do_iqit_cmd&identifier_q;
	//	tx_row_4_3_data  <= result_samples((16*sample_width)-1 downto (8*sample_width));
	//	tx_row_2_1_data  <= result_samples((8*sample_width)-1 downto 0) ;
	uint64_t header = (uint64_t)x_addr;
	header = (header << 53) | ((LCbCr_Select&0x03)<<27) | y_addr << 16 | 4<<8 | 0xFF;
    uint64_t data_0 = (((uint64_t) row3[3])<<56) |
                      (((uint64_t) row3[2])<<48) |
                      (((uint64_t) row3[1])<<40) |
                      (((uint64_t) row3[0])<<32) |
                      (((uint64_t) row2[3])<<24) |
                      (((uint64_t) row2[2])<<16) |
                      (((uint64_t) row2[1])<<8 ) |
                       ((uint64_t) row2[0])        ;
	uint64_t data_1 = (((uint64_t) row1[3])<<56) |
                      (((uint64_t) row1[2])<<48) |
                      (((uint64_t) row1[1])<<40) |
                      (((uint64_t) row1[0])<<32) |
                      (((uint64_t) row0[3])<<24) |
                      (((uint64_t) row0[2])<<16) |
                      (((uint64_t) row0[1])<<8 ) |
                       ((uint64_t) row0[0])        ;

	printf("%016llx\n", data_0);
	printf("%016llx\n", data_1);
	printf("++++++++++++\n");


	packet rx_packet;
	rx_packet.num_flits = 0;
	while(rx_packet.num_flits == 0){
		rx_packet = get_packet_by_id(0xFE);
		if(rx_packet.num_flits == 0){
			buffers_loop(1);
		}
	}

	send_flit(addr, (header>>32)&0xFFFFFFFF, header&0xFFFFFFFF, 0);
	send_flit(addr, (data_0>>32)&0xFFFFFFFF, data_0&0xFFFFFFFF, 0);
	send_flit(addr, (data_1>>32)&0xFFFFFFFF, data_1&0xFFFFFFFF, 1);
}


