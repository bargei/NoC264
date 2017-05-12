#include "common.h"
#include "noc_control.h"
#include <inttypes.h>

typedef struct L_MC_temp_block  {
  uint32_t p[9][9];
} L_MC_temp_block;

typedef struct C_MC_temp_block {
  uint32_t p[3][3];
} C_MC_temp_block;

typedef struct {
	uint8_t byte_0;
	uint8_t byte_1;
	uint8_t byte_2;
	uint8_t byte_3;
	uint8_t byte_4;
	uint8_t byte_5;
	uint8_t byte_6;
	uint8_t byte_7;
} inter_rx_struct;

void mocomp_print_block(frame *this, int org_x, int org_y){
	int x,y;
	for(y=0; y<4; ++y)
	{
			  for(x=0; x<4; ++x)
			  {
				  printf("%d ",L_pixel(this,x+org_x,y+org_y));
			  }
			  printf("\n");
	}

}


static inline L_MC_temp_block GetLMCTempBlock(frame *ref, int org_x, int org_y) {
  L_MC_temp_block b;
  int x,y,sx,sy;
  for(y=0; y<9; ++y) {
    sy=org_y+y;
    if(sy<0) sy=0;
    if(sy>=ref->Lheight) sy=ref->Lheight-1;
    for(x=0; x<9; ++x) {
      sx=org_x+x;
      if(sx<0)            b.p[y][x]=L_pixel(ref,0,sy); else
      if(sx>=ref->Lwidth) b.p[y][x]=L_pixel(ref,ref->Lwidth-1,sy);
                     else b.p[y][x]=L_pixel(ref,sx,sy);
    }
  }
  return b;
}

void GetLMCTempBlock_2(frame *ref, int org_x, int org_y, L_MC_temp_block *the_block){
	int x,y,sx,sy;
	for(y=0; y<9; ++y) {
		sy=org_y+y;
		if(sy<0){
			sy=0;
		}
		if(sy>=ref->Lheight){
			sy=ref->Lheight-1;
		}
		for(x=0; x<9; ++x) {
			sx=org_x+x;
			if(sx<0){
				the_block->p[y][x]=L_pixel(ref,0,sy);
			}
			else {
				if(sx>=ref->Lwidth){
					the_block->p[y][x]=L_pixel(ref,ref->Lwidth-1,sy);
				}
				else{
					the_block->p[y][x]=L_pixel(ref,sx,sy);
				}
			}
		}
	}
	return;
}


#define Filter(E,F,G,H,I,J) Clip1(((E)-5*(F)+20*(G)+20*(H)-5*(I)+(J)+16)>>5)
static inline int Clip1(int i) {
  if(i<0) return 0; else if(i>255) return 255; else return i;
}

#define iffrac(x,y) if(frac==y*4+x)
#define Mix(a,b) (((a)+(b)+1)>>1)

static inline int L_MC_get_sub(uint32_t *data, int frac) {
#define p(x,y) data[(y)*9+(x)]
  int b,cc,dd,ee,ff,h,j,m,s;
  iffrac(0,0) {
	  //printf("frac = %d, letter = ?\n", frac);
	  return p(0,0);
  }
  b=Filter(p(-2,0),p(-1,0),p(0,0),p(1,0),p(2,0),p(3,0));
  iffrac(1,0){
	  //printf("frac = %d, letter = (a)\n", frac);
	  return Mix(p(0,0),b);
  }
  iffrac(2,0){
	  //printf("frac = %d, letter = b\n", frac);
	  return b;
  }
  iffrac(3,0){
	  //printf("frac = %d, letter = (c)\n", frac);
	  return Mix(b,p(1,0));
  }
  h=Filter(p(0,-2),p(0,-1),p(0,0),p(0,1),p(0,2),p(0,3));
  iffrac(0,1){
	  //printf("frac = %d, letter = (d)\n", frac);
	  return Mix(p(0,0),h);
  }
  iffrac(0,2){
	  //printf("frac = %d, letter = h\n", frac);
	  return h;
  }
  iffrac(0,3){
	  //printf("frac = %d, letter = (n)\n", frac);
	  return Mix(h,p(0,1));
  }
  iffrac(1,1){
	  //printf("frac = %d, letter = e\n", frac);
	  return Mix(b,h);
  }
  m=Filter(p(1,-2),p(1,-1),p(1,0),p(1,1),p(1,2),p(1,3));
  iffrac(3,1){
	  //printf("frac = %d, letter = g\n", frac);
	  return Mix(b,m);
  }
  s=Filter(p(-2,1),p(-1,1),p(0,1),p(1,1),p(2,1),p(3,1));
  iffrac(1,3){
	  //printf("frac = %d, letter = p\n", frac);
	  return Mix(h,s);
  }
  iffrac(3,3){
	  //printf("frac = %d, letter = r\n", frac);
	  return Mix(s,m);
  }
  cc=Filter(p(-2,-2),p(-2,-1),p(-2,0),p(-2,1),p(-2,2),p(-2,3));
  dd=Filter(p(-1,-2),p(-1,-1),p(-1,0),p(-1,1),p(-1,2),p(-1,3));
  ee=Filter(p(2,-2),p(2,-1),p(2,0),p(2,1),p(2,2),p(2,3));
  ff=Filter(p(3,-2),p(3,-1),p(3,0),p(3,1),p(3,2),p(3,3));
  j=Filter(cc,dd,h,m,ee,ff);
  iffrac(2,2){
	  //printf("frac = %d, letter = j\n", frac);
	  return j;
  }
  iffrac(2,1){
	  //printf("frac = %d, letter = f\n", frac);
	  return Mix(b,j);
  }
  iffrac(1,2){
	  //printf("frac = %d, letter = i\n", frac);
	  return Mix(h,j);
  }
  iffrac(2,3){
	  //printf("frac = %d, letter = q\n", frac);
	  return Mix(j,s);
  }
  iffrac(3,2){
	  //printf("frac = %d, letter = k\n", frac);
	  return Mix(j,m);
  }
  return 128;  // when we arrive here, something's going seriosly wrong ...
#undef p
}


static inline C_MC_temp_block GetCMCTempBlock(frame *ref, int iCbCr, int org_x, int org_y) {
  C_MC_temp_block b;
  int x,y,sx,sy;
  for(y=0; y<3; ++y) {
    sy=org_y+y;
    if(sy<0) sy=0;
    if(sy>=ref->Cheight) sy=ref->Cheight-1;
    for(x=0; x<3; ++x) {
      sx=org_x+x;
      if(sx<0)            b.p[y][x]=C_pixel(ref,iCbCr,0,sy); else
      if(sx>=ref->Cwidth) b.p[y][x]=C_pixel(ref,iCbCr,ref->Cwidth-1,sy);
                     else b.p[y][x]=C_pixel(ref,iCbCr,sx,sy);
    }
  }
  return b;
}

