library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;


entity deblocking_filter_node is
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
     
    --debugging
    has_rxd        : out std_logic;
    is_idle        : out std_logic;
    is_filtering   : out std_logic;
    is_tx_ing      : out std_logic;
    is_cleanup_ing : out std_logic;
    rx_non_zero    : out std_logic;
    tx_non_zero    : out std_logic
);
end entity deblocking_filter_node;

architecture fsmd of deblocking_filter_node is

    component h264_deblock_filter_core is
        port(
            clk               : in  std_logic;
            rst               : in  std_logic;
            is_chroma         : in  std_logic;
            boundary_strength : in  signed(8 downto 0);
            p0                : in  signed(8 downto 0);
            p1                : in  signed(8 downto 0);
            p2                : in  signed(8 downto 0);
            p3                : in  signed(8 downto 0);
            q0                : in  signed(8 downto 0);
            q1                : in  signed(8 downto 0);
            q2                : in  signed(8 downto 0);
            q3                : in  signed(8 downto 0);
            alpha             : in  signed(8 downto 0);
            beta              : in  signed(8 downto 0);
            tc0               : in  signed(8 downto 0);
            p0_out            : out signed(8 downto 0);
            p1_out            : out signed(8 downto 0);
            p2_out            : out signed(8 downto 0);
            q0_out            : out signed(8 downto 0);
            q1_out            : out signed(8 downto 0);
            q2_out            : out signed(8 downto 0)
        );
    end component h264_deblock_filter_core;
     
    component priority_encoder is
    generic(
        encoded_word_size : integer := 2
    );
    Port(
        input    : in  std_logic_vector(2**encoded_word_size-1 downto 0);
        output   : out std_logic_vector(encoded_word_size-1 downto 0)
         
    );
    end component priority_encoder;
    
    --signals
    signal is_chroma         : std_logic;
    signal boundary_strength : std_logic_vector(8 downto 0);
    signal p0                : std_logic_vector(8 downto 0);
    signal p1                : std_logic_vector(8 downto 0);
    signal p2                : std_logic_vector(8 downto 0);
    signal p3                : std_logic_vector(8 downto 0);
    signal q0                : std_logic_vector(8 downto 0);
    signal q1                : std_logic_vector(8 downto 0);
    signal q2                : std_logic_vector(8 downto 0);
    signal q3                : std_logic_vector(8 downto 0);
    signal alpha             : std_logic_vector(8 downto 0);
    signal beta              : std_logic_vector(8 downto 0);
    signal tc0               : std_logic_vector(8 downto 0);
    signal bS                : std_logic_vector(8 downto 0);
    signal p0_out            : signed(8 downto 0);
    signal p1_out            : signed(8 downto 0);
    signal p2_out            : signed(8 downto 0);
    signal q0_out            : signed(8 downto 0);
    signal q1_out            : signed(8 downto 0);
    signal q2_out            : signed(8 downto 0);

    
    signal p0_out_vector     : std_logic_vector(8 downto 0);
    signal p1_out_vector     : std_logic_vector(8 downto 0);
    signal p2_out_vector     : std_logic_vector(8 downto 0);
    signal q0_out_vector     : std_logic_vector(8 downto 0);
    signal q1_out_vector     : std_logic_vector(8 downto 0);
    signal q2_out_vector     : std_logic_vector(8 downto 0);
    signal identifier        : std_logic_vector(7 downto 0);
    
    signal selected_vc_enc     : std_logic_vector(vc_sel_width-1 downto 0);
    signal selected_vc_q       : std_logic_vector(vc_sel_width-1 downto 0);
    signal selected_vc_d       : std_logic_vector(vc_sel_width-1 downto 0);
    signal selected_vc_one_hot : std_logic_vector(num_vc-1 downto 0);
    
    signal has_rxd_q, has_rxd_d : std_logic;
    
    signal recv_packet_q        : std_logic_vector(127 downto 0);
    signal recv_packet_d        : std_logic_vector(127 downto 0);
     
    signal send_data_0          : std_logic_vector(63 downto 0);
    signal send_data_1          : std_logic_vector(63 downto 0);
     
    --constants
    constant p_index      : integer := 96;
    constant q_index      : integer := 64;
    constant param_index      : integer := 32;
    constant sys_param_index      : integer := 0;
    
    --states
    type db_filter_states is (idle, select_vc, rx_0, rx_1, wait_rx_0, tx_0, tx_1, dequeue_0, dequeue_1, wait_tx_0, wait_tx_1);
    signal next_state, current_state : db_filter_states;
    

