library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;

entity iqit_node is
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
end entity iqit_node;


architecture fsmd of iqit_node is
    
    --- COMPONENTS ------------------------------------------------------------
    component zigzag is
    generic(
        sample_width : integer := 8
    );
    port(
        x : in  std_logic_vector((16*sample_width)-1 downto 0);
        y : out std_logic_vector((16*sample_width)-1 downto 0)
    );
    end component zigzag;
    
    component inverse_quant is
    generic(
        in_sample_width  : integer := 8;
        out_sample_width : integer := 16;
        qp_width         : integer := 8;
        wo_dc_width      : integer := 8
    );
    port(
        quantized_samples : in  std_logic_vector((16*in_sample_width)-1 downto 0);
        quant_param       : in  std_logic_vector(qp_width-1 downto 0);
        without_dc        : in  std_logic_vector(wo_dc_width-1 downto 0);
        dequant_samples   : out std_logic_vector((16*out_sample_width)-1 downto 0)
    );
    end component inverse_quant;
    
    component inverse_transform is
    generic(
        in_sample_width  : integer := 16;
        out_sample_width : integer := 8
    );
    port(
        transform_block     : in  std_logic_vector((16*in_sample_width)-1 downto 0);
        inv_transform_block : out std_logic_vector((16*out_sample_width)-1 downto 0);
        sign_mask           : out std_logic_vector(15 downto 0)
    );
    end component inverse_transform;
    
    component priority_encoder is
    generic(
        encoded_word_size : integer := 3
    );
    Port(
        input    : in  std_logic_vector(2**encoded_word_size-1 downto 0);
        output   : out std_logic_vector(encoded_word_size-1 downto 0)
    );
    end component priority_encoder;
    
    --- TYPES -----------------------------------------------------------------
    type iqit_states is (idle, 
                         sel_vc,
                         rx_header,
                         dequeue_header,
                         wait_row_4_3,
                         rx_row_4_3,
                         dequeue_row_4_3,
                         wait_row_2_1,
                         rx_row_2_1,
                         dequeue_row_2_1,
                         wait_tx_header,
                         tx_header,
                         wait_tx_row_4_3,
                         tx_row_4_3,
                         wait_tx_row_2_1,
                         tx_row_2_1
                        );

    --- SIGNALS ---------------------------------------------------------------
    signal state                 : iqit_states;
    signal next_state            : iqit_states;
    signal quant_param_d         : std_logic_vector(qp_width-1 downto 0);
    signal quant_param_q         : std_logic_vector(qp_width-1 downto 0);
    signal without_dc_d          : std_logic_vector(wo_dc_width-1 downto 0);
    signal without_dc_q          : std_logic_vector(wo_dc_width-1 downto 0);
    signal identifier_d          : std_logic_vector(7 downto 0);
    signal identifier_q          : std_logic_vector(7 downto 0);
    signal input_samples_d       : std_logic_vector((16*sample_width)-1 downto 0);
    signal input_samples_q       : std_logic_vector((16*sample_width)-1 downto 0);
    signal samples_after_zigzag  : std_logic_vector((16*sample_width)-1 downto 0);
    signal samples_after_inv_q   : std_logic_vector((16*2*sample_width)-1 downto 0);
    signal inv_t_input           : std_logic_vector((16*2*sample_width)-1 downto 0);
    signal result_samples        : std_logic_vector((16*sample_width)-1 downto 0);
    signal tx_header_data        : std_logic_vector(data_width-1 downto 0);
    signal tx_row_4_3_data       : std_logic_vector(data_width-1 downto 0);
    signal tx_row_2_1_data       : std_logic_vector(data_width-1 downto 0);
    signal sel_vc_d              : std_logic_vector(vc_sel_width-1 downto 0);
    signal sel_vc_q              : std_logic_vector(vc_sel_width-1 downto 0);
    signal sel_vc_enc            : std_logic_vector(vc_sel_width-1 downto 0);
    signal sel_vc_one_hot        : std_logic_vector(num_vc-1       downto 0);
    signal dc_high_byte_q        : std_logic_vector(7 downto 0);
    signal dc_high_byte_d        : std_logic_vector(7 downto 0);
    signal sign_mask             : std_logic_vector(15 downto 0);
     
    signal x_pass_thru_d         : std_logic_vector(10 downto 0);
    signal y_pass_thru_d         : std_logic_vector(10 downto 0);
    signal LCbCr_pass_thru_d     : std_logic_vector(1  downto 0); 
    
    signal x_pass_thru_q         : std_logic_vector(10 downto 0);
    signal y_pass_thru_q         : std_logic_vector(10 downto 0);
    signal LCbCr_pass_thru_q     : std_logic_vector(1  downto 0);
    
    
    
    constant do_iqit_cmd         : std_logic_vector(7 downto 0) := x"03";
    
