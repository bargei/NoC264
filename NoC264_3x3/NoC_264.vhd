library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; 
use ieee.std_logic_misc.all;



ENTITY NoC_264 IS 
port (
    SLIDE_SW : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    BUTTON, M1_DDR2_oct_rdn, M1_DDR2_oct_rup : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    OSC_50_BANK3 : IN STD_LOGIC;
    LED : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    M1_DDR2_addr : OUT STD_LOGIC_VECTOR (13 DOWNTO 0);
    M1_DDR2_ba : OUT STD_LOGIC_VECTOR (2 DOWNTO 0);
    M1_DDR2_cas_n, M1_DDR2_ras_n, M1_DDR2_we_n : OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
    M1_DDR2_clk, M1_DDR2_clk_n : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    M1_DDR2_cke, M1_DDR2_cs_n, M1_DDR2_odt : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    M1_DDR2_dm : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    M1_DDR2_dq : INOUT STD_LOGIC_VECTOR (63 DOWNTO 0);
    M1_DDR2_dqs, M1_DDR2_dqsn : INOUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    M2_DDR2_addr :                               OUT STD_LOGIC_VECTOR (13 DOWNTO 0);
    M2_DDR2_ba :                                 OUT STD_LOGIC_VECTOR (2 DOWNTO 0);
    M2_DDR2_cas_n, M2_DDR2_ras_n, M2_DDR2_we_n : OUT STD_LOGIC_VECTOR (0 DOWNTO 0);
    M2_DDR2_clk,   M2_DDR2_clk_n :               OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    M2_DDR2_cke,   M2_DDR2_cs_n,  M2_DDR2_odt :  OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    M2_DDR2_dm :                                 OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    M2_DDR2_dq :                                 INOUT STD_LOGIC_VECTOR (63 DOWNTO 0);
    M2_DDR2_dqs,   M2_DDR2_dqsn :                INOUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    M2_DDR2_oct_rdn, M2_DDR2_oct_rup :           IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    sd_card_b_SD_cmd   : inout std_logic                     := '0';             --  sd_card.b_SD_cmd
    sd_card_b_SD_dat   : inout std_logic                     := '0';             --         .b_SD_dat
    sd_card_b_SD_dat3  : inout std_logic                     := '0';             --         .b_SD_dat3
    sd_card_o_SD_clock : out   std_logic;
    gpio                                  : out std_logic_vector(35 downto 0)
);
END NoC_264;

