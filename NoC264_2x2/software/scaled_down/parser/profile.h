#ifndef PROFILE_HEADER
#define PROFILE_HEADER



#include <inttypes.h>


//counters
uint64_t intra_counter;
uint64_t inter_counter;
uint64_t deblock_counter;
uint64_t flits_rx_counter;
uint64_t flits_tx_counter;
uint64_t iqit_counter;
uint64_t calvc_counter;
uint64_t other_counter;
uint64_t iqit_dc_counter;
uint64_t nal_counter;






#define ENABLE_PROFILING
//dummy macros for non-profiling mode
#ifndef ENABLE_PROFILING
#define INTRA_INC
#define INTER_INC
#define DEBLOCK_INC
#define FLIT_RX_INC
#define FLIT_TX_INC
#define IQIT_INC
#define CALVC_INC
#define OTHER_INC
#define IQIT_DC_INC
#define NAL_INC

#else
//increment the counters
#define INTRA_INC    intra_counter++;
#define INTER_INC    inter_counter++;
#define DEBLOCK_INC  deblock_counter++;
#define FLIT_RX_INC  flits_rx_counter++;
#define FLIT_TX_INC  flits_tx_counter++;
#define IQIT_INC     iqit_counter++;
#define CALVC_INC    calvc_counter++;
#define OTHER_INC    other_counter++;
#define IQIT_DC_INC  iqit_dc_counter++;
#define NAL_INC      nal_counter++;

#endif














#endif
