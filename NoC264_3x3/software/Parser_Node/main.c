#include "common.h"
#include "input.h"
#include "nal.h"
#include "cavlc.h"
#include "params.h"
#include "slicehdr.h"
#include "slice.h"
#include "residual.h"
#include "mode_pred.h" 
#include "main.h"
#include <altera_up_sd_card_avalon_interface.h>
#include "noc_control.h"
#include <time.h>
#include "parser_2_buffer.h"

frame *this=NULL, *ref=NULL;
mode_pred_info *mpi=NULL;
int frame_no;
nal_unit nalu;
seq_parameter_set sps;
pic_parameter_set pps;
slice_header sh;


int h264_open(char *filename) {
  int have_sps=0,have_pps=0;
  if(!input_open(filename)) {
    fprintf(stderr,"H.264 Error: Cannot open input file!\n");
    return 0;
  }
  init_code_tables();
  frame_no=0;
  while(get_next_nal_unit(&nalu)) {
    switch(nalu.nal_unit_type) {
      case 7:  // sequence parameter set //
        if(have_sps)
          fprintf(stderr,"H.264 Warning: Duplicate sequence parameter set, skipping!\n");
        else {
          decode_seq_parameter_set(&sps);
          have_sps=1;
        }
        break;
      case 8:  // picture parameter set //
        if(!have_sps)
          fprintf(stderr,"H.264 Warning: Picture parameter set without sequence parameter set, skipping!\n");
        else if(have_pps)
          fprintf(stderr,"H.264 Warning: Duplicate picture parameter set, skipping!\n");
        else {
          decode_pic_parameter_set(&pps);
          have_pps=1;
          if(check_unsupported_features(&sps,&pps)) {
            fprintf(stderr,"H.264 Error: Unsupported features found in headers!\n");
            input_close();
            return 0;
          }
          this=alloc_frame(sps.PicWidthInSamples,sps.FrameHeightInSamples);
          ref=alloc_frame(sps.PicWidthInSamples,sps.FrameHeightInSamples);

          send_alloc_frame(7,sps.PicWidthInSamples,sps.FrameHeightInSamples);
          //simulate_buffer_node();

          mpi=alloc_mode_pred_info(sps.PicWidthInSamples,sps.FrameHeightInSamples);
          return (sps.FrameHeightInSamples<<16)|sps.PicWidthInSamples;
        }
        break;
      case 1: case 5:  // coded slice of a picture //
        fprintf(stderr,"H.264 Warning: Pictures sent before headers!\n");
        break;
      default:  // unsupported NAL unit type //
        fprintf(stderr,"H.264 Warning: NAL unit with unsupported type, skipping!\n");
    }
  }
  fprintf(stderr,"H.264 Error: Unexpected end of file!\n");
  return 0;
}

frame *h264_decode_frame(int verbose) {
	//printf("file: %s, line : %d\n",__FILE__, __LINE__);
  while(get_next_nal_unit(&nalu)){
	  //printf("file: %s, line : %d\n",__FILE__, __LINE__);
    if(nalu.nal_unit_type==1 || nalu.nal_unit_type==5) {
    	//printf("file: %s, line : %d\n",__FILE__, __LINE__);
      perf_enter("slice decoding");
      ++frame_no;
      decode_slice_header(&sh,&sps,&pps,&nalu);
      //printf("file: %s, line : %d\n",__FILE__, __LINE__);
      if(verbose){
    	  //printf("Frame%4d: %s",frame_no,_str_slice_type(sh.slice_type));
    	  if(frame_no%10==0){
    		  printf("nf=%d\n", frame_no);
    	  }
      }
      if(sh.slice_type!=I_SLICE && sh.slice_type!=P_SLICE)
        fprintf(stderr,"H.264 Warning: Unsupported slice type (%s), skipping!\n",
                       _str_slice_type(sh.slice_type));
      else {
        frame *temp;
        int the_QP = decode_slice_data(&sh,&sps,&pps,&nalu,this,ref,mpi);




        send_start_new_frame(7, the_QP);
        //simulate_buffer_node(/*this, ref*/);
        temp=this; this=ref; ref=temp;

        return temp;
      }
    } else if(nalu.nal_unit_type!=7 && nalu.nal_unit_type!=8)
      fprintf(stderr,"H.264 Warning: unexpected or unsupported NAL unit type!\n");
  }
  return NULL;
}

void h264_rewind() {
  input_rewind();
  frame_no=0;
}

void h264_close() {
  free_frame(this);
  free_frame(ref);
  free_mode_pred_info(mpi);
  input_close();
}


inline int h264_frame_no() {
  return frame_no;
}


///////////////////////////////////////////////////////////////////////////////
int sd_fwrite(const char *data, int count, short int fileh){
	for(int i = 0; i < count; i++){
		alt_up_sd_card_write(fileh, data[i]);
	}
	return count;
}