int send_luma_motion_comp_fast(frame *ref, int org_x, int org_y, int frac){
	static int id = 127;
	id = (id+1)%(LUMA_MOCOMP_MAX-LUMA_MOCOMP_MIN) + LUMA_MOCOMP_MIN;
	send_flit(2, id, id, 0);
	uint32_t sizes = (0x0F & (uint64_t)frac) | (4 << 8) | (4 << 16);
	send_flit(2, 0, sizes, 0);

	int x,y,sx,sy;
	for(y=0; y<9; ++y) {
		sy=org_y+y;
		if(sy<0){
			sy=0;
		}
		if(sy>=ref->Lheight){
			sy=ref->Lheight-1;
		}
		sx = org_x;
		if((sx >= 0) && ((sx+8) < ref->Lwidth)){
			WR_PIO(TX_0_BASE, L_pixel(ref,sx+7,sy)  );
			WR_PIO(TX_1_BASE, L_pixel(ref,sx+6,sy)  );
			WR_PIO(TX_2_BASE, L_pixel(ref,sx+5,sy)  );
			WR_PIO(TX_3_BASE, L_pixel(ref,sx+4,sy)  );
			WR_PIO(TX_4_BASE, L_pixel(ref,sx+3,sy)  );
			WR_PIO(TX_5_BASE, L_pixel(ref,sx+2,sy)  );
			WR_PIO(TX_6_BASE, L_pixel(ref,sx+1,sy)  );
			WR_PIO(TX_7_BASE, L_pixel(ref,sx+0,sy)  );
			no_data_send(FORMAT_0 | IN_PLACE_LINTER_0_ADDR | CPU_TX_REQ);
			WR_PIO(TX_0_BASE, L_pixel(ref,sx+8,sy)  );
			no_data_send(FORMAT_0 | IN_PLACE_LINTER_0_ADDR | CPU_TX_REQ | (y==8?TAIL_FLIT_BIT:0));
		}else{


			int x8 = ((sx+8)>0)?sx+8:0;
			x8     = (x8 < ref->Lwidth)?x8: ref->Lwidth-1;

			int x7 = ((sx+7)>0)?sx+7:0;
			x7     = (x7 < ref->Lwidth)?x7: ref->Lwidth-1;

			int x6 = ((sx+6)>0)?sx+6:0;
			x6     = (x6 < ref->Lwidth)?x6: ref->Lwidth-1;

			int x5 = ((sx+5)>0)?sx+5:0;
			x5     = (x5 < ref->Lwidth)?x5: ref->Lwidth-1;

			int x4 = ((sx+4)>0)?sx+4:0;
			x4     = (x4 < ref->Lwidth)?x4: ref->Lwidth-1;

			int x3 = ((sx+3)>0)?sx+3:0;
			x3     = (x3 < ref->Lwidth)?x3: ref->Lwidth-1;

			int x2 = ((sx+2)>0)?sx+2:0;
			x2     = (x2 < ref->Lwidth)?x2: ref->Lwidth-1;

			int x1 = ((sx+1)>0)?sx+1:0;
			x1     = (x1 < ref->Lwidth)?x1: ref->Lwidth-1;

			int x0 = ((sx)>0)?sx:0;
			x0     = (x0 < ref->Lwidth)?x0: ref->Lwidth-1;

			WR_PIO(TX_0_BASE, L_pixel(ref,x7,sy)  );
			WR_PIO(TX_1_BASE, L_pixel(ref,x6,sy)  );
			WR_PIO(TX_2_BASE, L_pixel(ref,x5,sy)  );
			WR_PIO(TX_3_BASE, L_pixel(ref,x4,sy)  );
			WR_PIO(TX_4_BASE, L_pixel(ref,x3,sy)  );
			WR_PIO(TX_5_BASE, L_pixel(ref,x2,sy)  );
			WR_PIO(TX_6_BASE, L_pixel(ref,x1,sy)  );
			WR_PIO(TX_7_BASE, L_pixel(ref,x0,sy)  );
			no_data_send(FORMAT_0 | IN_PLACE_LINTER_0_ADDR | CPU_TX_REQ);
			WR_PIO(TX_0_BASE, L_pixel(ref,x8,sy)  );
			no_data_send(FORMAT_0 | IN_PLACE_LINTER_0_ADDR | CPU_TX_REQ | (y==8?TAIL_FLIT_BIT:0));
		}

	}

	return id;




}


int send_luma_1_motion_comp_fast(frame *ref, int org_x, int org_y, int frac){
	static int id = 127;
	id = (id+1)%(LUMA_1_MOCOMP_MAX-LUMA_1_MOCOMP_MIN) + LUMA_1_MOCOMP_MIN;
	send_flit(9, id, id, 0);
	uint32_t sizes = (0x0F & (uint64_t)frac) | (4 << 8) | (4 << 16);
	send_flit(9, 0, sizes, 0);

	int x,y,sx,sy;
	for(y=0; y<9; ++y) {
		sy=org_y+y;
		if(sy<0){
			sy=0;
		}
		if(sy>=ref->Lheight){
			sy=ref->Lheight-1;
		}
		sx = org_x;
		if((sx >= 0) && ((sx+8) < ref->Lwidth)){
			WR_PIO(TX_0_BASE, L_pixel(ref,sx+7,sy)  );
			WR_PIO(TX_1_BASE, L_pixel(ref,sx+6,sy)  );
			WR_PIO(TX_2_BASE, L_pixel(ref,sx+5,sy)  );
			WR_PIO(TX_3_BASE, L_pixel(ref,sx+4,sy)  );
			WR_PIO(TX_4_BASE, L_pixel(ref,sx+3,sy)  );
			WR_PIO(TX_5_BASE, L_pixel(ref,sx+2,sy)  );
			WR_PIO(TX_6_BASE, L_pixel(ref,sx+1,sy)  );
			WR_PIO(TX_7_BASE, L_pixel(ref,sx+0,sy)  );
			no_data_send(FORMAT_0 | IN_PLACE_LINTER_1_ADDR | CPU_TX_REQ);
			WR_PIO(TX_0_BASE, L_pixel(ref,sx+8,sy)  );
			no_data_send(FORMAT_0 | IN_PLACE_LINTER_1_ADDR | CPU_TX_REQ | (y==8?TAIL_FLIT_BIT:0));
		}else{


			int x8 = ((sx+8)>0)?sx+8:0;
			x8     = (x8 < ref->Lwidth)?x8: ref->Lwidth-1;

			int x7 = ((sx+7)>0)?sx+7:0;
			x7     = (x7 < ref->Lwidth)?x7: ref->Lwidth-1;

			int x6 = ((sx+6)>0)?sx+6:0;
			x6     = (x6 < ref->Lwidth)?x6: ref->Lwidth-1;

			int x5 = ((sx+5)>0)?sx+5:0;
			x5     = (x5 < ref->Lwidth)?x5: ref->Lwidth-1;

			int x4 = ((sx+4)>0)?sx+4:0;
			x4     = (x4 < ref->Lwidth)?x4: ref->Lwidth-1;

			int x3 = ((sx+3)>0)?sx+3:0;
			x3     = (x3 < ref->Lwidth)?x3: ref->Lwidth-1;

			int x2 = ((sx+2)>0)?sx+2:0;
			x2     = (x2 < ref->Lwidth)?x2: ref->Lwidth-1;

			int x1 = ((sx+1)>0)?sx+1:0;
			x1     = (x1 < ref->Lwidth)?x1: ref->Lwidth-1;

			int x0 = ((sx)>0)?sx:0;
			x0     = (x0 < ref->Lwidth)?x0: ref->Lwidth-1;

			WR_PIO(TX_0_BASE, L_pixel(ref,x7,sy)  );
			WR_PIO(TX_1_BASE, L_pixel(ref,x6,sy)  );
			WR_PIO(TX_2_BASE, L_pixel(ref,x5,sy)  );
			WR_PIO(TX_3_BASE, L_pixel(ref,x4,sy)  );
			WR_PIO(TX_4_BASE, L_pixel(ref,x3,sy)  );
			WR_PIO(TX_5_BASE, L_pixel(ref,x2,sy)  );
			WR_PIO(TX_6_BASE, L_pixel(ref,x1,sy)  );
			WR_PIO(TX_7_BASE, L_pixel(ref,x0,sy)  );
			no_data_send(FORMAT_0 | IN_PLACE_LINTER_1_ADDR | CPU_TX_REQ);
			WR_PIO(TX_0_BASE, L_pixel(ref,x8,sy)  );
			no_data_send(FORMAT_0 | IN_PLACE_LINTER_1_ADDR | CPU_TX_REQ | (y==8?TAIL_FLIT_BIT:0));
		}

	}

	return id;

}














