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
    any_previous(2**encoded_word_size-1) <= input(2**encoded_word_size-1);
    encoded_sig(2**encoded_word_size-1) <=  std_logic_vector(to_unsigned(2**encoded_word_size-1, encoded_word_size));
    encode: for i in 2**encoded_word_size-2 downto 0 generate
    begin
        any_previous(i) <= input(i) or any_previous(i+1);
        encoded_sig(i) <= std_logic_vector(to_unsigned(i, encoded_word_size)) when any_previous(i+1) = '0' else encoded_sig(i+1);
    end generate;
     
    output <= encoded_sig(0);

end architecture rtl;