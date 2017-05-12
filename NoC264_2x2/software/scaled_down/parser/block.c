#include "common.h"
#include "common.h"
#include "coretrans.h"
#include "block.h"
#include "noc_control.h"
#include "profile.h"


int send_iqit_request(int *scan, int qp, int without_dc, int LCbCr, int x, int y){
	IQIT_INC

    //wait for ack from previous command
    packet rx_packet;
    rx_packet.num_flits = 0;
    while(rx_packet.num_flits == 0){
		rx_packet = get_packet_by_id(0xFE);
		if(rx_packet.num_flits == 0){
			buffers_loop(1);
		}
	}


	static int id = 0xFF;

	int dc_upper_byte = without_dc?0xFF&(scan[0]>>8):0;

	//send header (dc_upper_byte, qp, wodc, id)
	uint32_t header_low_word = (LCbCr<<30) | ((y&0x7FF)<<19) | ((x&0x7FF)<<8) | id;
	send_flit(6, (dc_upper_byte<<16)|(qp<<8) | without_dc, header_low_word, 0);

	//send rows 4 and 3
	send_flit(6, ((scan[15]&0xFF)<<24) | ((scan[14]&0xFF)<<16) | ((scan[13]&0xFF)<<8) | (scan[12]&0xFF),
	             ((scan[11]&0xFF)<<24) | ((scan[10]&0xFF)<<16) | ((scan[ 9]&0xFF)<<8) | (scan[8] &0xFF), 0);


	//send rows 2 and 1
	send_flit(6, ((scan[ 7]&0xFF)<<24) | ((scan[ 6]&0xFF)<<16) | ((scan[ 5]&0xFF)<<8) | (scan[4]&0xFF),
	             ((scan[ 3]&0xFF)<<24) | ((scan[ 2]&0xFF)<<16) | ((scan[ 1]&0xFF)<<8) | (scan[0]&0xFF), 1);


	return id;

}

