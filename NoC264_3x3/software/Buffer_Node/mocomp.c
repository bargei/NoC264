#include "common.h"
#include "noc_control.h"
#include <inttypes.h>
#include "system.h"
#include <altera_avalon_pio_regs.h>
#include <system.h>
#include "hw_timer.h"

static uint64_t start;

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
	  return p(0,0);
  }
  b=Filter(p(-2,0),p(-1,0),p(0,0),p(1,0),p(2,0),p(3,0));
  iffrac(1,0){
	  return Mix(p(0,0),b);
  }
  iffrac(2,0){
	  return b;
  }
  iffrac(3,0){
	  return Mix(b,p(1,0));
  }
  h=Filter(p(0,-2),p(0,-1),p(0,0),p(0,1),p(0,2),p(0,3));
  iffrac(0,1){
	  return Mix(p(0,0),h);
  }
  iffrac(0,2){
	  return h;
  }
  iffrac(0,3){
	  return Mix(h,p(0,1));
  }
  iffrac(1,1){
	  return Mix(b,h);
  }
  m=Filter(p(1,-2),p(1,-1),p(1,0),p(1,1),p(1,2),p(1,3));
  iffrac(3,1){
	  return Mix(b,m);
  }
  s=Filter(p(-2,1),p(-1,1),p(0,1),p(1,1),p(2,1),p(3,1));
  iffrac(1,3){
	  return Mix(h,s);
  }
  iffrac(3,3){
	  return Mix(s,m);
  }
  cc=Filter(p(-2,-2),p(-2,-1),p(-2,0),p(-2,1),p(-2,2),p(-2,3));
  dd=Filter(p(-1,-2),p(-1,-1),p(-1,0),p(-1,1),p(-1,2),p(-1,3));
  ee=Filter(p(2,-2),p(2,-1),p(2,0),p(2,1),p(2,2),p(2,3));
  ff=Filter(p(3,-2),p(3,-1),p(3,0),p(3,1),p(3,2),p(3,3));
  j=Filter(cc,dd,h,m,ee,ff);
  iffrac(2,2){
	  return j;
  }
  iffrac(2,1){
	  return Mix(b,j);
  }
  iffrac(1,2){
	  return Mix(h,j);
  }
  iffrac(2,3){
	  return Mix(j,s);
  }
  iffrac(3,2){
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
	send_flit(LINTER_0_ADDR, id, id, 0);
	uint32_t sizes = (0x0F & (uint64_t)frac) | (4 << 8) | (4 << 16);
	send_flit(LINTER_0_ADDR, 0, sizes, 0);

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

void rx_luma_motion_comp_packet(int id, frame *this, int org_x, int org_y)
{
	//start = read_timer();
	packet *inter_packet = (void *)0;
	while(inter_packet == (void *)0){
		inter_packet = get_packet_pointer_by_id(id);
		if(inter_packet == (void *)0){
			buffers_loop(1);
			//print_rx_buffer();
		}
	}

	inter_rx_struct *flit_1 = (inter_rx_struct *)(&(inter_packet->data.flit[1]));
	inter_rx_struct *flit_2 = (inter_rx_struct *)(&(inter_packet->data.flit[2]));

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

	remove_packet_with_id(id);

}

int send_chroma_motion_comp_packet_fast(frame *ref, int org_x, int org_y, int xFrac, int yFrac)
{
	static int id = 32;
    id = ((id+1)%32) + 65;
    uint32_t header_msw = xFrac;
    uint32_t header_lsw = (yFrac<<24) | (xFrac<<16) | (yFrac<<8) | id;


	send_flit(4, header_msw, header_lsw, 0);

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

	//start = read_timer();
	packet *inter_packet = (void *)0;
	while(inter_packet == (void *)0){
		inter_packet = get_packet_pointer_by_id(id);
		if(inter_packet == (void *)0){
			buffers_loop(1);
		}
	}
	//add_time(HW_INTER_COUNTS, read_timer() - start);

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

	  if((frac != 0)){
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

int send_luma_1_motion_comp_fast(frame *ref, int org_x, int org_y, int frac){
	static int id = 127;
	id = (id+1)%(LUMA_1_MOCOMP_MAX-LUMA_1_MOCOMP_MIN) + LUMA_1_MOCOMP_MIN;

	send_flit(LINTER_1_ADDR, id, id, 0);
	uint32_t sizes = (0x0F & (uint64_t)frac) | (4 << 8) | (4 << 16);

	send_flit(LINTER_1_ADDR, 0, sizes, 0);


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
			//printf("    *\n");
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
			//printf("    ~\n");

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
            //    printf("luma 0 sent packet with id: %d\n", luma_id_0);
                luma_0_hw_x = org_x|(x<<2);
                luma_0_hw_y = org_y|(y<<2);
                waiting_hw_luma_0 = 1;
                //printf(".\n");
            }
            else if(luma_id_1==0){
                //printf("sending to luma node 1\n");
                luma_id_1 = motion_comp_send_luma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4], 1);
              //  printf("luma 1 sent packet with id: %d\n", luma_id_1);
                luma_1_hw_x = org_x|(x<<2);
                luma_1_hw_y = org_y|(y<<2);
                waiting_hw_luma_1 = 1;
                //printf(".\n");
            }
            else if(rx_packet_by_id_no_block(luma_id_0, 1) != (void *)0){
            //    printf("recieved from luma node 0 (id = %d)\n", luma_id_0);
                rx_luma_motion_comp_packet(luma_id_0, this, luma_0_hw_x, luma_0_hw_y);
                luma_id_0 = motion_comp_send_luma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4], 0);
             //   printf("luma 0 sent packet with id: %d\n", luma_id_0);
                luma_0_hw_x = org_x|(x<<2);
                luma_0_hw_y = org_y|(y<<2);
                waiting_hw_luma_0 = 1;
                //printf(".\n");
            }
            else if(rx_packet_by_id_no_block(luma_id_1, 1) != (void *)0){
            //    printf("recieved from luma node 1(id = %d)\n", luma_id_1);
                rx_luma_motion_comp_packet(luma_id_1, this, luma_1_hw_x, luma_1_hw_y);
                luma_id_1 = motion_comp_send_luma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4], 1);
            //    printf("luma 1 sent packet with id: %d\n", luma_id_1);
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
              //  printf("sending to chroma node\n");
                chroma_id_0=motion_comp_send_chroma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4]);
              //  printf("chroma 0 sent packet with id: %d\n", chroma_id_0);
                chroma_0_hw_x = org_x|(x<<2);
                chroma_0_hw_y = org_y|(y<<2);
                waiting_hw_chroma_0 = 1;
                //printf(".\n");
            }
            else if(rx_packet_by_id_no_block(chroma_id_0, 1) != (void *)0){
            //	printf("recieved from chroma node 0(id = %d)\n", chroma_id_0);
                rx_chroma_motion_comp_packet(chroma_id_0, this, (chroma_0_hw_x>>1), (chroma_0_hw_y>>1));
                chroma_id_0=motion_comp_send_chroma(this,ref,org_x|(x<<2),org_y|(y<<2),mvx[x+y*4], mvy[x+y*4]);
            //    printf("chroma 0 sent packet with id: %d\n", chroma_id_0);
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



//    rx_packet_by_id_no_block(chroma_id_0, 1);
//    rx_packet_by_id_no_block(luma_id_0, 1);
//    rx_packet_by_id_no_block(luma_id_1, 1);
//    print_rx_buffer();

    if(waiting_hw_luma_0){
        //printf("waiting for luma 0 (id = %d)\n", luma_id_0);
        rx_luma_motion_comp_packet(luma_id_0, this, luma_0_hw_x, luma_0_hw_y);
    }
    if(waiting_hw_luma_1){
    	//printf("waiting for luma 1 (id = %d)\n", luma_id_1);
        rx_luma_motion_comp_packet(luma_id_1, this, luma_1_hw_x, luma_1_hw_y);
    }
    if(waiting_hw_chroma_0){
    	//printf("waiting for chroma 0 (id = %d)\n", chroma_id_0);
        rx_chroma_motion_comp_packet(chroma_id_0, this, (chroma_0_hw_x>>1), (chroma_0_hw_y>>1));
    }
    //printf("--------------------------------------------\n");
    //while(1);


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


