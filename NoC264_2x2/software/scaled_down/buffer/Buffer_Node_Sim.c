#include "common.h"
#include "noc_control.h"
#include "intra_pred.h"
#include "h264.h"

#define IS_BUFFER_NODE 1

#if IS_BUFFER_NODE

#define DO_INTRA           1
#define DO_INTER           2
#define DO_IQIT            3
#define DO_DIRECT_WRITE    4
#define DO_START_NEW_FRAME 5
#define DO_ALLOC_FRAME     6
#define DO_LOOP_TEST       7

#define LUMA_SELECT        0
#define CB_SELECT          1
#define CR_SELECT          2

#define INTRA_HW_AVAILIBLE 0

static frame *ref_buf;
static frame *working_buf;

void do_intra_func(packet *the_packet){

    //parse the packet
    uint64_t bx            = ((the_packet->data.flit[1])>>48)&0xFFFF;
    uint64_t by            = ((the_packet->data.flit[1])>>32)&0xFFFF;
    uint64_t LCbCr_select  = ((the_packet->data.flit[1])>>16)&0xFFFF;
    uint64_t blk_idx_check = ((the_packet->data.flit[1])>>0 )&0xFFFF;
    uint64_t intra_cmd     = the_packet->data.flit[2];
    uint64_t identifier    = (intra_cmd>>56)&0xFF;
    uint64_t size          = (intra_cmd>>8)&0xFF;

    //printf("%d,%d,%d\n",(int)identifier, the_packet.num_flits, get_num_packets());

#if 0
    printf("buffer node rx'd an intra info flit!\n");
    printf("flit info: \n");
    printf("    number of flits  %lu\n",   the_packet.num_flits);
    printf("    packet id        %lu\n", the_packet.identifier);
    printf("    bx               %llu\n", bx            );
    printf("    by               %llu\n", by            );
    printf("    LCbCr_select     %llu\n", LCbCr_select  );
    printf("    blk_idx_check    %llu\n", blk_idx_check );
    printf("    intra_cmd        0x%016llx\n", intra_cmd);
    printf("    identifier       %llu\n", identifier    );
    printf("    size             %llu\n", size          );


    for(int j = 0; j < the_packet.num_flits; j++){
    	printf("    flit[%d]:         0x%016llx\n",j, the_packet.flit[j]);
    }
#endif



		if(LCbCr_select == 0){
			if(INTRA_HW_AVAILIBLE ){
				//printf("about to send intra request!\n");
				send_luma_intra_packet_2(size, working_buf, bx, by,blk_idx_check, intra_cmd, identifier);
				//printf("intra command sent!\n");
				//buffers_loop(1);
				//printf("intra response received!\n");
				rx_intra_packet(identifier, working_buf, bx, by, LCbCr_select);
				//printf("intra prediction added to buffer!\n");
			}
		    else{
				uint32_t mode    = (intra_cmd>>16)&0xFF;
		    	uint32_t y_avail = (intra_cmd>>24)&0xFFFF;
				uint32_t x_avail = (intra_cmd>>32)&0xFFFF;
		    	software_intra(working_buf,
		    			       (int)size,
		    			       (int)mode,
		    			       (int)bx,
		    			       (int)by,
		    			       (uint32_t)x_avail,
		    			       (uint32_t)y_avail,
		    			       (int)LCbCr_select,
		    			       (int)blk_idx_check);
		    }
		}else{
			if(INTRA_HW_AVAILIBLE){
				uint64_t mode    = (intra_cmd>>16)&0xFF;
				uint32_t y_avail = (intra_cmd>>24)&0xFFFF;
				uint32_t x_avail = (intra_cmd>>32)&0xFFFF;
				Intra_Chroma_Dispatch_2(working_buf, mode, bx, by, x_avail, y_avail);
			}
		    else{
		    	uint32_t mode    = (intra_cmd>>16)&0xFF;
		    	uint32_t y_avail = (intra_cmd>>24)&0xFFFF;
				uint32_t x_avail = (intra_cmd>>32)&0xFFFF;
		    	software_intra(working_buf,
		    			       (int)size,
		    			       (int)mode,
		    			       (int)bx,
		    			       (int)by,
		    			       (uint32_t)x_avail,
		    			       (uint32_t)y_avail,
		    			       (int)LCbCr_select,
		    			       (int)blk_idx_check);
		    }
		}

}


