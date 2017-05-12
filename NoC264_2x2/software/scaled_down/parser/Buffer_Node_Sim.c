#include "parser_2_buffer.h"
#include "common.h"

#define IS_BUFFER_NODE 0

#if IS_BUFFER_NODE

static frame *ref_buf;
static frame *working_buf;

void do_intra_func(packet the_packet){
    //parse the packet
    uint64_t bx            = ((the_packet.flit[1])>>48)&0xFFFF;
    uint64_t by            = ((the_packet.flit[1])>>32)&0xFFFF;
    uint64_t LCbCr_select  = ((the_packet.flit[1])>>16)&0xFFFF;
    uint64_t blk_idx_check = ((the_packet.flit[1])>>0 )&0xFFFF;
    uint64_t intra_cmd     = the_packet.flit[2];
    uint64_t identifier    = (intra_cmd>>56)&0xFF;
    uint64_t size          = (intra_cmd>>8)&0xFF;

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
    	send_luma_intra_packet_2(size, working_buf, bx, by,blk_idx_check, intra_cmd, identifier);
        buffers_loop(1);
        rx_intra_packet(identifier, working_buf, bx, by, LCbCr_select);
    }else{
    	uint64_t mode    = (intra_cmd>>16)&0xFF;
    	uint32_t y_avail = (intra_cmd>>24)&0xFFFF;
    	uint32_t x_avail = (intra_cmd>>32)&0xFFFF;
    	Intra_Chroma_Dispatch_2(working_buf, mode, bx, by, x_avail, y_avail);
    }

}


void do_inter_func(packet the_packet){
	int32_t  mvx[16];
	int32_t  mvy[16];
	uint32_t org_x   = (the_packet.flit[1]>>32)&0xFFFFFFFF;
	uint32_t org_y   = (the_packet.flit[1]    )&0xFFFFFFFF;

	for(int i = 0; i<8; i++){
		int j = 2*i;
		mvx[j]   = (the_packet.flit[2+i]>>48)&0xFFFF ;
		mvy[j]   = (the_packet.flit[2+i]>>32)&0xFFFF ;
		mvx[j+1] = (the_packet.flit[2+i]>>16)&0xFFFF ;
		mvy[j+1] = (the_packet.flit[2+i]    )&0xFFFF ;
	}

	for(int i = 0; i < 16; i++){
		mvx[i] = mvx[i]<(65526/2)?mvx[i]:mvx[i] | 0xFFFF0000;
		mvy[i] = mvy[i]<(65526/2)?mvy[i]:mvy[i] | 0xFFFF0000;
	}

#if 0
	//debug
	printf("----------------\n");
	for(int i = 0; i<16; i++){
		printf("mv(rx'd)[%d] = (%d, %d)\n",i, mvx[i], mvy[i]);
	}
#endif

	MotionCompensateMB_2( working_buf,
			              ref_buf,
						  (int *)mvx,
						  (int *)mvy,
						  org_x,
						  org_y
						  );
}


void do_iqit_func(packet the_packet){
	rx_iqit_request_2(working_buf, the_packet);
}

