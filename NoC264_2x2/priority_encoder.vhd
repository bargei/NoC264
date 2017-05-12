library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity priority_encoder is
generic(
    encoded_word_size : integer := 2
);
Port(
    input    : in  std_logic_vector(2**encoded_word_size-1 downto 0);
    output   : out std_logic_vector(encoded_word_size-1 downto 0)
	 
);
end entity priority_encoder;

architecture rtl of priority_encoder is
    signal any_previous     : std_logic_vector(2**encoded_word_size-1 downto 0);
    signal highest_bit_only : std_logic_vector(2**encoded_word_size-1 downto 0);
    type   encoded_sig_type is array(2**encoded_word_size-1 downto 0) of std_logic_vector(encoded_word_size-1 downto 0);
    signal encoded_sig   : encoded_sig_type;
    
begin
    
    --- -- Convert to a one hot encoding
    --- highest_bit_only(2**encoded_word_size-1) <= input(2**encoded_word_size-1);
    --- any_previous(2**encoded_word_size-1) <= input(2**encoded_word_size-1);
    --- one_hot_gen: for i in 2**encoded_word_size-2 downto 0 generate
    --- begin
    ---     any_previous(i) <= input(i) or any_previous(i+1);
    ---     highest_bit_only(i) <= input(i) and not any_previous(i+1);
    --- end generate;
    --- 
    --- -- create lookup table to convert from one hot to bin
    --- -- will be sparse, but I'll trust the compiler for now
    --- one_hot_to_bin <= (others => (others => '0'));
    --- encode_lut: for i in encoded_word_size-1 downto 0 generate
    ---     constant output_value : std_logic_vector := std_logic_vector(to_unsigned(i,encoded_word_size));
    ---     constant lut_index : integer := 2**i;
    --- begin
    ---     one_hot_to_bin(lut_index) <= output_value;
    --- end generate;
    --- 
    --- -- output
    --- output <= one_hot_to_bin(to_integer(unsigned(highest_bit_only)));
    
	 --process(input)
	 --    variable keep_looking : std_logic := '1';
	 --begin
	 --    for i in 2**encoded_word_size-1 downto 0 loop
    --        if input(i) = '1' and keep_looking = '1' then
    --            output <= std_logic_vector(to_unsigned(i, encoded_word_size));
    --			 keep_looking := '0';
    --        end if;
	 --    end loop;
	 --end process;
	 
	 
	 any_previous(2**encoded_word_size-1) <= input(2**encoded_word_size-1);
	 encoded_sig(2**encoded_word_size-1) <=  std_logic_vector(to_unsigned(2**encoded_word_size-1, encoded_word_size));
    encode: for i in 2**encoded_word_size-2 downto 0 generate
    begin
        any_previous(i) <= input(i) or any_previous(i+1);
        encoded_sig(i) <= std_logic_vector(to_unsigned(i, encoded_word_size)) when any_previous(i+1) = '0' else encoded_sig(i+1);
    end generate;
	 
	 output <= encoded_sig(0);
	 
	 
	 
	 
end architecture rtl;