int send_luma_motion_comp_packet(uint8_t *data, int frac)
{
#define p(x,y) data[(y)*9+(x)]
	static int id = 127;
	id = (id+1)%32 + 33;
	send_flit(2, id, id, 0);
	uint32_t sizes = (0x0F & (uint64_t)frac) | (4 << 8) | (4 << 16);
	send_flit(2, 0, sizes, 0);

	int i;
	for(i = 0; i < 9; i++)
	{
//		uint32_t lsw;// = (p(0,i)<<0)|(p(1,i)<<8)|(p(2,i)<<16)|(p(3,i)<<24);
//		uint32_t msw;// = (p(4,i)<<0)|(p(5,i)<<8)|(p(6,i)<<16)|(p(7,i)<<24);
//
//		memcpy(&lsw, &(p(0,i)), 4);
//		memcpy(&msw, &(p(4,i)), 4);
//
//		send_flit(2, msw, lsw, 0);
//		lsw = p(8,i);
//		msw = 0;
//		send_flit(2, msw, lsw, i==8);
		WR_PIO(TX_0_BASE, p(7,i));
		WR_PIO(TX_1_BASE, p(6,i));
		WR_PIO(TX_2_BASE, p(5,i));
		WR_PIO(TX_3_BASE, p(4,i));
		WR_PIO(TX_4_BASE, p(3,i));
		WR_PIO(TX_5_BASE, p(2,i));
		WR_PIO(TX_6_BASE, p(1,i));
		WR_PIO(TX_7_BASE, p(0,i));
		no_data_send(FORMAT_0 | IN_PLACE_LINTER_0_ADDR | CPU_TX_REQ);
		WR_PIO(TX_0_BASE, p(8,i));
		no_data_send(FORMAT_0 | IN_PLACE_LINTER_0_ADDR | CPU_TX_REQ | (i==8?TAIL_FLIT_BIT:0));

	}

	return id;
#undef p
}

void rx_luma_motion_comp_packet(int id, frame *this, int org_x, int org_y)
{
//	printf("im here");
	packet *inter_packet = (void *)0;
	while(inter_packet == (void *)0){
		inter_packet = get_packet_pointer_by_id(id);
		if(inter_packet == (void *)0){
			buffers_loop(1);
		}
	}

	inter_rx_struct *flit_1 = (inter_rx_struct *)(&(inter_packet->data.flit[1]));
	inter_rx_struct *flit_2 = (inter_rx_struct *)(&(inter_packet->data.flit[2]));

//	L_pixel(this,0+org_x,0+org_y) = (uint8_t)((inter_packet.flit[1]&0xFF00000000000000ull)>>56);
//	L_pixel(this,1+org_x,0+org_y) = (uint8_t)((inter_packet.flit[1]&0x00FF000000000000ull)>>48);
//	L_pixel(this,2+org_x,0+org_y) = (uint8_t)((inter_packet.flit[1]&0x0000FF0000000000ull)>>40);
//	L_pixel(this,3+org_x,0+org_y) = (uint8_t)((inter_packet.flit[1]&0x000000FF00000000ull)>>32);
//	L_pixel(this,0+org_x,1+org_y) = (uint8_t)((inter_packet.flit[1]&0x00000000FF000000ull)>>24);
//	L_pixel(this,1+org_x,1+org_y) = (uint8_t)((inter_packet.flit[1]&0x0000000000FF0000ull)>>16);
//	L_pixel(this,2+org_x,1+org_y) = (uint8_t)((inter_packet.flit[1]&0x000000000000FF00ull)>>8 );
//	L_pixel(this,3+org_x,1+org_y) = (uint8_t)((inter_packet.flit[1]&0x00000000000000FFull)>>0 );
//	L_pixel(this,0+org_x,2+org_y) = (uint8_t)((inter_packet.flit[2]&0xFF00000000000000ull)>>56);
//	L_pixel(this,1+org_x,2+org_y) = (uint8_t)((inter_packet.flit[2]&0x00FF000000000000ull)>>48);
//	L_pixel(this,2+org_x,2+org_y) = (uint8_t)((inter_packet.flit[2]&0x0000FF0000000000ull)>>40);
//	L_pixel(this,3+org_x,2+org_y) = (uint8_t)((inter_packet.flit[2]&0x000000FF00000000ull)>>32);
//	L_pixel(this,0+org_x,3+org_y) = (uint8_t)((inter_packet.flit[2]&0x00000000FF000000ull)>>24);
//	L_pixel(this,1+org_x,3+org_y) = (uint8_t)((inter_packet.flit[2]&0x0000000000FF0000ull)>>16);
//	L_pixel(this,2+org_x,3+org_y) = (uint8_t)((inter_packet.flit[2]&0x000000000000FF00ull)>>8 );
//	L_pixel(this,3+org_x,3+org_y) = (uint8_t)((inter_packet.flit[2]&0x00000000000000FFull)>>0 );

	L_pixel(this,0+org_x,0+org_y) = flit_1->byte_7;
	L_pixel(this,1+org_x,0+org_y) = flit_1->byte_6;
	L_pixel(this,2+org_x,0+org_y) = flit_1->byte_5;
	L_pixel(this,3+org_x,0+org_y) = flit_1->byte_4;
	L_pixel(this,0+org_x,1+org_y) = flit_1->byte_3;
	L_pixel(this,1+org_x,1+org_y) = flit_1->byte_2;
	L_pixel(this,2+org_x,1+org_y) = flit_1->byte_1;
	L_pixel(this,3+org_x,1+org_y) = flit_1->byte_0;
	L_pixel(this,0+org_x,2+org_y) = flit_2->byte_7;
	L_pixel(this,1+org_x,2+org_y) = flit_2->byte_6;
	L_pixel(this,2+org_x,2+org_y) = flit_2->byte_5;
	L_pixel(this,3+org_x,2+org_y) = flit_2->byte_4;
	L_pixel(this,0+org_x,3+org_y) = flit_2->byte_3;
	L_pixel(this,1+org_x,3+org_y) = flit_2->byte_2;
	L_pixel(this,2+org_x,3+org_y) = flit_2->byte_1;
	L_pixel(this,3+org_x,3+org_y) = flit_2->byte_0;


//	for(int i = 0; i < inter_packet.num_flits; i++){
//		printf("    %d\n", inter_packet.data.u_word[i]);
//	}


//	int header_offset = 8;
//	L_pixel(this,0+org_x,0+org_y) = inter_packet->data.u_byte[0 + header_offset];
//	L_pixel(this,1+org_x,0+org_y) = inter_packet->data.u_byte[1 + header_offset];
//	L_pixel(this,2+org_x,0+org_y) = inter_packet->data.u_byte[2 + header_offset];
//	L_pixel(this,3+org_x,0+org_y) = inter_packet->data.u_byte[3 + header_offset];
//	L_pixel(this,0+org_x,1+org_y) = inter_packet->data.u_byte[4 + header_offset];
//	L_pixel(this,1+org_x,1+org_y) = inter_packet->data.u_byte[5 + header_offset];
//	L_pixel(this,2+org_x,1+org_y) = inter_packet->data.u_byte[6 + header_offset];
//	L_pixel(this,3+org_x,1+org_y) = inter_packet->data.u_byte[7 + header_offset];
//	L_pixel(this,0+org_x,2+org_y) = inter_packet->data.u_byte[0 + header_offset + 8];
//	L_pixel(this,1+org_x,2+org_y) = inter_packet->data.u_byte[1 + header_offset + 8];
//	L_pixel(this,2+org_x,2+org_y) = inter_packet->data.u_byte[2 + header_offset + 8];
//	L_pixel(this,3+org_x,2+org_y) = inter_packet->data.u_byte[3 + header_offset + 8];
//	L_pixel(this,0+org_x,3+org_y) = inter_packet->data.u_byte[4 + header_offset + 8];
//	L_pixel(this,1+org_x,3+org_y) = inter_packet->data.u_byte[5 + header_offset + 8];
//	L_pixel(this,2+org_x,3+org_y) = inter_packet->data.u_byte[6 + header_offset + 8];
//	L_pixel(this,3+org_x,3+org_y) = inter_packet->data.u_byte[7 + header_offset + 8];

	remove_packet_with_id(id);

	//uint32_t *dataptr = (uint32_t *)(&(inter_packet.flit[1]));

//	printf("-----------------------------------\n");
//
//	printf("flit1: 0x%016llx\n", inter_packet.flit[1]);
//	printf("flit2: 0x%016llx\n", inter_packet.flit[2]);
//
//	printf("*dataptr     : 0x%08lx\n", *dataptr);
//	printf("*(dataptr+1) : 0x%08lx\n", *(dataptr+1));
//	printf("*(dataptr+2) : 0x%08lx\n", *(dataptr+2));
//	printf("*(dataptr+3) : 0x%08lx\n", *(dataptr+3));

//	memcpy(&(L_pixel(this,org_x  ,org_y  )), dataptr + 1, 4);
//	memcpy(&(L_pixel(this,org_x  ,org_y+1)), dataptr    , 4);
//	memcpy(&(L_pixel(this,org_x  ,org_y+2)), dataptr + 3, 4);
//	memcpy(&(L_pixel(this,org_x  ,org_y+3)), dataptr + 2, 4);

}

