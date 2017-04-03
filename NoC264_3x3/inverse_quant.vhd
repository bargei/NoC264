library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;

entity inverse_quant is
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
end entity inverse_quant;

architecture initial of inverse_quant is
    
    --- TYPES -----------------------------------------------------------------
    type block_type is array(15 downto 0) of integer;
    
    --- CONSTANTS -------------------------------------------------------------
    constant factor_table_entry_0 : block_type := (10,13,10,13,13,16,13,16,10,13,10,13,13,16,13,16);
    constant factor_table_entry_1 : block_type := (11,14,11,14,14,18,14,18,11,14,11,14,14,18,14,18);
    constant factor_table_entry_2 : block_type := (13,16,13,16,16,20,16,20,13,16,13,16,16,20,16,20);
    constant factor_table_entry_3 : block_type := (14,18,14,18,18,23,18,23,14,18,14,18,18,23,18,23);
    constant factor_table_entry_4 : block_type := (16,20,16,20,20,25,20,25,16,20,16,20,20,25,20,25);
    constant factor_table_entry_5 : block_type := (18,23,18,23,23,29,23,29,18,23,18,23,23,29,23,29);

    
    --- SIGNALS ---------------------------------------------------------------
    signal quantization_bits : integer;
    signal quantized_block   : block_type;
    signal dequantized_block : block_type;
    signal block_item_signs  : block_type;
    signal the_factors       : block_type;
    signal factor_selector   : integer;
    signal quant_shift       : signed(31 downto 0);

begin

    -- determine correct factor table entry to use
    factor_selector <= to_integer(unsigned( quant_param )) mod 6;
    the_factors <= factor_table_entry_0 when factor_selector = 0 else
                   factor_table_entry_1 when factor_selector = 1 else
                   factor_table_entry_2 when factor_selector = 2 else
                   factor_table_entry_3 when factor_selector = 3 else
                   factor_table_entry_4 when factor_selector = 4 else
                   factor_table_entry_5;
    
    -- parse the input into integers
    -- and find the signs
    signs: for i in 15 downto 0 generate
        constant lower_index : integer := i * in_sample_width;
        constant upper_index : integer := lower_index + in_sample_width - 1;
    begin
        quantized_block(i)  <= to_integer(signed( quantized_samples(upper_index downto lower_index) ));
        block_item_signs(i) <= -1 when quantized_block(i) < 0 else 1; 
    end generate;
    
    --perform the algorithm on samples 15..1
    quantization_bits <= to_integer(signed(quant_param))/6;
    quant_shift <= shift_left(to_signed(1,32), quantization_bits);
    
    alg: for i in 15 downto 1 generate
    begin
        dequantized_block(i) <= block_item_signs(i) * 
            (abs(quantized_block(i)) * the_factors(15-i) * to_integer(quant_shift)
            );
    end generate;

    --perform the algorithm on the special case of 0
    dequantized_block(0) <= quantized_block(0) when or_reduce(without_dc) = '1' else 
                            block_item_signs(0) * 
                            (abs(quantized_block(0)) * 
                            the_factors(15) *
                            to_integer(quant_shift)
                            );
                            
    --format the output
    output: for i in 15 downto 0 generate
        constant lower_index : integer := i * out_sample_width;
        constant upper_index : integer := lower_index + out_sample_width - 1;
    begin
        dequant_samples(upper_index downto lower_index) <= std_logic_vector(to_signed(dequantized_block(i), out_sample_width));
    end generate;

end architecture initial;