begin
    ---------------------------------------------------------------------------
    -- DATAPATH
    ---------------------------------------------------------------------------
    process(clk, rst)
     begin
        if rst = '1' then
            recv_packet_q <= (others => '0');
            selected_vc_q <= (others => '0');
        elsif rising_edge(clk) then
            recv_packet_q <= recv_packet_d;
            selected_vc_q <= selected_vc_d;
        end if;
     end process;
     
     recv_packet_d(63 downto 0)   <= recv_data       when current_state = rx_0 else recv_packet_q(63 downto 0);
     recv_packet_d(127 downto 64) <= recv_data       when current_state = rx_1 else recv_packet_q(127 downto 64);
     selected_vc_d                <= selected_vc_enc when current_state = select_vc else selected_vc_q;
     
     selected_vc_one_hot <= "01" when selected_vc_q = "0" else "10";
     --parse input   
    p3( 7 downto 0 )     <=      (recv_packet_q( p_index         + 31  downto p_index         + 24));
    p2( 7 downto 0 )     <=      (recv_packet_q( p_index         + 23  downto p_index         + 16));
    p1( 7 downto 0 )     <=      (recv_packet_q( p_index         + 15  downto p_index         +  8));
    p0( 7 downto 0 )     <=      (recv_packet_q( p_index         + 7   downto p_index         +  0));   
    q3( 7 downto 0 )     <=      (recv_packet_q( q_index         + 31  downto q_index         + 24));
    q2( 7 downto 0 )     <=      (recv_packet_q( q_index         + 23  downto q_index         + 16));
    q1( 7 downto 0 )     <=      (recv_packet_q( q_index         + 15  downto q_index         +  8));
    q0( 7 downto 0 )     <=      (recv_packet_q( q_index         + 7   downto q_index         +  0));
    alpha( 7 downto 0 )  <=      (recv_packet_q( param_index     + 31  downto param_index     + 24));
    beta( 7 downto 0 )   <=      (recv_packet_q( param_index     + 23  downto param_index     + 16));
    bS( 7 downto 0 )     <=      (recv_packet_q( param_index     + 15  downto param_index     + 8 ));
    tc0( 7 downto 0 )    <=      (recv_packet_q( param_index     + 7   downto param_index     + 0 )); 
    p3( 8 )              <= '0';  
    p2( 8 )              <= '0';  
    p1( 8 )              <= '0';  
    p0( 8 )              <= '0';  
    q3( 8 )              <= '0';  
    q2( 8 )              <= '0';  
    q1( 8 )              <= '0';   
    q0( 8 )              <= '0';       
    alpha( 8 )           <= '0';
    beta( 8 )            <= '0'; 
    bS( 8 )              <= '0'; 
    tc0( 8 )             <= '0';           
     
     
    is_chroma  <=        recv_packet_q( sys_param_index + 16                             );          
    identifier <=        recv_packet_q( sys_param_index + 15  downto sys_param_index + 8 ); 


    --form response
    p0_out_vector <= std_logic_vector(p0_out);
    p1_out_vector <= std_logic_vector(p1_out);
    p2_out_vector <= std_logic_vector(p2_out);
    q0_out_vector <= std_logic_vector(q0_out);
    q1_out_vector <= std_logic_vector(q1_out);
    q2_out_vector <= std_logic_vector(q2_out);
    
    send_data_1                      <= p3(7 downto 0) &
                                        p2_out_vector(7 downto 0) & 
                                        p1_out_vector(7 downto 0) & 
                                        p0_out_vector(7 downto 0) &
                                        q3(7 downto 0) &
                                        q2_out_vector(7 downto 0) & 
                                        q1_out_vector(7 downto 0) & 
                                        q0_out_vector(7 downto 0);
                                                     
    send_data_0                      <= X"00000000"               &
                                                     x"000000"                 &
                                        identifier;
    
    send_data <= send_data_0 when current_state = wait_tx_0 or current_state = dequeue_1 or current_state = tx_0 else
                 send_data_1;
     
    --network controls
    dest_addr <= std_logic_vector(to_unsigned(7, addr_width));
    select_vc_read <= selected_vc_q;
    set_tail_flit  <= '1' when current_state = wait_tx_1 or current_state = tx_1 else '0';
    send_flit      <= '1' when current_state = tx_0 or current_state = tx_1 else '0';
    dequeue        <= selected_vc_one_hot when current_state = dequeue_0 or current_state = dequeue_1 else "00";
    
    -- filter core
    u0: component h264_deblock_filter_core port map(
            clk               => '0',     
            rst               => '0',
            is_chroma         => is_chroma,
            boundary_strength => signed( bs    ),
            p0                => signed( p0    ),
            p1                => signed( p1    ),
            p2                => signed( p2    ),
            p3                => signed( p3    ),
            q0                => signed( q0    ),
            q1                => signed( q1    ),
            q2                => signed( q2    ),
            q3                => signed( q3    ),
            alpha             => signed( alpha ),
            beta              => signed( beta  ),
            tc0               => signed( tc0   ),
            p0_out            => p0_out,
            p1_out            => p1_out,
            p2_out            => p2_out,
            q0_out            => q0_out,
            q1_out            => q1_out,
            q2_out            => q2_out
        );      
          
    -- select which bufer to read from
    u1: priority_encoder generic map(vc_sel_width)
                         port    map(data_in_buffer, selected_vc_enc);
                                
    

    ---------------------------------------------------------------------------
    -- STATE MACHINE
    ---------------------------------------------------------------------------
    --state register
     process(clk, rst) begin
        if rst = '1' then
            current_state <= idle;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
     end process;
    --update logic
    process(current_state, data_in_buffer, ready_to_send) begin
    
        --default
        next_state <= current_state;
        
        if current_state = idle and or_reduce(data_in_buffer) = '1' then 
            next_state <= select_vc;
        end if;
        
        if current_state = select_vc then
            next_state <= rx_0;
        end if;
        
        if current_state = rx_0 then
            next_state <= dequeue_0;
        end if;
          
        if current_state = dequeue_0 then
            next_state <= wait_rx_0;
        end if; 
        
          if current_state = wait_rx_0 and or_reduce(data_in_buffer and selected_vc_one_hot) = '1' then
            next_state <= rx_1;
        end if; 
          
        if current_state = rx_1 then
            next_state <= dequeue_1;
        end if;
        
        if current_state = dequeue_1 then
            next_state <= wait_tx_0;
        end if; 
            
          if current_state = wait_tx_0 and ready_to_send = '1' then
            next_state <= tx_0;
        end if;
          
          if current_state = tx_0 then
            next_state <= wait_tx_1;
        end if; 
          
          if current_state = wait_tx_1 and ready_to_send = '1' then
            next_state <= tx_1;
        end if;
          
          if current_state = tx_1 then
            next_state <= idle;
        end if;
        
    end process;
end architecture fsmd;  
    



        
