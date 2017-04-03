library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

entity intra_prediction_node is
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
end entity intra_prediction_node;

architecture fsmd of intra_prediction_node is
    ---------------------------------------------------------------------------
    --- Constants -------------------------------------------------------------
    ---------------------------------------------------------------------------
    constant size_of_byte   : integer := 8;

    --- for parsing cmd byte --------------------------------------------------
    constant cmd_start      : integer := 0;
    constant cmd_bytes      : integer := 1;
    constant cmd_end        : integer := cmd_start + cmd_bytes * size_of_byte - 1;

    --- for parsing set samples command ---------------------------------------
    constant wr_addr_start  : integer := cmd_end + 1;
    constant wr_addr_bytes  : integer := 1;
    constant wr_addr_end    : integer := wr_addr_start + wr_addr_bytes * size_of_byte - 1;

    constant samples_start  : integer := wr_addr_end + 1;
    constant samples_bytes  : integer := 4;
    constant samples_end    : integer := samples_start + samples_bytes * size_of_byte - 1;

    --- for parsing perform prediction command --------------------------------
    constant block_size_start  : integer := cmd_end + 1;
    constant block_size_bytes  : integer := 1;
    constant block_size_end    : integer := block_size_start + block_size_bytes * size_of_byte - 1;

    constant mode_start  : integer := block_size_end + 1;
    constant mode_bytes  : integer := 1;
    constant mode_end    : integer := mode_start + mode_bytes * size_of_byte - 1;

    constant availible_mask_start  : integer := mode_end + 1;
    constant availible_mask_bytes  : integer := 4;
    constant availible_mask_end    : integer := availible_mask_start + availible_mask_bytes * size_of_byte - 1;

    constant identifier_start  : integer := availible_mask_end + 1;
    constant identifier_bytes  : integer := 1;
    constant identifier_end    : integer := identifier_start + identifier_bytes * size_of_byte - 1;

    --- commands
    constant cmd_write_sample  : std_logic_vector(7 downto 0) := "00000001";
    constant cmd_predict       : std_logic_vector(7 downto 0) := "00000010";

    --- tx constants ----------------------------------------------------------
    constant flit_size         : integer := data_width;

    constant tx_len_16x16      : integer := 32;   --todo --(16*16)/(flit_size/size_of_byte);
    constant tx_len_8x8        : integer := 16;   --todo --(8*8)/(flit_size/size_of_byte);
    constant tx_len_4x4        : integer := 8;    --todo --todo

    constant tx_loop_max_16x16 : integer := tx_len_16x16;--integer( real(tx_len_16x16) / real(flit_size/size_of_byte) + 0.5 );
    constant tx_loop_max_8x8   : integer := tx_len_8x8  ;--integer( real(tx_len_8x8  ) / real(flit_size/size_of_byte) + 0.5 );
    constant tx_loop_max_4x4   : integer := tx_len_4x4  ;--integer( real(tx_len_4x4  ) / real(flit_size/size_of_byte) + 0.5 );

    constant header_pad_size   : integer := 0;
    constant header_pad        : std_logic_vector := std_logic_vector(to_unsigned(0, header_pad_size));

    ---------------------------------------------------------------------------
    --- Components ------------------------------------------------------------
    ---------------------------------------------------------------------------
    component intra_prediction_core is
    port(
        clk                 : in  std_logic;
        rst                 : in  std_logic;

        --interface to enable "set samples" command
        sample_data         : in  std_logic_vector(31 downto 0);
        sample_write_addr   : in  unsigned(7 downto 0);
        sample_write_enable : in  std_logic;

        --interface to enable "perform prediction" command
        block_size          : in  unsigned(7 downto   0);
        mode                : in  unsigned(7 downto   0);
        row_addr            : in  unsigned(7 downto   0);
        availible_mask      : in  std_logic_vector(31 downto 0);
        row_data            : out unsigned(127 downto 0)
    );
    end component intra_prediction_core;

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
    type intra_node_ctrl_states is ( intra_idle,
                                     intra_data_rxd,
                                     intra_write_sample,
                                     intra_start_pred,
                                     intra_start_tx_loop,
                                     intra_start_tx_loop_hold,
                                     intra_tx,
                                     intra_tx_hold,
                                     intra_tx_gen_next,
                                                 intra_tx_gen_next_hold,
                                     intra_dequeue_rx          );


    ---------------------------------------------------------------------------
    --- Signals ---------------------------------------------------------------
    ---------------------------------------------------------------------------
    signal sample_data             : std_logic_vector(31 downto 0);
    signal sample_write_addr       : unsigned(7 downto 0);
    signal sample_write_enable     : std_logic;
    signal block_size              : unsigned(7 downto   0);
    signal mode                    : unsigned(7 downto   0);
    signal row_addr                : unsigned(7 downto   0);
    signal availible_mask          : std_logic_vector(31 downto 0);
    signal row_data                : unsigned(127 downto 0);

    signal wr_sample_data          : std_logic;
    signal wr_sample_write_addr    : std_logic;
    signal wr_sample_write_enable  : std_logic;
    signal wr_block_size           : std_logic;
    signal wr_mode                 : std_logic;
    signal wr_row_addr             : std_logic;
    signal wr_availible_mask       : std_logic;
    signal wr_row_data             : std_logic;

    signal parsed_cmd              : std_logic_vector(7  downto 0);
    signal parsed_wr_addr          : std_logic_vector(7  downto 0);
    signal parsed_samples          : std_logic_vector(31 downto 0);
    signal parsed_block_size       : std_logic_vector(7  downto 0);
    signal parsed_mode             : std_logic_vector(7  downto 0);
    signal parsed_availible_mask   : std_logic_vector(31 downto 0);
    signal parsed_identifier       : std_logic_vector(7  downto 0);

    signal tx_loop_count_q         : unsigned(7 downto 0);
    signal tx_loop_count_d         : unsigned(7 downto 0);
    signal tx_loop_done            : std_logic;
    signal last_loop               : std_logic;

    signal send_data_internal      : std_logic_vector(flit_size-1 downto 0);

    signal intra_state             : intra_node_ctrl_states;
    signal next_intra_state        : intra_node_ctrl_states;

    signal selected_vc_encoder     : std_logic_vector(vc_sel_width-1 downto 0);

    signal row_seg_full            : std_logic_vector(127 downto 0);
    signal row_seg                 : std_logic_vector(flit_size-1 downto 0);
    
    signal selected_vc_q           : std_logic_vector(vc_sel_width-1 downto 0);
    signal selected_vc_d           : std_logic_vector(vc_sel_width-1 downto 0);
    
    signal padded_id               : std_logic_vector(31 downto 0);
    signal padded_block_size       : std_logic_vector(31 downto 0);

