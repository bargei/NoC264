library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;

entity inverse_transform is
generic(
    in_sample_width  : integer := 16;
    out_sample_width : integer := 8
);
port(
    transform_block     : in  std_logic_vector((16*in_sample_width)-1 downto 0);
    inv_transform_block : out std_logic_vector((16*out_sample_width)-1 downto 0);
    sign_mask           : out std_logic_vector(15 downto 0)
);
end entity inverse_transform;

architecture initial of inverse_transform is
    
    --- TYPES -----------------------------------------------------------------
    type block_type is array(15 downto 0) of integer;
    
    --- SIGNALS ---------------------------------------------------------------
    signal input_block          : block_type;
    signal intermediate_block   : block_type;
    signal output_block         : block_type;
    signal inv_block            : block_type;
    
    --- CONSTANTS -------------------------------------------------------------

    
begin
    
    -- parse the input into integers
    parse: for i in 15 downto 0 generate
        constant lower_index : integer := i * in_sample_width;
        constant upper_index : integer := lower_index + in_sample_width - 1;
    begin
        input_block(i)  <= to_integer(signed( transform_block(upper_index downto lower_index) ));
    end generate;
    
    
    --the inverse transform
    g0: for i in 3 downto 0 generate
        constant col_0_index : integer := i * 4;
        constant col_1_index : integer := col_0_index + 1;
        constant col_2_index : integer := col_0_index + 2;
        constant col_3_index : integer := col_0_index + 3;
        constant idx         : integer := col_0_index;
        
        constant row_0_index : integer := i;
        constant row_1_index : integer := i + 4;
        constant row_2_index : integer := i + 8;
        constant row_3_index : integer := i + 12;
        
        
        
    begin
        intermediate_block(col_0_index) <= input_block(idx) + input_block(idx + 1)   + input_block(idx + 2) + input_block(idx + 3)/2;
        intermediate_block(col_1_index) <= input_block(idx) + input_block(idx + 1)/2 - input_block(idx + 2) - input_block(idx + 3);
        intermediate_block(col_2_index) <= input_block(idx) - input_block(idx + 1)/2 - input_block(idx + 2) + input_block(idx + 3);
        intermediate_block(col_3_index) <= input_block(idx) - input_block(idx + 1)   + input_block(idx + 2) - input_block(idx + 3)/2;
        
        inv_block(row_0_index)          <= (intermediate_block(i) + intermediate_block(i+8) + intermediate_block(i+4)   + intermediate_block(i+12)/2 + 32)/64;
        inv_block(row_1_index)          <= (intermediate_block(i) - intermediate_block(i+8) + intermediate_block(i+4)/2 - intermediate_block(i+12)   + 32)/64;
        inv_block(row_2_index)          <= (intermediate_block(i) - intermediate_block(i+8) - intermediate_block(i+4)/2 + intermediate_block(i+12)   + 32)/64;
        inv_block(row_3_index)          <= (intermediate_block(i) + intermediate_block(i+8) - intermediate_block(i+4)   - intermediate_block(i+12)/2 + 32)/64;
        
    end generate;

    --format the output
    output: for i in 15 downto 0 generate
        constant lower_index : integer := i * out_sample_width;
        constant upper_index : integer := lower_index + out_sample_width - 1;
    begin
    
        --output_block(i)       <= inv_block(i) when inv_block(i)<(2**(out_sample_width-1)) and inv_block(i)>(-1*(2**(out_sample_width-1))) else
        --                         (2**(out_sample_width-1)-1) when inv_block(i)>(-1*(2**(out_sample_width-1))) else 
        --                         (-1*(2**(out_sample_width-1)));
        output_block(i) <= abs(inv_block(i));
        sign_mask(i) <= '1' when inv_block(i) < 0 else '0';
        inv_transform_block(upper_index downto lower_index) <= std_logic_vector(to_unsigned(output_block(i), out_sample_width));
    end generate;
            
        
        
    
end architecture initial;