void rx_luma_motion_comp_packet2(int id, frame *this, int org_x, int org_y, packet inter_packet)
{


	L_pixel(this,0+org_x,0+org_y) = (uint8_t)((inter_packet.data.flit[1]&0xFF00000000000000ull)>>56);
	L_pixel(this,1+org_x,0+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x00FF000000000000ull)>>48);
	L_pixel(this,2+org_x,0+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x0000FF0000000000ull)>>40);
	L_pixel(this,3+org_x,0+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x000000FF00000000ull)>>32);
	L_pixel(this,0+org_x,1+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x00000000FF000000ull)>>24);
	L_pixel(this,1+org_x,1+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x0000000000FF0000ull)>>16);
	L_pixel(this,2+org_x,1+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x000000000000FF00ull)>>8 );
	L_pixel(this,3+org_x,1+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x00000000000000FFull)>>0 );
	L_pixel(this,0+org_x,2+org_y) = (uint8_t)((inter_packet.data.flit[2]&0xFF00000000000000ull)>>56);
	L_pixel(this,1+org_x,2+org_y) = (uint8_t)((inter_packet.data.flit[2]&0x00FF000000000000ull)>>48);
	L_pixel(this,2+org_x,2+org_y) = (uint8_t)((inter_packet.data.flit[2]&0x0000FF0000000000ull)>>40);
	L_pixel(this,3+org_x,2+org_y) = (uint8_t)((inter_packet.data.flit[2]&0x000000FF00000000ull)>>32);
	L_pixel(this,0+org_x,3+org_y) = (uint8_t)((inter_packet.data.flit[2]&0x00000000FF000000ull)>>24);
	L_pixel(this,1+org_x,3+org_y) = (uint8_t)((inter_packet.data.flit[2]&0x0000000000FF0000ull)>>16);
	L_pixel(this,2+org_x,3+org_y) = (uint8_t)((inter_packet.data.flit[2]&0x000000000000FF00ull)>>8 );
	L_pixel(this,3+org_x,3+org_y) = (uint8_t)((inter_packet.data.flit[2]&0x00000000000000FFull)>>0 );

}

int send_chroma_motion_comp_packet(uint8_t *datacr,uint8_t *datacb, int xFrac, int yFrac)
{
	static int id = 32;
    id = rand()%32 + 65;
    uint32_t header_msw = xFrac;
    uint32_t header_lsw = (yFrac<<24) | (xFrac<<16) | (yFrac<<8) | id;
    uint32_t data_flit_0_msw;// = (datacr[7]<<24) | (datacr[6]<<16) | (datacr[5]<<8) | datacr[4];
    uint32_t data_flit_0_lsw;// = (datacr[3]<<24) | (datacr[2]<<16) | (datacr[1]<<8) | datacr[0];
    uint32_t data_flit_1_msw;// = (datacb[7]<<24) | (datacb[6]<<16) | (datacb[5]<<8) | datacb[4];
    uint32_t data_flit_1_lsw;// = (datacb[3]<<24) | (datacb[2]<<16) | (datacb[1]<<8) | datacb[0];
    uint32_t data_flit_2_msw = datacr[8];
    uint32_t data_flit_2_lsw = datacb[8];

    memcpy(&data_flit_0_msw, &(datacr[4]), 4);
    memcpy(&data_flit_0_lsw, &(datacr[0]), 4);
    memcpy(&data_flit_1_msw, &(datacb[4]), 4);
    memcpy(&data_flit_1_lsw, &(datacb[0]), 4);

    send_flit(4, header_msw, header_lsw, 0);
    send_flit(4, data_flit_0_msw, data_flit_0_lsw, 0);
    send_flit(4, data_flit_1_msw, data_flit_1_lsw, 0);
    send_flit(4, data_flit_2_msw, data_flit_2_lsw, 1);

    //send_flit2(4,&(datacr[0]),0);
    //send_flit2(4,&(datacb[0]),0);
    //send_flit(4, data_flit_2_msw, data_flit_2_lsw, 1);


    return id;

}