begin

    ---------------------------------------------------------------------------
    --- Datapath --------------------------------------------------------------
    ---------------------------------------------------------------------------

    --- instantiate the intra prediction core --------------------------------
    core0: component intra_prediction_core port map(
        clk                 => clk ,
        rst                 => rst ,
        sample_data         => sample_data ,
        sample_write_addr   => sample_write_addr ,
        sample_write_enable => sample_write_enable ,
        block_size          => block_size ,
        mode                => mode ,
        row_addr            => row_addr ,
        availible_mask      => availible_mask ,
        row_data            => row_data
    );

    -- instantiate priority_encoder for vc selection
    encoded0: component priority_encoder generic map (
        encoded_word_size => vc_sel_width
    ) Port map(
        input             => data_in_buffer,
        output            => selected_vc_encoder
    );

    --- implement data parser -------------------------------------------------
    parsed_cmd            <= recv_data(cmd_end            downto cmd_start           );
    parsed_wr_addr        <= recv_data(wr_addr_end        downto wr_addr_start       );
    parsed_samples        <= recv_data(samples_end        downto samples_start       );
    parsed_block_size     <= recv_data(block_size_end     downto block_size_start    );
    parsed_mode           <= recv_data(mode_end           downto mode_start          );
    parsed_availible_mask <= recv_data(availible_mask_end downto availible_mask_start);
    parsed_identifier     <= recv_data(identifier_end     downto identifier_start);

    --- hook up parsed data to intra prediction core --------------------------
    sample_data       <= parsed_samples;
    sample_write_addr <= unsigned(parsed_wr_addr);
    block_size        <= unsigned(parsed_block_size);
    mode              <= unsigned(parsed_mode);
    availible_mask    <= parsed_availible_mask;

    --- data path registers ---------------------------------------------------
    dp_regs: process(clk, rst) begin
        if rst = '1' then
            tx_loop_count_q <= (others => '0');
            selected_vc_q   <= (others => '0');
        elsif rising_edge(clk) then
            tx_loop_count_q <= tx_loop_count_d;
            selected_vc_q   <= selected_vc_d;
        end if;
    end process;

    --- tx loop check ---------------------------------------------------------
    tx_loop_done <= '0' when tx_loop_count_q < tx_loop_max_16x16 and block_size = to_unsigned(16, 8) else
                    '0' when tx_loop_count_q < tx_loop_max_8x8   and block_size = to_unsigned(8, 8)  else
                    '0' when tx_loop_count_q < tx_loop_max_4x4   and block_size = to_unsigned(4, 8)  else
                    '1';
                          
    last_loop    <= '0' when tx_loop_count_q < (tx_loop_max_16x16 - 1) and block_size = to_unsigned(16, 8) else
                    '0' when tx_loop_count_q < (tx_loop_max_8x8   - 1) and block_size = to_unsigned(8, 8)  else
                    '0' when tx_loop_count_q < (tx_loop_max_4x4   - 1) and block_size = to_unsigned(4, 8)  else
                    '1';

    --- row read address generator --------------------------------------------
    --  supports 128, 64, and 32 bit flit data feilds
    assert flit_size  = 128 or flit_size  = 64  or   flit_size = 32 report "intra_prediction_node: unsupported flit size" severity failure;
    row_addr <= tx_loop_count_q                 when flit_size = 128 else -- tx's full row per flit
                shift_right(tx_loop_count_q, 1) when flit_size = 64  else -- tx's half row per flit
                shift_right(tx_loop_count_q, 2) when flit_size = 32  else -- tx's quarter row per flit
                (others => '0');

    --- row segment selection -------------------------------------------------
    row_seg_full <= std_logic_vector(row_data)                                                       when flit_size = 128 else
                    std_logic_vector(to_unsigned(0, 64)) & std_logic_vector(row_data(127 downto 64)) when flit_size = 64 and tx_loop_count_q(0) = '0' else
                    std_logic_vector(to_unsigned(0, 64)) & std_logic_vector(row_data(63  downto  0)) when flit_size = 64 and tx_loop_count_q(0) = '1' else
                    std_logic_vector(to_unsigned(0, 96)) & std_logic_vector(row_data(127 downto 96)) when flit_size = 32 and tx_loop_count_q(1 downto 0) = "00" else
                    std_logic_vector(to_unsigned(0, 96)) & std_logic_vector(row_data(95  downto 64)) when flit_size = 32 and tx_loop_count_q(1 downto 0) = "01" else
                    std_logic_vector(to_unsigned(0, 96)) & std_logic_vector(row_data(63  downto 32)) when flit_size = 32 and tx_loop_count_q(1 downto 0) = "10" else
                    std_logic_vector(to_unsigned(0, 96)) & std_logic_vector(row_data(31  downto 0) ) when flit_size = 32 and tx_loop_count_q(1 downto 0) = "11" else
                    (others => '0');

    row_seg      <= row_seg_full(flit_size-1 downto 0);

    --- misc assignments ------------------------------------------------------
    select_vc_read     <= selected_vc_q;
    padded_id          <= std_logic_vector(to_unsigned(0, 24)) & parsed_identifier;
    padded_block_size  <= std_logic_vector(to_unsigned(0, 24)) & parsed_block_size; 


    ---------------------------------------------------------------------------
    --- State Machine ---------------------------------------------------------
    ---------------------------------------------------------------------------

    --- FSM State Register ----------------------------------------------------
    state_reg: process(clk, rst) begin
        if rst = '1' then
            intra_state <= intra_idle;
        elsif rising_edge(clk) then
            intra_state <= next_intra_state;
        end if;
    end process;

    --- FSM Update Logic ------------------------------------------------------
    state_update: process(parsed_cmd, intra_state, tx_loop_done) begin
        -- default
        next_intra_state <= intra_state;

        -- wait for new data to arrive
        if intra_state = intra_idle and or_reduce(data_in_buffer) = '1' then
            next_intra_state <= intra_data_rxd;
        end if;

        -- write samples to intra_core
        if intra_state = intra_data_rxd and parsed_cmd = cmd_write_sample then
            next_intra_state <= intra_write_sample;
        end if;

        if intra_state = intra_write_sample then
            next_intra_state <= intra_dequeue_rx;
        end if;

        -- perform prediction
        if intra_state = intra_data_rxd and parsed_cmd = cmd_predict then
            next_intra_state <= intra_start_pred;
        end if;

        if intra_state = intra_start_pred and ready_to_send = '1' then
            next_intra_state <= intra_start_tx_loop;
        end if;

        --transmit result
        if intra_state = intra_start_tx_loop then
            next_intra_state <= intra_start_tx_loop_hold;
        end if;

        if intra_state = intra_start_tx_loop_hold and ready_to_send = '1'  then
            next_intra_state <= intra_tx;
        end if;

        if intra_state = intra_tx then
            next_intra_state <= intra_tx_hold;
        end if;

        if intra_state = intra_tx_hold and tx_loop_done = '0' then
            next_intra_state <= intra_tx_gen_next;
        end if;

        if intra_state = intra_tx_hold and tx_loop_done = '1' then
            next_intra_state <= intra_dequeue_rx;
        end if;

        if intra_state = intra_tx_gen_next then
            next_intra_state <= intra_tx_gen_next_hold;
        end if;
          
        if intra_state = intra_tx_gen_next_hold and ready_to_send = '1' then
            next_intra_state <= intra_tx;
        end if;

        if intra_state = intra_dequeue_rx then
            next_intra_state <= intra_idle;
        end if;
    end process;

    --- FSM output logic ------------------------------------------------------
    sample_write_enable <= '1'                                 when intra_state = intra_write_sample  else '0';
    
    tx_loop_count_d     <= (others => '0')                     when intra_state = intra_start_pred    else
                           tx_loop_count_q + to_unsigned(1, 8) when intra_state = intra_tx            else
                           tx_loop_count_q;

    send_data <= header_pad & padded_block_size & padded_id  when intra_state = intra_start_tx_loop or intra_state = intra_start_tx_loop_hold else
                 row_seg;

    selected_vc_d <= selected_vc_encoder                     when intra_state = intra_data_rxd else selected_vc_q;

    dequeue       <= "01"                                    when selected_vc_q = "0" and intra_state = intra_dequeue_rx else
                     "10"                                    when selected_vc_q = "1" and intra_state = intra_dequeue_rx else
                     "00";
                     
    dest_addr     <= std_logic_vector(to_unsigned(7, addr_width));
    set_tail_flit <= '1'                                     when last_loop   = '1' else '0';
    send_flit     <= '1'                                     when intra_state = intra_start_tx_loop else
                     '1'                                     when intra_state = intra_tx else
                     '0';
    
    --- debug outputs ---------------------------------------------------------
    s_intra_idle                <= '1' when intra_state = intra_idle               else '0';
    s_intra_data_rxd            <= '1' when intra_state = intra_data_rxd           else '0';
    s_intra_write_sample        <= '1' when intra_state = intra_write_sample       else '0';
    s_intra_start_pred          <= '1' when intra_state = intra_start_pred         else '0';
    s_intra_start_tx_loop       <= '1' when intra_state = intra_start_tx_loop      else '0';
    s_intra_start_tx_loop_hold  <= '1' when intra_state = intra_start_tx_loop_hold else '0';
    s_intra_tx                  <= '1' when intra_state = intra_tx                 else '0';
    s_intra_tx_hold             <= '1' when intra_state = intra_tx_hold            else '0';
    s_intra_tx_gen_next         <= '1' when intra_state = intra_tx_gen_next        else '0';
    s_intra_dequeue_rx          <= '1' when intra_state = intra_dequeue_rx         else '0';

end architecture fsmd;