#include "common.h"
#include "input.h"
#include "cavlc.h"
#include "params.h"
#include "mbmodes.h"
#include "residual.h"
#include "mode_pred.h"
#include "intra_pred.h"
#include "mocomp.h"
#include "block.h"
#include "slicehdr.h"
#include "slice.h"
#include "noc_control.h"
#include "Buffer_Node_Sim.h"

extern int frame_no;

// needed from mbmodes.c
extern int CodedBlockPatternMapping_Intra4x4[];
extern int CodedBlockPatternMapping_Inter[];

int Intra4x4ScanOrder[16][2]={
  { 0, 0},  { 4, 0},  { 0, 4},  { 4, 4},
  { 8, 0},  {12, 0},  { 8, 4},  {12, 4},
  { 0, 8},  { 4, 8},  { 0,12},  { 4,12},
  { 8, 8},  {12, 8},  { 8,12},  {12,12}
};

int QPcTable[22]=
  {29,30,31,32,32,33,34,34,35,35,36,36,37,37,37,38,38,38,39,39,39,39};


// some macros for easier access to the various ModePredInfo structures
#define LumaDC_nC     get_luma_nC(mpi,mb_pos_x,mb_pos_y)
#define LumaAC_nC     get_luma_nC(mpi,mb_pos_x+Intra4x4ScanOrder[i8x8*4+i4x4][0],mb_pos_y+Intra4x4ScanOrder[i8x8*4+i4x4][1])
#define ChromaDC_nC   -1
#define ChromaAC_nC   get_chroma_nC(mpi,mb_pos_x+(i4x4&1)*8,mb_pos_y+(i4x4>>1)*8,iCbCr)
#define LumaAdjust    ModePredInfo_TotalCoeffL(mpi,(mb_pos_x+Intra4x4ScanOrder[i8x8*4+i4x4][0])>>2,(mb_pos_y+Intra4x4ScanOrder[i8x8*4+i4x4][1])>>2) =
#define ChromaAdjust  ModePredInfo_TotalCoeffC(mpi,(mb_pos_x+(i4x4&1)*8)>>3,(mb_pos_y+(i4x4>>1)*8)>>3,iCbCr) =
#define Intra4x4PredMode(i) ModePredInfo_Intra4x4PredMode(mpi,(mb_pos_x+Intra4x4ScanOrder[i][0])>>2,(mb_pos_y+Intra4x4ScanOrder[i][1])>>2)