void do_inter_func(packet *the_packet){
	int32_t  mvx[16];
	int32_t  mvy[16];
	uint32_t org_x   = (the_packet->data.flit[1]>>32)&0xFFFFFFFF;
	uint32_t org_y   = (the_packet->data.flit[1]    )&0xFFFFFFFF;

	for(int i = 0; i<8; i++){
		int j = 2*i;
		mvx[j]   = (the_packet->data.flit[2+i]>>48)&0xFFFF ;
		mvy[j]   = (the_packet->data.flit[2+i]>>32)&0xFFFF ;
		mvx[j+1] = (the_packet->data.flit[2+i]>>16)&0xFFFF ;
		mvy[j+1] = (the_packet->data.flit[2+i]    )&0xFFFF ;
	}

	for(int i = 0; i < 16; i++){
		mvx[i] = mvx[i]<(65536/2)?mvx[i]:mvx[i] | 0xFFFF0000;
		mvy[i] = mvy[i]<(65536/2)?mvy[i]:mvy[i] | 0xFFFF0000;
	}

#if 0
	//debug
	printf("----------------\n");
	for(int i = 0; i<16; i++){
		printf("mv(rx'd)[%d] = (%d, %d)\n",i, mvx[i], mvy[i]);
	}
#endif

	MotionCompensateMB_7( working_buf,
			              ref_buf,
						  (int *)mvx,
						  (int *)mvy,
						  org_x,
						  org_y
						  );
}


void do_iqit_func(packet *the_packet){
	rx_iqit_request_2(working_buf, the_packet);
}

void do_direct_write_func( packet *the_packet){
	//parse header
	int height       = (the_packet->data.flit[0]>>48) & 0xFF;
	int width        = (the_packet->data.flit[0]>>56) & 0xFF;
	int add_flag     = (the_packet->data.flit[0]>>40) & 0xFF;
	int LCbCr_select = (the_packet->data.flit[0]>>32) & 0xFF;

	//get coords
	int x_offset     = (the_packet->data.flit[the_packet->num_flits - 1]>>32) & 0xFFFFFFFF;
	int y_offset     = (the_packet->data.flit[the_packet->num_flits - 1]    ) & 0xFFFFFFFF;

	//debug
	for(int i = 0; i < width*height; i++){
		int byte_index    = i;
		int flit_index    = byte_index/8;
		int in_flit_index = byte_index%8;
		int shift         = (8 - in_flit_index)*8;
		uint32_t the_data = ((the_packet->data.flit[flit_index+1])>>shift)&0xff;
		printf("data[%d]: %d\n", i, (int) the_data );
	}

	for(int x = x_offset; x < (width+x_offset); x++){
		for(int y = y_offset; y < (height+y_offset); y++){


			int byte_index    = x + y * width;
			int flit_index    = byte_index/8;
			int in_flit_index = byte_index%8;
			int shift         = (8 - in_flit_index)*8;
			uint32_t the_data = ((the_packet->data.flit[flit_index+1])>>shift)&0xff;


			if(LCbCr_select == 0){
				L_pixel(working_buf,x,y) = (add_flag?L_pixel(working_buf,x,y):0)  +  (uint8_t)the_data;
			}else{
				C_pixel(working_buf,LCbCr_select-1,x,y) = (add_flag?C_pixel(working_buf,LCbCr_select-1,x,y):0)  + (uint8_t)the_data;
			}
		}
	}


}

