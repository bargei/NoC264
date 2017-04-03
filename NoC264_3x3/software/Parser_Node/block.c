#include "common.h"
#include "common.h"
#include "coretrans.h"
#include "block.h"
#include "noc_control.h"


int send_iqit_request(int *scan, int qp, int without_dc, int LCbCr, int x, int y){

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
	send_flit(IQIT_0_ADDR, (dc_upper_byte<<16)|(qp<<8) | without_dc, header_low_word, 0);

	//send rows 4 and 3
	send_flit(IQIT_0_ADDR, ((scan[15]&0xFF)<<24) | ((scan[14]&0xFF)<<16) | ((scan[13]&0xFF)<<8) | (scan[12]&0xFF),
	             ((scan[11]&0xFF)<<24) | ((scan[10]&0xFF)<<16) | ((scan[ 9]&0xFF)<<8) | (scan[8] &0xFF), 0);


	//send rows 2 and 1
	send_flit(IQIT_0_ADDR, ((scan[ 7]&0xFF)<<24) | ((scan[ 6]&0xFF)<<16) | ((scan[ 5]&0xFF)<<8) | (scan[4]&0xFF),
	             ((scan[ 3]&0xFF)<<24) | ((scan[ 2]&0xFF)<<16) | ((scan[ 1]&0xFF)<<8) | (scan[0]&0xFF), 1);


	return id;

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

CONST int LevelScale[6]={10,11,13,14,16,18};

void transform_luma_dc(int *scan, int *out, int qp) {
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