int send_chroma_motion_comp_packet_fast(frame *ref, int org_x, int org_y, int xFrac, int yFrac)
{
	static int id = 32;
    id = ((id+1)%32) + 65;
    uint32_t header_msw = xFrac;
    uint32_t header_lsw = (yFrac<<24) | (xFrac<<16) | (yFrac<<8) | id;

//    memcpy(&data_flit_0_msw, &(datacr[4]), 4);
//    memcpy(&data_flit_0_lsw, &(datacr[0]), 4);
//    memcpy(&data_flit_1_msw, &(datacb[4]), 4);
//    memcpy(&data_flit_1_lsw, &(datacb[0]), 4);

	send_flit(4, header_msw, header_lsw, 0);
//    send_flit(4, data_flit_0_msw, data_flit_0_lsw, 0);
//    send_flit(4, data_flit_1_msw, data_flit_1_lsw, 0);
//    send_flit(4, data_flit_2_msw, data_flit_2_lsw, 1);

    //send_flit2(4,&(datacr[0]),0);
    //send_flit2(4,&(datacb[0]),0);
    //send_flit(4, data_flit_2_msw, data_flit_2_lsw, 1);

    //write CB data 0..7
    int y1 = org_y>0?org_y:0;
    y1 = y1<ref->Cheight?y1:ref->Cheight-1;

    int y2 = org_y+1>0?org_y+1:0;
    y2 = y2<ref->Cheight?y2:ref->Cheight-1;

	int y3 = org_y+2>0?org_y+2:0;
	y3 = y3<ref->Cheight?y3:ref->Cheight-1;

    int x1 = org_x>0?org_x:0;
    x1 = x1<ref->Cwidth?x1:ref->Cwidth-1;

    int x2 = (org_x+1)>0?org_x+1:0;
	x2 = x2<ref->Cwidth?x2:ref->Cwidth-1;

    int x3 = (org_x+2)>0?org_x+2:0;
	x3 = x3<ref->Cwidth?x3:ref->Cwidth-1;

	//printf("%d %d %d %d %d %d\n", x1, x2, x3, y1, y2, y3);

	WR_PIO(TX_0_BASE, C_pixel(ref,0,x2,y3)  );
	WR_PIO(TX_1_BASE, C_pixel(ref,0,x1,y3)  );
	WR_PIO(TX_2_BASE, C_pixel(ref,0,x3,y2)  );
	WR_PIO(TX_3_BASE, C_pixel(ref,0,x2,y2)  );
	WR_PIO(TX_4_BASE, C_pixel(ref,0,x1,y2)  );
	WR_PIO(TX_5_BASE, C_pixel(ref,0,x3,y1)  );
	WR_PIO(TX_6_BASE, C_pixel(ref,0,x2,y1)  );
	WR_PIO(TX_7_BASE, C_pixel(ref,0,x1,y1)  );
	no_data_send(FORMAT_0 | IN_PLACE_CINTER_0_ADDR | CPU_TX_REQ);

	//Now CR
	WR_PIO(TX_0_BASE, C_pixel(ref,1,x2,y3)  );
	WR_PIO(TX_1_BASE, C_pixel(ref,1,x1,y3)  );
	WR_PIO(TX_2_BASE, C_pixel(ref,1,x3,y2)  );
	WR_PIO(TX_3_BASE, C_pixel(ref,1,x2,y2)  );
	WR_PIO(TX_4_BASE, C_pixel(ref,1,x1,y2)  );
	WR_PIO(TX_5_BASE, C_pixel(ref,1,x3,y1)  );
	WR_PIO(TX_6_BASE, C_pixel(ref,1,x2,y1)  );
	WR_PIO(TX_7_BASE, C_pixel(ref,1,x1,y1)  );
	no_data_send(FORMAT_0 | IN_PLACE_CINTER_0_ADDR | CPU_TX_REQ);

	//Now the last two samples which don't fit nicely...
	WR_PIO(TX_0_BASE, C_pixel(ref,0,x3,y3)  );
	WR_PIO(TX_1_BASE, C_pixel(ref,1,x3,y3)  );
	no_data_send(FORMAT_2 | IN_PLACE_CINTER_0_ADDR | CPU_TX_REQ | TAIL_FLIT_BIT);




    return id;

}



void rx_chroma_motion_comp_packet(int id, frame *this, int org_x, int org_y)
{
//	//printf("parsing inter packet!\n");
//	packet inter_packet;
//	do{
//		//printf("locating packet %d...\n", id);
//		peak_rx_buffer2(&inter_packet);
//		//printf("packet %d is at top of rx stack\n", inter_packet.identifier);
//	}while(inter_packet.identifier != id);
//	pop_rx_buffer();

	packet *inter_packet = (void *)0;
	while(inter_packet == (void *)0){
		inter_packet = get_packet_pointer_by_id(id);
		if(inter_packet == (void *)0){
			buffers_loop(1);
		}
	}


	C_pixel(this,0,0+org_x,0+org_y) = (uint8_t)((inter_packet->data.flit[1]&0xFF00000000000000ull)>>56);
	C_pixel(this,0,1+org_x,0+org_y) = (uint8_t)((inter_packet->data.flit[1]&0x00FF000000000000ull)>>48);
	C_pixel(this,0,0+org_x,1+org_y) = (uint8_t)((inter_packet->data.flit[1]&0x0000FF0000000000ull)>>40);
	C_pixel(this,0,1+org_x,1+org_y) = (uint8_t)((inter_packet->data.flit[1]&0x000000FF00000000ull)>>32);
	C_pixel(this,1,0+org_x,0+org_y) = (uint8_t)((inter_packet->data.flit[1]&0x00000000FF000000ull)>>24);
	C_pixel(this,1,1+org_x,0+org_y) = (uint8_t)((inter_packet->data.flit[1]&0x0000000000FF0000ull)>>16);
	C_pixel(this,1,0+org_x,1+org_y) = (uint8_t)((inter_packet->data.flit[1]&0x000000000000FF00ull)>>8 );
	C_pixel(this,1,1+org_x,1+org_y) = (uint8_t)((inter_packet->data.flit[1]&0x00000000000000FFull)>>0 );

	remove_packet_with_id(id);
}

void rx_chroma_motion_comp_packet2(int id, frame *this, int org_x, int org_y, packet inter_packet)
{


	C_pixel(this,0,0+org_x,0+org_y) = (uint8_t)((inter_packet.data.flit[1]&0xFF00000000000000ull)>>56);
	C_pixel(this,0,1+org_x,0+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x00FF000000000000ull)>>48);
	C_pixel(this,0,0+org_x,1+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x0000FF0000000000ull)>>40);
	C_pixel(this,0,1+org_x,1+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x000000FF00000000ull)>>32);
	C_pixel(this,1,0+org_x,0+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x00000000FF000000ull)>>24);
	C_pixel(this,1,1+org_x,0+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x0000000000FF0000ull)>>16);
	C_pixel(this,1,0+org_x,1+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x000000000000FF00ull)>>8 );
	C_pixel(this,1,1+org_x,1+org_y) = (uint8_t)((inter_packet.data.flit[1]&0x00000000000000FFull)>>0 );
}

