library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;


entity vga_node is
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
end entity vga_node;

architecture fsmd of vga_node is
    
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
    
    --component display_buffer is
    --generic(
    --    rgb_size   : integer := 8;
    --    horizontal : integer := 320;
    --    vertical   : integer := 144;
    --    addr_size  : integer := 16
    --);
    --port(
    --    clk        : in  std_logic;
    --    rst        : in  std_logic;
    --
    --    red_in     : in  std_logic_vector(rgb_size-1  downto 0);
    --    green_in   : in  std_logic_vector(rgb_size-1  downto 0);
    --    blue_in    : in  std_logic_vector(rgb_size-1  downto 0);
    --    wr_addr    : in  std_logic_vector(addr_size-1 downto 0);
    --    wr_enable  : in  std_logic;
    --    
    --    red_out    : out std_logic_vector(rgb_size-1  downto 0);
    --    green_out  : out std_logic_vector(rgb_size-1  downto 0);
    --    blue_out   : out std_logic_vector(rgb_size-1  downto 0);
    --    rd_addr    : in  std_logic_vector(addr_size-1 downto 0)    
    --    
    --);
    --end component display_buffer;
	 
	 component vga_controller is
		generic(
			h_pulse 	:	integer := 208;    	--horiztonal sync pulse width in pixels
			h_bp	 	:	integer := 336;		--horiztonal back porch width in pixels
			h_pixels	:	integer := 1920;		--horiztonal display width in pixels
			h_fp	 	:	integer := 128;		--horiztonal front porch width in pixels
			h_pol		:	std_logic := '0';		--horizontal sync pulse polarity (1 = positive, 0 = negative)
			v_pulse 	:	integer := 3;			--vertical sync pulse width in rows
			v_bp	 	:	integer := 38;			--vertical back porch width in rows
			v_pixels	:	integer := 1200;		--vertical display width in rows
			v_fp	 	:	integer := 1;			--vertical front porch width in rows
			v_pol		:	std_logic := '1');	--vertical sync pulse polarity (1 = positive, 0 = negative)
		port(
			pixel_clk	:	in		std_logic;	--pixel clock at frequency of vga mode being used
			reset_n		:	in		std_logic;	--active low asycnchronous reset
			h_sync		:	out	std_logic;	--horiztonal sync pulse
			v_sync		:	out	std_logic;	--vertical sync pulse
			disp_ena		:	out	std_logic;	--display enable ('1' = display time, '0' = blanking time)
			column		:	out	integer;		--horizontal pixel coordinate
			row			:	out	integer;		--vertical pixel coordinate
			n_blank		:	out	std_logic;	--direct blacking output to dac
			n_sync		:	out	std_logic); --sync-on-green output to dac
    end component vga_controller;
	 
	 component ram_dual is
    generic
	 (
		 ram_width : integer := 24;
	 	 ram_depth : integer := 65536
	 );
    port
    (
       clock1        : in   std_logic;
       clock2        : in   std_logic;
       data          : in   std_logic_vector(ram_width-1 downto 0);
       write_address : in   integer;
       read_address  : in   integer;
       we            : in   std_logic;
       q             : out  std_logic_vector(ram_width-1 downto 0)
    );
    end component ram_dual;
	 
	 
    
    component ycbcr_to_rgb is
    port(
        clk   : in  std_logic;
        y     : in  std_logic_vector(7 downto 0);
        cb    : in  std_logic_vector(7 downto 0);
        cr    : in  std_logic_vector(7 downto 0);
        red   : out std_logic_vector(7 downto 0);
        green : out std_logic_vector(7 downto 0);
        blue  : out std_logic_vector(7 downto 0)
    );
    end component ycbcr_to_rgb;
    
    --component vga_driver is
    --port(
    --    r         : in  std_logic_vector(9 downto 0);
    --    g         : in  std_logic_vector(9 downto 0);
    --    b         : in  std_logic_vector(9 downto 0);
    --    current_x : out std_logic_vector(9 downto 0);
    --    current_y : out std_logic_vector(9 downto 0);
    --    request   : out std_logic;
    --    vga_r     : out std_logic_vector(9 downto 0);
    --    vga_g     : out std_logic_vector(9 downto 0);
    --    vga_b     : out std_logic_vector(9 downto 0);
    --    vga_hs    : out std_logic;
    --    vga_vs    : out std_logic;
    --    vga_blank : out std_logic;
    --    vga_clock : out std_logic;
    --    clk27     : in  std_logic;
    --    rst27     : in  std_logic 
    --);
    --end component vga_driver;
	 
	 --- Constants -------------------------------------------------------------
	 constant rgb_size        : integer := 6;
    constant horizontal      : integer := 320;
    constant vertical        : integer := 200;
    constant addr_size       : integer := 19;
    
    --- Types -----------------------------------------------------------------
    type vga_node_states is (idle, 
                             sel_vc, 
                             rx,
                             convert_0,
                             wr_rgb_0,
                             convert_1,
                             wr_rgb_1,
                             dequeue_flit                                  
                             );
    
    --- signals and registers -------------------------------------------------
    signal state             : vga_node_states;
    signal next_state        : vga_node_states;
    signal convert_counter_d : unsigned(7 downto 0);
    signal convert_counter_q : unsigned(7 downto 0);
    
    signal red_in            : std_logic_vector(rgb_size-1  downto 0);
    signal green_in          : std_logic_vector(rgb_size-1  downto 0);
    signal blue_in           : std_logic_vector(rgb_size-1  downto 0);
    signal wr_addr           : integer;
    signal wr_enable         : std_logic;
    signal red_out           : std_logic_vector(rgb_size-1  downto 0);
    signal green_out         : std_logic_vector(rgb_size-1  downto 0);
    signal blue_out          : std_logic_vector(rgb_size-1  downto 0);
    signal rd_addr           : integer;
    
    signal y                 : std_logic_vector(7 downto 0);
    signal cb                : std_logic_vector(7 downto 0);
    signal cr                : std_logic_vector(7 downto 0);
    signal red               : std_logic_vector(7 downto 0);
    signal green             : std_logic_vector(7 downto 0);
    signal blue              : std_logic_vector(7 downto 0);
    
    signal r                 : std_logic_vector(9 downto 0);
    signal g                 : std_logic_vector(9 downto 0);
    signal b                 : std_logic_vector(9 downto 0);
    signal current_x         : integer;
    signal current_y         : integer;
    signal request           : std_logic;
    signal vga_r             : std_logic_vector(9 downto 0);
    signal vga_g             : std_logic_vector(9 downto 0);
    signal vga_b             : std_logic_vector(9 downto 0);
    signal vga_hs            : std_logic;
    signal vga_vs            : std_logic;
    signal vga_blank         : std_logic;
    signal vga_clock         : std_logic;
    
    signal rd_addr_32        : std_logic_vector(31 downto 0);
	 
	 signal sel_vc_d       : std_logic_vector(vc_sel_width-1 downto 0);
    signal sel_vc_q       : std_logic_vector(vc_sel_width-1 downto 0);
    signal sel_vc_enc     : std_logic_vector(vc_sel_width-1 downto 0);
    signal sel_vc_one_hot : std_logic_vector(num_vc-1       downto 0);
	 
	 signal rgb_read       : std_logic_vector(3*rgb_size-1 downto 0);
	 
	 signal disp_ena       : std_logic;
    


    
