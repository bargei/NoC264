library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;


entity network_interface is
generic(
    data_width      : integer := 64;
    addr_width      : integer := 1;
    vc_sel_width    : integer := 1;
    num_vc          : integer := 2;
    flit_buff_depth : integer := 8
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
end entity network_interface;

architecture structural of network_interface is

    --fifo buffer for reciving
    component fifo_buffer is
    generic(
        word_len : integer := 64;
        buff_len : integer := 8
    );
    port(
        write_data   : in  std_logic_vector(word_len-1 downto 0);
        read_data    : out std_logic_vector(word_len-1 downto 0);
        buffer_full  : out std_logic;
        buffer_empty : out std_logic;
        enqueue      : in  std_logic;
        dequeue      : in  std_logic;
        clk          : in  std_logic;
        rst          : in  std_logic
    );
    end component fifo_buffer;
    
    type fifo_io is array(num_vc-1 downto 0) of std_logic_vector(vc_sel_width+data_width+addr_width+1 downto 0);
    signal write_vc, read_vc: fifo_io;
    signal buffer_full_vc, buffer_empty_vc, enqueue_vc, dequeue_vc: std_logic_vector(num_vc-1 downto 0);
    signal receive_vc: std_logic_vector(vc_sel_width-1 downto 0);
    
    -- priority encoder
    component priority_encoder is
    generic(
        encoded_word_size : integer := 3
    );
    Port(
        input    : in  std_logic_vector(2**encoded_word_size-1 downto 0);
        output   : out std_logic_vector(encoded_word_size-1 downto 0)
    );
    end component priority_encoder;
    
	 signal selected_vc : std_logic_vector(vc_sel_width-1 downto 0);
    
    --constants to parse flits
    constant data_msb       : integer := data_width-1;
    constant data_lsb       : integer := 0;
    constant vc_msb         : integer := vc_sel_width+data_width-1;
    constant vc_lsb         : integer := data_width;
    constant addr_msb       : integer := vc_sel_width+data_width+addr_width-1;
    constant addr_lsb       : integer := vc_sel_width+data_width;
    constant is_tail_index  : integer := vc_sel_width+data_width+addr_width;
    constant is_valid_index : integer := vc_sel_width+data_width+addr_width+1;
	 constant flit_size      : integer := vc_sel_width+data_width+addr_width+2;

begin

    ---------------------------------------------------------------------------
    --RECEIVE SIDE ------------------------------------------------------------
    ---------------------------------------------------------------------------
    
    -- create and map 1 buffer for each VC
    receive_buffer: for i in num_vc-1 downto 0 generate
        signal vc_select  : integer;
        signal flit_valid : std_logic;
    begin
        ur_i: fifo_buffer generic map(data_width+addr_width+vc_sel_width+2, flit_buff_depth)
								  port map(write_vc(i), read_vc(i), buffer_full_vc(i), buffer_empty_vc(i), 
                                   enqueue_vc(i), dequeue_vc(i), clk, rst);
                          
                         
        vc_select     <= to_integer(unsigned(recv_getFlit(vc_msb downto vc_lsb)));
        flit_valid    <= recv_getFlit(is_valid_index);
        write_vc(i)   <= recv_getFlit when i = vc_select else std_logic_vector(to_unsigned(0,flit_size));
        enqueue_vc(i) <= flit_valid when i = vc_select else '0'; 
    
    end generate;
    
    -- IO for receive side of controller
    EN_recv_getFlit <= '1'; -- always read to receive flits as long as buffers aren't full
    recv_putNonFullVCs_nonFullVCs <= not buffer_full_vc;
    data_in_buffer <= not buffer_empty_vc;
    recv_data <= read_vc(to_integer(unsigned(select_vc_read)))(data_msb downto data_lsb);
    dequeue_vc <= dequeue;
    is_tail_flit <= read_vc(to_integer(unsigned(select_vc_read)))(is_tail_index);
    src_addr <= read_vc(to_integer(unsigned(select_vc_read)))(addr_msb downto addr_lsb);
    EN_recv_putNonFullVCs <= '1'; -- readme is not clear about what this does, assuming it is not need for peek flow control
    
    ---------------------------------------------------------------------------
    --SEND SIDE ---------------------------------------------------------------
    ---------------------------------------------------------------------------
    
  -------- priority encoder to determine which vc to use
  ------us_0: priority_encoder generic map(vc_sel_width)
	------                       port map(send_getNonFullVCs, selected_vc);                           
  ------
  ------
  -------- IO for sending side of controller
  ------send_putFlit_flit_in <= send_flit & set_tail_flit & dest_addr & selected_vc & send_data;
  --------ready_to_send <= '0' when to_integer(unsigned(send_getNonFullVCs)) = 0 else '1';
	------ready_to_send <= or_reduce(send_getNonFullVCs);
  ------EN_send_putFlit <= send_flit;
  ------EN_send_getNonFullVCs <= '1'; --always read to recieve credits
  ------
  ------

    -- test version which only sends on VC0
    -- priority encoder to determine which vc to use
    selected_vc <= (others => '0');                         
    
    
    -- IO for sending side of controller
    send_putFlit_flit_in <= send_flit & set_tail_flit & dest_addr & selected_vc & send_data;
	 ready_to_send <= send_getNonFullVCs(0);
    EN_send_putFlit <= send_flit;
    EN_send_getNonFullVCs <= '1'; --always read to recieve credits  
    
    
    
end architecture structural;