//void rx_iqit_request(frame *f, int x, int y, int id, int LCbCr, int* test){
//
//	packet iqit_packet;
//	do{
//		peak_rx_buffer2(&iqit_packet);
//
//		//print_rx_buffer();
//	}while(iqit_packet.identifier != id);
//	pop_rx_buffer();
//
//
//	int pitch = LCbCr?f->Cpitch:f->Lpitch;
//	uint8_t *img  = LCbCr?&(C_pixel(f,LCbCr-1,x,y)):&(L_pixel(f,x,y));
//
//	int residuals[16];
//	uint16_t sign_mask = (uint16_t)(iqit_packet.data.flit[0]>>32);
//
//	//memcpy( &(residuals[0]), &(iqit_packet.flit[1]), 16);
//	residuals[15] = (int)((iqit_packet.data.flit[1]&0xFF00000000000000ull)>>56);
//	residuals[14] = (int)((iqit_packet.data.flit[1]&0x00FF000000000000ull)>>48);
//	residuals[13] = (int)((iqit_packet.data.flit[1]&0x0000FF0000000000ull)>>40);
//	residuals[12] = (int)((iqit_packet.data.flit[1]&0x000000FF00000000ull)>>32);
//	residuals[11] = (int)((iqit_packet.data.flit[1]&0x00000000FF000000ull)>>24);
//	residuals[10] = (int)((iqit_packet.data.flit[1]&0x0000000000FF0000ull)>>16);
//	residuals[9 ] = (int)((iqit_packet.data.flit[1]&0x000000000000FF00ull)>>8 );
//	residuals[8 ] = (int)((iqit_packet.data.flit[1]&0x00000000000000FFull)>>0 );
//	residuals[7 ] = (int)((iqit_packet.data.flit[2]&0xFF00000000000000ull)>>56);
//	residuals[6 ] = (int)((iqit_packet.data.flit[2]&0x00FF000000000000ull)>>48);
//	residuals[5 ] = (int)((iqit_packet.data.flit[2]&0x0000FF0000000000ull)>>40);
//	residuals[4 ] = (int)((iqit_packet.data.flit[2]&0x000000FF00000000ull)>>32);
//	residuals[3 ] = (int)((iqit_packet.data.data.flit[2]&0x00000000FF000000ull)>>24);
//	residuals[2 ] = (int)((iqit_packet.data.flit[2]&0x0000000000FF0000ull)>>16);
//	residuals[1 ] = (int)((iqit_packet.data.flit[2]&0x000000000000FF00ull)>>8 );
//	residuals[0 ] = (int)((iqit_packet.data.flit[2]&0x00000000000000FFull)>>0 );
//	for(int i = 0; i < 16; i++)
//	{
//		residuals[i] = (sign_mask&(1<<i))?-1*residuals[i]:residuals[i];
//	}
//
//
////	printf("from noc: ");
////	for(int i = 0; i < 16; i++)
////	{
////		//printf("%d ", residuals[i]);
////		test[i] = residuals[i];
////
////	}
////	printf("\n");
//
//	//for(int i=0; i < 16; i++) residuals[i] = residuals[i]<=0?residuals[i]-1:residuals[i]+1;
//
//	for(int i=0; i < 4; i++){
//		  int tmp = img[0] + (int)residuals[i];
//		  img[0] = Clip(tmp);
//		  tmp = img[pitch   ] + (int)residuals[i+4];
//		  img[pitch] = Clip(tmp);
//		  tmp = img[pitch<<1] + (int)residuals[i+8];
//		  img[pitch<<1] = Clip(tmp);
//		  tmp = img[pitch*3] + (int)residuals[i+12];
//		  img[pitch*3] = Clip(tmp);
//		  img++;
//	  }
//
//}
//
//void rx_iqit_request_2(frame *f, packet the_packet){
//
//	packet iqit_packet = the_packet;
//
//	int LCbCr = ((iqit_packet.flit[0]>>27)&0x3);
//	int x     = ((iqit_packet.flit[0]>>53)&0x7FF);
//	int y     = ((iqit_packet.flit[0]>>16)&0x7FF);
//
//	int pitch = LCbCr?f->Cpitch:f->Lpitch;
//	uint8_t *img  = LCbCr?&(C_pixel(f,LCbCr-1,x,y)):&(L_pixel(f,x,y));
//
//	int residuals[16];
//	uint16_t sign_mask = (uint16_t)((iqit_packet.flit[0]>>32)&0xFFFF);
//
//	//memcpy( &(residuals[0]), &(iqit_packet.flit[1]), 16);
//	residuals[15] = (int)((iqit_packet.flit[1]&0xFF00000000000000ull)>>56);
//	residuals[14] = (int)((iqit_packet.flit[1]&0x00FF000000000000ull)>>48);
//	residuals[13] = (int)((iqit_packet.flit[1]&0x0000FF0000000000ull)>>40);
//	residuals[12] = (int)((iqit_packet.flit[1]&0x000000FF00000000ull)>>32);
//	residuals[11] = (int)((iqit_packet.flit[1]&0x00000000FF000000ull)>>24);
//	residuals[10] = (int)((iqit_packet.flit[1]&0x0000000000FF0000ull)>>16);
//	residuals[9 ] = (int)((iqit_packet.flit[1]&0x000000000000FF00ull)>>8 );
//	residuals[8 ] = (int)((iqit_packet.flit[1]&0x00000000000000FFull)>>0 );
//	residuals[7 ] = (int)((iqit_packet.flit[2]&0xFF00000000000000ull)>>56);
//	residuals[6 ] = (int)((iqit_packet.flit[2]&0x00FF000000000000ull)>>48);
//	residuals[5 ] = (int)((iqit_packet.flit[2]&0x0000FF0000000000ull)>>40);
//	residuals[4 ] = (int)((iqit_packet.flit[2]&0x000000FF00000000ull)>>32);
//	residuals[3 ] = (int)((iqit_packet.flit[2]&0x00000000FF000000ull)>>24);
//	residuals[2 ] = (int)((iqit_packet.flit[2]&0x0000000000FF0000ull)>>16);
//	residuals[1 ] = (int)((iqit_packet.flit[2]&0x000000000000FF00ull)>>8 );
//	residuals[0 ] = (int)((iqit_packet.flit[2]&0x00000000000000FFull)>>0 );
//	for(int i = 0; i < 16; i++)
//	{
//		residuals[i] = (sign_mask&(1<<i))?-1*residuals[i]:residuals[i];
//	}
//
//
////	printf("from noc: ");
////	for(int i = 0; i < 16; i++)
////	{
////		//printf("%d ", residuals[i]);
////		test[i] = residuals[i];
////
////	}
////	printf("\n");
//
//	//for(int i=0; i < 16; i++) residuals[i] = residuals[i]<=0?residuals[i]-1:residuals[i]+1;
//
//	for(int i=0; i < 4; i++){
//		  int tmp = img[0] + (int)residuals[i];
//		  img[0] = Clip(tmp);
//		  tmp = img[pitch   ] + (int)residuals[i+4];
//		  img[pitch] = Clip(tmp);
//		  tmp = img[pitch<<1] + (int)residuals[i+8];
//		  img[pitch<<1] = Clip(tmp);
//		  tmp = img[pitch*3] + (int)residuals[i+12];
//		  img[pitch*3] = Clip(tmp);
//		  img++;
//	  }
//
//}
void enter_luma_block(int *scan, frame *f, int x, int y, int qp, int without_dc) {
int test[16];

////software workaround for dc values which are too large, but still need dequant...
////iqit is linear so this should work
//if((scan[0]>127 || scan[0]<-128) && without_dc==0)
//{
//	scan[0] = scan[0]>>1;
//	int scan_2[16] = {0};
//	scan_2[0] = scan[0];
//
//	int id2 = send_iqit_request(scan_2, qp, without_dc, 0, x, y);
//	buffers_loop(1);
//	rx_iqit_request(f, x, y, id2, 0, test);
////	//rx_iqit_request_2(f);
//
//}
//
//int id = send_iqit_request(scan, qp, without_dc, 0, x, y);
//buffers_loop(1);
//rx_iqit_request(f, x, y, id, 0, test);
////
////  direct_ict(inverse_quantize(coeff_scan(scan),qp,without_dc),
////             &L_pixel(f,x,y),f->Lpitch, test);

}