begin
    
    --- DATAPATH --------------------------------------------------------------
    u0: component zigzag
    generic map(
        sample_width => sample_width
    )
    port map(
        x => input_samples_q,
        y => samples_after_zigzag
    );
    
    u1: component inverse_quant
    generic map(
        in_sample_width  => sample_width,
        out_sample_width => 2*sample_width,
        qp_width         => qp_width,
        wo_dc_width      => wo_dc_width
    )
    port map(
        quantized_samples => samples_after_zigzag,
        quant_param       => quant_param_q,
        without_dc        => without_dc_q,
        dequant_samples   => samples_after_inv_q
    );
    
    u2: component inverse_transform
    generic map(
        in_sample_width  => 2*sample_width,
        out_sample_width => sample_width
    )
    port map(
        transform_block     => inv_t_input,
        inv_transform_block => result_samples,
        sign_mask           => sign_mask
    );   
    
    u3: component priority_encoder
    generic map(
        encoded_word_size => vc_sel_width
    )
    Port map(
        input    => data_in_buffer,
        output   => sel_vc_enc
    );
    
    --register process
    process(clk, rst) begin
        if rst = '1' then
            state             <= idle;
            quant_param_q     <= (others => '0');
            without_dc_q      <= (others => '0');
            identifier_q      <= (others => '0');
            input_samples_q   <= (others => '0');
            sel_vc_q          <= (others => '0');
            dc_high_byte_q    <= (others => '0');
                x_pass_thru_q     <= (others => '0');
                y_pass_thru_q     <= (others => '0');
                LCbCr_pass_thru_q <= (others => '0');
        elsif rising_edge(clk) then
            state             <= next_state;          
            quant_param_q     <= quant_param_d;  
            without_dc_q      <= without_dc_d;   
            identifier_q      <= identifier_d;   
            input_samples_q   <= input_samples_d;
            sel_vc_q          <= sel_vc_d;
            dc_high_byte_q    <= dc_high_byte_d;
                x_pass_thru_q     <= x_pass_thru_d;    
                y_pass_thru_q     <= y_pass_thru_d;    
                LCbCr_pass_thru_q <= LCbCr_pass_thru_d;
        end if;
    end  process;
    
    --insert high byte of dc into signal if non-zero
    inv_t_input <= samples_after_inv_q(16*2*sample_width-1 downto sample_width*2) & dc_high_byte_q & samples_after_inv_q(sample_width-1 downto 0) when or_reduce(dc_high_byte_q) = '1' else 
                   samples_after_inv_q;
    
    --parse packet
    quant_param_d     <= recv_data(47 downto 40) when state = rx_header else quant_param_q;
    without_dc_d      <= recv_data(39 downto 32) when state = rx_header else without_dc_q;
    identifier_d      <= recv_data(7 downto 0)   when state = rx_header else identifier_q;
    dc_high_byte_d    <= recv_data(55 downto 48) when state = rx_header else dc_high_byte_q;
    x_pass_thru_d     <= recv_data(18 downto 8)  when state = rx_header else x_pass_thru_q;
    y_pass_thru_d     <= recv_data(29 downto 19) when state = rx_header else y_pass_thru_q;
    LCbCr_pass_thru_d <= recv_data(31 downto 30) when state = rx_header else LCbCr_pass_thru_q;
    
    input_samples_d((16*sample_width)-1 downto (8*sample_width)) <= recv_data when state = rx_row_4_3 else 
        input_samples_q((16*sample_width)-1 downto (8*sample_width));
    
    input_samples_d((8*sample_width)-1 downto 0) <= recv_data when state = rx_row_2_1 else 
        input_samples_q((8*sample_width)-1 downto 0);    
    
    
    -- format repsonse packet
    tx_header_data   <= x_pass_thru_q & "00000" &sign_mask& "000" & LCbCr_pass_thru_q & y_pass_thru_q &do_iqit_cmd&identifier_q;
    tx_row_4_3_data  <= result_samples((16*sample_width)-1 downto (8*sample_width));
    tx_row_2_1_data  <= result_samples((8*sample_width)-1 downto 0) ;
    
    -- channel selection logic
    sel_vc_d <= sel_vc_enc when state = sel_vc else sel_vc_q;
    
    --rx controls
    dequeue        <= sel_vc_one_hot when state = dequeue_header or state = dequeue_row_4_3 or state = dequeue_row_2_1 else "00";
    select_vc_read <= sel_vc_q;
    sel_vc_one_hot <= "01" when sel_vc_q = "0" else "10";
    
    --packet generation
    send_data      <= tx_header_data  when state = wait_tx_header or state = tx_header else 
                      tx_row_4_3_data when state = wait_tx_row_4_3 or state = tx_row_4_3 else
                      tx_row_2_1_data when state = wait_tx_row_2_1 or state = tx_row_2_1 else 
                      std_logic_vector(to_unsigned(0, data_width));
    dest_addr      <= std_logic_vector(to_unsigned(7, addr_width));
    set_tail_flit  <= '1' when state = wait_row_2_1 or state = tx_row_2_1 else '0';
    send_flit      <= '1' when state = tx_header or state = tx_row_4_3 or state = tx_row_2_1 else '0';
    
    -- STATE MACHINE ----------------------------------------------------------
    process(state, data_in_buffer, is_tail_flit, sel_vc_one_hot, ready_to_send)
    begin
        next_state <= state; --default behaviour
        
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
            next_state <= wait_row_4_3;
        end if;
        
        if state = wait_row_4_3 and or_reduce(sel_vc_one_hot and data_in_buffer) = '1' then
            next_state <= rx_row_4_3;
        end if;
        
        if state = rx_row_4_3 then
            next_state <= dequeue_row_4_3;
        end if;
        
        if state = dequeue_row_4_3 then
            next_state <= wait_row_2_1;
        end if;
        
        if state = wait_row_2_1 and or_reduce(sel_vc_one_hot and data_in_buffer) = '1' then
            next_state <= rx_row_2_1;
        end if;
        
        if state = rx_row_2_1 then
            next_state <= dequeue_row_2_1;
        end if;
        
        if state = dequeue_row_2_1 then
            next_state <= wait_tx_header;
        end if;
        
        if state = wait_tx_header and ready_to_send = '1' then
            next_state <= tx_header;
        end if;
        
        if state = tx_header then
            next_state <= wait_tx_row_4_3;
        end if;
        
        if state = wait_tx_row_4_3 and ready_to_send = '1' then
            next_state <= tx_row_4_3;
        end if;
        
        if state = tx_row_4_3 then
            next_state <= wait_tx_row_2_1;
        end if;
        
        if state = wait_tx_row_2_1 and ready_to_send = '1' then
            next_state <= tx_row_2_1;
        end if;
        
        if state = tx_row_2_1 then
            next_state <= idle;
        end if;
    
    end process;

end architecture fsmd;