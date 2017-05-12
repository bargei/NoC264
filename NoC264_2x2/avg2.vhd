-- Inter-Prediction Interpolator Filter
-- see ITU Std. 8.4.2.2.1 and 8.4.2.2.2

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;

entity avg2 is 
port(
    x0  :  in  std_logic_vector(7 downto 0);
    x1  :  in  std_logic_vector(7 downto 0);
    y   :  out std_logic_vector(7 downto 0)
);
end entity avg2;

architecture rtl of avg2 is
    
    signal sum    : unsigned(8 downto 0);
    signal y_extd : std_logic_vector(8 downto 0);
    
begin
    
    sum <= unsigned("0" & x0) + unsigned("0" & x1) + to_unsigned(1, 9);
    y_extd   <= std_logic_vector(shift_right(sum, 1));
    y <= y_extd( 7 downto 0);
    
end architecture rtl;