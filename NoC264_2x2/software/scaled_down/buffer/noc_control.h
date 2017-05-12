#ifndef NOC_CTRL_H
#define NOC_CTRL_H
#include <inttypes.h>
#include "hps_0.h"


#define CPU_1

//------------------------------------------------------------------------------
//-- NOC CONTROL REGISTERS -----------------------------------------------------
//------------------------------------------------------------------------------
#ifdef CPU_0
//compiled for cpu 0
#define NOC_CTRL_BASE NOC_CTRL_0_BASE
#define TX_0_BASE     CPU_0_TX_0_BASE
#define TX_1_BASE     CPU_0_TX_1_BASE
#define TX_2_BASE     CPU_0_TX_2_BASE
#define TX_3_BASE     CPU_0_TX_3_BASE
#define TX_4_BASE     CPU_0_TX_4_BASE
#define TX_5_BASE     CPU_0_TX_5_BASE
#define TX_6_BASE     CPU_0_TX_6_BASE
#define TX_7_BASE     CPU_0_TX_7_BASE
#define RX_0_BASE     CPU_0_RX_0_BASE
#define RX_1_BASE     CPU_0_RX_1_BASE
#define RX_2_BASE     CPU_0_RX_2_BASE
#define RX_3_BASE     CPU_0_RX_3_BASE
#define RX_4_BASE     CPU_0_RX_4_BASE
#define RX_5_BASE     CPU_0_RX_5_BASE
#define RX_6_BASE     CPU_0_RX_6_BASE
#define RX_7_BASE     CPU_0_RX_7_BASE
#define NOC_STS_BASE  NOC_STATUS_0_BASE
#endif

#ifdef CPU_1
//compiled for cpu 1
#define NOC_CTRL_BASE NOC_CTRL_1_BASE
#define TX_0_BASE     CPU_1_TX_0_BASE
#define TX_1_BASE     CPU_1_TX_1_BASE
#define TX_2_BASE     CPU_1_TX_2_BASE
#define TX_3_BASE     CPU_1_TX_3_BASE
#define TX_4_BASE     CPU_1_TX_4_BASE
#define TX_5_BASE     CPU_1_TX_5_BASE
#define TX_6_BASE     CPU_1_TX_6_BASE
#define TX_7_BASE     CPU_1_TX_7_BASE
#define RX_0_BASE     CPU_1_RX_0_BASE
#define RX_1_BASE     CPU_1_RX_1_BASE
#define RX_2_BASE     CPU_1_RX_2_BASE
#define RX_3_BASE     CPU_1_RX_3_BASE
#define RX_4_BASE     CPU_1_RX_4_BASE
#define RX_5_BASE     CPU_1_RX_5_BASE
#define RX_6_BASE     CPU_1_RX_6_BASE
#define RX_7_BASE     CPU_1_RX_7_BASE
#define NOC_STS_BASE  NOC_STATUS_1_BASE
#endif

//------------------------------------------------------------------------------
//-- UTILITY DEFINES -----------------------------------------------------------
//------------------------------------------------------------------------------
#define CPU_0_ADDR    0
#define CPU_1_ADDR    7
#define IQIT_0_ADDR   6
#define DB_0_ADDR     5
#define INTRA_0_ADDR  3
#define LINTER_0_ADDR 2
#define CINTER_0_ADDR 4
#define VGA_0_ADDR    8
#define LINTER_1_ADDR 9

#define TAIL_FLIT_BIT (1<<31)
#define CPU_TX_REQ    (1<<30)
#define CPU_RX_CTRL   (1<<29)
#define NOC_RESET     (1<<28)

#define IN_PLACE_CPU_0_ADDR     (CPU_0_ADDR    << 16)
#define IN_PLACE_CPU_1_ADDR     (CPU_1_ADDR    << 16)
#define IN_PLACE_IQIT_0_ADDR    (IQIT_0_ADDR   << 16)
#define IN_PLACE_DB_0_ADDR      (DB_0_ADDR     << 16)
#define IN_PLACE_INTRA_0_ADDR   (INTRA_0_ADDR  << 16)
#define IN_PLACE_LINTER_0_ADDR  (LINTER_0_ADDR << 16)
#define IN_PLACE_CINTER_0_ADDR  (CINTER_0_ADDR << 16)
#define IN_PLACE_VGA_0_ADDR     (VGA_0_ADDR    << 16)
#define IN_PLACE_LINTER_1_ADDR  (LINTER_1_ADDR << 16)

