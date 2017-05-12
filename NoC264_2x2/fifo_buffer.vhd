library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity fifo_buffer is
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
end entity fifo_buffer;

architecture behavioral of fifo_buffer is

    signal enqueue_pointer : integer;
    type buffer_type is array(buff_len-1 downto 0) of std_logic_vector(word_len-1 downto 0);
    signal the_buffer : buffer_type;
    signal buffer_full_sig : std_logic;
    signal buffer_empty_sig : std_logic;

begin

    --read/write to buffer
    process(clk, rst)
    begin
        if rst = '1' then
            enqueue_pointer <= 0;
            the_buffer <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if enqueue = '1' and buffer_full_sig = '0' then
                the_buffer(enqueue_pointer) <= write_data;
                enqueue_pointer <= enqueue_pointer + 1;
            end if;
            
            if dequeue = '1' and buffer_empty_sig = '0' then 
                enqueue_pointer <= enqueue_pointer - 1;
                the_buffer(buff_len-2 downto 0) <= the_buffer(buff_len-1 downto 1);
            end if;
        end if;
    end process;
            
    --output logic
    read_data        <= the_buffer(0);
    buffer_full_sig  <= '0' when enqueue_pointer < buff_len else '1';
    buffer_empty_sig <= '0' when enqueue_pointer > 0 else '1';
    buffer_full      <= buffer_full_sig;
    buffer_empty     <= buffer_empty_sig;
    
            
end architecture behavioral;