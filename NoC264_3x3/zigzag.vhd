library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;


entity zigzag is
generic(
    sample_width : integer := 8
);
port(
    x : in  std_logic_vector((16*sample_width)-1 downto 0);
    y : out std_logic_vector((16*sample_width)-1 downto 0)
);
end entity zigzag;

architecture rtl of zigzag is
    
    type block_type is array(15 downto 0) of integer;
    constant order : block_type := (0,1,4,8,5,2,3,6,9,12,13,10,7,11,14,15);
    
begin

    g0: for i in 15 downto 0 generate
        constant zigzag_i         : integer := order(15-i);
        constant pre_lower_index  : integer := i * sample_width;
        constant pre_upper_index  : integer := pre_lower_index + sample_width - 1;
        constant post_lower_index : integer := zigzag_i * sample_width;
        constant post_upper_index : integer := post_lower_index + sample_width - 1;
    begin
        
        y(post_upper_index downto post_lower_index) <= 
            x(pre_upper_index downto pre_lower_index);
        
    end generate;
    
end architecture rtl;