ARCHITECTURE MAIN OF NoC_264 IS

    -- constants
    constant data_width        : integer := 64;
    constant addr_width        : integer := 4;
    constant vc_sel_width      : integer := 1;
    constant num_vc            : integer := 2;
    constant flit_buff_depth   : integer := 8;
    
    COMPONENT nios_system
    port (
        clk_clk                               : in    std_logic                     := '0';             --                            clk.clk
        cpu_0_noc_ctrl_export                 : out   std_logic_vector(31 downto 0);                    --                 cpu_0_noc_ctrl.export
        cpu_0_noc_sts_export                  : in    std_logic_vector(31 downto 0) := (others => '0'); --                  cpu_0_noc_sts.export
        cpu_0_rx_0_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_0_rx_0_external_connection.export
        cpu_0_rx_1_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_0_rx_1_external_connection.export
        cpu_0_rx_2_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_0_rx_2_external_connection.export
        cpu_0_rx_3_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_0_rx_3_external_connection.export
        cpu_0_rx_4_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_0_rx_4_external_connection.export
        cpu_0_rx_5_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_0_rx_5_external_connection.export
        cpu_0_rx_6_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_0_rx_6_external_connection.export
        cpu_0_rx_7_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_0_rx_7_external_connection.export
        cpu_0_tx_0_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_0_tx_0_external_connection.export
        cpu_0_tx_1_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_0_tx_1_external_connection.export
        cpu_0_tx_2_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_0_tx_2_external_connection.export
        cpu_0_tx_3_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_0_tx_3_external_connection.export
        cpu_0_tx_4_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_0_tx_4_external_connection.export
        cpu_0_tx_5_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_0_tx_5_external_connection.export
        cpu_0_tx_6_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_0_tx_6_external_connection.export
        cpu_0_tx_7_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_0_tx_7_external_connection.export
        cpu_1_noc_ctrl_export                 : out   std_logic_vector(31 downto 0);                    --                 cpu_1_noc_ctrl.export
        cpu_1_noc_sts_export                  : in    std_logic_vector(31 downto 0) := (others => '0'); --                  cpu_1_noc_sts.export
        cpu_1_rx_0_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_1_rx_0_external_connection.export
        cpu_1_rx_1_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_1_rx_1_external_connection.export
        cpu_1_rx_2_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_1_rx_2_external_connection.export
        cpu_1_rx_3_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_1_rx_3_external_connection.export
        cpu_1_rx_4_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_1_rx_4_external_connection.export
        cpu_1_rx_5_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_1_rx_5_external_connection.export
        cpu_1_rx_6_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_1_rx_6_external_connection.export
        cpu_1_rx_7_external_connection_export : in    std_logic_vector(31 downto 0) := (others => '0'); -- cpu_1_rx_7_external_connection.export
        cpu_1_tx_0_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_1_tx_0_external_connection.export
        cpu_1_tx_1_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_1_tx_1_external_connection.export
        cpu_1_tx_2_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_1_tx_2_external_connection.export
        cpu_1_tx_3_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_1_tx_3_external_connection.export
        cpu_1_tx_4_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_1_tx_4_external_connection.export
        cpu_1_tx_5_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_1_tx_5_external_connection.export
        cpu_1_tx_6_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_1_tx_6_external_connection.export
        cpu_1_tx_7_external_connection_export : out   std_logic_vector(31 downto 0);                    -- cpu_1_tx_7_external_connection.export
        leds_export                           : out   std_logic_vector(7 downto 0);                     --                           leds.export
        memory_mem_a                          : out   std_logic_vector(13 downto 0);                    --                         memory.mem_a
        memory_mem_ba                         : out   std_logic_vector(2 downto 0);                     --                               .mem_ba
        memory_mem_ck                         : out   std_logic_vector(1 downto 0);                     --                               .mem_ck
        memory_mem_ck_n                       : out   std_logic_vector(1 downto 0);                     --                               .mem_ck_n
        memory_mem_cke                        : out   std_logic_vector(0 downto 0);                     --                               .mem_cke
        memory_mem_cs_n                       : out   std_logic_vector(0 downto 0);                     --                               .mem_cs_n
        memory_mem_dm                         : out   std_logic_vector(7 downto 0);                     --                               .mem_dm
        memory_mem_ras_n                      : out   std_logic_vector(0 downto 0);                     --                               .mem_ras_n
        memory_mem_cas_n                      : out   std_logic_vector(0 downto 0);                     --                               .mem_cas_n
        memory_mem_we_n                       : out   std_logic_vector(0 downto 0);                     --                               .mem_we_n
        memory_mem_dq                         : inout std_logic_vector(63 downto 0) := (others => '0'); --                               .mem_dq
        memory_mem_dqs                        : inout std_logic_vector(7 downto 0)  := (others => '0'); --                               .mem_dqs
        memory_mem_dqs_n                      : inout std_logic_vector(7 downto 0)  := (others => '0'); --                               .mem_dqs_n
        memory_mem_odt                        : out   std_logic_vector(0 downto 0);                     --                               .mem_odt
        memory_0_mem_a                        : out   std_logic_vector(13 downto 0);                    --                       memory_0.mem_a
        memory_0_mem_ba                       : out   std_logic_vector(2 downto 0);                     --                               .mem_ba
        memory_0_mem_ck                       : out   std_logic_vector(1 downto 0);                     --                               .mem_ck
        memory_0_mem_ck_n                     : out   std_logic_vector(1 downto 0);                     --                               .mem_ck_n
        memory_0_mem_cke                      : out   std_logic_vector(0 downto 0);                     --                               .mem_cke
        memory_0_mem_cs_n                     : out   std_logic_vector(0 downto 0);                     --                               .mem_cs_n
        memory_0_mem_dm                       : out   std_logic_vector(7 downto 0);                     --                               .mem_dm
        memory_0_mem_ras_n                    : out   std_logic_vector(0 downto 0);                     --                               .mem_ras_n
        memory_0_mem_cas_n                    : out   std_logic_vector(0 downto 0);                     --                               .mem_cas_n
        memory_0_mem_we_n                     : out   std_logic_vector(0 downto 0);                     --                               .mem_we_n
        memory_0_mem_dq                       : inout std_logic_vector(63 downto 0) := (others => '0'); --                               .mem_dq
        memory_0_mem_dqs                      : inout std_logic_vector(7 downto 0)  := (others => '0'); --                               .mem_dqs
        memory_0_mem_dqs_n                    : inout std_logic_vector(7 downto 0)  := (others => '0'); --                               .mem_dqs_n
        memory_0_mem_odt                      : out   std_logic_vector(0 downto 0);                     --                               .mem_odt
        oct_rdn                               : in    std_logic                     := '0';             --                            oct.rdn
        oct_rup                               : in    std_logic                     := '0';             --                               .rup
        oct_0_rdn                             : in    std_logic                     := '0';             --                          oct_0.rdn
        oct_0_rup                             : in    std_logic                     := '0';             --                               .rup
        pll_clock_clk                         : out   std_logic;                                        --                      pll_clock.clk
        sd_card_b_SD_cmd                      : inout std_logic                     := '0';             --                        sd_card.b_SD_cmd
        sd_card_b_SD_dat                      : inout std_logic                     := '0';             --                               .b_SD_dat
        sd_card_b_SD_dat3                     : inout std_logic                     := '0';             --                               .b_SD_dat3
        sd_card_o_SD_clock                    : out   std_logic;                                        --                               .o_SD_clock
        switches_export                       : in    std_logic_vector(7 downto 0)  := (others => '0'); --                       switches.export
        vga_clock_clk                         : out   std_logic                                         --                      vga_clock.clk
    );
    end component;
     
      
        
    component intra_prediction_node is
    generic (
        data_width      : integer := 128;
        addr_width      : integer := 1;
        vc_sel_width    : integer := 1;
        num_vc          : integer := 2;
        flit_buff_depth : integer := 8
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
    
        -- recv interface to network
        recv_data      : in  std_logic_vector(data_width-1 downto 0);
        src_addr       : in  std_logic_vector(addr_width-1 downto 0);
        is_tail_flit   : in  std_logic;
        data_in_buffer : in  std_logic_vector(num_vc-1 downto 0);
        dequeue        : out std_logic_vector(num_vc-1 downto 0);
        select_vc_read : out std_logic_vector(vc_sel_width-1 downto 0);
    
        -- send interface to network
        send_data      : out std_logic_vector(data_width-1 downto 0);
        dest_addr      : out std_logic_vector(addr_width-1 downto 0);
        set_tail_flit  : out std_logic;
        send_flit      : out std_logic;
        ready_to_send  : in  std_logic;
    
        --debugging
        s_intra_idle               : out std_logic;
        s_intra_data_rxd           : out std_logic;
        s_intra_write_sample       : out std_logic;
        s_intra_start_pred         : out std_logic;
        s_intra_start_tx_loop      : out std_logic;
        s_intra_start_tx_loop_hold : out std_logic;
        s_intra_tx                 : out std_logic;
        s_intra_tx_hold            : out std_logic;
        s_intra_tx_gen_next        : out std_logic;
        s_intra_dequeue_rx         : out std_logic   
  
    );
    end component intra_prediction_node;
   
    component noc_interface is
    generic(
        data_width      : integer := 64;
        addr_width      : integer := 1;
        vc_sel_width    : integer := 1;
        num_vc          : integer := 2;
        flit_buff_depth : integer := 8;
        use_vc          : integer := 0
    );
    port(
        --clk, reset
        clk           : in  std_logic;
        rst           : in  std_logic;
    
        --user sending interface
        send_data      : in  std_logic_vector(data_width-1 downto 0);
        dest_addr      : in  std_logic_vector(addr_width-1 downto 0);
        set_tail_flit  : in  std_logic;
        send_flit      : in  std_logic;
        ready_to_send  : out std_logic;
        
        --user receiving interface
        recv_data      : out std_logic_vector(data_width-1 downto 0);
        src_addr       : out std_logic_vector(addr_width-1 downto 0);
        is_tail_flit   : out std_logic;
        data_in_buffer : out std_logic_vector(num_vc-1 downto 0);
        dequeue        : in  std_logic_vector(num_vc-1 downto 0);
        select_vc_read : in  std_logic_vector(vc_sel_width-1 downto 0);
        
        --interface to network
        send_putFlit_flit_in          : out std_logic_vector(data_width+addr_width+vc_sel_width+1 downto 0);
        EN_send_putFlit               : out std_logic;
        EN_send_getNonFullVCs         : out std_logic;
        send_getNonFullVCs            : in  std_logic_vector(num_vc-1 downto 0);
        EN_recv_getFlit               : out std_logic;
        recv_getFlit                  : in  std_logic_vector(data_width+addr_width+vc_sel_width+1 downto 0);
        recv_putNonFullVCs_nonFullVCs : out std_logic_vector(num_vc-1 downto 0);
        EN_recv_putNonFullVCs         : out std_logic;
        recv_info_getRecvPortID       : in  std_logic_vector(addr_width-1 downto 0)
    );
    end component noc_interface;
     
    component mkNetworkSimple is
    port(
        CLK                                   : in  std_logic;
        RST_N                                 : in  std_logic;
        send_ports_0_putFlit_flit_in          : in  std_logic_vector(70 downto 0);
        EN_send_ports_0_putFlit               : in  std_logic;
        EN_send_ports_0_getNonFullVCs         : in  std_logic;
        send_ports_0_getNonFullVCs            : out std_logic_vector(1 downto 0);
        send_ports_1_putFlit_flit_in          : in  std_logic_vector(70 downto 0);
        EN_send_ports_1_putFlit               : in  std_logic;
        EN_send_ports_1_getNonFullVCs         : in  std_logic;
        send_ports_1_getNonFullVCs            : out std_logic_vector(1 downto 0);
        send_ports_2_putFlit_flit_in          : in  std_logic_vector(70 downto 0);
        EN_send_ports_2_putFlit               : in  std_logic;
        EN_send_ports_2_getNonFullVCs         : in  std_logic;
        send_ports_2_getNonFullVCs            : out std_logic_vector(1 downto 0);
        send_ports_3_putFlit_flit_in          : in  std_logic_vector(70 downto 0);
        EN_send_ports_3_putFlit               : in  std_logic;
        EN_send_ports_3_getNonFullVCs         : in  std_logic;
        send_ports_3_getNonFullVCs            : out std_logic_vector(1 downto 0);
        send_ports_4_putFlit_flit_in          : in  std_logic_vector(70 downto 0);
        EN_send_ports_4_putFlit               : in  std_logic;
        EN_send_ports_4_getNonFullVCs         : in  std_logic;
        send_ports_4_getNonFullVCs            : out std_logic_vector(1 downto 0);
        send_ports_5_putFlit_flit_in          : in  std_logic_vector(70 downto 0);
        EN_send_ports_5_putFlit               : in  std_logic;
        EN_send_ports_5_getNonFullVCs         : in  std_logic;
        send_ports_5_getNonFullVCs            : out std_logic_vector(1 downto 0);
        send_ports_6_putFlit_flit_in          : in  std_logic_vector(70 downto 0);
        EN_send_ports_6_putFlit               : in  std_logic;
        EN_send_ports_6_getNonFullVCs         : in  std_logic;
        send_ports_6_getNonFullVCs            : out std_logic_vector(1 downto 0);
        send_ports_7_putFlit_flit_in          : in  std_logic_vector(70 downto 0);
        EN_send_ports_7_putFlit               : in  std_logic;
        EN_send_ports_7_getNonFullVCs         : in  std_logic;
        send_ports_7_getNonFullVCs            : out std_logic_vector(1 downto 0);
        send_ports_8_putFlit_flit_in          : in  std_logic_vector(70 downto 0);
        EN_send_ports_8_putFlit               : in  std_logic;
        EN_send_ports_8_getNonFullVCs         : in  std_logic;
        send_ports_8_getNonFullVCs            : out std_logic_vector(1 downto 0);
        
        EN_recv_ports_0_getFlit               : in  std_logic;
        recv_ports_0_getFlit                  : out std_logic_vector(70 downto 0);
        recv_ports_0_putNonFullVCs_nonFullVCs : in  std_logic_vector(1 downto 0);
        EN_recv_ports_0_putNonFullVCs         : in  std_logic;
        EN_recv_ports_1_getFlit               : in  std_logic;
        recv_ports_1_getFlit                  : out std_logic_vector(70 downto 0);
        recv_ports_1_putNonFullVCs_nonFullVCs : in  std_logic_vector(1 downto 0);
        EN_recv_ports_1_putNonFullVCs         : in  std_logic;
        EN_recv_ports_2_getFlit               : in  std_logic;
        recv_ports_2_getFlit                  : out std_logic_vector(70 downto 0);
        recv_ports_2_putNonFullVCs_nonFullVCs : in  std_logic_vector(1 downto 0);
        EN_recv_ports_2_putNonFullVCs         : in  std_logic;
        EN_recv_ports_3_getFlit               : in  std_logic;
        recv_ports_3_getFlit                  : out std_logic_vector(70 downto 0);
        recv_ports_3_putNonFullVCs_nonFullVCs : in  std_logic_vector(1 downto 0);
        EN_recv_ports_3_putNonFullVCs         : in  std_logic;
        EN_recv_ports_4_getFlit               : in  std_logic;
        recv_ports_4_getFlit                  : out std_logic_vector(70 downto 0);
        recv_ports_4_putNonFullVCs_nonFullVCs : in  std_logic_vector(1 downto 0);
        EN_recv_ports_4_putNonFullVCs         : in  std_logic;
        EN_recv_ports_5_getFlit               : in  std_logic;
        recv_ports_5_getFlit                  : out std_logic_vector(70 downto 0);
        recv_ports_5_putNonFullVCs_nonFullVCs : in  std_logic_vector(1 downto 0);
        EN_recv_ports_5_putNonFullVCs         : in  std_logic;
        EN_recv_ports_6_getFlit               : in  std_logic;
        recv_ports_6_getFlit                  : out std_logic_vector(70 downto 0);
        recv_ports_6_putNonFullVCs_nonFullVCs : in  std_logic_vector(1 downto 0);
        EN_recv_ports_6_putNonFullVCs         : in  std_logic;
        EN_recv_ports_7_getFlit               : in  std_logic;
        recv_ports_7_getFlit                  : out std_logic_vector(70 downto 0);
        recv_ports_7_putNonFullVCs_nonFullVCs : in  std_logic_vector(1 downto 0);
        EN_recv_ports_7_putNonFullVCs         : in  std_logic;
        EN_recv_ports_8_getFlit               : in  std_logic;
        recv_ports_8_getFlit                  : out std_logic_vector(70 downto 0);
        recv_ports_8_putNonFullVCs_nonFullVCs : in  std_logic_vector(1 downto 0);
        EN_recv_ports_8_putNonFullVCs         : in  std_logic;
        
        recv_ports_info_0_getRecvPortID       : out std_logic_vector(3 downto 0);
        recv_ports_info_1_getRecvPortID       : out std_logic_vector(3 downto 0);
        recv_ports_info_2_getRecvPortID       : out std_logic_vector(3 downto 0);
        recv_ports_info_3_getRecvPortID       : out std_logic_vector(3 downto 0);
        recv_ports_info_4_getRecvPortID       : out std_logic_vector(3 downto 0);
        recv_ports_info_5_getRecvPortID       : out std_logic_vector(3 downto 0);
        recv_ports_info_6_getRecvPortID       : out std_logic_vector(3 downto 0);
        recv_ports_info_7_getRecvPortID       : out std_logic_vector(3 downto 0);
        recv_ports_info_8_getRecvPortID       : out std_logic_vector(3 downto 0)
    );
    end component mkNetworkSimple;
    
    component deblocking_filter_node is
    generic (
        data_width      : integer := 64;
        addr_width      : integer := 1;
        vc_sel_width    : integer := 1;
        num_vc          : integer := 2;
        flit_buff_depth : integer := 8
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
    
        -- recv interface to network
        recv_data      : in  std_logic_vector(data_width-1 downto 0);
        src_addr       : in  std_logic_vector(addr_width-1 downto 0);
        is_tail_flit   : in  std_logic;
        data_in_buffer : in  std_logic_vector(num_vc-1 downto 0);
        dequeue        : out std_logic_vector(num_vc-1 downto 0);
        select_vc_read : out std_logic_vector(vc_sel_width-1 downto 0);
        
        -- send interface to network
        send_data      : out std_logic_vector(data_width-1 downto 0);
        dest_addr      : out std_logic_vector(addr_width-1 downto 0);
        set_tail_flit  : out std_logic;
        send_flit      : out std_logic;
        ready_to_send  : in  std_logic;
        has_rxd        : out std_logic;
        is_idle        : out std_logic;
        is_filtering   : out std_logic;
        is_tx_ing      : out std_logic;
        is_cleanup_ing : out std_logic;
        rx_non_zero    : out std_logic;
        tx_non_zero    : out std_logic
    );
    end component deblocking_filter_node;
     
    component noc_control_plus is
    generic(
        data_width      : integer := 128;
        addr_width      : integer := 2;
        vc_sel_width    : integer := 1;
        num_vc          : integer := 2;
        flit_buff_depth : integer := 8
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;

        -- recv interface to network
        recv_data      : in  std_logic_vector(data_width-1 downto 0);
        src_addr       : in  std_logic_vector(addr_width-1 downto 0);
        is_tail_flit   : in  std_logic;
        data_in_buffer : in  std_logic_vector(num_vc-1 downto 0);
        dequeue        : out std_logic_vector(num_vc-1 downto 0);
        select_vc_read : out std_logic_vector(vc_sel_width-1 downto 0);
        
        -- send interface to network
        send_data      : out std_logic_vector(data_width-1 downto 0);
        dest_addr      : out std_logic_vector(addr_width-1 downto 0);
        set_tail_flit  : out std_logic;
        send_flit      : out std_logic;
        ready_to_send  : in  std_logic;
        
        --send interface to CPU
        set_tail_cpu   : in  std_logic;
        addr_cpu       : in  std_logic_vector(addr_width-1 downto 0);
        tx_0           : in  std_logic_vector(31 downto 0);
        tx_1           : in  std_logic_vector(31 downto 0);
        tx_2           : in  std_logic_vector(31 downto 0);
        tx_3           : in  std_logic_vector(31 downto 0);
        tx_4           : in  std_logic_vector(31 downto 0);
        tx_5           : in  std_logic_vector(31 downto 0);
        tx_6           : in  std_logic_vector(31 downto 0);
        tx_7           : in  std_logic_vector(31 downto 0);
        format_select  : in  std_logic_vector(7  downto 0);
        send_cmd_cpu   : in  std_logic;
        send_ack       : out std_logic;

        --receive interface to cpu
        rx_0           : out std_logic_vector(31 downto 0);
        rx_1           : out std_logic_vector(31 downto 0);
        rx_2           : out std_logic_vector(31 downto 0);
        rx_3           : out std_logic_vector(31 downto 0);
        rx_4           : out std_logic_vector(31 downto 0);
        rx_5           : out std_logic_vector(31 downto 0);
        rx_6           : out std_logic_vector(31 downto 0);
        rx_7           : out std_logic_vector(31 downto 0);
        parse_select   : in  std_logic_vector(7  downto 0);
        cpu_rx_ctrl    : in  std_logic;
        rx_state_out   : out std_logic_vector(7 downto 0) 
    );
    end component noc_control_plus;
     
     
    component inter_node is
    generic(
        size_x          : integer := 12; --20  ;  --12; --20 --20
        size_y          : integer := 12; --20  ;  --12; --20 --20
        interp_x        : integer := 8;  --4   ;  --8;  --2  --4
        interp_y        : integer := 2;  --4   ;  --1;  --2  --4
        sample_size     : integer := 8;  --8   ;  --8;
        samples_per_wr  : integer := 16; --16  ;  --8;  --4  --16
        data_width      : integer := 128;--128 ;  --64; --32 --128
        addr_width      : integer := 1;  --1   ;  --1;  
        vc_sel_width    : integer := 1;  --1   ;  --1;  
        num_vc          : integer := 2;  --2   ;  --2;  
        flit_buff_depth : integer := 8   --8      --8  
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
    
        -- recv interface to network
        recv_data      : in  std_logic_vector(data_width-1 downto 0);
        src_addr       : in  std_logic_vector(addr_width-1 downto 0);
        is_tail_flit   : in  std_logic;
        data_in_buffer : in  std_logic_vector(num_vc-1 downto 0);
        dequeue        : out std_logic_vector(num_vc-1 downto 0);
        select_vc_read : out std_logic_vector(vc_sel_width-1 downto 0);
    
        -- send interface to network
        send_data      : out std_logic_vector(data_width-1 downto 0);
        dest_addr      : out std_logic_vector(addr_width-1 downto 0);
        set_tail_flit  : out std_logic;
        send_flit      : out std_logic;
        ready_to_send  : in  std_logic
    );
    end component inter_node;
     
    component chroma_motion is
    generic(
        data_width      : integer := 64;
        addr_width      : integer := 4; 
        vc_sel_width    : integer := 1; 
        num_vc          : integer := 2; 
        flit_buff_depth : integer := 8  
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
    
        -- recv interface to network
        recv_data      : in  std_logic_vector(data_width-1 downto 0);
        src_addr       : in  std_logic_vector(addr_width-1 downto 0);
        is_tail_flit   : in  std_logic;
        data_in_buffer : in  std_logic_vector(num_vc-1 downto 0);
        dequeue        : out std_logic_vector(num_vc-1 downto 0);
        select_vc_read : out std_logic_vector(vc_sel_width-1 downto 0);
    
        -- send interface to network
        send_data      : out std_logic_vector(data_width-1 downto 0);
        dest_addr      : out std_logic_vector(addr_width-1 downto 0);
        set_tail_flit  : out std_logic;
        send_flit      : out std_logic;
        ready_to_send  : in  std_logic
        
    );
    end component chroma_motion;
     
     
     
    component iqit_node is
    generic(
        sample_width    : integer := 8;
        qp_width        : integer := 8;
        wo_dc_width     : integer := 8;
        data_width      : integer := 64;
        addr_width      : integer := 1;
        vc_sel_width    : integer := 1;
        num_vc          : integer := 2;
        flit_buff_depth : integer := 8
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
    
        -- recv interface to network
        recv_data      : in  std_logic_vector(data_width-1 downto 0);
        src_addr       : in  std_logic_vector(addr_width-1 downto 0);
        is_tail_flit   : in  std_logic;
        data_in_buffer : in  std_logic_vector(num_vc-1 downto 0);
        dequeue        : out std_logic_vector(num_vc-1 downto 0);
        select_vc_read : out std_logic_vector(vc_sel_width-1 downto 0);
        
        -- send interface to network
        send_data      : out std_logic_vector(data_width-1 downto 0);
        dest_addr      : out std_logic_vector(addr_width-1 downto 0);
        set_tail_flit  : out std_logic;
        send_flit      : out std_logic;
        ready_to_send  : in  std_logic
    );
    end component iqit_node;
     
     
    component vga_node is
    generic(
        data_width      : integer := 64;
        addr_width      : integer := 4; 
        vc_sel_width    : integer := 1; 
        num_vc          : integer := 2; 
        flit_buff_depth : integer := 8  
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
    
        -- recv interface to network
        recv_data      : in  std_logic_vector(data_width-1 downto 0);
        src_addr       : in  std_logic_vector(addr_width-1 downto 0);
        is_tail_flit   : in  std_logic;
        data_in_buffer : in  std_logic_vector(num_vc-1 downto 0);
        dequeue        : out std_logic_vector(num_vc-1 downto 0);
        select_vc_read : out std_logic_vector(vc_sel_width-1 downto 0);
    
        -- send interface to network
        send_data      : out std_logic_vector(data_width-1 downto 0);
        dest_addr      : out std_logic_vector(addr_width-1 downto 0);
        set_tail_flit  : out std_logic;
        send_flit      : out std_logic;
        ready_to_send  : in  std_logic;
        
        -- vga connections
        clk27          : in  std_logic;
        rst27          : in  std_logic;
        vga_red        : out std_logic_vector(5 downto 0);
        vga_blue       : out std_logic_vector(5 downto 0);
        vga_green      : out std_logic_vector(5 downto 0);
        vga_v_sync     : out std_logic;
        vga_h_sync     : out std_logic
        
        
    );
    end component vga_node;
     
     
    signal cpu_0_noc_ctrl_export : std_logic_vector(31 downto 0);
    signal cpu_0_noc_sts_export  : std_logic_vector(31 downto 0);
    signal cpu_0_rx_high_export  : std_logic_vector(31 downto 0);
    signal cpu_0_rx_low_export   : std_logic_vector(31 downto 0);
    signal cpu_0_tx_high_export  : std_logic_vector(31 downto 0);
    signal cpu_0_tx_low_export   : std_logic_vector(31 downto 0);
    signal cpu_1_noc_ctrl_export : std_logic_vector(31 downto 0);
    signal cpu_1_noc_sts_export  : std_logic_vector(31 downto 0);
    signal cpu_1_rx_high_export  : std_logic_vector(31 downto 0);
    signal cpu_1_rx_low_export   : std_logic_vector(31 downto 0);
    signal cpu_1_tx_high_export  : std_logic_vector(31 downto 0);
    signal cpu_1_tx_low_export   : std_logic_vector(31 downto 0);   

    signal vga_clock_clk         : std_logic; 
    
    signal cpu_0_rx_0_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_rx_1_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_rx_2_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_rx_3_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_rx_4_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_rx_5_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_rx_6_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_rx_7_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_tx_0_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_tx_1_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_tx_2_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_tx_3_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_tx_4_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_tx_5_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_tx_6_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_0_tx_7_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_rx_0_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_rx_1_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_rx_2_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_rx_3_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_rx_4_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_rx_5_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_rx_6_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_rx_7_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_tx_0_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_tx_1_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_tx_2_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_tx_3_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_tx_4_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_tx_5_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_tx_6_external_connection_export  : std_logic_vector(31 downto 0);
    signal cpu_1_tx_7_external_connection_export  : std_logic_vector(31 downto 0);

    signal clock_50                               : std_logic;
    signal vga_clock                              : std_logic;

    signal hps_h2f_rst                            : std_logic;

    signal send_ports_0_putFlit_flit_in           : std_logic_vector(70 downto 0);
    signal EN_send_ports_0_putFlit                : std_logic;
    signal EN_send_ports_0_getNonFullVCs          : std_logic;
    signal send_ports_0_getNonFullVCs             : std_logic_vector(1 downto 0);
    signal send_ports_1_putFlit_flit_in           : std_logic_vector(70 downto 0);
    signal EN_send_ports_1_putFlit                : std_logic;
    signal EN_send_ports_1_getNonFullVCs          : std_logic;
    signal send_ports_1_getNonFullVCs             : std_logic_vector(1 downto 0);
    signal send_ports_2_putFlit_flit_in           : std_logic_vector(70 downto 0);
    signal EN_send_ports_2_putFlit                : std_logic;
    signal EN_send_ports_2_getNonFullVCs          : std_logic;
    signal send_ports_2_getNonFullVCs             : std_logic_vector(1 downto 0);
    signal send_ports_3_putFlit_flit_in           : std_logic_vector(70 downto 0);
    signal EN_send_ports_3_putFlit                : std_logic;
    signal EN_send_ports_3_getNonFullVCs          : std_logic;
    signal send_ports_3_getNonFullVCs             : std_logic_vector(1 downto 0);
    signal send_ports_4_putFlit_flit_in           : std_logic_vector(70 downto 0);
    signal EN_send_ports_4_putFlit                : std_logic;
    signal EN_send_ports_4_getNonFullVCs          : std_logic;
    signal send_ports_4_getNonFullVCs             : std_logic_vector(1 downto 0);
    signal send_ports_5_putFlit_flit_in           : std_logic_vector(70 downto 0);
    signal EN_send_ports_5_putFlit                : std_logic;
    signal EN_send_ports_5_getNonFullVCs          : std_logic;
    signal send_ports_5_getNonFullVCs             : std_logic_vector(1 downto 0);
    signal send_ports_6_putFlit_flit_in           : std_logic_vector(70 downto 0);
    signal EN_send_ports_6_putFlit                : std_logic;
    signal EN_send_ports_6_getNonFullVCs          : std_logic;
    signal send_ports_6_getNonFullVCs             : std_logic_vector(1 downto 0);
    signal send_ports_7_putFlit_flit_in           : std_logic_vector(70 downto 0);
    signal EN_send_ports_7_putFlit                : std_logic;
    signal EN_send_ports_7_getNonFullVCs          : std_logic;
    signal send_ports_7_getNonFullVCs             : std_logic_vector(1 downto 0);
    signal send_ports_8_putFlit_flit_in           : std_logic_vector(70 downto 0);
    signal EN_send_ports_8_putFlit                : std_logic;
    signal EN_send_ports_8_getNonFullVCs          : std_logic;
    signal send_ports_8_getNonFullVCs             : std_logic_vector(1 downto 0);
    signal EN_recv_ports_0_getFlit                : std_logic;
    signal recv_ports_0_getFlit                   : std_logic_vector(70 downto 0);
    signal recv_ports_0_putNonFullVCs_nonFullVCs  : std_logic_vector(1 downto 0);
    signal EN_recv_ports_0_putNonFullVCs          : std_logic;
    signal EN_recv_ports_1_getFlit                : std_logic;
    signal recv_ports_1_getFlit                   : std_logic_vector(70 downto 0);
    signal recv_ports_1_putNonFullVCs_nonFullVCs  : std_logic_vector(1 downto 0);
    signal EN_recv_ports_1_putNonFullVCs          : std_logic;
    signal EN_recv_ports_2_getFlit                : std_logic;
    signal recv_ports_2_getFlit                   : std_logic_vector(70 downto 0);
    signal recv_ports_2_putNonFullVCs_nonFullVCs  : std_logic_vector(1 downto 0);
    signal EN_recv_ports_2_putNonFullVCs          : std_logic;
    signal EN_recv_ports_3_getFlit                : std_logic;
    signal recv_ports_3_getFlit                   : std_logic_vector(70 downto 0);
    signal recv_ports_3_putNonFullVCs_nonFullVCs  : std_logic_vector(1 downto 0);
    signal EN_recv_ports_3_putNonFullVCs          : std_logic;
    signal EN_recv_ports_4_getFlit                : std_logic;
    signal recv_ports_4_getFlit                   : std_logic_vector(70 downto 0);
    signal recv_ports_4_putNonFullVCs_nonFullVCs  : std_logic_vector(1 downto 0);
    signal EN_recv_ports_4_putNonFullVCs          : std_logic;
    signal EN_recv_ports_5_getFlit                : std_logic;
    signal recv_ports_5_getFlit                   : std_logic_vector(70 downto 0);
    signal recv_ports_5_putNonFullVCs_nonFullVCs  : std_logic_vector(1 downto 0);
    signal EN_recv_ports_5_putNonFullVCs          : std_logic;
    signal EN_recv_ports_6_getFlit                : std_logic;
    signal recv_ports_6_getFlit                   : std_logic_vector(70 downto 0);
    signal recv_ports_6_putNonFullVCs_nonFullVCs  : std_logic_vector(1 downto 0);
    signal EN_recv_ports_6_putNonFullVCs          : std_logic;
    signal EN_recv_ports_7_getFlit                : std_logic;
    signal recv_ports_7_getFlit                   : std_logic_vector(70 downto 0);
    signal recv_ports_7_putNonFullVCs_nonFullVCs  : std_logic_vector(1 downto 0);
    signal EN_recv_ports_7_putNonFullVCs          : std_logic;
    signal EN_recv_ports_8_getFlit                : std_logic;
    signal recv_ports_8_getFlit                   : std_logic_vector(70 downto 0);
    signal recv_ports_8_putNonFullVCs_nonFullVCs  : std_logic_vector(1 downto 0);
    signal EN_recv_ports_8_putNonFullVCs          : std_logic;
    signal recv_ports_info_0_getRecvPortID        : std_logic_vector(3 downto 0);
    signal recv_ports_info_1_getRecvPortID        : std_logic_vector(3 downto 0);
    signal recv_ports_info_2_getRecvPortID        : std_logic_vector(3 downto 0);
    signal recv_ports_info_3_getRecvPortID        : std_logic_vector(3 downto 0);
    signal recv_ports_info_4_getRecvPortID        : std_logic_vector(3 downto 0);
    signal recv_ports_info_5_getRecvPortID        : std_logic_vector(3 downto 0);
    signal recv_ports_info_6_getRecvPortID        : std_logic_vector(3 downto 0);
    signal recv_ports_info_7_getRecvPortID        : std_logic_vector(3 downto 0);
    signal recv_ports_info_8_getRecvPortID        : std_logic_vector(3 downto 0);
    signal send_ports_9_putFlit_flit_in           : std_logic_vector(70 downto 0);
    signal EN_send_ports_9_putFlit                : std_logic;
    signal EN_send_ports_9_getNonFullVCs          : std_logic;
    signal send_ports_9_getNonFullVCs             : std_logic_vector(1 downto 0);
    signal send_ports_10_putFlit_flit_in          : std_logic_vector(70 downto 0);
    signal EN_send_ports_10_putFlit               : std_logic;
    signal EN_send_ports_10_getNonFullVCs         : std_logic;
    signal send_ports_10_getNonFullVCs            : std_logic_vector(1 downto 0);
    signal send_ports_11_putFlit_flit_in          : std_logic_vector(70 downto 0);
    signal EN_send_ports_11_putFlit               : std_logic;
    signal EN_send_ports_11_getNonFullVCs         : std_logic;
    signal send_ports_11_getNonFullVCs            : std_logic_vector(1 downto 0);
    signal EN_recv_ports_9_getFlit                : std_logic;
    signal recv_ports_9_getFlit                   : std_logic_vector(70 downto 0);
    signal recv_ports_9_putNonFullVCs_nonFullVCs  : std_logic_vector(1 downto 0);
    signal EN_recv_ports_9_putNonFullVCs          : std_logic;
    signal EN_recv_ports_10_getFlit               : std_logic;
    signal recv_ports_10_getFlit                  : std_logic_vector(70 downto 0);
    signal recv_ports_10_putNonFullVCs_nonFullVCs : std_logic_vector(1 downto 0);
    signal EN_recv_ports_10_putNonFullVCs         : std_logic;
    signal EN_recv_ports_11_getFlit               : std_logic;
    signal recv_ports_11_getFlit                  : std_logic_vector(70 downto 0);
    signal recv_ports_11_putNonFullVCs_nonFullVCs : std_logic_vector(1 downto 0);
    signal EN_recv_ports_11_putNonFullVCs         : std_logic;
    signal recv_ports_info_9_getRecvPortID        : std_logic_vector(3 downto 0);
    signal recv_ports_info_10_getRecvPortID       : std_logic_vector(3 downto 0);
    signal recv_ports_info_11_getRecvPortID       : std_logic_vector(3 downto 0);


    signal send_data_pe0       : std_logic_vector(data_width-1 downto 0);                          
    signal dest_addr_pe0       : std_logic_vector(addr_width-1 downto 0);
    signal set_tail_flit_pe0   : std_logic;             
    signal send_flit_pe0       : std_logic;          
    signal ready_to_send_pe0   : std_logic;             
    signal recv_data_pe0       : std_logic_vector(data_width-1 downto 0);        
    signal src_addr_pe0        : std_logic_vector(addr_width-1 downto 0);       
    signal is_tail_flit_pe0    : std_logic;            
    signal data_in_buffer_pe0  : std_logic_vector(num_vc-1 downto 0);             
    signal dequeue_pe0         : std_logic_vector(num_vc-1 downto 0);       
    signal select_vc_read_pe0  : std_logic_vector(vc_sel_width-1 downto 0);                 
    
    signal send_data_pe1       : std_logic_vector(data_width-1 downto 0);                          
    signal dest_addr_pe1       : std_logic_vector(addr_width-1 downto 0);
    signal set_tail_flit_pe1   : std_logic;             
    signal send_flit_pe1       : std_logic;          
    signal ready_to_send_pe1   : std_logic;             
    signal recv_data_pe1       : std_logic_vector(data_width-1 downto 0);        
    signal src_addr_pe1        : std_logic_vector(addr_width-1 downto 0);       
    signal is_tail_flit_pe1    : std_logic;            
    signal data_in_buffer_pe1  : std_logic_vector(num_vc-1 downto 0);             
    signal dequeue_pe1         : std_logic_vector(num_vc-1 downto 0);       
    signal select_vc_read_pe1  : std_logic_vector(vc_sel_width-1 downto 0);  
     
    signal send_data_pe2       : std_logic_vector(data_width-1 downto 0);                          
    signal dest_addr_pe2       : std_logic_vector(addr_width-1 downto 0);
    signal set_tail_flit_pe2   : std_logic;             
    signal send_flit_pe2       : std_logic;          
    signal ready_to_send_pe2   : std_logic;             
    signal recv_data_pe2       : std_logic_vector(data_width-1 downto 0);        
    signal src_addr_pe2        : std_logic_vector(addr_width-1 downto 0);       
    signal is_tail_flit_pe2    : std_logic;            
    signal data_in_buffer_pe2  : std_logic_vector(num_vc-1 downto 0);             
    signal dequeue_pe2         : std_logic_vector(num_vc-1 downto 0);       
    signal select_vc_read_pe2  : std_logic_vector(vc_sel_width-1 downto 0); 

    signal send_data_pe3       : std_logic_vector(data_width-1 downto 0);                          
    signal dest_addr_pe3       : std_logic_vector(addr_width-1 downto 0);
    signal set_tail_flit_pe3   : std_logic;             
    signal send_flit_pe3       : std_logic;          
    signal ready_to_send_pe3   : std_logic;             
    signal recv_data_pe3       : std_logic_vector(data_width-1 downto 0);        
    signal src_addr_pe3        : std_logic_vector(addr_width-1 downto 0);       
    signal is_tail_flit_pe3    : std_logic;            
    signal data_in_buffer_pe3  : std_logic_vector(num_vc-1 downto 0);             
    signal dequeue_pe3         : std_logic_vector(num_vc-1 downto 0);       
    signal select_vc_read_pe3  : std_logic_vector(vc_sel_width-1 downto 0);  

    signal send_data_pe4       : std_logic_vector(data_width-1 downto 0);                          
    signal dest_addr_pe4       : std_logic_vector(addr_width-1 downto 0);
    signal set_tail_flit_pe4   : std_logic;             
    signal send_flit_pe4       : std_logic;          
    signal ready_to_send_pe4   : std_logic;             
    signal recv_data_pe4       : std_logic_vector(data_width-1 downto 0);        
    signal src_addr_pe4        : std_logic_vector(addr_width-1 downto 0);       
    signal is_tail_flit_pe4    : std_logic;            
    signal data_in_buffer_pe4  : std_logic_vector(num_vc-1 downto 0);             
    signal dequeue_pe4         : std_logic_vector(num_vc-1 downto 0);       
    signal select_vc_read_pe4  : std_logic_vector(vc_sel_width-1 downto 0);      

     
    signal send_data_pe5       : std_logic_vector(data_width-1 downto 0);                          
    signal dest_addr_pe5       : std_logic_vector(addr_width-1 downto 0);
    signal set_tail_flit_pe5   : std_logic;             
    signal send_flit_pe5       : std_logic;          
    signal ready_to_send_pe5   : std_logic;             
    signal recv_data_pe5       : std_logic_vector(data_width-1 downto 0);        
    signal src_addr_pe5        : std_logic_vector(addr_width-1 downto 0);       
    signal is_tail_flit_pe5    : std_logic;            
    signal data_in_buffer_pe5  : std_logic_vector(num_vc-1 downto 0);             
    signal dequeue_pe5         : std_logic_vector(num_vc-1 downto 0);       
    signal select_vc_read_pe5  : std_logic_vector(vc_sel_width-1 downto 0);      
     
    signal send_data_pe6       : std_logic_vector(data_width-1 downto 0);                          
    signal dest_addr_pe6       : std_logic_vector(addr_width-1 downto 0);
    signal set_tail_flit_pe6   : std_logic;             
    signal send_flit_pe6       : std_logic;          
    signal ready_to_send_pe6   : std_logic;             
    signal recv_data_pe6       : std_logic_vector(data_width-1 downto 0);        
    signal src_addr_pe6        : std_logic_vector(addr_width-1 downto 0);       
    signal is_tail_flit_pe6    : std_logic;            
    signal data_in_buffer_pe6  : std_logic_vector(num_vc-1 downto 0);             
    signal dequeue_pe6         : std_logic_vector(num_vc-1 downto 0);       
    signal select_vc_read_pe6  : std_logic_vector(vc_sel_width-1 downto 0);     
     
    signal send_data_pe7       : std_logic_vector(data_width-1 downto 0);                          
    signal dest_addr_pe7       : std_logic_vector(addr_width-1 downto 0);
    signal set_tail_flit_pe7   : std_logic;             
    signal send_flit_pe7       : std_logic;          
    signal ready_to_send_pe7   : std_logic;             
    signal recv_data_pe7       : std_logic_vector(data_width-1 downto 0);        
    signal src_addr_pe7        : std_logic_vector(addr_width-1 downto 0);       
    signal is_tail_flit_pe7    : std_logic;            
    signal data_in_buffer_pe7  : std_logic_vector(num_vc-1 downto 0);             
    signal dequeue_pe7         : std_logic_vector(num_vc-1 downto 0);       
    signal select_vc_read_pe7  : std_logic_vector(vc_sel_width-1 downto 0); 
     
    signal send_data_pe8       : std_logic_vector(data_width-1 downto 0);                          
    signal dest_addr_pe8       : std_logic_vector(addr_width-1 downto 0);
    signal set_tail_flit_pe8   : std_logic;             
    signal send_flit_pe8       : std_logic;          
    signal ready_to_send_pe8   : std_logic;             
    signal recv_data_pe8       : std_logic_vector(data_width-1 downto 0);        
    signal src_addr_pe8        : std_logic_vector(addr_width-1 downto 0);       
    signal is_tail_flit_pe8    : std_logic;            
    signal data_in_buffer_pe8  : std_logic_vector(num_vc-1 downto 0);             
    signal dequeue_pe8         : std_logic_vector(num_vc-1 downto 0);       
    signal select_vc_read_pe8  : std_logic_vector(vc_sel_width-1 downto 0); 
     
    signal send_data_pe9       : std_logic_vector(data_width-1 downto 0);                          
    signal dest_addr_pe9       : std_logic_vector(addr_width-1 downto 0);
    signal set_tail_flit_pe9   : std_logic;             
    signal send_flit_pe9       : std_logic;          
    signal ready_to_send_pe9   : std_logic;             
    signal recv_data_pe9       : std_logic_vector(data_width-1 downto 0);        
    signal src_addr_pe9        : std_logic_vector(addr_width-1 downto 0);       
    signal is_tail_flit_pe9    : std_logic;            
    signal data_in_buffer_pe9  : std_logic_vector(num_vc-1 downto 0);             
    signal dequeue_pe9         : std_logic_vector(num_vc-1 downto 0);       
    signal select_vc_read_pe9  : std_logic_vector(vc_sel_width-1 downto 0); 

    signal noc_rst             : std_logic;
    signal noc_ctrl_export     : std_logic_vector(31 downto 0);
    signal noc_status_export   : std_logic_vector(31 downto 0);

    signal LEDR_NOPE : std_logic_vector(9 downto 0);
    
    signal is_idle         : std_logic_vector(2 downto 0);
    signal is_filtering    : std_logic_vector(2 downto 0);
    signal is_tx_ing       : std_logic_vector(2 downto 0);
    signal is_cleanup_ing  : std_logic_vector(2 downto 0);

    signal ledr            : std_logic_vector(9 downto 0);
     
    signal clk27          : std_logic;
    signal rst27          : std_logic;
    signal vga_red        : std_logic_vector(5 downto 0);
    signal vga_blue       : std_logic_vector(5 downto 0);
    signal vga_green      : std_logic_vector(5 downto 0);
    signal vga_v_sync     : std_logic;
    signal vga_h_sync     : std_logic;
     
    signal data_in_cpu_0    :  std_logic_vector(63 downto 0);
    signal data_out_cpu_0   :  std_logic_vector(63 downto 0);
    signal noc_ctrl_cpu_0   :  std_logic_vector(31 downto 0);
    signal noc_sts_cpu_0    :  std_logic_vector(31 downto 0);
    signal data_in_cpu_1    :  std_logic_vector(63 downto 0);
    signal data_out_cpu_1   :  std_logic_vector(63 downto 0);
    signal noc_ctrl_cpu_1   :  std_logic_vector(31 downto 0);
    signal noc_sts_cpu_1    :  std_logic_vector(31 downto 0);
    signal rx               :  std_logic_vector(63 downto 0);
    signal pll_clock_clk    :  std_logic;
     
     

    
    