void do_direct_write_func( packet the_packet){
	//parse header
	int height       = (the_packet.flit[0]>>48) & 0xFF;
	int width        = (the_packet.flit[0]>>56) & 0xFF;
	int add_flag     = (the_packet.flit[0]>>40) & 0xFF;
	int LCbCr_select = (the_packet.flit[0]>>32) & 0xFF;

	//get coords
	int x_offset     = (the_packet.flit[the_packet.num_flits - 1]>>32) & 0xFFFFFFFF;
	int y_offset     = (the_packet.flit[the_packet.num_flits - 1]    ) & 0xFFFFFFFF;

	//debug
	for(int i = 0; i < width*height; i++){
		int byte_index    = i;
		int flit_index    = byte_index/8;
		int in_flit_index = byte_index%8;
		int shift         = (8 - in_flit_index)*8;
		uint32_t the_data = ((the_packet.flit[flit_index+1])>>shift)&0xff;
		printf("data[%d]: %d\n", i, (int) the_data );
	}

	for(int x = x_offset; x < (width+x_offset); x++){
		for(int y = y_offset; y < (height+y_offset); y++){


			int byte_index    = x + y * width;
			int flit_index    = byte_index/8;
			int in_flit_index = byte_index%8;
			int shift         = (8 - in_flit_index)*8;
			uint32_t the_data = ((the_packet.flit[flit_index+1])>>shift)&0xff;


			if(LCbCr_select == 0){
				L_pixel(working_buf,x,y) = (add_flag?L_pixel(working_buf,x,y):0)  +  (uint8_t)the_data;
			}else{
				C_pixel(working_buf,LCbCr_select-1,x,y) = (add_flag?C_pixel(working_buf,LCbCr_select-1,x,y):0)  + (uint8_t)the_data;
			}
		}
	}


}

void do_start_new_frame_func(packet the_packet){
	//run deblocking filter
	//todo


	//display current frame
	frame *f = working_buf;
    for(int i = 0; i < f->Lwidth; i+=2){
    	for(int j = 0; j < f->Lheight; j++){
    		uint32_t buffer_addr   = i + 320 * j;
    		uint32_t luma_addr     = i + f->Lwidth * j;
    		int i_chroma           = i/2;
    		int j_chroma           = j/2;
    		int chroma_addr        = i_chroma + j_chroma * f->Cwidth;

    		uint32_t pixel1 = ((f->L[luma_addr  ])&0xFF)<<16 | ((f->C[0][chroma_addr])&0xFF)<<8 | ((f->C[1][chroma_addr])&0xFF);
    		uint32_t pixel2 = ((f->L[luma_addr+1])&0xFF)<<16 | ((f->C[0][chroma_addr])&0xFF)<<8 | ((f->C[1][chroma_addr])&0xFF);

    		uint32_t upper = pixel1<<8 | pixel2>>16;
    		uint32_t lower = pixel2<<16 | (buffer_addr&0xFFFF);

    		send_flit(8, upper, lower  , 1);
    	}
    }

    //update reference frame (this doesn't work in simulation mode)
    //NOTE: I-Frames Still Work
    f=working_buf; working_buf=ref_buf; ref_buf=f;

}

void do_alloc_frame_func(packet the_packet){
	printf("I'm about to alloc a frame!\n");
	int width; int height;
	width  = (the_packet.flit[0]>>48) & 0xFFFF;
	height = (the_packet.flit[0]>>32) & 0xFFFF;

	printf("width:  %d\n", width);
	printf("height: %d\n", height);

	working_buf = alloc_frame(width, height);
	ref_buf  = alloc_frame(width, height);
	printf("I did it!\n");
}

void simulate_buffer_node(){
	buffers_loop(1);
	packet rx_packet;
	peak_rx_buffer2(&rx_packet);
	pop_rx_buffer();

	int command = (rx_packet.flit[0]>>8)&0xFF;
	switch(command){
        case DO_INTRA:
            do_intra_func(rx_packet);
            break;

        case DO_INTER:
        	do_inter_func(rx_packet);
        	break;

        case DO_IQIT:
        	do_iqit_func(rx_packet);
        	break;

        case DO_DIRECT_WRITE:
        	do_direct_write_func(rx_packet);
        	break;

        case DO_START_NEW_FRAME:
        	do_start_new_frame_func(rx_packet);
        	break;

        case DO_ALLOC_FRAME:
        	do_alloc_frame_func(rx_packet);
        	break;

        default:
            printf("simulate_buffer_node says \"TODO\"!\n");
	}
	//also todo move this to new file so that it can be called from main as well
}
// END BUFFER NODE SIMULATION
#else

void simulate_buffer_node()
{}

#endif