///////////////////////////////////////////////////////////////////////////////
void decode_slice_data(slice_header *sh,
                       seq_parameter_set *sps, pic_parameter_set *pps,
                       nal_unit *nalu,
                       frame *this, frame *ref,
                       mode_pred_info *mpi) {

    int CurrMbAddr=sh->first_mb_in_slice*(1+sh->MbaffFrameFlag);
    int moreDataFlag=1;
    int prevMbSkipped=0;
    int MbCount=mpi->MbWidth*mpi->MbHeight;
    int mb_skip_run;
    int mb_qp_delta;
    int QPy,QPc;
    int intra_chroma_pred_mode=0;

    int mb_pos_x,mb_pos_y;
    mb_mode mb;
    sub_mb_mode sub[4];

    // transform coefficient levels
    int LumaDCLevel[16];      // === Intra16x16DCLevel
    int LumaACLevel[16][16];  // === Intra16x16ACLevel
    int ChromaDCLevel[2][4];
    int ChromaACLevel[2][4][16];

    // initialize some values
    clear_mode_pred_info(mpi);
    QPy=sh->SliceQPy;
    QPc=QPy;  // only to prevent a warning

    moreDataFlag=more_rbsp_data(nalu);
    while(moreDataFlag && CurrMbAddr<MbCount) {

        // mb_skip_run ////////////////////////////////////////////////////////////
        if(sh->slice_type!=I_SLICE && sh->slice_type!=SI_SLICE) {
            mb_skip_run=get_unsigned_exp_golomb();
            prevMbSkipped=(mb_skip_run>0);
            for(; mb_skip_run; --mb_skip_run, ++CurrMbAddr) {
                if(CurrMbAddr>=MbCount) return;
                mb_pos_x=CurrMbAddr%sps->PicWidthInMbs;
                mb_pos_y=CurrMbAddr/sps->PicWidthInMbs;
                ModePredInfo_MbMode(mpi,mb_pos_x,mb_pos_y)=P_Skip;
                mb_pos_x<<=4; mb_pos_y<<=4;
                Derive_P_Skip_MVs(mpi,mb_pos_x,mb_pos_y);
                //MotionCompensateMB(this,ref,mpi,mb_pos_x,mb_pos_y);
                send_inter_info( 7,          //int addr,
								 mpi,        //mode_pred_info *mpi,
								 mb_pos_x,   //int org_x,
								 mb_pos_y    //int org_y
								);
				//simulate_buffer_node(/*this, ref*/);



            }
            moreDataFlag=more_rbsp_data(nalu);
        }
        if(CurrMbAddr>=MbCount) return;

        if(moreDataFlag) {  // macroblock_layer() /////////////////////////////////
            decode_mb_mode(&mb,sh->slice_type,get_unsigned_exp_golomb());
            mb_pos_x=CurrMbAddr%sps->PicWidthInMbs;
            mb_pos_y=CurrMbAddr/sps->PicWidthInMbs;
            ModePredInfo_MbMode(mpi,mb_pos_x,mb_pos_y)=mb.mb_type;
            mb_pos_x<<=4; mb_pos_y<<=4;
            if(mb.mb_type==I_PCM) {  // I_PCM macroblock ////////////////////////////
                int x,y,iCbCr;
                unsigned char *pos;
                input_align_to_next_byte();
                //pos=&L_pixel(this,mb_pos_x,mb_pos_y);
                uint8_t data[256];
                int data_index = 0;

                for(y=16; y; --y) {
                	for(x=16; x; --x){
                		//*pos++=input_get_byte();
                		data[data_index++] = input_get_byte();
                	}
                	//pos+=this->Lpitch-16;
                }
                send_direct_write(7,mb_pos_x, mb_pos_y, 16, 16, 0, data, 0);
                //simulate_buffer_node(/*this, ref*/);


                for(iCbCr=0; iCbCr<2; ++iCbCr) {
                    pos=&C_pixel(this,iCbCr,mb_pos_x>>1,mb_pos_y>>1);
                    for(y=8; y; --y) {
                        for(x=8; x; --x){
                            *pos++=input_get_byte();
                        }
                        pos+=this->Cpitch-8;
                    }
                }
                // fix mode_pred_info->TotalCoeff data
                for(y=0; y<4; ++y)
                    for(x=0; x<4; ++x)
                        ModePredInfo_TotalCoeffL(mpi,(mb_pos_x>>2)+x,(mb_pos_y>>2)+y)=16;
                for(y=0; y<2; ++y)
                    for(x=0; x<2; ++x) {
                    ModePredInfo_TotalCoeffC(mpi,(mb_pos_x>>3)+x,(mb_pos_y>>3)+y,0)=16;
                    ModePredInfo_TotalCoeffC(mpi,(mb_pos_x>>3)+x,(mb_pos_y>>3)+y,1)=16;
                    }
            }
            else {  // "normal" macroblock ////////////////////////////////////////

                if(mb.MbPartPredMode[0]!=Intra_4x4 &&
                mb.MbPartPredMode[0]!=Intra_16x16 &&
                mb.NumMbPart==4)
                { // sub_mb_pred() ////////////////////////////////////////////////////
                int mbPartIdx,subMbPartIdx;
                for(mbPartIdx=0; mbPartIdx<4; ++mbPartIdx)
                    decode_sub_mb_mode(&sub[mbPartIdx],sh->slice_type,
                                    get_unsigned_exp_golomb());
                for(mbPartIdx=0; mbPartIdx<4; ++mbPartIdx)
                    if(sub[mbPartIdx].sub_mb_type!=B_Direct_8x8 &&
                    sub[mbPartIdx].SubMbPredMode!=Pred_L1)
                    { // SOF = "scan order factor"
                    int SOF=(sub[mbPartIdx].sub_mb_type==P_L0_8x4)?2:1;
                    for(subMbPartIdx=0; subMbPartIdx<sub[mbPartIdx].NumSubMbPart; ++subMbPartIdx) {
                        int mvdx=get_signed_exp_golomb();
                        int mvdy=get_signed_exp_golomb();
                        DeriveMVs(mpi,
                        mb_pos_x+Intra4x4ScanOrder[mbPartIdx*4+subMbPartIdx*SOF][0],
                        mb_pos_y+Intra4x4ScanOrder[mbPartIdx*4+subMbPartIdx*SOF][1],
                        sub[mbPartIdx].SubMbPartWidth,
                        sub[mbPartIdx].SubMbPartHeight,
                        mvdx, mvdy);
                    }
                    }
                }
                else {  // mb_pred() ////////////////////////////////////////////////
                    if(mb.MbPartPredMode[0]==Intra_4x4 ||
                        mb.MbPartPredMode[0]==Intra_16x16)
                    {  // mb_pred() for intra macroblocks ///////////////////////////////
                        if(mb.MbPartPredMode[0]==Intra_4x4) {
                        int luma4x4BlkIdx;
                            for(luma4x4BlkIdx=0; luma4x4BlkIdx<16; ++luma4x4BlkIdx) {
                                int predIntra4x4PredMode=get_predIntra4x4PredMode(mpi,
                                    mb_pos_x+Intra4x4ScanOrder[luma4x4BlkIdx][0],
                                    mb_pos_y+Intra4x4ScanOrder[luma4x4BlkIdx][1]);
                                if(input_get_one_bit())  // prev_intra4x4_pred_mode_flag
                                Intra4x4PredMode(luma4x4BlkIdx)=predIntra4x4PredMode;
                                else {
                                int rem_intra4x4_pred_mode=input_get_bits(3);
                                if(rem_intra4x4_pred_mode<predIntra4x4PredMode)
                                    Intra4x4PredMode(luma4x4BlkIdx)=rem_intra4x4_pred_mode;
                                else
                                    Intra4x4PredMode(luma4x4BlkIdx)=rem_intra4x4_pred_mode+1;
                                }
                            }
                        }
                        intra_chroma_pred_mode=get_unsigned_exp_golomb();
                    } else { // mb_pred() for inter macroblocks /////////////////////////
                        int mbPartIdx;
                        // ignoring ref_idx_* and *_l1 stuff for now -- I do not support
                        // long-term prediction or B-frames anyway ...
                        int SOF=(mb.mb_type==P_L0_L0_16x8)?8:4;
                        for(mbPartIdx=0; mbPartIdx<mb.NumMbPart; ++mbPartIdx){
                            if(mb.MbPartPredMode[mbPartIdx]!=Pred_L1) {
                                int mvdx=get_signed_exp_golomb();
                                int mvdy=get_signed_exp_golomb();
                                DeriveMVs(mpi,
                                mb_pos_x+Intra4x4ScanOrder[mbPartIdx*SOF][0],
                                mb_pos_y+Intra4x4ScanOrder[mbPartIdx*SOF][1],
                                mb.MbPartWidth, mb.MbPartHeight, mvdx, mvdy);
                            }
                        }
                    }
                }

                // coded_block_pattern ////////////////////////////////////////////////
                if(mb.MbPartPredMode[0]!=Intra_16x16) {
                    int coded_block_pattern=get_unsigned_exp_golomb();
                    if(mb.MbPartPredMode[0]==Intra_4x4)
                        coded_block_pattern=CodedBlockPatternMapping_Intra4x4[coded_block_pattern];
                    else
                        coded_block_pattern=CodedBlockPatternMapping_Inter[coded_block_pattern];
                    mb.CodedBlockPatternLuma=coded_block_pattern&15;
                    mb.CodedBlockPatternChroma=coded_block_pattern>>4;
                }

                // Before parsing the residual data, set all coefficients to zero. In
                // the original H.264 documentation, this is done either in
                // residual_block() at the very beginning or by setting values to zero
                // according to the CodedBlockPattern values. So, there's only little
                // overhead if we do it right here.
                memset(LumaDCLevel,0,sizeof(LumaDCLevel));
                memset(LumaACLevel,0,sizeof(LumaACLevel));
                memset(ChromaDCLevel,0,sizeof(ChromaDCLevel));
                memset(ChromaACLevel,0,sizeof(ChromaACLevel));

                // residual() /////////////////////////////////////////////////////////
                if(mb.CodedBlockPatternLuma>0 || mb.CodedBlockPatternChroma>0 ||
                mb.MbPartPredMode[0]==Intra_16x16)
                {
                    int i8x8,i4x4,iCbCr,QPi;

                    mb_qp_delta=get_signed_exp_golomb();
                    QPy=(QPy+mb_qp_delta+52)%52;
                    QPi=QPy+pps->chroma_qp_index_offset;
                    QPi=CustomClip(QPi,0,51);
                    if(QPi<30) QPc=QPi;
                            else QPc=QPcTable[QPi-30];
                    // OK, now let's parse the hell out of the stream ;)
                    if(mb.MbPartPredMode[0]==Intra_16x16)
                        residual_block(&LumaDCLevel[0],16,LumaDC_nC);
                    for(i8x8=0; i8x8<4; ++i8x8)
                        for(i4x4=0; i4x4<4; ++i4x4)
                        if(mb.CodedBlockPatternLuma&(1<<i8x8)) {
                            if(mb.MbPartPredMode[0]==Intra_16x16)
                            LumaAdjust residual_block(&LumaACLevel[i8x8*4+i4x4][1],15,LumaAC_nC);
                            else
                            LumaAdjust residual_block(&LumaACLevel[i8x8*4+i4x4][0],16,LumaAC_nC);
                        };
                    for(iCbCr=0; iCbCr<2; iCbCr++)
                        if(mb.CodedBlockPatternChroma&3)
                        residual_block(&ChromaDCLevel[iCbCr][0],4,ChromaDC_nC);
                    for(iCbCr=0; iCbCr<2; iCbCr++)
                        for(i4x4=0; i4x4<4; ++i4x4)
                        if(mb.CodedBlockPatternChroma&2)
                            ChromaAdjust residual_block(&ChromaACLevel[iCbCr][i4x4][1],15,ChromaAC_nC);
                }

                //////////////////////////// RENDERING ////////////////////////////////
                // Now that we have all the informations needed about this macroblock,
                // we can go ahead and really render it.

                if(mb.MbPartPredMode[0]==Intra_4x4) {  ///////////////// Intra_4x4_Pred
					int i;
					for(i=0; i<16; ++i) {

					int x=mb_pos_x+Intra4x4ScanOrder[i][0];
					int y=mb_pos_y+Intra4x4ScanOrder[i][1];
					perf_enter("intra prediction");
				    int mode=ModePredInfo_Intra4x4PredMode(mpi,x>>2,y>>2);
//						uint32_t id = send_luma_intra_packet(4, this, mpi, mode, x, y, 0, i);
//						buffers_loop(1);
//						rx_intra_packet(id, this, x, y, TYPE_LUMA);

					//Intra_4x4_Dispatch(this,mpi,x,y,i);

					send_intra_info( 7,                //int             addr,
					                 mpi,              //mode_pred_info *mpi,
					                 mode,             //int             mode,
					                 x,                //int             bx,
					                 y,                //int             by,
					                 0,                //int             constrained_intra_pred,
					                 0,                //int             LCbCr_select,
					                 i,                //int             luma4x4BlkIdx,
					                 4,                //int             size,
					                 this->Lwidth      //int             Lwidth
					                 );


					//simulate_buffer_node(/*this, ref*/);

					perf_enter("block entering");
					//enter_luma_block(&LumaACLevel[i][0],this,x,y,QPy,0);
					send_iqit(&LumaACLevel[i][0],x,y, QPy, 0, 0);
					//simulate_buffer_node(/*this, ref*/);



					}
					//Intra_Chroma_Dispatch(this,mpi,intra_chroma_pred_mode,mb_pos_x>>1,mb_pos_y>>1,pps->constrained_intra_pred_flag);
					send_intra_info( 7,                //int             addr,
									 mpi,              //mode_pred_info *mpi,
									 intra_chroma_pred_mode,             //int             mode,
									 mb_pos_x>>1,                //int             bx,
									 mb_pos_y>>1,                //int             by,
									 pps->constrained_intra_pred_flag,                //int             constrained_intra_pred,
									 1,                //int             LCbCr_select,
									 0,                //int             luma4x4BlkIdx,
									 0,                //int             size,
									 0                 //int             Lwidth
									 );

					//simulate_buffer_node(/*this, ref*/);




                }
                else if(mb.MbPartPredMode[0]==Intra_16x16) {  ////// Intra_16x16_Pred
                    int i,j;
                    perf_enter("intra prediction");
                    //Intra_16x16_Dispatch(this,mpi,mb.Intra16x16PredMode,mb_pos_x,mb_pos_y,pps->constrained_intra_pred_flag);

                    send_intra_info( 7,                //int             addr,
									 mpi,              //mode_pred_info *mpi,
									 mb.Intra16x16PredMode,             //int             mode,
									 mb_pos_x,         //int             bx,
									 mb_pos_y,         //int             by,
									 pps->constrained_intra_pred_flag,                //int             constrained_intra_pred,
									 0,                //int             LCbCr_select,
									 0,                //int             luma4x4BlkIdx,
									 16,               //int             size,
									 this->Lwidth      //int             Lwidth
									 );


					//simulate_buffer_node(/*this, ref*/);



                    perf_enter("block entering");
                    transform_luma_dc(&LumaDCLevel[0],&LumaACLevel[0][0],QPy);
                    for(i=0; i<16; ++i) {
                        int x=mb_pos_x+Intra4x4ScanOrder[i][0];
                        int y=mb_pos_y+Intra4x4ScanOrder[i][1];
                        //enter_luma_block(&LumaACLevel[i][0],this,x,y,QPy,1);
                        send_iqit(&LumaACLevel[i][0],x,y, QPy, 1, 0);
                        //simulate_buffer_node(/*this, ref*/);



                    }
                    perf_enter("block entering");




                    //Intra_Chroma_Dispatch(this,mpi,intra_chroma_pred_mode,mb_pos_x>>1,mb_pos_y>>1,pps->constrained_intra_pred_flag);
                    send_intra_info( 7,                //int             addr,
									 mpi,              //mode_pred_info *mpi,
									 intra_chroma_pred_mode,             //int             mode,
									 mb_pos_x>>1,                //int             bx,
									 mb_pos_y>>1,                //int             by,
									 pps->constrained_intra_pred_flag,                //int             constrained_intra_pred,
									 1,                //int             LCbCr_select,
									 0,                //int             luma4x4BlkIdx,
									 0,                //int             size,
									 0                 //int             Lwidth
									 );

                    //simulate_buffer_node(/*this, ref*/);





                    // act as if all transform blocks inside this macroblock were
                    // predicted using the Intra_4x4_DC prediction mode
                    // (without constrained_intra_pred, we'd have to do the same for
                    // inter MBs)
                    for(i=0; i<4; ++i) for(j=0; j<4; ++j)
                        ModePredInfo_Intra4x4PredMode(mpi,(mb_pos_x>>2)+j,(mb_pos_y>>2)+i)=2;
                } else { ///////////////////////////////////////////////// Inter_*_Pred
                    int i;

                    perf_enter("inter prediction");
                    //MotionCompensateMB(this,ref,mpi,mb_pos_x,mb_pos_y);
                    send_inter_info( 7,          //int addr,
                    		         mpi,        //mode_pred_info *mpi,
                    		         mb_pos_x,   //int org_x,
                    		         mb_pos_y    //int org_y
                    		        );
                    //simulate_buffer_node(/*this, ref*/);



                    perf_enter("block entering");
                    for(i=0; i<16; ++i) {
                        int x=mb_pos_x+Intra4x4ScanOrder[i][0];
                        int y=mb_pos_y+Intra4x4ScanOrder[i][1];
                        //enter_luma_block(&LumaACLevel[i][0],this,x,y,QPy,0);
                        send_iqit(&LumaACLevel[i][0],x,y, QPy, 0, 0);
                        simulate_buffer_node(/*this, ref*/);
                    }
                }
                if(mb.CodedBlockPatternChroma) { ////////////////////// Chroma Residual
                    int iCbCr,i;
                    perf_enter("block entering");
                    for(iCbCr=0; iCbCr<2; ++iCbCr) {
                        transform_chroma_dc(&ChromaDCLevel[iCbCr][0],QPc);
                        for(i=0; i<4; ++i)
                            ChromaACLevel[iCbCr][i][0]=ChromaDCLevel[iCbCr][i];
                        for(i=0; i<4; ++i){
//                            enter_chroma_block(&ChromaACLevel[iCbCr][i][0],this,iCbCr,
//                                (mb_pos_x>>1)+Intra4x4ScanOrder[i][0],
//                                (mb_pos_y>>1)+Intra4x4ScanOrder[i][1],
//                                 QPc,1);
                        	send_iqit(&ChromaACLevel[iCbCr][i][0],
                        			  (mb_pos_x>>1)+Intra4x4ScanOrder[i][0],
                        			  (mb_pos_y>>1)+Intra4x4ScanOrder[i][1],
                        			  QPc, 1, iCbCr + 1);
                        	//simulate_buffer_node(/*this, ref*/);
                        }



                    }
                }

                //run deblocking filter
//                for(int i=0; i < 16; i++)
//                {
//                    int bS = 4; //todo find the actual block strength...
//                    int LCrCb = 0;
//                    int id;
//                    if(mb_pos_x > 0){
//                        id = send_deblocking_packet(this, 1, 0, mb_pos_x, mb_pos_y+i, QPy, bS, LCrCb);
//                        buffers_loop(1);
//                        rx_deblocking_packet(id, this, 1,0, mb_pos_x, mb_pos_y+i, LCrCb);
//                    }
//                    if(mb_pos_y > 0){
//                        id = send_deblocking_packet(this, 0, 1, mb_pos_x+i, mb_pos_y, QPy, bS, LCrCb);
//                        buffers_loop(1);
//                        rx_deblocking_packet(id, this, 0,1, mb_pos_x+i, mb_pos_y, LCrCb);
//                    }
//                }
                for(int i=0; i < 16; i++)
                {
                    L_pixel(this,mb_pos_x+i, mb_pos_y ) = 0;
                }




            }
        } ///////////// end of macroblock_layer() /////////////////////////////////
        moreDataFlag=more_rbsp_data(nalu);
        ++CurrMbAddr;
    } /* while(moreDataFlag && CurrMbAddr<=MbCount) */
}
