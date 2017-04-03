library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

entity noc_controller is
generic(
    data_width      : integer := 128;
    addr_width      : integer := 2;
    vc_sel_width    : integer := 1;
    num_vc          : integer := 2;
    flit_buff_depth : integer := 8
);
port(
    clk         : in std_logic;
    rst         : in std_logic;

    -- interface with hps
    data_in     : in  std_logic_vector(data_width-1 downto 0);
    data_out    : out std_logic_vector(data_width-1 downto 0);
    noc_ctrl    : in  std_logic_vector(31 downto 0);
    noc_sts     : out std_logic_vector(31 downto 0);
    
    --network sending interface
    send_data      : out std_logic_vector(data_width-1 downto 0);
    dest_addr      : out std_logic_vector(addr_width-1 downto 0);
    set_tail_flit  : out std_logic;
    send_flit      : out std_logic;
    ready_to_send  : in  std_logic;
    
    --network receiving interface
    recv_data      : in  std_logic_vector(data_width-1 downto 0);
    src_addr       : in  std_logic_vector(addr_width-1 downto 0);
    is_tail_flit   : in  std_logic;
    data_in_buffer : in  std_logic_vector(num_vc-1 downto 0);
    dequeue        : out std_logic_vector(num_vc-1 downto 0);
    select_vc_read : out std_logic_vector(vc_sel_width-1 downto 0);
     
     --debugging
     has_rxd        : out std_logic;
	  tx_non_zero    : out std_logic
	  
);
end entity noc_controller;

architecture fsmd of noc_controller is
    constant identifier_msb : integer := 7;
    constant identifier_lsb : integer := 0;
	 constant num_data_regs  : integer := 1;

    component priority_encoder is
    generic(
        encoded_word_size : integer := 3
    );
    Port(
        input    : in  std_logic_vector(2**encoded_word_size-1 downto 0);
        output   : out std_logic_vector(encoded_word_size-1 downto 0)
    );
    end component priority_encoder;

    type regs is array(num_data_regs-1 downto 0) of std_logic_vector(data_width-1 downto 0);
    signal data_register_d, data_register_q    : regs;
    signal data_in_buffer_q, data_in_buffer_delay : std_logic_vector(num_vc-1 downto 0);
    signal write_enable     : std_logic;
    signal selected_vc_q, selected_vc_d, selected_vc_encoder      : std_logic_vector(vc_sel_width-1 downto 0);
    
    signal identifier : std_logic_vector(7 downto 0);
    signal id_select  : std_logic_vector(7 downto 0);
    
    
    signal has_rxd_d, has_rxd_q : std_logic; 
    
    signal send_flit_once_edge, send_flit_once_d, send_flit_once_q, send_flit_once_q2 : std_logic;
    
    type send_states is (idle, send, waiting);
    signal send_state, next_send_state : send_states;
    
    type rx_states is (rx_idle, rx_addr_rst, rx_start_read, rx_sel_vc, rx_rxd, rx_wait_cpu, rx_dequeue, rx_wait_flits);
    signal rx_state, next_rx_state : rx_states;
    signal selected_vc_one_hot : std_logic_vector(1 downto 0);
    signal state               : std_logic_vector(3 downto 0);
    signal cpu_read_ctrl       : std_logic;
     
