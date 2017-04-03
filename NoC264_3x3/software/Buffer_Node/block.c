#include "common.h"
#include "block.h"
#include "noc_control.h"

void rx_iqit_request_2(frame *f, packet *the_packet, int clear){

	packet *iqit_packet = the_packet;

	int LCbCr = ((iqit_packet->data.flit[0]>>27)&0x3);
	int x     = ((iqit_packet->data.flit[0]>>53)&0x7FF);
	int y     = ((iqit_packet->data.flit[0]>>16)&0x7FF);

	int pitch = LCbCr?f->Cpitch:f->Lpitch;
	uint8_t *img  = LCbCr?&(C_pixel(f,LCbCr-1,x,y)):&(L_pixel(f,x,y));

	int residuals[16];
	uint16_t sign_mask = (uint16_t)((iqit_packet->data.flit[0]>>32)&0xFFFF);

	//memcpy( &(residuals[0]), &(iqit_packet.flit[1]), 16);
	residuals[15] = (int)((iqit_packet->data.flit[1]&0xFF00000000000000ull)>>56);
	residuals[14] = (int)((iqit_packet->data.flit[1]&0x00FF000000000000ull)>>48);
	residuals[13] = (int)((iqit_packet->data.flit[1]&0x0000FF0000000000ull)>>40);
	residuals[12] = (int)((iqit_packet->data.flit[1]&0x000000FF00000000ull)>>32);
	residuals[11] = (int)((iqit_packet->data.flit[1]&0x00000000FF000000ull)>>24);
	residuals[10] = (int)((iqit_packet->data.flit[1]&0x0000000000FF0000ull)>>16);
	residuals[9 ] = (int)((iqit_packet->data.flit[1]&0x000000000000FF00ull)>>8 );
	residuals[8 ] = (int)((iqit_packet->data.flit[1]&0x00000000000000FFull)>>0 );
	residuals[7 ] = (int)((iqit_packet->data.flit[2]&0xFF00000000000000ull)>>56);
	residuals[6 ] = (int)((iqit_packet->data.flit[2]&0x00FF000000000000ull)>>48);
	residuals[5 ] = (int)((iqit_packet->data.flit[2]&0x0000FF0000000000ull)>>40);
	residuals[4 ] = (int)((iqit_packet->data.flit[2]&0x000000FF00000000ull)>>32);
	residuals[3 ] = (int)((iqit_packet->data.flit[2]&0x00000000FF000000ull)>>24);
	residuals[2 ] = (int)((iqit_packet->data.flit[2]&0x0000000000FF0000ull)>>16);
	residuals[1 ] = (int)((iqit_packet->data.flit[2]&0x000000000000FF00ull)>>8 );
	residuals[0 ] = (int)((iqit_packet->data.flit[2]&0x00000000000000FFull)>>0 );
	for(int i = 0; i < 16; i++)
	{
		residuals[i] = (sign_mask&(1<<i))?-1*residuals[i]:residuals[i];
	}

	if(clear == 0){
		for(int i=0; i < 4; i++){
			  int tmp = img[0] + (int)residuals[i];
			  img[0] = Clip(tmp);
			  tmp = img[pitch   ] + (int)residuals[i+4];
			  img[pitch] = Clip(tmp);
			  tmp = img[pitch<<1] + (int)residuals[i+8];
			  img[pitch<<1] = Clip(tmp);
			  tmp = img[pitch*3] + (int)residuals[i+12];
			  img[pitch*3] = Clip(tmp);
			  img++;
		 }
	}else
	{
		for(int i=0; i < 4; i++){
			  img[0]        = residuals[i];
			  img[pitch]    = residuals[i+4];
			  img[pitch<<1] = residuals[i+8];
			  img[pitch*3]  = residuals[i+12];
			  img++;
		 }
	}

}
