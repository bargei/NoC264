#ifndef parser_2_buffer_header
#define parser_2_buffer_header
#include "mode_pred.h"
#include "noc_control.h"
#include "mbmodes.h"
#include "block.h"


#define DO_INTRA           1
#define DO_INTER           2
#define DO_IQIT            3
#define DO_DIRECT_WRITE    4
#define DO_START_NEW_FRAME 5
#define DO_ALLOC_FRAME     6

#define LUMA_SELECT        0
#define CB_SELECT          1
#define CR_SELECT          2

void send_intra_info(int             addr,
        mode_pred_info *mpi,
        int             mode,
        int             bx,
        int             by,
        int             constrained_intra_pred,
        int             LCbCr_select,
        int             luma4x4BlkIdx,
        int             size,
        int             Lwidth);


void send_inter_info(int addr, mode_pred_info *mpi, int org_x, int org_y);

void send_direct_write(int addr,int x, int y, int width, int height, int LCbCr_select, uint8_t *bytes, int add_flag);

void send_start_new_frame(int addr, int Qp);

void send_4x4_direct_write(int addr, int x_addr, int y_addr, uint8_t *row0, uint8_t *row1, uint8_t *row2, uint8_t *row3, int LCbCr_Select);

#endif