begin

    ---------------------------------------------------------------------------
    --- DATAPATH --------------------------------------------------------------
    ---------------------------------------------------------------------------
    --components
    u0: component priority_encoder
    generic map(
        encoded_word_size => vc_sel_width
    )
    Port map(
        input    => data_in_buffer,
        output   => sel_vc_enc
    );
    
    --u1: component display_buffer
    --generic map (
    --    rgb_size   => rgb_size  ,  
    --    horizontal => horizontal,
    --    vertical   => vertical  ,
    --    addr_size  => addr_size 
    --)
    --port map(
    --    clk        =>  clk      ,        
    --    rst        =>  rst      ,  
    --    red_in     =>  red_in   ,  
    --    green_in   =>  green_in ,  
    --    blue_in    =>  blue_in  ,  
    --    wr_addr    =>  wr_addr  ,  
    --    wr_enable  =>  wr_enable,   
    --    red_out    =>  red_out  ,  
    --    green_out  =>  green_out,  
    --    blue_out   =>  blue_out ,  
    --    rd_addr    =>  rd_addr     
    --    
    --);
	 
	 red_ram: component ram_dual
    generic map
	 (
		 ram_width => 6,
	 	 ram_depth => horizontal*vertical
	 )
    port map
    (
       clock1        => clk,
       clock2        => clk27,
       data          => red_in,
       write_address => wr_addr,
       read_address  => rd_addr,
       we            => wr_enable,
       q             => red_out
    );
    
	 blue_ram: component ram_dual
    generic map
	 (
		 ram_width => 6,
	 	 ram_depth => horizontal*vertical
	 )
    port map
    (
       clock1        => clk,
       clock2        => clk27,
       data          => blue_in,
       write_address => wr_addr,
       read_address  => rd_addr,
       we            => wr_enable,
       q             => blue_out
    );
	 
	 green_ram: component ram_dual
    generic map
	 (
		 ram_width => 6,
	 	 ram_depth => horizontal*vertical
	 )
    port map
    (
       clock1        => clk,
       clock2        => clk27,
       data          => green_in,
       write_address => wr_addr,
       read_address  => rd_addr,
       we            => wr_enable,
       q             => green_out
    );
	 
    u2: component ycbcr_to_rgb
    port map(
        clk       =>   clk  , 
        y         =>   y    , 
        cb        =>   cb   , 
        cr        =>   cr   , 
        red       =>   red  , 
        green     =>   green, 
        blue      =>   blue  
    );
    
    --u3: component vga_driver
    --port map(
    --    r         =>   r        ,        
    --    g         =>   g        , 
    --    b         =>   b        , 
    --    current_x =>   current_x, 
    --    current_y =>   current_y, 
    --    request   =>   request  , 
    --    vga_r     =>   vga_r    , 
    --    vga_g     =>   vga_g    , 
    --    vga_b     =>   vga_b    , 
    --    vga_hs    =>   vga_hs   , 
    --    vga_vs    =>   vga_vs   , 
    --    vga_blank =>   vga_blank, 
    --    vga_clock =>   vga_clock, 
    --    clk27     =>   clk27    , 
    --    rst27     =>   rst27     
    --);
	 
	 u3: component vga_controller
		generic map(
			h_pulse 	  => 96,
			h_bp	 	  => 48,
			h_pixels	  => 640,
			h_fp	 	  => 16,
			h_pol		  => '0',
			v_pulse 	  => 2,
			v_bp	 	  => 35,
			v_pixels	  => 400,
			v_fp	 	  => 12,
			v_pol		  => '1'
			)
		port map(
			pixel_clk	=> clk27,
			reset_n		=> not rst27,
			h_sync		=> vga_hs,
			v_sync		=> vga_vs,
			column		=> current_x,
			row			=> current_y,
			disp_ena    => disp_ena
	 );
    
    -- wire components together
    -- r             <= red_out    & std_logic_vector(to_unsigned(0, 10-rgb_size));
    -- g             <= green_out  & std_logic_vector(to_unsigned(0, 10-rgb_size));
    -- b             <= blue_out   & std_logic_vector(to_unsigned(0, 10-rgb_size));   
    --rd_addr_32    <= std_logic_vector((to_unsigned(1, 22)  * unsigned(current_x)) + 
    --                                  (unsigned(current_y) * to_unsigned(horizontal, 22)));
    --                 
    --rd_addr       <= to_integer(unsigned(rd_addr_32));
	 rd_addr     <= (current_x mod horizontal) +
	                (current_y mod vertical  ) * horizontal;

    vga_red     <= red_out    when disp_ena = '1' else "000000";  --red_out; 
    vga_blue    <= blue_out   when disp_ena = '1' else "000000";  --green_out; 
    vga_green   <= green_out   when disp_ena = '1' else "000000";  --blue_out; 
    vga_v_sync  <= vga_vs;
    vga_h_sync  <= vga_hs;
    
    y           <= recv_data(63 downto 56) when state = convert_0 else recv_data(39 downto 32);
    cb          <= recv_data(55 downto 48) when state = convert_0 else recv_data(31 downto 24);
    cr          <= recv_data(47 downto 40) when state = convert_0 else recv_data(23 downto 16);
    red_in      <= red(7 downto 2);   
    green_in    <= green(7 downto 2);  
    blue_in     <= blue(7 downto 2);     
    
	 wr_addr     <= to_integer(unsigned(recv_data(15 downto 0))) when state = wr_rgb_0 or state = convert_0 else
	                to_integer(unsigned(recv_data(15 downto 0))) + 1; 
    wr_enable   <= '1' when state = wr_rgb_0 else
                   '1' when state = wr_rgb_1 else
                   '0';

    --counter for coversion wait states
    convert_counter_d <= convert_counter_q + to_unsigned(1, 8) when state = convert_0 else
                         convert_counter_q + to_unsigned(1, 8) when state = convert_1 else
                         to_unsigned(0, 8);

    process(clk, rst)
    begin
        if rst = '1' then
		      sel_vc_q <= (others => '0');
				convert_counter_q <= (others => '0');
        elsif rising_edge(clk) then
            convert_counter_q <= convert_counter_d;
				sel_vc_q <= sel_vc_d;
        end if;
    end process;
    
                         
    --packet generation
    send_data      <= (others => '0');
    dest_addr      <= (others => '0');
    set_tail_flit  <= '0';
    send_flit      <= '0';
    
    --rx controls
	 sel_vc_d       <= sel_vc_enc when state = sel_vc else sel_vc_q;
    dequeue        <= sel_vc_one_hot when state = dequeue_flit else "00";
    select_vc_read <= sel_vc_q;
    sel_vc_one_hot <= "01" when sel_vc_q = "0" else "10";
    
    ---------------------------------------------------------------------------
    --- STATE MACHINE ---------------------------------------------------------
    ---------------------------------------------------------------------------
    
	 process(clk, rst)
	 begin
		if rst = '1' then
			state <= idle;
		elsif rising_edge(clk) then
			state <= next_state;
		end if;
	 end process;
	 
	 
    process(state, data_in_buffer, is_tail_flit, sel_vc_one_hot, ready_to_send, convert_counter_q)
    begin
        
        next_state <= state;
        
        if state = idle and or_reduce(data_in_buffer) = '1' then
            next_state <= sel_vc;
        end if;
        
        if state = sel_vc then
            next_state <= rx;
        end if;
        
        if state = rx then
            next_state <= convert_0;
        end if;
        
        if state = convert_0 and convert_counter_q > to_unsigned(2, 8) then
            next_state <= wr_rgb_0;
        end if;
        
        if state = wr_rgb_0 then
            next_state <= convert_1;
        end if;
        
        if state = convert_1 and convert_counter_q > to_unsigned(2, 8) then
            next_state <= wr_rgb_1;
        end if;
        
        if state = wr_rgb_1 then
            next_state <= dequeue_flit;
        end if;
        
        if state = dequeue_flit then
            next_state <= idle;
        end if;
        
    end process;   
    
end architecture;