int main(int argc, char *argv[]) {
  FILE *out;
  FILE *tst;
  frame *f;
  int info;

  printf("initializing the network!\n");


  noc_init();


  //write test image to display
  for(int luma = 128; luma < 129; luma++){
	  for(int i = 0; i < 320; i+=2){
		for(int j = 0; j < 200; j++){
			uint32_t buffer_addr   = i + 320 * j;
			if( i < 200){

				uint32_t Chroma_r = (int)((i * 1.0)/200 * 255);
				uint32_t Chroma_b = (int)((j * 1.0)/200 * 255);

				uint32_t pixel1 = (luma)<<16 | (Chroma_r)<<8 | (Chroma_b);
				uint32_t pixel2 = (luma)<<16 | (Chroma_r)<<8 | (Chroma_b);

				uint32_t upper = pixel1<<8 | pixel2>>16;
				uint32_t lower = pixel2<<16 | (buffer_addr&0xFFFF);


				send_flit(8, upper, lower  , 1);
			}
			else{

				uint32_t pixel1 = 0;
				uint32_t pixel2 = 0;

				if(j < 50){
					pixel1 = pixel2 = 82<<16 | 90<<8 | 240;
				}else if(j < 100){
					pixel1 = pixel2 = 145<<16 | 54<<8 | 34;
				}else if(j < 150){
					pixel1 = pixel2 = 41<<16 | 240<<8 | 110;
				}else{
					pixel1 = pixel2 = 235<<16 | 128<<8 | 128;
				}

				uint32_t upper = pixel1<<8 | pixel2>>16;
				uint32_t lower = pixel2<<16 | (buffer_addr&0xFFFF);


				send_flit(8, upper, lower  , 1);
			}
		}
	  }
  }



  ////open sd card using altera interface
  //alt_up_sd_card_dev *sd_card_dev = alt_up_sd_card_open_dev(ALTERA_UP_SD_CARD_AVALON_INTERFACE_0_NAME);
  //int is_present = alt_up_sd_card_is_Present();
  //int is_fat     = alt_up_sd_card_is_FAT16();
  //printf("test... 1234\n");

  info=h264_open("/mnt/host/in.264");
  if(!info) return 1;

  //blank out the display
  for(int luma = 128; luma < 129; luma++){
	  for(int i = 0; i < 320; i+=2){
		for(int j = 0; j < 200; j++){
			uint32_t buffer_addr   = i + 320 * j;
			uint32_t luma = 0;
			uint32_t Chroma_r = 128;
			uint32_t Chroma_b = 128;

			uint32_t pixel1 = (luma)<<16 | (Chroma_r)<<8 | (Chroma_b);
			uint32_t pixel2 = (luma)<<16 | (Chroma_r)<<8 | (Chroma_b);


			uint32_t upper = pixel1<<8 | pixel2>>16;
			uint32_t lower = pixel2<<16 | (buffer_addr&0xFFFF);


			send_flit(8, upper, lower  , 1);
		}
	  }
  }



//  short int out        = alt_up_sd_card_fopen("out", true);
//
//  if( (out < 0) || (!is_fat) || (!is_present) )
//  {
//	  printf("ERROR: cannot open output file\n");
//	  printf("out:        %d", out);
//	  printf("is_fat:     %d", is_fat);
//	  printf("is_present: %d", is_present);
//  }
  //if(!(out=fopen("/mnt/host/out","wb"))) {
  //  fprintf(stderr,"Error: Cannot open output file!\n");
  //  return 1;
  //}

  //use large buffer so that the video isn't written to file before it is completely decoded
  //const int out_buff_size = 7120000;
  //char *out_buf[out_buff_size];
  //setvbuf(out, out_buf, _IOFBF, out_buff_size);


  printf("H.264 stream, %dx%d pixels\n",H264_WIDTH(info),H264_HEIGHT(info));
  printf("file: %s, line : %d\n",__FILE__, __LINE__);
  //start = time(0);
  while((f=h264_decode_frame(1))) {
  }
  //send done command
  //wait for ack from previous command
      packet rx_packet;
      rx_packet.num_flits = 0;
      while(rx_packet.num_flits == 0){
  		rx_packet = get_packet_by_id(0xFE);
  		if(rx_packet.num_flits == 0){
  			buffers_loop(1);
  		}
  	}
  send_flit(7, 0, (8<<8) | 0xFF, 1);
  //wait for ack from previous command
      rx_packet.num_flits = 0;
      while(rx_packet.num_flits == 0){
  		rx_packet = get_packet_by_id(0xFE);
  		if(rx_packet.num_flits == 0){
  			buffers_loop(1);
  		}
  	}

  h264_close();
  return 0;
}