BEGIN

    NiosII: nios_system
    port MAP (
        clk_clk                 => OSC_50_BANK3,
        --reset_reset_n         => BUTTON(0),
        switches_export     => SLIDE_SW,
        leds_export             => LED,
        memory_mem_a            => M1_DDR2_addr,
        memory_mem_ba           => M1_DDR2_ba,
        memory_mem_ck           => M1_DDR2_clk,
        memory_mem_ck_n     => M1_DDR2_clk_n,
        memory_mem_cke          => M1_DDR2_cke,
        memory_mem_cs_n     => M1_DDR2_cs_n,
        memory_mem_dm           => M1_DDR2_dm,
        memory_mem_ras_n        => M1_DDR2_ras_n,
        memory_mem_cas_n        => M1_DDR2_cas_n,
        memory_mem_we_n     => M1_DDR2_we_n,
        memory_mem_dq           => M1_DDR2_dq,
        memory_mem_dqs          => M1_DDR2_dqs,
        memory_mem_dqs_n        => M1_DDR2_dqsn,
        memory_mem_odt          => M1_DDR2_odt,
        oct_rdn                 => M1_DDR2_oct_rdn(0),
        oct_rup                 => M1_DDR2_oct_rup(0),
        sd_card_b_SD_cmd     => sd_card_b_SD_cmd,  
        sd_card_b_SD_dat     => sd_card_b_SD_dat,  
        sd_card_b_SD_dat3    => sd_card_b_SD_dat3, 
        sd_card_o_SD_clock   => sd_card_o_SD_clock,
        memory_0_mem_a          => M2_DDR2_addr,
        memory_0_mem_ba     => M2_DDR2_ba,
        memory_0_mem_ck     => M2_DDR2_clk,
        memory_0_mem_ck_n       => M2_DDR2_clk_n,
        memory_0_mem_cke        => M2_DDR2_cke,
        memory_0_mem_cs_n       => M2_DDR2_cs_n,
        memory_0_mem_dm    => M2_DDR2_dm,
        memory_0_mem_ras_n   => M2_DDR2_ras_n,
        memory_0_mem_cas_n   => M2_DDR2_cas_n,
        memory_0_mem_we_n       => M2_DDR2_we_n,
        memory_0_mem_dq    => M2_DDR2_dq,
        memory_0_mem_dqs       => M2_DDR2_dqs,
        memory_0_mem_dqs_n   => M2_DDR2_dqsn,
        memory_0_mem_odt       => M2_DDR2_odt,
        oct_0_rdn               => M2_DDR2_oct_rdn(0),
        oct_0_rup               => M2_DDR2_oct_rup(0),
        pll_clock_clk        => pll_clock_clk,
        cpu_0_noc_ctrl_export => cpu_0_noc_ctrl_export, 
        cpu_0_noc_sts_export  => cpu_0_noc_sts_export,   
        cpu_1_noc_ctrl_export => cpu_1_noc_ctrl_export, 
        cpu_1_noc_sts_export  => cpu_1_noc_sts_export,  
        cpu_0_rx_0_external_connection_export => cpu_0_rx_0_external_connection_export,
        cpu_0_rx_1_external_connection_export => cpu_0_rx_1_external_connection_export,
        cpu_0_rx_2_external_connection_export => cpu_0_rx_2_external_connection_export,
        cpu_0_rx_3_external_connection_export => cpu_0_rx_3_external_connection_export,
        cpu_0_rx_4_external_connection_export => cpu_0_rx_4_external_connection_export,
        cpu_0_rx_5_external_connection_export => cpu_0_rx_5_external_connection_export,
        cpu_0_rx_6_external_connection_export => cpu_0_rx_6_external_connection_export,
        cpu_0_rx_7_external_connection_export => cpu_0_rx_7_external_connection_export,
        cpu_0_tx_0_external_connection_export => cpu_0_tx_0_external_connection_export,
        cpu_0_tx_1_external_connection_export => cpu_0_tx_1_external_connection_export,
        cpu_0_tx_2_external_connection_export => cpu_0_tx_2_external_connection_export,
        cpu_0_tx_3_external_connection_export => cpu_0_tx_3_external_connection_export,
        cpu_0_tx_4_external_connection_export => cpu_0_tx_4_external_connection_export,
        cpu_0_tx_5_external_connection_export => cpu_0_tx_5_external_connection_export,
        cpu_0_tx_6_external_connection_export => cpu_0_tx_6_external_connection_export,
        cpu_0_tx_7_external_connection_export => cpu_0_tx_7_external_connection_export,
        cpu_1_rx_0_external_connection_export => cpu_1_rx_0_external_connection_export,
        cpu_1_rx_1_external_connection_export => cpu_1_rx_1_external_connection_export,
        cpu_1_rx_2_external_connection_export => cpu_1_rx_2_external_connection_export,
        cpu_1_rx_3_external_connection_export => cpu_1_rx_3_external_connection_export,
        cpu_1_rx_4_external_connection_export => cpu_1_rx_4_external_connection_export,
        cpu_1_rx_5_external_connection_export => cpu_1_rx_5_external_connection_export,
        cpu_1_rx_6_external_connection_export => cpu_1_rx_6_external_connection_export,
        cpu_1_rx_7_external_connection_export => cpu_1_rx_7_external_connection_export,
        cpu_1_tx_0_external_connection_export => cpu_1_tx_0_external_connection_export,
        cpu_1_tx_1_external_connection_export => cpu_1_tx_1_external_connection_export,
        cpu_1_tx_2_external_connection_export => cpu_1_tx_2_external_connection_export,
        cpu_1_tx_3_external_connection_export => cpu_1_tx_3_external_connection_export,
        cpu_1_tx_4_external_connection_export => cpu_1_tx_4_external_connection_export,
        cpu_1_tx_5_external_connection_export => cpu_1_tx_5_external_connection_export,
        cpu_1_tx_6_external_connection_export => cpu_1_tx_6_external_connection_export,
        cpu_1_tx_7_external_connection_export => cpu_1_tx_7_external_connection_export,
        vga_clock_clk         => vga_clock_clk       
    );

    clock_50 <= OSC_50_BANK3; 
    vga_clock <= vga_clock_clk;
    data_in_cpu_0         <= cpu_0_tx_0_external_connection_export & cpu_0_tx_1_external_connection_export;
    noc_ctrl_cpu_0        <= cpu_0_noc_ctrl_export;
    cpu_0_noc_sts_export  <= noc_sts_cpu_0;

    data_in_cpu_1         <= cpu_1_tx_0_external_connection_export & cpu_1_tx_1_external_connection_export;
    noc_ctrl_cpu_1        <= cpu_1_noc_ctrl_export;
    cpu_1_noc_sts_export  <= noc_sts_cpu_1;


    u1 : component mkNetworkSimple
    port map(
        CLK                                    => CLOCK_50                               ,
        RST_N                                  => not noc_rst                            ,
        send_ports_0_putFlit_flit_in           => send_ports_0_putFlit_flit_in           ,
        EN_send_ports_0_putFlit                => EN_send_ports_0_putFlit                ,
        EN_send_ports_0_getNonFullVCs          => EN_send_ports_0_getNonFullVCs          ,
        send_ports_0_getNonFullVCs             => send_ports_0_getNonFullVCs             ,
        send_ports_1_putFlit_flit_in           => send_ports_1_putFlit_flit_in           ,
        EN_send_ports_1_putFlit                => EN_send_ports_1_putFlit                ,
        EN_send_ports_1_getNonFullVCs          => EN_send_ports_1_getNonFullVCs          ,
        send_ports_1_getNonFullVCs             => send_ports_1_getNonFullVCs             ,
        send_ports_2_putFlit_flit_in           => send_ports_2_putFlit_flit_in           ,
        EN_send_ports_2_putFlit                => EN_send_ports_2_putFlit                ,
        EN_send_ports_2_getNonFullVCs          => EN_send_ports_2_getNonFullVCs          ,
        send_ports_2_getNonFullVCs             => send_ports_2_getNonFullVCs             ,
        send_ports_3_putFlit_flit_in           => send_ports_3_putFlit_flit_in           ,
        EN_send_ports_3_putFlit                => EN_send_ports_3_putFlit                ,
        EN_send_ports_3_getNonFullVCs          => EN_send_ports_3_getNonFullVCs          ,
        send_ports_3_getNonFullVCs             => send_ports_3_getNonFullVCs             ,
        send_ports_4_putFlit_flit_in           => send_ports_4_putFlit_flit_in           ,
        EN_send_ports_4_putFlit                => EN_send_ports_4_putFlit                ,
        EN_send_ports_4_getNonFullVCs          => EN_send_ports_4_getNonFullVCs          ,
        send_ports_4_getNonFullVCs             => send_ports_4_getNonFullVCs             ,
        send_ports_5_putFlit_flit_in           => send_ports_5_putFlit_flit_in           ,
        EN_send_ports_5_putFlit                => EN_send_ports_5_putFlit                ,
        EN_send_ports_5_getNonFullVCs          => EN_send_ports_5_getNonFullVCs          ,
        send_ports_5_getNonFullVCs             => send_ports_5_getNonFullVCs             ,
        send_ports_6_putFlit_flit_in           => send_ports_6_putFlit_flit_in           ,
        EN_send_ports_6_putFlit                => EN_send_ports_6_putFlit                ,
        EN_send_ports_6_getNonFullVCs          => EN_send_ports_6_getNonFullVCs          ,
        send_ports_6_getNonFullVCs             => send_ports_6_getNonFullVCs             ,
        send_ports_7_putFlit_flit_in           => send_ports_7_putFlit_flit_in           ,
        EN_send_ports_7_putFlit                => EN_send_ports_7_putFlit                ,
        EN_send_ports_7_getNonFullVCs          => EN_send_ports_7_getNonFullVCs          ,
        send_ports_7_getNonFullVCs             => send_ports_7_getNonFullVCs             ,
        send_ports_8_putFlit_flit_in           => send_ports_8_putFlit_flit_in           ,
        EN_send_ports_8_putFlit                => EN_send_ports_8_putFlit                ,
        EN_send_ports_8_getNonFullVCs          => EN_send_ports_8_getNonFullVCs          ,
        send_ports_8_getNonFullVCs             => send_ports_8_getNonFullVCs             ,
        EN_recv_ports_0_getFlit                => EN_recv_ports_0_getFlit                ,
        recv_ports_0_getFlit                   => recv_ports_0_getFlit                   ,
        recv_ports_0_putNonFullVCs_nonFullVCs  => recv_ports_0_putNonFullVCs_nonFullVCs  ,
        EN_recv_ports_0_putNonFullVCs          => EN_recv_ports_0_putNonFullVCs          ,
        EN_recv_ports_1_getFlit                => EN_recv_ports_1_getFlit                ,
        recv_ports_1_getFlit                   => recv_ports_1_getFlit                   ,
        recv_ports_1_putNonFullVCs_nonFullVCs  => recv_ports_1_putNonFullVCs_nonFullVCs  ,
        EN_recv_ports_1_putNonFullVCs          => EN_recv_ports_1_putNonFullVCs          ,
        EN_recv_ports_2_getFlit                => EN_recv_ports_2_getFlit                ,
        recv_ports_2_getFlit                   => recv_ports_2_getFlit                   ,
        recv_ports_2_putNonFullVCs_nonFullVCs  => recv_ports_2_putNonFullVCs_nonFullVCs  ,
        EN_recv_ports_2_putNonFullVCs          => EN_recv_ports_2_putNonFullVCs          ,
        EN_recv_ports_3_getFlit                => EN_recv_ports_3_getFlit                ,
        recv_ports_3_getFlit                   => recv_ports_3_getFlit                   ,
        recv_ports_3_putNonFullVCs_nonFullVCs  => recv_ports_3_putNonFullVCs_nonFullVCs  ,
        EN_recv_ports_3_putNonFullVCs          => EN_recv_ports_3_putNonFullVCs          ,
        EN_recv_ports_4_getFlit                => EN_recv_ports_4_getFlit                ,
        recv_ports_4_getFlit                   => recv_ports_4_getFlit                   ,
        recv_ports_4_putNonFullVCs_nonFullVCs  => recv_ports_4_putNonFullVCs_nonFullVCs  ,
        EN_recv_ports_4_putNonFullVCs          => EN_recv_ports_4_putNonFullVCs          ,
        EN_recv_ports_5_getFlit                => EN_recv_ports_5_getFlit                ,
        recv_ports_5_getFlit                   => recv_ports_5_getFlit                   ,
        recv_ports_5_putNonFullVCs_nonFullVCs  => recv_ports_5_putNonFullVCs_nonFullVCs  ,
        EN_recv_ports_5_putNonFullVCs          => EN_recv_ports_5_putNonFullVCs          ,
        EN_recv_ports_6_getFlit                => EN_recv_ports_6_getFlit                ,
        recv_ports_6_getFlit                   => recv_ports_6_getFlit                   ,
        recv_ports_6_putNonFullVCs_nonFullVCs  => recv_ports_6_putNonFullVCs_nonFullVCs  ,
        EN_recv_ports_6_putNonFullVCs          => EN_recv_ports_6_putNonFullVCs          ,
        EN_recv_ports_7_getFlit                => EN_recv_ports_7_getFlit                ,
        recv_ports_7_getFlit                   => recv_ports_7_getFlit                   ,
        recv_ports_7_putNonFullVCs_nonFullVCs  => recv_ports_7_putNonFullVCs_nonFullVCs  ,
        EN_recv_ports_7_putNonFullVCs          => EN_recv_ports_7_putNonFullVCs          ,
        EN_recv_ports_8_getFlit                => EN_recv_ports_8_getFlit                ,
        recv_ports_8_getFlit                   => recv_ports_8_getFlit                   ,
        recv_ports_8_putNonFullVCs_nonFullVCs  => recv_ports_8_putNonFullVCs_nonFullVCs  ,
        EN_recv_ports_8_putNonFullVCs          => EN_recv_ports_8_putNonFullVCs          ,
        recv_ports_info_0_getRecvPortID        => recv_ports_info_0_getRecvPortID        ,
        recv_ports_info_1_getRecvPortID        => recv_ports_info_1_getRecvPortID        ,
        recv_ports_info_2_getRecvPortID        => recv_ports_info_2_getRecvPortID        ,
        recv_ports_info_3_getRecvPortID        => recv_ports_info_3_getRecvPortID        ,
        recv_ports_info_4_getRecvPortID        => recv_ports_info_4_getRecvPortID        ,
        recv_ports_info_5_getRecvPortID        => recv_ports_info_5_getRecvPortID        ,
        recv_ports_info_6_getRecvPortID        => recv_ports_info_6_getRecvPortID        ,
        recv_ports_info_7_getRecvPortID        => recv_ports_info_7_getRecvPortID        ,
        recv_ports_info_8_getRecvPortID        => recv_ports_info_8_getRecvPortID       
 
    );
    
   i0: noc_interface 
        generic map(
            data_width      => data_width,
            addr_width      => addr_width,
            vc_sel_width    => vc_sel_width,
            num_vc          => num_vc,
            flit_buff_depth => flit_buff_depth,
            use_vc          => 1)
        port map(
            clk                           => clock_50,
            rst                           => noc_rst,
            send_data                     => send_data_pe0,
            dest_addr                     => dest_addr_pe0,
            set_tail_flit                 => set_tail_flit_pe0,               
            send_flit                     => send_flit_pe0,                    
            ready_to_send                 => ready_to_send_pe0,                
            recv_data                     => recv_data_pe0,                    
            src_addr                      => src_addr_pe0,                     
            is_tail_flit                  => is_tail_flit_pe0,                 
            data_in_buffer                => data_in_buffer_pe0,               
            dequeue                       => dequeue_pe0,                      
            select_vc_read                => select_vc_read_pe0,               
            send_putFlit_flit_in          => send_ports_0_putFlit_flit_in,         
            EN_send_putFlit               => EN_send_ports_0_putFlit,              
            EN_send_getNonFullVCs         => EN_send_ports_0_getNonFullVCs,        
            send_getNonFullVCs            => send_ports_0_getNonFullVCs,           
            EN_recv_getFlit               => EN_recv_ports_0_getFlit,              
            recv_getFlit                  => recv_ports_0_getFlit,                 
            recv_putNonFullVCs_nonFullVCs => recv_ports_0_putNonFullVCs_nonFullVCs,
            EN_recv_putNonFullVCs         => EN_recv_ports_0_putNonFullVCs,        
            recv_info_getRecvPortID       => recv_ports_info_0_getRecvPortID);

    i1: noc_interface 
        generic map(
            data_width      => data_width,
            addr_width      => addr_width,
            vc_sel_width    => vc_sel_width,
            num_vc          => num_vc,
            flit_buff_depth => flit_buff_depth)
        port map(
            clk                           => clock_50,
            rst                           => noc_rst,
            send_data                     => send_data_pe1,
            dest_addr                     => dest_addr_pe1,
            set_tail_flit                 => set_tail_flit_pe1,               
            send_flit                     => send_flit_pe1,                    
            ready_to_send                 => ready_to_send_pe1,                
            recv_data                     => recv_data_pe1,                    
            src_addr                      => src_addr_pe1,                     
            is_tail_flit                  => is_tail_flit_pe1,                 
            data_in_buffer                => data_in_buffer_pe1,               
            dequeue                       => dequeue_pe1,                      
            select_vc_read                => select_vc_read_pe1,               
            send_putFlit_flit_in          => send_ports_1_putFlit_flit_in,         
            EN_send_putFlit               => EN_send_ports_1_putFlit,              
            EN_send_getNonFullVCs         => EN_send_ports_1_getNonFullVCs,        
            send_getNonFullVCs            => send_ports_1_getNonFullVCs,           
            EN_recv_getFlit               => EN_recv_ports_1_getFlit,              
            recv_getFlit                  => recv_ports_1_getFlit,                 
            recv_putNonFullVCs_nonFullVCs => recv_ports_1_putNonFullVCs_nonFullVCs,
            EN_recv_putNonFullVCs         => EN_recv_ports_1_putNonFullVCs,        
            recv_info_getRecvPortID       => recv_ports_info_1_getRecvPortID);

                
    i2: noc_interface 
        generic map(
            data_width      => data_width,
            addr_width      => addr_width,
            vc_sel_width    => vc_sel_width,
            num_vc          => num_vc,
            flit_buff_depth => flit_buff_depth)
        port map(
            clk                           => clock_50,
            rst                           => noc_rst,
            send_data                     => send_data_pe2,
            dest_addr                     => dest_addr_pe2,
            set_tail_flit                 => set_tail_flit_pe2,               
            send_flit                     => send_flit_pe2,                    
            ready_to_send                 => ready_to_send_pe2,                
            recv_data                     => recv_data_pe2,                    
            src_addr                      => src_addr_pe2,                     
            is_tail_flit                  => is_tail_flit_pe2,                 
            data_in_buffer                => data_in_buffer_pe2,               
            dequeue                       => dequeue_pe2,                      
            select_vc_read                => select_vc_read_pe2,               
            send_putFlit_flit_in          => send_ports_2_putFlit_flit_in,         
            EN_send_putFlit               => EN_send_ports_2_putFlit,              
            EN_send_getNonFullVCs         => EN_send_ports_2_getNonFullVCs,        
            send_getNonFullVCs            => send_ports_2_getNonFullVCs,           
            EN_recv_getFlit               => EN_recv_ports_2_getFlit,              
            recv_getFlit                  => recv_ports_2_getFlit,                 
            recv_putNonFullVCs_nonFullVCs => recv_ports_2_putNonFullVCs_nonFullVCs,
            EN_recv_putNonFullVCs         => EN_recv_ports_2_putNonFullVCs,        
            recv_info_getRecvPortID       => recv_ports_info_2_getRecvPortID); 
                
    i3: noc_interface 
        generic map(
            data_width      => data_width,
            addr_width      => addr_width,
            vc_sel_width    => vc_sel_width,
            num_vc          => num_vc,
            flit_buff_depth => flit_buff_depth)
        port map(
            clk                           => clock_50,
            rst                           => noc_rst,
            send_data                     => send_data_pe3,
            dest_addr                     => dest_addr_pe3,
            set_tail_flit                 => set_tail_flit_pe3,               
            send_flit                     => send_flit_pe3,                    
            ready_to_send                 => ready_to_send_pe3,                
            recv_data                     => recv_data_pe3,                    
            src_addr                      => src_addr_pe3,                     
            is_tail_flit                  => is_tail_flit_pe3,                 
            data_in_buffer                => data_in_buffer_pe3,               
            dequeue                       => dequeue_pe3,                      
            select_vc_read                => select_vc_read_pe3,               
            send_putFlit_flit_in          => send_ports_3_putFlit_flit_in,         
            EN_send_putFlit               => EN_send_ports_3_putFlit,              
            EN_send_getNonFullVCs         => EN_send_ports_3_getNonFullVCs,        
            send_getNonFullVCs            => send_ports_3_getNonFullVCs,           
            EN_recv_getFlit               => EN_recv_ports_3_getFlit,              
            recv_getFlit                  => recv_ports_3_getFlit,                 
            recv_putNonFullVCs_nonFullVCs => recv_ports_3_putNonFullVCs_nonFullVCs,
            EN_recv_putNonFullVCs         => EN_recv_ports_3_putNonFullVCs,        
            recv_info_getRecvPortID       => recv_ports_info_3_getRecvPortID);  
                
     i4: noc_interface 
        generic map(
            data_width      => data_width,
            addr_width      => addr_width,
            vc_sel_width    => vc_sel_width,
            num_vc          => num_vc,
            flit_buff_depth => flit_buff_depth)
        port map(
            clk                           => clock_50,
            rst                           => noc_rst,
            send_data                     => send_data_pe4,
            dest_addr                     => dest_addr_pe4,
            set_tail_flit                 => set_tail_flit_pe4,               
            send_flit                     => send_flit_pe4,                    
            ready_to_send                 => ready_to_send_pe4,                
            recv_data                     => recv_data_pe4,                    
            src_addr                      => src_addr_pe4,                     
            is_tail_flit                  => is_tail_flit_pe4,                 
            data_in_buffer                => data_in_buffer_pe4,               
            dequeue                       => dequeue_pe4,                      
            select_vc_read                => select_vc_read_pe4,               
            send_putFlit_flit_in          => send_ports_4_putFlit_flit_in,         
            EN_send_putFlit               => EN_send_ports_4_putFlit,              
            EN_send_getNonFullVCs         => EN_send_ports_4_getNonFullVCs,        
            send_getNonFullVCs            => send_ports_4_getNonFullVCs,           
            EN_recv_getFlit               => EN_recv_ports_4_getFlit,              
            recv_getFlit                  => recv_ports_4_getFlit,                 
            recv_putNonFullVCs_nonFullVCs => recv_ports_4_putNonFullVCs_nonFullVCs,
            EN_recv_putNonFullVCs         => EN_recv_ports_4_putNonFullVCs,        
            recv_info_getRecvPortID       => recv_ports_info_4_getRecvPortID);  
                
    i5: noc_interface 
        generic map(
            data_width      => data_width,
            addr_width      => addr_width,
            vc_sel_width    => vc_sel_width,
            num_vc          => num_vc,
            flit_buff_depth => flit_buff_depth)
        port map(
            clk                           => clock_50,
            rst                           => noc_rst,
            send_data                     => send_data_pe5,
            dest_addr                     => dest_addr_pe5,
            set_tail_flit                 => set_tail_flit_pe5,               
            send_flit                     => send_flit_pe5,                    
            ready_to_send                 => ready_to_send_pe5,                
            recv_data                     => recv_data_pe5,                    
            src_addr                      => src_addr_pe5,                     
            is_tail_flit                  => is_tail_flit_pe5,                 
            data_in_buffer                => data_in_buffer_pe5,               
            dequeue                       => dequeue_pe5,                      
            select_vc_read                => select_vc_read_pe5,               
            send_putFlit_flit_in          => send_ports_5_putFlit_flit_in,         
            EN_send_putFlit               => EN_send_ports_5_putFlit,              
            EN_send_getNonFullVCs         => EN_send_ports_5_getNonFullVCs,        
            send_getNonFullVCs            => send_ports_5_getNonFullVCs,           
            EN_recv_getFlit               => EN_recv_ports_5_getFlit,              
            recv_getFlit                  => recv_ports_5_getFlit,                 
            recv_putNonFullVCs_nonFullVCs => recv_ports_5_putNonFullVCs_nonFullVCs,
            EN_recv_putNonFullVCs         => EN_recv_ports_5_putNonFullVCs,        
            recv_info_getRecvPortID       => recv_ports_info_5_getRecvPortID);  
                
    i6: noc_interface 
        generic map(
            data_width      => data_width,
            addr_width      => addr_width,
            vc_sel_width    => vc_sel_width,
            num_vc          => num_vc,
            flit_buff_depth => flit_buff_depth)
        port map(
            clk                           => clock_50,
            rst                           => noc_rst,
            send_data                     => send_data_pe6,
            dest_addr                     => dest_addr_pe6,
            set_tail_flit                 => set_tail_flit_pe6,               
            send_flit                     => send_flit_pe6,                    
            ready_to_send                 => ready_to_send_pe6,                
            recv_data                     => recv_data_pe6,                    
            src_addr                      => src_addr_pe6,                     
            is_tail_flit                  => is_tail_flit_pe6,                 
            data_in_buffer                => data_in_buffer_pe6,               
            dequeue                       => dequeue_pe6,                      
            select_vc_read                => select_vc_read_pe6,               
            send_putFlit_flit_in          => send_ports_6_putFlit_flit_in,         
            EN_send_putFlit               => EN_send_ports_6_putFlit,              
            EN_send_getNonFullVCs         => EN_send_ports_6_getNonFullVCs,        
            send_getNonFullVCs            => send_ports_6_getNonFullVCs,           
            EN_recv_getFlit               => EN_recv_ports_6_getFlit,              
            recv_getFlit                  => recv_ports_6_getFlit,                 
            recv_putNonFullVCs_nonFullVCs => recv_ports_6_putNonFullVCs_nonFullVCs,
            EN_recv_putNonFullVCs         => EN_recv_ports_6_putNonFullVCs,        
            recv_info_getRecvPortID       => recv_ports_info_6_getRecvPortID);  
                
    i7: noc_interface 
        generic map(
            data_width      => data_width,
            addr_width      => addr_width,
            vc_sel_width    => vc_sel_width,
            num_vc          => num_vc,
            flit_buff_depth => flit_buff_depth,
                use_vc          => 0)
        port map(
            clk                           => clock_50,
            rst                           => noc_rst,
            send_data                     => send_data_pe7,
            dest_addr                     => dest_addr_pe7,
            set_tail_flit                 => set_tail_flit_pe7,               
            send_flit                     => send_flit_pe7,                    
            ready_to_send                 => ready_to_send_pe7,                
            recv_data                     => recv_data_pe7,                    
            src_addr                      => src_addr_pe7,                     
            is_tail_flit                  => is_tail_flit_pe7,                 
            data_in_buffer                => data_in_buffer_pe7,               
            dequeue                       => dequeue_pe7,                      
            select_vc_read                => select_vc_read_pe7,               
            send_putFlit_flit_in          => send_ports_7_putFlit_flit_in,         
            EN_send_putFlit               => EN_send_ports_7_putFlit,              
            EN_send_getNonFullVCs         => EN_send_ports_7_getNonFullVCs,        
            send_getNonFullVCs            => send_ports_7_getNonFullVCs,           
            EN_recv_getFlit               => EN_recv_ports_7_getFlit,              
            recv_getFlit                  => recv_ports_7_getFlit,                 
            recv_putNonFullVCs_nonFullVCs => recv_ports_7_putNonFullVCs_nonFullVCs,
            EN_recv_putNonFullVCs         => EN_recv_ports_7_putNonFullVCs,        
            recv_info_getRecvPortID       => recv_ports_info_7_getRecvPortID);  
                
     i8: noc_interface 
        generic map(
            data_width      => data_width,
            addr_width      => addr_width,
            vc_sel_width    => vc_sel_width,
            num_vc          => num_vc,
            flit_buff_depth => flit_buff_depth)
        port map(
            clk                           => clock_50,
            rst                           => noc_rst,
            send_data                     => send_data_pe8,
            dest_addr                     => dest_addr_pe8,
            set_tail_flit                 => set_tail_flit_pe8,               
            send_flit                     => send_flit_pe8,                    
            ready_to_send                 => ready_to_send_pe8,                
            recv_data                     => recv_data_pe8,                    
            src_addr                      => src_addr_pe8,                     
            is_tail_flit                  => is_tail_flit_pe8,                 
            data_in_buffer                => data_in_buffer_pe8,               
            dequeue                       => dequeue_pe8,                      
            select_vc_read                => select_vc_read_pe8,               
            send_putFlit_flit_in          => send_ports_8_putFlit_flit_in,         
            EN_send_putFlit               => EN_send_ports_8_putFlit,              
            EN_send_getNonFullVCs         => EN_send_ports_8_getNonFullVCs,        
            send_getNonFullVCs            => send_ports_8_getNonFullVCs,           
            EN_recv_getFlit               => EN_recv_ports_8_getFlit,              
            recv_getFlit                  => recv_ports_8_getFlit,                 
            recv_putNonFullVCs_nonFullVCs => recv_ports_8_putNonFullVCs_nonFullVCs,
            EN_recv_putNonFullVCs         => EN_recv_ports_8_putNonFullVCs,        
            recv_info_getRecvPortID       => recv_ports_info_8_getRecvPortID);


    n0: component deblocking_filter_node
    generic map(
        data_width      => data_width     , 
        addr_width      => addr_width     , 
        vc_sel_width    => vc_sel_width   , 
        num_vc          => num_vc         , 
        flit_buff_depth => flit_buff_depth 
    )
    port map(
        clk            => clock_50,
        rst            => noc_rst,
        recv_data      => recv_data_pe2,     
        src_addr       => src_addr_pe2,      
        is_tail_flit   => is_tail_flit_pe2,  
        data_in_buffer => data_in_buffer_pe2,
        dequeue        => dequeue_pe2,       
        select_vc_read => select_vc_read_pe2,
        send_data      => send_data_pe2,
        dest_addr      => dest_addr_pe2,
        set_tail_flit  => set_tail_flit_pe2,
        send_flit      => send_flit_pe2,    
        ready_to_send  => ready_to_send_pe2
    );    

    n1: component inter_node
    generic map(
        size_x          => 16,
        size_y          => 9,
        interp_x        => 4 ,
        interp_y        => 2 ,
        sample_size     => 8 ,
        samples_per_wr  => 8 ,
        data_width      => data_width     ,
        addr_width      => addr_width     ,
        vc_sel_width    => vc_sel_width   ,
        num_vc          => num_vc         ,
        flit_buff_depth => flit_buff_depth          
    )
    port map(
        clk            => clock_50,
        rst            => noc_rst,
        recv_data      => recv_data_pe5,     
        src_addr       => src_addr_pe5,      
        is_tail_flit   => is_tail_flit_pe5,  
        data_in_buffer => data_in_buffer_pe5,
        dequeue        => dequeue_pe5,       
        select_vc_read => select_vc_read_pe5,
        send_data      => send_data_pe5,
        dest_addr      => dest_addr_pe5,
        set_tail_flit  => set_tail_flit_pe5,
        send_flit      => send_flit_pe5,    
        ready_to_send  => ready_to_send_pe5
    );
     
     n2: component intra_prediction_node
     generic map(
        data_width      => data_width     , 
        addr_width      => addr_width     , 
        vc_sel_width    => vc_sel_width   , 
        num_vc          => num_vc         , 
        flit_buff_depth => flit_buff_depth 
     )
     port map(
        clk            => clock_50,
        rst            => noc_rst,
        recv_data      => recv_data_pe3,     
        src_addr       => src_addr_pe3,      
        is_tail_flit   => is_tail_flit_pe3,  
        data_in_buffer => data_in_buffer_pe3,
        dequeue        => dequeue_pe3,       
        select_vc_read => select_vc_read_pe3,
        send_data      => send_data_pe3,
        dest_addr      => dest_addr_pe3,
        set_tail_flit  => set_tail_flit_pe3,
        send_flit      => send_flit_pe3,    
        ready_to_send  => ready_to_send_pe3,
        s_intra_idle               => ledr(0),
        s_intra_data_rxd           => ledr(1),
        s_intra_write_sample       => ledr(2),
        s_intra_start_pred         => ledr(3),
        s_intra_start_tx_loop      => ledr(4),
        s_intra_start_tx_loop_hold => ledr(5),
        s_intra_tx                 => ledr(6),
        s_intra_tx_hold            => ledr(7),
        s_intra_tx_gen_next        => ledr(8),
        s_intra_dequeue_rx         => ledr(9)
    );
     
     n3: component noc_control_plus
    generic map(
        data_width      => data_width     , 
        addr_width      => addr_width     , 
        vc_sel_width    => vc_sel_width   , 
        num_vc          => num_vc         , 
        flit_buff_depth => flit_buff_depth
    )
    port map(
        clk            => clock_50,
        rst            => noc_rst,
        recv_data      => recv_data_pe0,    
        src_addr       => src_addr_pe0,     
        is_tail_flit   => is_tail_flit_pe0, 
        data_in_buffer => data_in_buffer_pe0,
        dequeue        => dequeue_pe0,      
        select_vc_read => select_vc_read_pe0, 
        send_data      => send_data_pe0,
        dest_addr      => dest_addr_pe0,
        set_tail_flit  => set_tail_flit_pe0,
        send_flit      => send_flit_pe0,   
        ready_to_send  => ready_to_send_pe0,
        set_tail_cpu   => noc_ctrl_cpu_0(31),
        addr_cpu       => std_logic_vector(resize(unsigned(noc_ctrl_cpu_0(23 downto 16)),addr_width)),
        format_select  => noc_ctrl_cpu_0(7 downto 0),
        send_cmd_cpu   => noc_ctrl_cpu_0(30),
        send_ack       => noc_sts_cpu_0(31),
        parse_select   => noc_ctrl_cpu_0(15 downto 8),
        cpu_rx_ctrl    => noc_ctrl_cpu_0(29),
        rx_state_out   => noc_sts_cpu_0(7 downto 0),
        rx_0           => cpu_0_rx_0_external_connection_export,
        rx_1           => cpu_0_rx_1_external_connection_export,
        rx_2           => cpu_0_rx_2_external_connection_export,
        rx_3           => cpu_0_rx_3_external_connection_export,
        rx_4           => cpu_0_rx_4_external_connection_export,
        rx_5           => cpu_0_rx_5_external_connection_export,
        rx_6           => cpu_0_rx_6_external_connection_export,
        rx_7           => cpu_0_rx_7_external_connection_export,
        tx_0           => cpu_0_tx_0_external_connection_export,
        tx_1           => cpu_0_tx_1_external_connection_export,
        tx_2           => cpu_0_tx_2_external_connection_export,
        tx_3           => cpu_0_tx_3_external_connection_export,
        tx_4           => cpu_0_tx_4_external_connection_export,
        tx_5           => cpu_0_tx_5_external_connection_export,
        tx_6           => cpu_0_tx_6_external_connection_export,
        tx_7           => cpu_0_tx_7_external_connection_export
    );
     
    n4: component chroma_motion
    generic map(
        data_width      => data_width     ,
        addr_width      => addr_width     ,
        vc_sel_width    => vc_sel_width   ,
        num_vc          => num_vc         ,
        flit_buff_depth => flit_buff_depth          
    )
    port map(
        clk            => clock_50,
        rst            => noc_rst,
        recv_data      => recv_data_pe4,     
        src_addr       => src_addr_pe4,      
        is_tail_flit   => is_tail_flit_pe4,  
        data_in_buffer => data_in_buffer_pe4,
        dequeue        => dequeue_pe4,       
        select_vc_read => select_vc_read_pe4,
        send_data      => send_data_pe4,
        dest_addr      => dest_addr_pe4,
        set_tail_flit  => set_tail_flit_pe4,
        send_flit      => send_flit_pe4,    
        ready_to_send  => ready_to_send_pe4
    );
     
    n6: component iqit_node
    generic map(
        sample_width    => 8,
        qp_width        => 8,
        wo_dc_width     => 8,
        data_width      => data_width     ,
        addr_width      => addr_width     ,
        vc_sel_width    => vc_sel_width   ,
        num_vc          => num_vc         ,
        flit_buff_depth => flit_buff_depth 
    )
    port map(
        clk            => clock_50,
        rst            => noc_rst,
        recv_data      => recv_data_pe1,     
        src_addr       => src_addr_pe1,      
        is_tail_flit   => is_tail_flit_pe1,  
        data_in_buffer => data_in_buffer_pe1,
        dequeue        => dequeue_pe1,       
        select_vc_read => select_vc_read_pe1,
        send_data      => send_data_pe1,
        dest_addr      => dest_addr_pe1,
        set_tail_flit  => set_tail_flit_pe1,
        send_flit      => send_flit_pe1,    
        ready_to_send  => ready_to_send_pe1
    );
     
    n7: component noc_control_plus
    generic map(
        data_width      => data_width     , 
        addr_width      => addr_width     , 
        vc_sel_width    => vc_sel_width   , 
        num_vc          => num_vc         , 
        flit_buff_depth => flit_buff_depth
    )
    port map(
        clk            => clock_50,
        rst            => noc_rst,
        recv_data      => recv_data_pe7,    
        src_addr       => src_addr_pe7,     
        is_tail_flit   => is_tail_flit_pe7, 
        data_in_buffer => data_in_buffer_pe7,
        dequeue        => dequeue_pe7,      
        select_vc_read => select_vc_read_pe7, 
        send_data      => send_data_pe7,
        dest_addr      => dest_addr_pe7,
        set_tail_flit  => set_tail_flit_pe7,
        send_flit      => send_flit_pe7,   
        ready_to_send  => ready_to_send_pe7,
        set_tail_cpu   => noc_ctrl_cpu_1(31),
        addr_cpu       => std_logic_vector(resize(unsigned(noc_ctrl_cpu_1(23 downto 16)),addr_width)),
        format_select  => noc_ctrl_cpu_1(7 downto 0),
        send_cmd_cpu   => noc_ctrl_cpu_1(30),
        send_ack       => noc_sts_cpu_1(31),
        parse_select   => noc_ctrl_cpu_1(15 downto 8),
        cpu_rx_ctrl    => noc_ctrl_cpu_1(29),
        rx_state_out   => noc_sts_cpu_1(7 downto 0),
        rx_0           => cpu_1_rx_0_external_connection_export,
        rx_1           => cpu_1_rx_1_external_connection_export,
        rx_2           => cpu_1_rx_2_external_connection_export,
        rx_3           => cpu_1_rx_3_external_connection_export,
        rx_4           => cpu_1_rx_4_external_connection_export,
        rx_5           => cpu_1_rx_5_external_connection_export,
        rx_6           => cpu_1_rx_6_external_connection_export,
        rx_7           => cpu_1_rx_7_external_connection_export,
        tx_0           => cpu_1_tx_0_external_connection_export,
        tx_1           => cpu_1_tx_1_external_connection_export,
        tx_2           => cpu_1_tx_2_external_connection_export,
        tx_3           => cpu_1_tx_3_external_connection_export,
        tx_4           => cpu_1_tx_4_external_connection_export,
        tx_5           => cpu_1_tx_5_external_connection_export,
        tx_6           => cpu_1_tx_6_external_connection_export,
        tx_7           => cpu_1_tx_7_external_connection_export
    );
     
    n8: component vga_node
    generic map(
        data_width      => data_width     , 
        addr_width      => addr_width     , 
        vc_sel_width    => vc_sel_width   , 
        num_vc          => num_vc         , 
        flit_buff_depth => flit_buff_depth 
    )
    port map(
        clk            => clock_50,
        rst            => noc_rst,
        recv_data      => recv_data_pe8,     
        src_addr       => src_addr_pe8,      
        is_tail_flit   => is_tail_flit_pe8,  
        data_in_buffer => data_in_buffer_pe8,
        dequeue        => dequeue_pe8,       
        select_vc_read => select_vc_read_pe8,
        send_data      => send_data_pe8,
        dest_addr      => dest_addr_pe8,
        set_tail_flit  => set_tail_flit_pe8,
        send_flit      => send_flit_pe8,    
        ready_to_send  => ready_to_send_pe8,
        clk27          => vga_clock,          
        rst27          => noc_rst,          
        vga_red        => vga_red,        
        vga_blue       => vga_blue,       
        vga_green      => vga_green,      
        vga_v_sync     => vga_v_sync,     
        vga_h_sync     => vga_h_sync     
        
        
    );
     
    --UNCOMMENT TO EXPERIMENT WITH 2 LMC NODES
    --n9: component inter_node
    --generic map(
    --    size_x          => 16,
    --    size_y          => 9,
    --    interp_x        => 4 ,
    --    interp_y        => 2 ,
    --    sample_size     => 8 ,
    --    samples_per_wr  => 8 ,
    --    data_width      => data_width     ,
    --    addr_width      => addr_width     ,
    --    vc_sel_width    => vc_sel_width   ,
    --    num_vc          => num_vc         ,
    --    flit_buff_depth => flit_buff_depth         
    --)
    --port map(
    --    clk            => clock_50,
    --    rst            => noc_rst,
    --    recv_data      => recv_data_pe6,     
    --    src_addr       => src_addr_pe6,      
    --    is_tail_flit   => is_tail_flit_pe6,  
    --    data_in_buffer => data_in_buffer_pe6,
    --    dequeue        => dequeue_pe6,       
    --    select_vc_read => select_vc_read_pe6,
    --    send_data      => send_data_pe6,
    --    dest_addr      => dest_addr_pe6,
    --    set_tail_flit  => set_tail_flit_pe6,
    --    send_flit      => send_flit_pe6,    
    --    ready_to_send  => ready_to_send_pe6
    --);
     
    noc_rst          <= noc_ctrl_cpu_0(28) or noc_ctrl_cpu_1(28); 
     
     
     
    --gpio header for vga
    gpio(0 ) <= '0';
    gpio(1 ) <= '0';
    gpio(2 ) <= vga_v_sync;
    gpio(3 ) <= '0';
    gpio(4 ) <= vga_h_sync;
    gpio(5 ) <= '0';
    gpio(6 ) <= vga_blue(0);
    gpio(7 ) <= vga_green(4);
    gpio(8 ) <= '0';
    gpio(9 ) <= vga_green(5);
    gpio(10) <= vga_red(1);
    gpio(11) <= vga_red(2);
    gpio(12) <= '0';
    gpio(13) <= '0';
    gpio(14) <= '0';
    gpio(15) <= '0';
    gpio(16) <= vga_green(0);
    gpio(17) <= '0';
    gpio(18) <= vga_blue(5);
    gpio(19) <= '0';
    gpio(20) <= vga_green(1);
    gpio(21) <= vga_blue(4);
    gpio(22) <= '0';
    gpio(23) <= vga_blue(3);
    gpio(24) <= vga_blue(1);
    gpio(25) <= '0';
    gpio(26) <= vga_blue(2);
    gpio(27) <= vga_green(2);
    gpio(28) <= vga_green(3);
    gpio(29) <= '0';
    gpio(30) <= vga_red(3);
    gpio(31) <= vga_red(0);
    gpio(32) <= '0';
    gpio(33) <= vga_red(4);
    gpio(34) <= '0';
    gpio(35) <= vga_red(5);
     
     
     
END MAIN;