void MotionCompensateTB(frame *this, frame *ref,
                        int org_x, int org_y,
                        int mvx, int mvy) {
  int x,y,iCbCr;


  //static uint64_t total_error[32] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  //static uint64_t total_counts[32] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

  int frac=(mvy&3)*4+(mvx&3);

  //int disp = 0;
  //if ((frac == 8) && (L_pixel(this,org_x,org_y) != 16))
  //{
  //disp = 1;
  //}

  int sw_mode = 0;
  if(sw_mode)
  {
	  L_MC_temp_block b=GetLMCTempBlock(ref,org_x+(mvx>>2)-2,org_y+(mvy>>2)-2);
	  //printf("org=%d,%d mv=%d,%d frac=%d\n",org_x,org_y,mvx,mvy,frac);
	  for(y=0; y<4; ++y)
		  for(x=0; x<4; ++x)
			  L_pixel(this,x+org_x,y+org_y)=L_MC_get_sub(&(b.p[y+2][x+2]),frac);

	  for(iCbCr=0; iCbCr<2; ++iCbCr) {
		C_MC_temp_block bc=GetCMCTempBlock(ref,iCbCr,(org_x>>1)+(mvx>>3),(org_y>>1)+(mvy>>3));

		org_x>>=1; org_y>>=1;
		int xFrac=(mvx&7), yFrac=(mvy&7);

		for(y=0; y<2; ++y)
		  for(x=0; x<2; ++x)
			C_pixel(this,iCbCr,x+org_x,y+org_y)=
			  ((8-xFrac)*(8-yFrac)*bc.p[y]  [x]  +
				  xFrac *(8-yFrac)*bc.p[y]  [x+1]+
			   (8-xFrac)*   yFrac *bc.p[y+1][x]  +
				  xFrac *   yFrac *bc.p[y+1][x+1]+
			 32)>>6;
	  }
  }
  else
  {
	  //printf("starting sub-pixel motion compensation...");

	  if(frac != 0){
		  int id0;
		  //L_MC_temp_block b=GetLMCTempBlock(ref,org_x+(mvx>>2)-2,org_y+(mvy>>2)-2);
		  id0 = send_luma_motion_comp_fast(ref, org_x+(mvx>>2)-2, org_y+(mvy>>2)-2, frac);

		  //C_MC_temp_block bcr = GetCMCTempBlock(ref,0,(org_x>>1)+(mvx>>3),(org_y>>1)+(mvy>>3));
		  //C_MC_temp_block bcb = GetCMCTempBlock(ref,1,(org_x>>1)+(mvx>>3),(org_y>>1)+(mvy>>3));

		  int xFrac=(mvx&7), yFrac=(mvy&7);
		  uint8_t zeros[9] = {0};
		  int id1 = send_chroma_motion_comp_packet_fast(ref, (org_x>>1)+(mvx>>3),(org_y>>1)+(mvy>>3), xFrac, yFrac);


		  rx_luma_motion_comp_packet(id0, this, org_x, org_y);
		  rx_chroma_motion_comp_packet(id1, this, (org_x>>1), (org_y>>1));
		  //printf("done!\n");
	  }
	  else{
		  L_MC_temp_block b=GetLMCTempBlock(ref,org_x+(mvx>>2)-2,org_y+(mvy>>2)-2);
		  C_MC_temp_block bcb = GetCMCTempBlock(ref,0,(org_x>>1)+(mvx>>3),(org_y>>1)+(mvy>>3));
		  C_MC_temp_block bcr = GetCMCTempBlock(ref,1,(org_x>>1)+(mvx>>3),(org_y>>1)+(mvy>>3));
		  int offset = 2;
		  L_pixel(this,0+org_x,0+org_y)         = b.p[0 + offset][0 + offset];
		  L_pixel(this,1+org_x,0+org_y)         = b.p[0 + offset][1 + offset];
		  L_pixel(this,2+org_x,0+org_y)         = b.p[0 + offset][2 + offset];
		  L_pixel(this,3+org_x,0+org_y)         = b.p[0 + offset][3 + offset];
		  L_pixel(this,0+org_x,1+org_y)         = b.p[1 + offset][0 + offset];
		  L_pixel(this,1+org_x,1+org_y)         = b.p[1 + offset][1 + offset];
		  L_pixel(this,2+org_x,1+org_y)         = b.p[1 + offset][2 + offset];
		  L_pixel(this,3+org_x,1+org_y)         = b.p[1 + offset][3 + offset];
		  L_pixel(this,0+org_x,2+org_y)         = b.p[2 + offset][0 + offset];
		  L_pixel(this,1+org_x,2+org_y)         = b.p[2 + offset][1 + offset];
		  L_pixel(this,2+org_x,2+org_y)         = b.p[2 + offset][2 + offset];
		  L_pixel(this,3+org_x,2+org_y)         = b.p[2 + offset][3 + offset];
		  L_pixel(this,0+org_x,3+org_y)         = b.p[3 + offset][0 + offset];
		  L_pixel(this,1+org_x,3+org_y)         = b.p[3 + offset][1 + offset];
		  L_pixel(this,2+org_x,3+org_y)         = b.p[3 + offset][2 + offset];
		  L_pixel(this,3+org_x,3+org_y)         = b.p[3 + offset][3 + offset];
		  C_pixel(this,0,0+(org_x>>1),0+(org_y>>1)) = bcb.p[0][0];
		  C_pixel(this,0,1+(org_x>>1),0+(org_y>>1)) = bcb.p[1][0];
		  C_pixel(this,0,0+(org_x>>1),1+(org_y>>1)) = bcb.p[0][1];
		  C_pixel(this,0,1+(org_x>>1),1+(org_y>>1)) = bcb.p[1][1];
		  C_pixel(this,1,0+(org_x>>1),0+(org_y>>1)) = bcr.p[0][0];
		  C_pixel(this,1,1+(org_x>>1),0+(org_y>>1)) = bcr.p[1][0];
		  C_pixel(this,1,0+(org_x>>1),1+(org_y>>1)) = bcr.p[0][1];
		  C_pixel(this,1,1+(org_x>>1),1+(org_y>>1)) = bcr.p[1][1];
	  }
  }
}

#if 0
void MotionCompensateMB(frame *this, frame *ref,
                        mode_pred_info *mpi,
                        int org_x, int org_y) {
  int x,y;
  static int count = 0;
  count++;

  int luma_ids[4];
  int chroma_ids[4];


  for(y=0; y<4; ++y){
    for(x=0; x<4; ++x){
    	MotionCompensateTB(this,ref,
    			           org_x|(x<<2), org_y|(y<<2),
                           ModePredInfo_MVx(mpi,(org_x>>2)+x,(org_y>>2)+y),
                           ModePredInfo_MVy(mpi,(org_x>>2)+x,(org_y>>2)+y)
                           );

//    	MotionCompensateTB_SEND_HALF(this,ref,
//    	    			           org_x|(x<<2), org_y|(y<<2),
//    	                           ModePredInfo_MVx(mpi,(org_x>>2)+x,(org_y>>2)+y),
//    	                           ModePredInfo_MVy(mpi,(org_x>>2)+x,(org_y>>2)+y),
//    	                           &(luma_ids[x]),
//    	                           &(chroma_ids[x]));

    }

//    buffers_loop(1);
//
//    for(x=0; x<4; ++x){
//    	packet the_packet = get_packet_by_id(luma_ids[x]);
//    	rx_luma_motion_comp_packet2(luma_ids[x], this, org_x|(x<<2), org_y|(y<<2), the_packet);
//    	the_packet = get_packet_by_id(chroma_ids[x]);
//    	rx_chroma_motion_comp_packet2(chroma_ids[x], this, (org_x|(x<<2))>>1, (org_y|(y<<2))>>1, the_packet);
//    }
//
//    for(int i = 0; i<1; i++)
//    {
//    	pop_rx_buffer();
//    }

  }
}
#endif

//TODO GET THIS WORKING
//void MotionCompensateMB_3(frame *this,
//		                  frame *ref,
//                          int mvx[16],
//						  int mvy[16],
//                          int org_x,
//                          int org_y
//                          ) {
//	int done = 0;
//	int last_sent      = -1;
//	int last_rxd       = -1;
//	int send_order[32] = {0};
//	int x[32]          = {0};
//	int y[32]          = {0};
//
//	while(!done){
//		if(get_buffer_rx_state() != 0){
//			buffers_loop(1);
//			last_rxd += 1;
//			if(last_rxd < 16){
//				rx_luma_motion_comp_packet(send_order[last_rxd], this, x[last_rxd], y[last_rxd]);
//			}else{
//				rx_chroma_motion_comp_packet(send_order[last_rxd], this, x[last_rxd], y[last_rxd]);
//			}
//		}else if(ready_2_send()){
//			last_sent += 1;
//			if(last_sent < 16){
//				int frac=(mvy[last_sent]&3)*4+(mvx[last_sent]&3);
//				L_MC_temp_block b=GetLMCTempBlock(ref,org_x+(mvx[last_sent]>>2)-2,org_y+(mvy[last_sent]>>2)-2);
//				send_order[last_sent] = send_luma_motion_comp_packet(&(b.p[0][0]), frac);
//				x[last_sent] = org_x + 4 * (last_sent % 4);
//				y[last_sent] = org_y + 4 * (last_sent / 4);
//			}else{
//				  C_MC_temp_block bcr = GetCMCTempBlock(ref,0,(org_x>>1)+(mvx[last_sent]>>3),(org_y>>1)+(mvy[last_sent]>>3));
//				  C_MC_temp_block bcb = GetCMCTempBlock(ref,1,(org_x>>1)+(mvx[last_sent]>>3),(org_y>>1)+(mvy[last_sent]>>3));
//				  int xFrac=(mvx[last_sent]&7), yFrac=(mvy[last_sent]&7);
//				  send_order[last_sent] = send_chroma_motion_comp_packet(&(bcr.p[0][0]),&(bcb.p[0][0]), xFrac, yFrac);
//				  x[last_sent] = org_x<<1 + 2 * ((last_sent-16) % 4);
//				  y[last_sent] = org_y<<1 + 2 * ((last_sent-16) / 4);
//			}
//
//		}
//
//		done = (last_rxd>=32)?1:0;
//
//	}
//
//}



