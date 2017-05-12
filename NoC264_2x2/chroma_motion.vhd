library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;


entity chroma_motion is
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
    
    --debug
    --state_out      : out std_logic_vector(7 downto 0)
    
);
end entity chroma_motion;

architecture fsmd of chroma_motion is
    
    --- Components ------------------------------------------------------------
    component priority_encoder is
    generic(
        encoded_word_size : integer := 3
    );
    Port(
        input    : in  std_logic_vector(2**encoded_word_size-1 downto 0);
        output   : out std_logic_vector(encoded_word_size-1 downto 0)
    );
    end component priority_encoder;
    
    --- Types -----------------------------------------------------------------
    type chroma_motion_states is (idle, 
                                  sel_vc, 
                                  rx_header, 
                                  dequeue_header,
                                  wait_rx_cr, 
                                  rx_cr, 
                                  dequeue_cr,
                                  wait_rx_cb, 
                                  rx_cb, 
                                  dequeue_cb,
                                  wait_rx_crcb,
                                  rx_crcb,
                                  dequeue_crcb,
                                  wait_tx_header,
                                  tx_header,
                                  wait_tx_data,
                                  tx_data);
    
    type reference_array is array (8 downto 0) of integer;
    type result_array    is array (3 downto 0) of integer;
    
    --- signals and registers -------------------------------------------------
    signal cr_ref_d       : reference_array;
    signal cb_ref_d       : reference_array;
    signal cr_ref_q       : reference_array;
    signal cb_ref_q       : reference_array;
    signal cr_result      : result_array;
    signal cb_result      : result_array;
    signal cr_x_frac_d    : integer;
    signal cr_y_frac_d    : integer;
    signal cr_x_frac_q    : integer;
    signal cr_y_frac_q    : integer;
    signal cb_x_frac_d    : integer;
    signal cb_y_frac_d    : integer;
    signal cb_x_frac_q    : integer;
    signal cb_y_frac_q    : integer;
    signal ref_d          : std_logic_vector(7 downto 0);
    signal ref_q          : std_logic_vector(7 downto 0);
    signal result_vect    : std_logic_vector(63 downto 0);
    signal resp_header    : std_logic_vector(63 downto 0);
    signal state          : chroma_motion_states;
    signal next_state     : chroma_motion_states;
    signal sel_vc_d       : std_logic_vector(vc_sel_width-1 downto 0);
    signal sel_vc_q       : std_logic_vector(vc_sel_width-1 downto 0);
    signal sel_vc_enc     : std_logic_vector(vc_sel_width-1 downto 0);
    signal sel_vc_one_hot : std_logic_vector(num_vc-1       downto 0);
    