#define FORMAT_0  0 //8  bits from each of tx0..tx7
#define FORMAT_1  1 //16 bits from each of tx0..tx3
#define FORMAT_2  2 //32 bits from each of tx0..tx1
#define FORMAT_3  3 //tx0 (zero fill)
#define FORMAT_4  4 //tx0 (sign fill)
#define FORMAT_5  5 //intra set
#define FORMAT_6  6 //intra start pred
#define FORMAT_7  7 //6 8 bit entries and 1 16 bit entry
#define FORMAT_8  8 //IQIT HEADER
#define FORMAT_9  9 //IQIT ROW

#define PARSE_32_BIT_UNSIGNED (0<<8)
#define PARSE_16_BIT_UNSIGNED (1<<8)
#define PARSE_8_BIT_UNSIGNED  (2<<8)
#define PARSE_32_BIT_SIGNED   (3<<8)
#define PARSE_16_BIT_SIGNED   (4<<8)
#define PARSE_8_BIT_SIGNED    (5<<8)

#define BUFFER_IDLE        0
#define BUFFER_SEL_VC      1
#define BUFFER_ADDR_RST    2
#define BUFFER_START_READ  3
#define BUFFER_RXD         4
#define BUFFER_WAIT_CPU    5
#define BUFFER_DEQUEUE     6
#define BUFFER_WAIT_FLITS  7

#define TX_ACK_BIT         (1<<31)

//------------------------------------------------------------------------------
//-- ID RANGES -----------------------------------------------------------------
//------------------------------------------------------------------------------
#define LUMA_MOCOMP_MAX LUMA_MOCOMP_MIN + 32
#define LUMA_MOCOMP_MIN 33

#define LUMA_1_MOCOMP_MAX LUMA_1_MOCOMP_MIN + 32
#define LUMA_1_MOCOMP_MIN 191


//------------------------------------------------------------------------------
//--MACROS for reading and writing PIOs
//------------------------------------------------------------------------------
#define RD_PIO(addr)        (*(volatile uint32_t *)(base_addr + addr))
#define WR_PIO(addr, value) (*(volatile uint32_t *)(base_addr + addr)=value)

//------------------------------------------------------------------------------
//-- FUNCTIONS AND DATA TYPES --------------------------------------------------
//------------------------------------------------------------------------------
//buffer storage consants
#define MAX_FLITS   33
#define MAX_PACKETS 256

typedef struct packet_struct {
    union{
    	uint64_t flit[MAX_FLITS];
    	uint32_t u_word[MAX_FLITS*2];
    	uint16_t u_halfword[MAX_FLITS*4];
    	uint8_t  u_byte[MAX_FLITS*8];
    	int32_t  s_word[MAX_FLITS*2];
    	int16_t  s_halfword[MAX_FLITS*4];
    	int8_t   s_byte[MAX_FLITS*8];
    } data;
    uint32_t num_flits;
    uint32_t src_addr;
    uint32_t identifier;
} packet;

typedef struct buffer_struct {
    packet    the_packets[MAX_PACKETS];
} buffer;

void noc_init();

void send_flit(uint32_t dest, uint32_t word0, uint32_t word1, uint32_t set_tail);

uint32_t get_buffer_rx_state();

uint32_t copy_to_buffer(uint32_t id);

void set_cpu_read_flag(int value);

uint32_t get_identifier();

uint32_t buffers_loop(uint32_t packet_count);

packet peak_rx_buffer();

void pop_rx_buffer();

uint32_t get_num_packets();

int flit_buffers_loop(uint32_t flit_count);

void peak_rx_buffer2(packet *return_packet);

void print_rx_buffer();

packet get_packet_by_id(uint32_t id);

uint32_t ready_2_send();

void no_data_send(uint32_t format_code);

packet* get_packet_pointer_by_id(uint32_t id);
void remove_packet_with_id(int id);
packet* rx_packet_by_id_no_block(uint32_t id, uint32_t trys);

void *base_addr;

#endif