void do_start_new_frame_func(packet *the_packet){
	frame *f = working_buf;

	int QPy = the_packet->data.flit[0]>>16 & 0xFF;
	int bS  = 3;

//	//run deblocking filter vertically
//	int num_vertical_edges   = ((f->Lwidth)/16)-1;
//	for(int i = 0; i < num_vertical_edges; i++){
//		for(int j = 0; j < f->Lheight; j++){
//			int x = (i + 1)*16;
//			int LCbCr = 0;
//			int id0 = send_deblocking_packet(f, 1, 0, x, j, QPy, bS, LCbCr);
//			rx_deblocking_packet(id0, f, 1,0, x, j, LCbCr);
//		}
//	}
//	//run deblocking filter horizontally
//	int num_horizontal_edges = ((f->Lheight)/16)-1;
//	for(int i = 0; i < num_horizontal_edges; i++){
//		for(int j = 0; j < f->Lheight; j++){
//			int y = (i + 1)*16;
//			int LCbCr = 0;
//			int id0 = send_deblocking_packet(f, 0, 1, j, y, QPy, bS, LCbCr);
//			rx_deblocking_packet(id0, f, 0,1, j, y, LCbCr);
//		}
//	}

	//printf("displaying completed frame!\n");

	//display current frame
    for(int i = 0; i < f->Lwidth; i+=2){
    	for(int j = 0; j < f->Lheight; j++){
    		uint32_t buffer_addr   = i + 320 * j;
    		uint32_t luma_addr     = i + f->Lwidth * j;
    		int i_chroma           = i/2;
    		int j_chroma           = j/2;
    		int chroma_addr        = i_chroma + j_chroma * f->Cwidth;

//    		uint32_t pixel1 = ((f->L[luma_addr  ])&0xFF)<<16 | ((f->C[0][chroma_addr])&0xFF)<<8 | ((f->C[1][chroma_addr])&0xFF);
//    		uint32_t pixel2 = ((f->L[luma_addr+1])&0xFF)<<16 | ((f->C[0][chroma_addr])&0xFF)<<8 | ((f->C[1][chroma_addr])&0xFF);
//
//    		uint32_t upper = pixel1<<8 | pixel2>>16;
//    		uint32_t lower = pixel2<<16 | (buffer_addr&0xFFFF);
//
//    		send_flit(8, upper, lower  , 1);
			WR_PIO(TX_0_BASE, f->L[luma_addr     ]  );
			WR_PIO(TX_1_BASE, f->C[0][chroma_addr]  );
			WR_PIO(TX_2_BASE, f->C[1][chroma_addr]  );
			WR_PIO(TX_3_BASE, f->L[luma_addr +1  ]  );
			WR_PIO(TX_4_BASE, f->C[0][chroma_addr]  );
			WR_PIO(TX_5_BASE, f->C[1][chroma_addr]  );
			WR_PIO(TX_6_BASE, buffer_addr );
			no_data_send(FORMAT_7 | IN_PLACE_VGA_0_ADDR | CPU_TX_REQ);


    	}
    }

    //update reference frame (this doesn't work in simulation mode)
    //NOTE: I-Frames Still Work
    f=working_buf; working_buf=ref_buf; ref_buf=f;

    //printf("TOTAL FLITS: %d\n", get_total_flits());

}

void do_alloc_frame_func(packet *the_packet){
	printf("I'm about to alloc a frame!\n");
	int width; int height;
	width  = (the_packet->data.flit[0]>>48) & 0xFFFF;
	height = (the_packet->data.flit[0]>>32) & 0xFFFF;

	printf("width:  %d\n", width);
	printf("height: %d\n", height);

	working_buf = alloc_frame(width, height);
	ref_buf  = alloc_frame(width, height);
	printf("I did it!\n");
}

void simulate_buffer_node(){
    //printf("buffer node waiting for packet\n");
	packet *rx_packet = (void *)0;
	while(rx_packet == (void *)0){
		rx_packet = get_packet_pointer_by_id(0xFF);
		if(rx_packet == (void *)0){
			buffers_loop(1);
		}
	}
    //printf("packet received\n");

	int command = (rx_packet->data.flit[0]>>8)&0xFF;
	//printf("command: %d\n", command);
	switch(command){
        case DO_INTRA:
        	//printf("starting intra\n");
            do_intra_func(rx_packet);
            break;

        case DO_INTER:
        	//printf("starting inter\n");
        	do_inter_func(rx_packet);
        	//printf("I'm finished with this inter stuff!\n");
        	break;

        case DO_IQIT:
        	//printf("starting iqit\n");
        	do_iqit_func(rx_packet);
        	break;

        case DO_DIRECT_WRITE:
        	//printf("starting direct write\n");
        	do_direct_write_func(rx_packet);
        	break;

        case DO_START_NEW_FRAME:
        	//printf("starting new frame\n");
        	do_start_new_frame_func(rx_packet);
        	break;

        case DO_ALLOC_FRAME:
        	//printf("starting alloc frame\n");
        	do_alloc_frame_func(rx_packet);
        	break;

        case DO_LOOP_TEST:
        	send_flit(0, 0, 0xFE, 0);
        	break;

        default:
        	//send_flit(0, 0, 0xFD, 0);
        	printf("simulate_buffer_node: \"What the heck is THIS?!?!?!?\"\n");


	}

	remove_packet_with_id(0xFF);
	//send ack
	send_flit(0, 0, 0xFE, 1);
	//printf("ack sent\n");

}


// END BUFFER NODE SIMULATION
#else

void simulate_buffer_node()
{}

#endif