int MotionCompensateTB_send_HW(frame *this, frame *ref,
                        int org_x, int org_y,
                        int mvx, int mvy) {
	int x,y,iCbCr;

	int frac=(mvy&3)*4+(mvx&3);
	//printf("starting sub-pixel motion compensation...");

	int id0;
	//L_MC_temp_block b=GetLMCTempBlock(ref,org_x+(mvx>>2)-2,org_y+(mvy>>2)-2);
	id0 = send_luma_motion_comp_fast(ref, org_x+(mvx>>2)-2, org_y+(mvy>>2)-2, frac);

	//C_MC_temp_block bcr = GetCMCTempBlock(ref,0,(org_x>>1)+(mvx>>3),(org_y>>1)+(mvy>>3));
	//C_MC_temp_block bcb = GetCMCTempBlock(ref,1,(org_x>>1)+(mvx>>3),(org_y>>1)+(mvy>>3));

	int xFrac=(mvx&7), yFrac=(mvy&7);
	uint8_t zeros[9] = {0};
	int id1 = send_chroma_motion_comp_packet_fast(ref, (org_x>>1)+(mvx>>3),(org_y>>1)+(mvy>>3), xFrac, yFrac);

	return (id0<<8) | id1;
}


int motion_comp_send_luma(frame *this, frame *ref,
                        int org_x, int org_y,
                        int mvx, int mvy, int select){
    int frac=(mvy&3)*4+(mvx&3);
    if(select == 0){
        return send_luma_motion_comp_fast(ref, org_x+(mvx>>2)-2, org_y+(mvy>>2)-2, frac); 
    }
    else{
        return send_luma_1_motion_comp_fast(ref, org_x+(mvx>>2)-2, org_y+(mvy>>2)-2, frac); 
    }
}

int motion_comp_send_chroma(frame *this, frame *ref,
                        int org_x, int org_y,
                        int mvx, int mvy){
    int xFrac=(mvx&7), yFrac=(mvy&7);
    return send_chroma_motion_comp_packet_fast(ref, (org_x>>1)+(mvx>>3),(org_y>>1)+(mvy>>3), xFrac, yFrac);  
}

void MotionCompensateTB_SW(frame *this, frame *ref,
                        int org_x, int org_y,
                        int mvx, int mvy) {
  int x,y,iCbCr;
  L_MC_temp_block b=GetLMCTempBlock(ref,org_x+(mvx>>2)-2,org_y+(mvy>>2)-2);
  int frac=(mvy&3)*4+(mvx&3);
//printf("org=%d,%d mv=%d,%d frac=%d\n",org_x,org_y,mvx,mvy,frac);
  for(y=0; y<4; ++y)
    for(x=0; x<4; ++x)
      L_pixel(this,x+org_x,y+org_y)=L_MC_get_sub(&(b.p[y+2][x+2]),frac);

  org_x>>=1; org_y>>=1;
  for(iCbCr=0; iCbCr<2; ++iCbCr) {
    C_MC_temp_block b=GetCMCTempBlock(ref,iCbCr,
                      org_x+(mvx>>3),org_y+(mvy>>3));
    int xFrac=(mvx&7), yFrac=(mvy&7);
    for(y=0; y<2; ++y)
      for(x=0; x<2; ++x)
        C_pixel(this,iCbCr,x+org_x,y+org_y)=
          ((8-xFrac)*(8-yFrac)*b.p[y]  [x]  +
              xFrac *(8-yFrac)*b.p[y]  [x+1]+
           (8-xFrac)*   yFrac *b.p[y+1][x]  +
              xFrac *   yFrac *b.p[y+1][x+1]+
         32)>>6;
  }
}

void sw_inter_luma(frame *this, frame *ref,
                        int org_x, int org_y,
                        int mvx, int mvy) {
  int x,y,iCbCr;
  L_MC_temp_block b=GetLMCTempBlock(ref,org_x+(mvx>>2)-2,org_y+(mvy>>2)-2);
  int frac=(mvy&3)*4+(mvx&3);
  for(y=0; y<4; ++y)
    for(x=0; x<4; ++x)
      L_pixel(this,x+org_x,y+org_y)=L_MC_get_sub(&(b.p[y+2][x+2]),frac);
}

void sw_inter_chroma(frame *this, frame *ref,
                        int org_x, int org_y,
                        int mvx, int mvy) {
  int x,y,iCbCr;
  org_x>>=1; org_y>>=1;
  for(iCbCr=0; iCbCr<2; ++iCbCr) {
    C_MC_temp_block b=GetCMCTempBlock(ref,iCbCr,
                      org_x+(mvx>>3),org_y+(mvy>>3));
    int xFrac=(mvx&7), yFrac=(mvy&7);
    for(y=0; y<2; ++y)
      for(x=0; x<2; ++x)
        C_pixel(this,iCbCr,x+org_x,y+org_y)=
          ((8-xFrac)*(8-yFrac)*b.p[y]  [x]  +
              xFrac *(8-yFrac)*b.p[y]  [x+1]+
           (8-xFrac)*   yFrac *b.p[y+1][x]  +
              xFrac *   yFrac *b.p[y+1][x+1]+
         32)>>6;
  }
}

void MotionCompensateTB_rx_HW(frame *this,
                        int org_x, int org_y,
                        int luma_id, int chroma_id) {

  rx_luma_motion_comp_packet(luma_id, this, org_x, org_y);
  rx_chroma_motion_comp_packet(chroma_id, this, (org_x>>1), (org_y>>1));

}


void MotionCompensateMB_5(frame *this,
		                  frame *ref,
                          int mvx[16],
						  int mvy[16],
                          int org_x,
                          int org_y
                          ) {
	  int x,y;
	  for(y=0; y<4; ++y){
	    for(x=0; x<4; x += 4){
	    	int ids = MotionCompensateTB_send_HW(this,ref,
	    			                             org_x|(x<<2),
	    			                             org_y|(y<<2),
	                                             mvx[x+y*4],
	                                             mvy[x+y*4]);
	    	int luma_id = ids>>8;
	    	int chroma_id = ids & 0xFF;
	    	MotionCompensateTB_SW(this,ref,
	                              org_x|((x+1)<<2),
	                              org_y|(y<<2),
                                  mvx[(x+1)+y*4],
                                  mvy[(x+1)+y*4]);
                                  
	    	MotionCompensateTB_SW(this,ref,
	                              org_x|((x+2)<<2),
	                              org_y|(y<<2),
                                  mvx[(x+1)+y*4],
                                  mvy[(x+1)+y*4]);
                                  
	    	MotionCompensateTB_SW(this,ref,
	                              org_x|((x+3)<<2),
	                              org_y|(y<<2),
                                  mvx[(x+1)+y*4],
                                  mvy[(x+1)+y*4]);

	    	MotionCompensateTB_rx_HW(this,
	    		    			     org_x|(x<<2),
	    		    			     org_y|(y<<2),
	    		    			     luma_id,
	    		    			     chroma_id);

	    }
	  }
}

