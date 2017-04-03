library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;

entity inter_core_reg_file is
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
end entity inter_core_reg_file;

architecture rtl of inter_core_reg_file is

    signal register_bits_d : std_logic_vector(size_x*size_y*sample_size-1 downto 0);
    signal register_bits_q : std_logic_vector(size_x*size_y*sample_size-1 downto 0);
    signal offset          : natural;
    signal rd_addr_x_int   : integer;
    signal rd_addr_y_int   : integer;

begin
    
    --register process
    process(clk, rst)
    begin
        if rst = '1' then
            register_bits_q <= (others => '0');
        elsif rising_edge(clk) then
            register_bits_q <= register_bits_d;
        end if;
    end process;
    
    --register update logic
    assert ((size_x*size_y) mod samples_per_wr) = 0 report "bad samples_per_wr" severity error;
    g0: for n in ((size_x*size_y)/samples_per_wr)-1 downto 0 generate
    
        constant x_location        : integer := n mod (size_x/samples_per_wr);
        constant y_location        : integer := n /  (size_x/samples_per_wr);
        
        constant vector_index_low  : integer := n * sample_size * samples_per_wr;
        constant vector_index_high : integer := vector_index_low + sample_size * samples_per_wr - 1;
        
    begin
    
        register_bits_d(vector_index_high downto vector_index_low) <= 
           (others => '0') when rst = '1' else
            wr_samples 
                                 when to_integer(unsigned(wr_addr_x)) = x_location 
                                 and  to_integer(unsigned(wr_addr_y)) = y_location
                                 and  wr_enable = '1' else
        register_bits_q(vector_index_high downto vector_index_low); 

    end generate;
    
    --read logic
    assert ((size_x - 4) mod interp_x) = 0 report "size_x/interp_x conflict" severity warning;
    assert ((size_y - 4) mod interp_y) = 0 report "size_y/interp_y conflict" severity warning;
    
    rd_addr_x_int <= to_integer(signed(rd_addr_x));
    rd_addr_y_int <= to_integer(signed(rd_addr_y));
    offset <= 256 when rd_addr_y_int = 4 else 0;
    
    g1: for n in (interp_y+5)-1 downto 0 generate   
        --indexes into the result vector
        constant bits_per_row    : integer := (interp_x+5) * sample_size;
        constant rd_samples_low  : integer := n * bits_per_row;
        constant rd_samples_high : integer := rd_samples_low + bits_per_row - 1;
        
        --indexes relative to offset of read data
        constant rel_lin_addr    : integer := n * size_x * sample_size;
        
    begin
        rd_samples(rd_samples_high downto rd_samples_low) <= register_bits_q(offset + rel_lin_addr + bits_per_row -1
                                                                            downto offset + rel_lin_addr);
    end generate;


end architecture rtl;