begin
    
    ---------------------------------------------------------------------------
    -- Sending Controls -------------------------------------------------------
    ---------------------------------------------------------------------------
    
    -- output logic
    send_data     <= data_in;
    dest_addr     <= noc_ctrl(addr_width-1 downto 0);
    set_tail_flit <= noc_ctrl(8);
    send_flit     <= '1' when send_state = send else '0';
    
     
    -- state register
    process(clk, rst) begin
        if rst = '1' then
            send_state <= idle;
        elsif rising_edge(clk) then
            send_state <= next_send_state;
        end if;
    end process;
    
    -- state transition logic
    process(send_state, noc_ctrl(9)) begin
        next_send_state <= send_state;
        if send_state = idle and noc_ctrl(9) = '1' then
            next_send_state <= send;
        end if;
        if send_state = send then
            next_send_state <= waiting;
        end if;
        if send_state = waiting and noc_ctrl(9) = '0' then
            next_send_state <= idle;
        end if;
    end process;
        
     
    ---------------------------------------------------------------------------
    -- receive inteface controls ----------------------------------------------
    ---------------------------------------------------------------------------
    --rx_idle, rx_sel_vc, rx_rxd, rx_wait_cpu, rx_dequeue, rx_wait_flits, rx_addr_rst, rx_start_read
    --- output logic ---
    dequeue <= "01" when selected_vc_q = "0" and rx_state = rx_dequeue else
               "10" when selected_vc_q = "1" and rx_state = rx_dequeue else
               "00";
               
    selected_vc_one_hot <= "01" when selected_vc_q = "0" else
                           "10";
               
    select_vc_read <= selected_vc_q;      
    state <= std_logic_vector(to_unsigned(0,  4)) when rx_state = rx_idle       else
             std_logic_vector(to_unsigned(1,  4)) when rx_state = rx_sel_vc     else
             std_logic_vector(to_unsigned(2,  4)) when rx_state = rx_addr_rst   else
             std_logic_vector(to_unsigned(3,  4)) when rx_state = rx_start_read else
             std_logic_vector(to_unsigned(4,  4)) when rx_state = rx_rxd        else
             std_logic_vector(to_unsigned(5,  4)) when rx_state = rx_wait_cpu   else
             std_logic_vector(to_unsigned(6,  4)) when rx_state = rx_dequeue    else
             std_logic_vector(to_unsigned(7,  4)) when rx_state = rx_wait_flits else
             std_logic_vector(to_unsigned(15, 4));
    
    --- data path ---
    -- data path registers
    process(clk, rst) begin
        if rst = '1' then 
            selected_vc_q <=(others => '0');
        elsif rising_edge(clk) then
            selected_vc_q <= selected_vc_d;
        end if;
    end process;
    
    --data path components
    u0: priority_encoder generic map(vc_sel_width)
                         port    map(data_in_buffer, selected_vc_encoder);
    
    -- data path logic
    selected_vc_d <= selected_vc_encoder when rx_state = rx_sel_vc else selected_vc_q;
    cpu_read_ctrl <= noc_ctrl(14);
    
    --- FSM ---
    -- state register
    process(clk, rst) begin
        if rst = '1' then
            rx_state <= rx_idle;
        elsif rising_edge(clk) then
            rx_state <= next_rx_state;
        end if;
    end process;
    
    --- state transition logic
    --rx_idle, rx_sel_vc, rx_rxd, rx_wait_cpu, rx_dequeue, rx_wait_flits
    process(rx_state, data_in_buffer, selected_vc_q) begin
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
    
    ---------------------------------------------------------------------------
    -- User Rx Interface -----------------------------------------------------
    ---------------------------------------------------------------------------
    id_select      <= noc_ctrl(31 downto 24);
    --data_out <= data_register_q(to_integer(unsigned(id_select)));
    data_out <= recv_data;
    
    
    noc_sts(24 + addr_width - 1 downto 24) <= src_addr;
    noc_sts(23 downto 20)                  <= state;
    noc_sts(0)                             <= not ready_to_send;
    noc_sts(17 downto 1) <= noc_ctrl(16 downto 0);
	 noc_sts(19 downto 18) <= "00" when send_state = idle else
	                          "01" when send_state = send else
									  "10" when send_state = waiting else
									  "11";

    ---------------------------------------------------------------------------
    -- debug ------------------------------------------------------------------
    ---------------------------------------------------------------------------
    has_rxd   <= or_reduce(data_in_buffer); --has_rxd_q;
    tx_non_zero <= or_reduce(recv_data);
    
    
    
end architecture fsmd;
    