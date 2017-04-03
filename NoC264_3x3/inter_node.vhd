library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;

entity inter_node is
generic(
    size_x          : integer := 9; 
    size_y          : integer := 9; 
    interp_x        : integer := 4; 
    interp_y        : integer := 4; 
    sample_size     : integer := 8; 
    samples_per_wr  : integer := 8; 
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
end entity inter_node;

architecture fsmd of inter_node is
    ---------------------------------------------------------------------------
    -- Constants --------------------------------------------------------------
    ---------------------------------------------------------------------------
    
    ---------------------------------------------------------------------------
    -- Components -------------------------------------------------------------
    ---------------------------------------------------------------------------
    component inter_core is 
    generic(
        x_len       : integer := 4;
        y_len       : integer := 4;
        sample_size : integer := 8
    );
    port(
        samples : in  std_logic_vector((x_len+5)*(y_len+5)*sample_size-1 downto 0);
        sel     : in  std_logic_vector(7 downto 0);
        result  : out std_logic_vector(x_len*y_len*sample_size-1 downto 0)
    );
    end component inter_core;
    
    component inter_core_reg_file is
    generic(
        size_x         : integer := 20;
        size_y         : integer := 20;
        interp_x       : integer := 1;
        interp_y       : integer := 1;
        sample_size    : integer := 4;
        samples_per_wr : integer := 1
        
    );
    port(
        clk            : in  std_logic;
        rst            : in  std_logic;
        
        --read interface
        rd_addr_x      : in  std_logic_vector(7 downto 0);
        rd_addr_y      : in  std_logic_vector(7 downto 0);
        rd_samples     : out std_logic_vector((interp_x+5)*(interp_y+5)*sample_size-1 downto 0);
        
        --write interface
        wr_addr_x      : in  std_logic_vector(7 downto 0);
        wr_addr_y      : in  std_logic_vector(7 downto 0);
        wr_enable      : in  std_logic;
        wr_samples     : in  std_logic_vector(samples_per_wr*sample_size-1 downto 0)
        
    );
    end component inter_core_reg_file;
    
    component priority_encoder is
    generic(
        encoded_word_size : integer := 3
    );
    Port(
        input    : in  std_logic_vector(2**encoded_word_size-1 downto 0);
        output   : out std_logic_vector(encoded_word_size-1 downto 0)
    );
    end component priority_encoder;

    ---------------------------------------------------------------------------
    -- Types ------------------------------------------------------------------
    ---------------------------------------------------------------------------
    type inter_states is (idle, sel_vc, init_rx, rx, rx_dequeue, wait_rx, init_tx, gen_resp, wait_tx, tx);
    
    ---------------------------------------------------------------------------
    -- Signals ----------------------------------------------------------------
    ---------------------------------------------------------------------------
    --component interfaces
    signal rd_addr_x             : std_logic_vector(7 downto 0);
    signal rd_addr_y             : std_logic_vector(7 downto 0);
    signal rd_samples            : std_logic_vector((interp_x+5)*(interp_y+5)*sample_size-1 downto 0);
    signal wr_addr_x             : std_logic_vector(7 downto 0);
    signal wr_addr_y             : std_logic_vector(7 downto 0);
    signal wr_enable             : std_logic;
    signal wr_samples            : std_logic_vector(samples_per_wr*sample_size-1 downto 0);
    signal sel                   : std_logic_vector(7 downto 0);
    signal result                : std_logic_vector(interp_x*interp_y*sample_size-1 downto 0);
    
    -- FSMD registers and signals                          
    signal interp_mode_d         : std_logic_vector(7 downto 0);   
    signal interp_mode_q         : std_logic_vector(7 downto 0);   
    signal cmd_width_d           : std_logic_vector(7 downto 0);
    signal cmd_width_q           : std_logic_vector(7 downto 0);
    signal cmd_height_d          : std_logic_vector(7 downto 0);
    signal cmd_height_q          : std_logic_vector(7 downto 0);
    signal part_width_d          : std_logic_vector(7 downto 0);
    signal part_width_q          : std_logic_vector(7 downto 0);
    signal part_height_d         : std_logic_vector(7 downto 0);
    signal part_height_q         : std_logic_vector(7 downto 0);
    signal ref_num_d             : std_logic_vector(31 downto 0);
    signal ref_num_q             : std_logic_vector(31 downto 0);

    signal counter_d             : unsigned(7 downto 0);
    signal counter_q             : unsigned(7 downto 0);
    signal tx_max_count          : unsigned(7 downto 0);
    
    signal selected_vc_encoder   : std_logic_vector(vc_sel_width-1 downto 0);
    signal selected_vc_d         : std_logic_vector(vc_sel_width-1 downto 0);
    signal selected_vc_q         : std_logic_vector(vc_sel_width-1 downto 0);
    signal selected_vc_one_hot   : std_logic_vector(num_vc-1 downto 0);
     
    signal wr_addr_x_int         : integer;
    signal wr_addr_y_int         : integer;
    signal rd_addr_x_int         : integer;
    signal rd_addr_y_int         : integer;
     
    -- state machine signals
    signal state                 : inter_states;
    signal next_state            : inter_states;
    
begin

    ---------------------------------------------------------------------------
    -- Datapath ---------------------------------------------------------------
    ---------------------------------------------------------------------------
    u0: component inter_core
    generic map(
        x_len       => interp_x,
        y_len       => interp_y,
        sample_size => sample_size
    )
    port map(
        samples     => rd_samples,
        sel         => sel,
        result      => result
    );
    
    u1: component inter_core_reg_file
    generic map(
        size_x         => size_x,        
        size_y         => size_y,        
        interp_x       => interp_x,      
        interp_y       => interp_y,      
        sample_size    => sample_size,   
        samples_per_wr => samples_per_wr
        
    )
    port map(
        clk            => clk,      
        rst            => rst,      
        rd_addr_x      => rd_addr_x, 
        rd_addr_y      => rd_addr_y, 
        rd_samples     => rd_samples,
        wr_addr_x      => wr_addr_x, 
        wr_addr_y      => wr_addr_y, 
        wr_enable      => wr_enable, 
        wr_samples     => wr_samples
    );
    
    u2: component priority_encoder
    generic map(
        encoded_word_size => vc_sel_width
    )
    Port map(
        input    => data_in_buffer,
        output   => selected_vc_encoder
    );
    
    --datapath registers
    process(clk, rst)
    begin
        if rst = '1' then 
            interp_mode_q <= (others => '0');
            cmd_width_q   <= (others => '0');
            cmd_height_q  <= (others => '0');
            part_width_q  <= (others => '0');
            part_height_q <= (others => '0');
            ref_num_q     <= (others => '0');
            counter_q     <= (others => '0');
            selected_vc_q <= (others => '0');
        elsif rising_edge(clk) then
            interp_mode_q <= interp_mode_d;
            cmd_width_q   <= cmd_width_d;
            cmd_height_q  <= cmd_height_d;
            part_width_q  <= part_width_d;
            part_height_q <= part_height_d;
            ref_num_q     <= ref_num_d;
            counter_q     <= counter_d;
            selected_vc_q <= selected_vc_d;
        end if;
    end process;
    
    --Parser logic
    ref_num_d           <= recv_data(31 downto 0 ) when state = rx and counter_q = x"00" else ref_num_q;
    interp_mode_d       <= recv_data(7  downto 0 ) when state = rx and counter_q = x"01" else interp_mode_q;
    part_width_d        <= recv_data(15 downto 8) when state = rx and counter_q = x"01" else part_width_q;
    part_height_d       <= recv_data(23 downto 16) when state = rx and counter_q = x"01" else part_height_q;
    sel                 <= interp_mode_q;
    wr_samples          <= recv_data(sample_size*samples_per_wr-1 downto 0);
    selected_vc_one_hot <= "10" when selected_vc_d = "1" else "01"; --todo make generic
    
    --calculate buffer write addresses
    wr_addr_x_int <= to_integer(unsigned(counter_q - to_unsigned(2, 8))) mod (size_x/samples_per_wr);
    wr_addr_y_int <= to_integer(unsigned(counter_q - to_unsigned(2, 8))) / (size_x/samples_per_wr);
    wr_addr_x     <= std_logic_vector(to_unsigned(wr_addr_x_int, 8));
    wr_addr_y     <= std_logic_vector(to_unsigned(wr_addr_y_int, 8));
    
    --buffer controls
    wr_enable     <= '1' when state = rx and counter_q >= to_unsigned(2, 8) else '0';
    
    --counter update
    counter_d <= counter_q + to_unsigned(1, 8) when state = rx_dequeue or state = gen_resp else 
                 to_unsigned(0, 8)             when state = init_tx  or state = sel_vc     else
                 counter_q;
    
    --select virtual channel
    selected_vc_d <= selected_vc_encoder when state = sel_vc else selected_vc_q;
    
    --packet generation logic
    assert interp_x*interp_y*sample_size = data_width report "inter_prediction_node: interpolation-block/flit-size mismatch" severity error;
    send_data     <= X"00000000" & ref_num_q when counter_q = x"01" else result;
    rd_addr_x_int <= 2; -- todo: this really shouldn't be a constant, some generic parameters will not work...
    rd_addr_x     <= std_logic_vector(to_unsigned(rd_addr_x_int, 8));
    rd_addr_y_int <= (to_integer(unsigned(counter_q)) - 2)*2 + 2;
    rd_addr_y     <= std_logic_vector(to_unsigned(rd_addr_y_int, 8));
    tx_max_count  <= unsigned(part_height_q) + to_unsigned(1, 8);
    
    --output logic (Noc control stuff)
    dequeue        <= selected_vc_one_hot when state = rx_dequeue else (others => '0'); 
    select_vc_read <= selected_vc_q;
    dest_addr      <= std_logic_vector(to_unsigned(7, addr_width));    
    set_tail_flit  <= '1' when (state = tx or state = wait_tx) and counter_q >= tx_max_count else '0';
    send_flit      <= '1' when state = tx else '0';
    
    ---------------------------------------------------------------------------
    -- State Machine ----------------------------------------------------------
    ---------------------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            state <= idle;
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process;
    
    process(state, data_in_buffer, is_tail_flit, selected_vc_one_hot, ready_to_send, counter_q, tx_max_count)
    begin
        --default 
        next_state <= state;
        
        if state = idle and or_reduce(data_in_buffer) = '1' then
            next_state <= sel_vc;
        end if;
        
        if state = sel_vc then
            next_state <= init_rx;
        end if;
        
        if state = init_rx then
            next_state <= rx;
        end if;
        
        if state = rx then
            next_state <= rx_dequeue;
        end if;
        
        if state = rx_dequeue and is_tail_flit = '0' then
            next_state <= wait_rx;
        end if;
        
        if state = rx_dequeue and is_tail_flit = '1' then
            next_state <= init_tx;
        end if;
        
        if state = wait_rx and or_reduce(selected_vc_one_hot and data_in_buffer) = '1' then
            next_state <= rx;
        end if;
        
        if state = init_tx then
            next_state <= gen_resp;
        end if;
        
        if state = gen_resp then
            next_state <= wait_tx;
        end if;
        
        if state = wait_tx and ready_to_send = '1' then
            next_state <= tx;
        end if;
        
        if state = tx and counter_q < tx_max_count then
            next_state <= gen_resp;
        end if;

        if state = tx and counter_q >= tx_max_count then
            next_state <= idle;
        end if;
        
    end process;
    
end architecture fsmd;