void send_iqit(int *scan, int x, int y, int qp, int without_dc, int LCbCr) {
	//software workaround for dc values which are too large, but still need dequant...
	//iqit is linear so this should work
	if((scan[0]>127 || scan[0]<-128) && without_dc==0)
	{
		scan[0] = scan[0]>>1;
		int scan_2[16] = {0};
		scan_2[0] = scan[0];

		send_iqit_request(scan_2, qp, without_dc, LCbCr, x, y);

	}

	send_iqit_request(scan, qp, without_dc, LCbCr, x, y);

}




void enter_chroma_block(int *scan, frame *f, int iCbCr, int x, int y, int qp, int without_dc) {
//	int test[16];
//	//software workaround for dc values which are too large, but still need dequant...
//	//iqit is linear so this should work
//	if((scan[0]>127 || scan[0]<-128) && without_dc==0)
//	{
//		scan[0] = scan[0]>>1;
//		int scan_2[16] = {0};
//		scan_2[0] = scan[0];
//
//		int id2 = send_iqit_request(scan_2, qp, without_dc, iCbCr+1, x, y);
//		buffers_loop(1);
//		rx_iqit_request(f, x, y, id2, iCbCr+1, test);
//
//	}
//
//	int id = send_iqit_request(scan, qp, without_dc, iCbCr+1, x, y);
//	buffers_loop(1);
//	rx_iqit_request(f, x, y, id, iCbCr+1, test);
////	direct_ict(inverse_quantize(coeff_scan(scan),qp,without_dc ),
////				&C_pixel(f,iCbCr,x,y),f->Cpitch,test);
}


CONST int LevelScale[6]={10,11,13,14,16,18};

void transform_luma_dc(int *scan, int *out, int qp) {
	IQIT_DC_INC
  CONST int ScanOrder[16]={0,1,4,5,2,3,6,7,8,9,12,13,10,11,14,15};
  core_block block=hadamard(coeff_scan(scan));
  int scale=LevelScale[qp%6];
  int i;
  if(qp>=12)
    for(i=0; i<16; ++i)
      out[ScanOrder[i]<<4]=(block.items[i]*scale)<<(qp/6-2);
  else {
    int round_adj=1<<(1-qp/6);
    for(i=0; i<16; ++i)
      out[ScanOrder[i]<<4]=(block.items[i]*scale+round_adj)>>(2-qp/6);
  }
}

void transform_chroma_dc(int *scan, int qp) {
	IQIT_DC_INC
  int scale=LevelScale[qp%6];
  int a=scan[0]+scan[1]+scan[2]+scan[3];
  int b=scan[0]-scan[1]+scan[2]-scan[3];
  int c=scan[0]+scan[1]-scan[2]-scan[3];
  int d=scan[0]-scan[1]-scan[2]+scan[3];
  if(qp>=6) {
    scan[0]=(a*scale)<<(qp/6-1);
    scan[1]=(b*scale)<<(qp/6-1);
    scan[2]=(c*scale)<<(qp/6-1);
    scan[3]=(d*scale)<<(qp/6-1);
  } else {
    scan[0]=(a*scale)>>1;
    scan[1]=(b*scale)>>1;
    scan[2]=(c*scale)>>1;
    scan[3]=(d*scale)>>1;
  }
}

CONST int ZigZagOrder[]={0,1,4,8,5,2,3,6,9,12,13,10,7,11,14,15};

core_block coeff_scan(int *scan) {
  core_block res;
  int i;
  for(i=0; i<16; ++i)
    res.items[ZigZagOrder[i]]=scan[i];
  return res;
}