begin

    ---------------------------------------------------------------------------
    --- DATAPATH --------------------------------------------------------------
    ---------------------------------------------------------------------------
    --components
    u2: component priority_encoder
    generic map(
        encoded_word_size => vc_sel_width
    )
    Port map(
        input    => data_in_buffer,
        output   => sel_vc_enc
    );
    
    --registers
    regs: process(clk, rst) begin
        if rst = '1' then
            cr_ref_q    <= (others => 0);
            cb_ref_q    <= (others => 0);
            cr_x_frac_q <= 0;
            cr_y_frac_q <= 0;
            cb_x_frac_q <= 0;
            cb_y_frac_q <= 0;
            ref_q       <= (others => '0');
            sel_vc_q    <= (others => '0');
            state       <= idle;
        elsif rising_edge(clk) then
            cr_ref_q    <=    cr_ref_d;   
            cb_ref_q    <=    cb_ref_d;   
            cr_x_frac_q <= cr_x_frac_d;
            cr_y_frac_q <= cr_y_frac_d;
            cb_x_frac_q <= cb_x_frac_d;
            cb_y_frac_q <= cb_y_frac_d;
            ref_q       <=       ref_d;  
            sel_vc_q    <=    sel_vc_d;
            state       <=  next_state;
        end if;
    end process;
    
    --register update
    reg_update: for i in 7 downto 0 generate
        constant recv_data_low_index  : integer := i * 8;
        constant recv_data_high_index : integer := recv_data_low_index + 7;
    begin
        cr_ref_d(i) <= to_integer(unsigned(recv_data(recv_data_high_index downto   
                                           recv_data_low_index))) when state = rx_cr 
                       else cr_ref_q(i);
        cb_ref_d(i) <= to_integer(unsigned(recv_data(recv_data_high_index downto   
                                           recv_data_low_index))) when state = rx_cb 
                       else cb_ref_q(i);
    end generate;
    cr_ref_d(8) <= to_integer(unsigned(recv_data(39 downto 32))) when state = rx_crcb else cr_ref_q(8);
    cb_ref_d(8) <= to_integer(unsigned(recv_data(7  downto 0 ))) when state = rx_crcb else cb_ref_q(8);
    cr_x_frac_d <= to_integer(unsigned(recv_data(39 downto 32))) when state = rx_header else cr_x_frac_q;
    cr_y_frac_d <= to_integer(unsigned(recv_data(31 downto 24))) when state = rx_header else cr_y_frac_q;
    cb_x_frac_d <= to_integer(unsigned(recv_data(23 downto 16))) when state = rx_header else cb_x_frac_q;
    cb_y_frac_d <= to_integer(unsigned(recv_data(15 downto 8 ))) when state = rx_header else cb_y_frac_q;   
    ref_d       <= recv_data(7 downto 0)                         when state = rx_header else ref_q;                                                              
    sel_vc_d    <= sel_vc_enc                                    when state = sel_vc    else sel_vc_q;
    
    --the algorithm
    chroma_motion_x: for x in 1 downto 0 generate
        chroma_motion_y: for y in 1 downto 0 generate
            constant ref_0_0_index      : integer := x     + y*3;
            constant ref_0_1_index      : integer := x     + (y+1)*3;
            constant ref_1_0_index      : integer := (x+1) + y*3;
            constant ref_1_1_index      : integer := (x+1) + (y+1) * 3;
            constant cr_cb_result_index : integer := x     + y*2;
            
        begin
            cr_result(cr_cb_result_index) <= 
                ((8-cr_x_frac_q)*(8-cr_y_frac_q)*cr_ref_q(ref_0_0_index) + 
                 cr_x_frac_q*(8-cr_y_frac_q)*cr_ref_q(ref_1_0_index)     +
                 (8-cr_x_frac_q)*cr_y_frac_q*cr_ref_q(ref_0_1_index)     +
                 cr_x_frac_q*cr_y_frac_q*cr_ref_q(ref_1_1_index)         +
                 32
                )/64;
                
            cb_result(cr_cb_result_index) <= 
                ((8-cb_x_frac_q)*(8-cb_y_frac_q)*cb_ref_q(ref_0_0_index) + 
                 cb_x_frac_q*(8-cb_y_frac_q)*cb_ref_q(ref_1_0_index)     +
                 (8-cb_x_frac_q)*cb_y_frac_q*cb_ref_q(ref_0_1_index)     +
                 cb_x_frac_q*cb_y_frac_q*cb_ref_q(ref_1_1_index)         +
                 32
                )/64;
        end generate;
    end generate; 

    --output formatting
    result_vect <= std_logic_vector(to_unsigned(cr_result(0), 8)) &
                   std_logic_vector(to_unsigned(cr_result(1), 8)) &
                   std_logic_vector(to_unsigned(cr_result(2), 8)) &
                   std_logic_vector(to_unsigned(cr_result(3), 8)) &
                   std_logic_vector(to_unsigned(cb_result(0), 8)) &
                   std_logic_vector(to_unsigned(cb_result(1), 8)) &
                   std_logic_vector(to_unsigned(cb_result(2), 8)) &
                   std_logic_vector(to_unsigned(cb_result(3), 8));
    resp_header <= x"00000000000000" & ref_q;
    
    --packet generation
    send_data      <= resp_header when state = wait_tx_header or state = tx_header else result_vect;
    dest_addr      <= std_logic_vector(to_unsigned(7, addr_width));
    set_tail_flit  <= '1' when state = wait_tx_data or state = tx_data else '0';
    send_flit      <= '1' when state = tx_header or state = tx_data else '0';
    
    --rx controls
    dequeue        <= sel_vc_one_hot when state = dequeue_cb or state = dequeue_cr or state = dequeue_crcb or state = dequeue_header else "00";
    select_vc_read <= sel_vc_q;
    sel_vc_one_hot <= "01" when sel_vc_q = "0" else "10";
    
    ---------------------------------------------------------------------------
    --- STATE MACHINE ---------------------------------------------------------
    ---------------------------------------------------------------------------
    
    process(state, data_in_buffer, is_tail_flit, sel_vc_one_hot, ready_to_send)
    begin
        
        next_state <= state;
        
        if state = idle and or_reduce(data_in_buffer) = '1' then
            next_state <= sel_vc;
        end if;
        
        if state = sel_vc then
            next_state <= rx_header;
        end if;
        
        if state = rx_header then
            next_state <= dequeue_header;
        end if;
        
        if state = dequeue_header then
            next_state <= wait_rx_cr;
        end if;
        
        if state = wait_rx_cr and or_reduce(sel_vc_one_hot and data_in_buffer) = '1' then
            next_state <= rx_cr;
        end if;
        
        if state = rx_cr then
            next_state <= dequeue_cr;
        end if;
        
        if state = dequeue_cr then
            next_state <= wait_rx_cb;
        end if;
        
        if state = wait_rx_cb and or_reduce(sel_vc_one_hot and data_in_buffer) = '1' then
            next_state <= rx_cb;
        end if;
        
        if state = rx_cb then
            next_state <= dequeue_cb;
        end if;
        
        if state = dequeue_cb then
            next_state <= wait_rx_crcb;
        end if;
        
        if state = wait_rx_crcb and or_reduce(sel_vc_one_hot and data_in_buffer) = '1' then
            next_state <= rx_crcb;
        end if;
        
        if state = rx_crcb then
            next_state <= dequeue_crcb;
        end if;
        
        if state = dequeue_crcb then
            next_state <= wait_tx_header;
        end if;
        
        if state = wait_tx_header and ready_to_send = '1' then
            next_state <= tx_header;
        end if;
        
        if state = tx_header then
            next_state <= wait_tx_data;
        end if;

        if state = wait_tx_data and ready_to_send = '1' then
            next_state <= tx_data;
        end if;
        
        if state = tx_data then
            next_state <= idle;
        end if;

    end process;
    
    --state_out <= x"00" when state = idle           else 
    --             x"01" when state = sel_vc         else 
    --             x"02" when state = rx_header      else 
    --             x"03" when state = dequeue_header else
    --             x"04" when state = wait_rx_cr     else 
    --             x"05" when state = rx_cr          else 
    --             x"06" when state = dequeue_cr     else
    --             x"07" when state = wait_rx_cb     else 
    --             x"08" when state = rx_cb          else 
    --             x"09" when state = dequeue_cb     else
    --             x"0A" when state = wait_rx_crcb   else
    --             x"0B" when state = rx_crcb        else
    --             x"0C" when state = dequeue_crcb   else
    --             x"0D" when state = wait_tx_header else
    --             x"0E" when state = tx_header      else
    --             x"0F" when state = wait_tx_data   else
    --             x"10" when state = tx_data        else
    --             x"FF";      
    
end architecture;
