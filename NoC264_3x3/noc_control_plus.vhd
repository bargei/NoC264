library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;


entity noc_control_plus is
generic (
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
end entity noc_control_plus;

architecture fsmd of noc_control_plus is
    
    component priority_encoder is
    generic(
        encoded_word_size : integer := 3
    );
    Port(
        input    : in  std_logic_vector(2**encoded_word_size-1 downto 0);
        output   : out std_logic_vector(encoded_word_size-1 downto 0)
    );
    end component priority_encoder;
    
    
    ----------------------------------------------------------------------------
    --- SIGNALS and CONSTANTS For Formating Flits ------------------------------
    ----------------------------------------------------------------------------
    --mode 0: fit as many of the lowest bits from each data word into the flit
    --Example: for 64 bit flits put the lowest 8 bits from each data word
    --This one covers inter and deblock
    signal mode_0_flit : std_logic_vector(data_width-1 downto 0);
    
    --mode 1: same as mode 0 but with data0-data3 only
    signal mode_1_flit : std_logic_vector(data_width-1 downto 0);
    
    --mode 2: same as modes 1,2 but with data0 and data1 only
    signal mode_2_flit : std_logic_vector(data_width-1 downto 0);
    
    --mode 3: data 0 only, zero fill
    signal mode_3_flit : std_logic_vector(data_width-1 downto 0);
    
    --mode 4: data 0 only, sign fill
    signal mode_4_flit : std_logic_vector(data_width-1 downto 0);
    
    --mode 5: Intra Set Command
    signal mode_5_flit : std_logic_vector(data_width-1 downto 0);
    
    --mode 6: Intra Start Prediction Command
    signal mode_6_flit : std_logic_vector(data_width-1 downto 0);
    
    --mode 7: Write to Display
    signal mode_7_flit : std_logic_vector(data_width-1 downto 0);
    
    --mode 8: IQIT Header
    signal mode_8_flit : std_logic_vector(data_width-1 downto 0);
    
    --mode 9: IQIT row
    signal mode_9_flit : std_logic_vector(data_width-1 downto 0);
    
    signal the_flit    : std_logic_vector(data_width-1 downto 0);
    
    --modes 0... 1
    constant eight_flit   : integer := data_width/8;
    constant quarter_flit : integer := data_width/4;
    
    --mode 3
    constant zero_fill    : integer := data_width-32;
    
    ----------------------------------------------------------------------------
    --- TYPES and SIGNALS for Sending Side State Machine -----------------------
    ----------------------------------------------------------------------------
    type send_state_type is (idle, send_requested, tx, ack);
    signal send_state, next_send_state : send_state_type;
    
    ----------------------------------------------------------------------------
    --- SIGNALS and CONSTANTS for Recieve Side ---------------------------------
    ----------------------------------------------------------------------------
    type rx_states is (rx_idle, rx_addr_rst, rx_start_read, rx_sel_vc, rx_rxd, rx_wait_cpu, rx_dequeue, rx_wait_flits);
    signal rx_state, next_rx_state : rx_states;
    signal selected_vc_one_hot : std_logic_vector(1 downto 0);
    signal state               : std_logic_vector(3 downto 0);
    signal cpu_read_ctrl       : std_logic;
    signal selected_vc_q, selected_vc_d, selected_vc_encoder      : std_logic_vector(vc_sel_width-1 downto 0);

     
    ----------------------------------------------------------------------------
    --- REGISTER for HW Timer --------------------------------------------------
    ----------------------------------------------------------------------------
    signal timer_d, timer_q : unsigned(31 downto 0);
    
begin
    --==========================================================================
    --==========================================================================
    --==SENDING SIDE============================================================
    --==========================================================================
    --==========================================================================

    ----------------------------------------------------------------------------
    --- FLIT GENERATION --------------------------------------------------------
    ----------------------------------------------------------------------------
    --format flit
    mode_0_flit <= tx_0(eight_flit-1   downto 0) & 
                   tx_1(eight_flit-1   downto 0) & 
                   tx_2(eight_flit-1   downto 0) & 
                   tx_3(eight_flit-1   downto 0) & 
                   tx_4(eight_flit-1   downto 0) & 
                   tx_5(eight_flit-1   downto 0) & 
                   tx_6(eight_flit-1   downto 0) & 
                   tx_7(eight_flit-1   downto 0);
    mode_1_flit <= tx_0(quarter_flit-1 downto 0) & 
                   tx_1(quarter_flit-1 downto 0) & 
                   tx_2(quarter_flit-1 downto 0) & 
                   tx_3(quarter_flit-1 downto 0);
    mode_2_flit <= tx_0 & tx_1;
    mode_3_flit <= std_logic_vector(to_unsigned(0,zero_fill)) & tx_0;
    mode_4_flit <= std_logic_vector(resize(signed( tx_0 ), data_width));
    mode_5_flit <= mode_0_flit;
    mode_6_flit <= mode_0_flit;
    mode_7_flit <= tx_0(eight_flit-1   downto 0) & 
                   tx_1(eight_flit-1   downto 0) & 
                   tx_2(eight_flit-1   downto 0) & 
                   tx_3(eight_flit-1   downto 0) & 
                   tx_4(eight_flit-1   downto 0) & 
                   tx_5(eight_flit-1   downto 0) & 
                   tx_6(quarter_flit-1   downto 0);
    mode_8_flit <= tx_0(15 downto 0) & --dc upper byte
                   tx_1(7  downto 0) & --qp
                   tx_2(7  downto 0) & --wo dc
                   tx_3(1  downto 0) & --LCbCr
                   tx_4(10 downto 0) & --y coord
                   tx_5(10 downto 0) & --x ccord
                   tx_6(7  downto 0);  --id
    mode_9_flit <= mode_0_flit;
    
    --select flit
    the_flit <= mode_0_flit when format_select = std_logic_vector(to_unsigned(0, 8)) else
                mode_1_flit when format_select = std_logic_vector(to_unsigned(1, 8)) else
                mode_2_flit when format_select = std_logic_vector(to_unsigned(2, 8)) else
                mode_3_flit when format_select = std_logic_vector(to_unsigned(3, 8)) else
                mode_4_flit when format_select = std_logic_vector(to_unsigned(4, 8)) else
                mode_5_flit when format_select = std_logic_vector(to_unsigned(5, 8)) else
                mode_6_flit when format_select = std_logic_vector(to_unsigned(6, 8)) else
                mode_7_flit when format_select = std_logic_vector(to_unsigned(7, 8)) else
                mode_8_flit when format_select = std_logic_vector(to_unsigned(8, 8)) else
                mode_9_flit when format_select = std_logic_vector(to_unsigned(9, 8)) else
                std_logic_vector(to_unsigned(0, data_width));
                
    ----------------------------------------------------------------------------
    --- SEND FSM ---------------------------------------------------------------
    ----------------------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            send_state <= idle;
        elsif rising_edge(clk) then
            send_state <= next_send_state;
        end if;
    end process;
    
    process(send_state, send_cmd_cpu, ready_to_send)
    begin
        --default
        next_send_state <= send_state;
        
        if send_state = idle and send_cmd_cpu = '1' then
            next_send_state <= send_requested;
        end if;
        
        if send_state = send_requested and ready_to_send = '1' then
            next_send_state <= tx;
        end if;
        
        if send_state = tx then
            next_send_state <= ack;
        end if;
        
        if send_state = ack and send_cmd_cpu = '0' then
            next_send_state <= idle;
        end if;
    end process;
    
    ----------------------------------------------------------------------------
    --- SEND SIDE OUTPUTS ------------------------------------------------------
    ----------------------------------------------------------------------------
    send_data      <= the_flit;
    dest_addr      <= addr_cpu; 
    set_tail_flit  <= set_tail_cpu when send_state = send_requested or send_state = tx else '0';
    send_flit      <= '1' when send_state = tx  else '0';
    send_ack       <= '1' when send_state = ack else '0';
    
    
    --==========================================================================
    --==========================================================================
    --==RECEIVING SIDE==========================================================
    --==========================================================================
    --==========================================================================
    
    ----------------------------------------------------------------------------
    -- DATAPATH ----------------------------------------------------------------
    ----------------------------------------------------------------------------
    process(clk, rst) begin
        if rst = '1' then 
            selected_vc_q <=(others => '0');
        elsif rising_edge(clk) then
            selected_vc_q <= selected_vc_d;
        end if;
    end process;
    
    u0: priority_encoder generic map(vc_sel_width)
                         port    map(data_in_buffer, selected_vc_encoder);

    selected_vc_d <= selected_vc_encoder when rx_state = rx_sel_vc else selected_vc_q;
    cpu_read_ctrl <= cpu_rx_ctrl;
    
    --Parser
    rx_0 <= std_logic_vector(resize(unsigned(recv_data(63 downto 32)), 32)) when parse_select = std_logic_vector(to_unsigned(0, 8)) else --mode 0: 32 bit unsigned
            std_logic_vector(resize(unsigned(recv_data(63 downto 48)), 32)) when parse_select = std_logic_vector(to_unsigned(1, 8)) else --mode 1: 16 bit unsigned
            std_logic_vector(resize(unsigned(recv_data(63 downto 56)), 32)) when parse_select = std_logic_vector(to_unsigned(2, 8)) else --mode 2: 8  bit unsigned
            std_logic_vector(resize(signed(  recv_data(63 downto 32)), 32)) when parse_select = std_logic_vector(to_unsigned(3, 8)) else --mode 3: 32 bit signed
            std_logic_vector(resize(signed(  recv_data(63 downto 48)), 32)) when parse_select = std_logic_vector(to_unsigned(4, 8)) else --mode 4: 16 bit signed
            std_logic_vector(resize(signed(  recv_data(63 downto 56)), 32)) when parse_select = std_logic_vector(to_unsigned(5, 8)) else --mode 5: 8  bit signed
            (others => '0');
    rx_1 <= std_logic_vector(resize(unsigned(recv_data(31 downto 0 )), 32)) when parse_select = std_logic_vector(to_unsigned(0, 8)) else --mode 0: 32 bit unsigned
            std_logic_vector(resize(unsigned(recv_data(47 downto 32)), 32)) when parse_select = std_logic_vector(to_unsigned(1, 8)) else --mode 1: 16 bit unsigned
            std_logic_vector(resize(unsigned(recv_data(55 downto 48)), 32)) when parse_select = std_logic_vector(to_unsigned(2, 8)) else --mode 2: 8  bit unsigned
            std_logic_vector(resize(signed(  recv_data(31 downto 0 )), 32)) when parse_select = std_logic_vector(to_unsigned(3, 8)) else --mode 3: 32 bit signed
            std_logic_vector(resize(signed(  recv_data(47 downto 32)), 32)) when parse_select = std_logic_vector(to_unsigned(4, 8)) else --mode 4: 16 bit signed
            std_logic_vector(resize(signed(  recv_data(55 downto 48)), 32)) when parse_select = std_logic_vector(to_unsigned(5, 8)) else --mode 5: 8  bit signed
            (others => '0');
    rx_2 <= std_logic_vector(resize(unsigned(recv_data(31 downto 16)), 32)) when parse_select = std_logic_vector(to_unsigned(1, 8)) else --mode 1: 16 bit unsigned
            std_logic_vector(resize(unsigned(recv_data(47 downto 40)), 32)) when parse_select = std_logic_vector(to_unsigned(2, 8)) else --mode 2: 8  bit unsigned
            std_logic_vector(resize(signed(  recv_data(31 downto 16)), 32)) when parse_select = std_logic_vector(to_unsigned(4, 8)) else --mode 4: 16 bit signed
            std_logic_vector(resize(signed(  recv_data(47 downto 40)), 32)) when parse_select = std_logic_vector(to_unsigned(5, 8)) else --mode 5: 8  bit signed
            std_logic_vector(timer_q); --this input reused for timer
    rx_3 <= std_logic_vector(resize(unsigned(recv_data(15 downto 0 )), 32)) when parse_select = std_logic_vector(to_unsigned(1, 8)) else --mode 1: 16 bit unsigned
            std_logic_vector(resize(unsigned(recv_data(39 downto 32)), 32)) when parse_select = std_logic_vector(to_unsigned(2, 8)) else --mode 2: 8  bit unsigned
            std_logic_vector(resize(signed(  recv_data(15 downto 0 )), 32)) when parse_select = std_logic_vector(to_unsigned(4, 8)) else --mode 4: 16 bit signed
            std_logic_vector(resize(signed(  recv_data(39 downto 32)), 32)) when parse_select = std_logic_vector(to_unsigned(5, 8)) else --mode 5: 8  bit signed
            (others => '0');
    rx_4 <= std_logic_vector(resize(unsigned(recv_data(31 downto 24)), 32)) when parse_select = std_logic_vector(to_unsigned(2, 8)) else --mode 2: 8  bit unsigned
            std_logic_vector(resize(signed(  recv_data(31 downto 24)), 32)) when parse_select = std_logic_vector(to_unsigned(5, 8)) else --mode 5: 8  bit signed
            (others => '0');
    rx_5 <= std_logic_vector(resize(unsigned(recv_data(23 downto 16)), 32)) when parse_select = std_logic_vector(to_unsigned(2, 8)) else --mode 2: 8  bit unsigned
            std_logic_vector(resize(signed(  recv_data(23 downto 16)), 32)) when parse_select = std_logic_vector(to_unsigned(5, 8)) else --mode 5: 8  bit signed
            (others => '0');
    rx_6 <= std_logic_vector(resize(unsigned(recv_data(15 downto 8 )), 32)) when parse_select = std_logic_vector(to_unsigned(2, 8)) else --mode 2: 8  bit unsigned
            std_logic_vector(resize(signed(  recv_data(15 downto 8 )), 32)) when parse_select = std_logic_vector(to_unsigned(5, 8)) else --mode 5: 8  bit signed
            (others => '0');
    rx_7 <= std_logic_vector(resize(unsigned(recv_data(7  downto 0 )), 32)) when parse_select = std_logic_vector(to_unsigned(2, 8)) else --mode 2: 8  bit unsigned
            std_logic_vector(resize(signed(  recv_data(7  downto 0 )), 32)) when parse_select = std_logic_vector(to_unsigned(5, 8)) else --mode 5: 8  bit signed
            (others => '0');
    
    --NoC Controls
    dequeue <= "01" when selected_vc_q = "0" and rx_state = rx_dequeue else
               "10" when selected_vc_q = "1" and rx_state = rx_dequeue else
               "00";
               
    selected_vc_one_hot <= "01" when selected_vc_q = "0" else
                           "10";
               
    select_vc_read <= selected_vc_q;      
    rx_state_out <= std_logic_vector(to_unsigned(0,  8)) when rx_state = rx_idle       else
                    std_logic_vector(to_unsigned(1,  8)) when rx_state = rx_sel_vc     else
                    std_logic_vector(to_unsigned(2,  8)) when rx_state = rx_addr_rst   else
                    std_logic_vector(to_unsigned(3,  8)) when rx_state = rx_start_read else
                    std_logic_vector(to_unsigned(4,  8)) when rx_state = rx_rxd        else
                    std_logic_vector(to_unsigned(5,  8)) when rx_state = rx_wait_cpu   else
                    std_logic_vector(to_unsigned(6,  8)) when rx_state = rx_dequeue    else
                    std_logic_vector(to_unsigned(7,  8)) when rx_state = rx_wait_flits else
                    std_logic_vector(to_unsigned(15, 8));

    ----------------------------------------------------------------------------
    --- RX FSM -----------------------------------------------------------------
    ----------------------------------------------------------------------------
    process(clk, rst) begin
        if rst = '1' then
            rx_state <= rx_idle;
        elsif rising_edge(clk) then
            rx_state <= next_rx_state;
        end if;
    end process;
    
    process(rx_state, data_in_buffer, selected_vc_q, cpu_read_ctrl) begin
        next_rx_state <= rx_state;
        
        if rx_state = rx_idle and or_reduce(data_in_buffer) = '1' then
            next_rx_state <= rx_sel_vc;
        end if;
        
        if rx_state = rx_sel_vc then
            next_rx_state <= rx_addr_rst;
        end if;
        
        if rx_state = rx_addr_rst and cpu_read_ctrl = '1' then
            next_rx_state <= rx_start_read;
        end if;
        
        if rx_state = rx_start_read and cpu_read_ctrl = '0' then
            next_rx_state <= rx_rxd;
        end if;
        
        if rx_state = rx_rxd and cpu_read_ctrl = '1' then
            next_rx_state <= rx_wait_cpu;
        end if;
        
        if rx_state = rx_wait_cpu and cpu_read_ctrl = '0' then
            next_rx_state <= rx_dequeue;
        end if;
        
        if rx_state = rx_dequeue and is_tail_flit = '1' then
            next_rx_state <= rx_idle;
        end if;
        
        if rx_state = rx_dequeue and is_tail_flit = '0' then
            next_rx_state <= rx_wait_flits;
        end if;
        
        if rx_state = rx_wait_flits and or_reduce(data_in_buffer and selected_vc_one_hot) = '1' then
            next_rx_state <= rx_rxd;
        end if;
        
    end process;
     
    --==========================================================================
    --==========================================================================
    --==TIMER===================================================================
    --==========================================================================
    --==========================================================================
    process(clk, rst) begin
         if rst = '1' then
             timer_q <= (others => '0');
         elsif rising_edge(clk) then
             timer_q <= timer_d;
        end if;
     end process;
     
     timer_d <= timer_q + to_unsigned(1, 32);
     
     
     
    
end architecture fsmd;  
    



        