void MotionCompensateMB_6(frame *this,
		                  frame *ref,
                          int mvx[16],
						  int mvy[16],
                          int org_x,
                          int org_y
                          ) {
	  int x,y;
      int luma_id = 0;
      int chroma_id = 0;
      packet *luma_packet = (void *)0;
      packet *chroma_packet = (void *)0;
      int last_hw_x, last_hw_y, waiting_for_resp;
      
	  for(y=0; y<4; ++y){
	    for(x=0; x<4; x++){           
            if(luma_id == 0){ 
                //if first run through transmitt inter requests
                int ids = MotionCompensateTB_send_HW(this,ref,
                                                    org_x|(x<<2),
                                                    org_y|(y<<2),
                                                    mvx[x+y*4],
                                                    mvy[x+y*4]);
                luma_id = ids>>8;
                chroma_id = ids & 0xFF;
                last_hw_x = org_x|(x<<2);
                last_hw_y = org_y|(y<<2);
                waiting_for_resp = 1;
            }
            else if(get_packet_pointer_by_id(luma_id) != (void *)0){
                //parse packet and send another
                MotionCompensateTB_rx_HW(this,
	    		    			     last_hw_x,
	    		    			     last_hw_y ,
	    		    			     luma_id,
	    		    			     chroma_id);
                int ids = MotionCompensateTB_send_HW(this,ref,
                                    org_x|(x<<2),
                                    org_y|(y<<2),
                                    mvx[x+y*4],
                                    mvy[x+y*4]);
                luma_id = ids>>8;
                chroma_id = ids & 0xFF;
                last_hw_x = org_x|(x<<2);
                last_hw_y = org_y|(y<<2);
                waiting_for_resp = 1;
            }
            else{
                //while we wait do some in sw
                MotionCompensateTB_SW(this,ref,
	                              org_x|((x)<<2),
	                              org_y|(y<<2),
                                  mvx[(x+0)+y*4],
                                  mvy[(x+0)+y*4]);
            }

	    }
	  }
      
      if(waiting_for_resp)
      {
        MotionCompensateTB_rx_HW(this,
                                 last_hw_x,
                                 last_hw_y ,
                                 luma_id,
                                 chroma_id);
      }
}

void MotionCompensateMB_7(frame *this,
		                  frame *ref,
                          int mvx[16],
						  int mvy[16],
                          int org_x,
                          int org_y
                          ) {
    int x,y;
    int luma_id_0 = 1;
    int luma_id_1 = 1;
    int chroma_id_0 = 1;
    int chroma_id_1 = 0;
    int luma_0_hw_x,   luma_0_hw_y,   waiting_hw_luma_0 = 0;
    int luma_1_hw_x,   luma_1_hw_y,   waiting_hw_luma_1 = 0;
    int chroma_0_hw_x, chroma_0_hw_y, waiting_hw_chroma_0 = 0;

    for(y=0; y<4; ++y){
        for(x=0; x<4; x++){
            if(luma_id_0==0){
                //printf("sending to luma node 0\n");
                luma_id_0 = motion_comp_send_luma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4], 0);
                luma_0_hw_x = org_x|(x<<2);
                luma_0_hw_y = org_y|(y<<2);
                waiting_hw_luma_0 = 1;
                //printf(".\n");
            }
            else if(luma_id_1==0){
                //printf("sending to luma node 1\n");
                luma_id_1 = motion_comp_send_luma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4], 1);
                luma_1_hw_x = org_x|(x<<2);
                luma_1_hw_y = org_y|(y<<2);
                waiting_hw_luma_1 = 1;
                //printf(".\n");
            }
            else if(rx_packet_by_id_no_block(luma_id_0, 1) != (void *)0){
                //printf("recieved from luma node 0\n");
                rx_luma_motion_comp_packet(luma_id_0, this, luma_0_hw_x, luma_0_hw_y);
                luma_id_0 = motion_comp_send_luma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4], 0);
                luma_0_hw_x = org_x|(x<<2);
                luma_0_hw_y = org_y|(y<<2);
                waiting_hw_luma_0 = 1;
                //printf(".\n");
            }
            else if(rx_packet_by_id_no_block(luma_id_1, 1) != (void *)0){
                //printf("recieved from luma node 1\n");
                rx_luma_motion_comp_packet(luma_id_1, this, luma_1_hw_x, luma_1_hw_y);
                luma_id_1 = motion_comp_send_luma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4], 1);
                luma_1_hw_x = org_x|(x<<2);
                luma_1_hw_y = org_y|(y<<2);
                waiting_hw_luma_1 = 1;
                //printf(".\n");
            }
            else{
                //printf("using SW luma inter\n");
                sw_inter_luma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4]);
                //printf(".\n");
            }


            if(chroma_id_0==0){
                //printf("sending to chroma node\n");
                chroma_id_0=motion_comp_send_chroma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4]);
                chroma_0_hw_x = org_x|(x<<2);
                chroma_0_hw_y = org_y|(y<<2);
                waiting_hw_chroma_0 = 1;
                //printf(".\n");
            }
            else if(rx_packet_by_id_no_block(chroma_id_0, 1) != (void *)0){
                //printf("recieved from chroma node\n");
                rx_chroma_motion_comp_packet(chroma_id_0, this, (chroma_0_hw_x>>1), (chroma_0_hw_y>>1));
                chroma_id_0=motion_comp_send_chroma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4]);
                chroma_0_hw_x = org_x|(x<<2);
                chroma_0_hw_y = org_y|(y<<2);
                waiting_hw_chroma_0 = 1;
                //printf(".\n");
            }
            else{
                //printf("using SW chroma inter\n");
                sw_inter_chroma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4]);
                //printf(".\n");
            }
        }
    }
    //printf("loop exited\n");

    if(waiting_hw_luma_0){
        //printf("waiting for luma 0\n");
        rx_luma_motion_comp_packet(luma_id_0, this, luma_0_hw_x, luma_0_hw_y);
    }
    if(waiting_hw_luma_1){
        //printf("waiting for luma 1\n");
        rx_luma_motion_comp_packet(luma_id_1, this, luma_1_hw_x, luma_1_hw_y);
    }
    if(waiting_hw_chroma_0){
        //printf("waiting for chroma\n");
        rx_chroma_motion_comp_packet(chroma_id_0, this, (chroma_0_hw_x>>1), (chroma_0_hw_y>>1));
    }
    //printf("done with motion comp... for now\n");


}


void MotionCompensateMB_2(frame *this,
		                  frame *ref,
                          int mvx[16],
						  int mvy[16],
                          int org_x,
                          int org_y
                          ) {
  int x,y;
  static int count = 0;
  count++;

  int luma_ids[4];
  int chroma_ids[4];


  for(y=0; y<4; ++y){
    for(x=0; x<4; ++x){
    	MotionCompensateTB(this,ref,
    			           org_x|(x<<2),
    			           org_y|(y<<2),
                           mvx[x+y*4],
                           mvy[x+y*4]);
    }
  }
}


