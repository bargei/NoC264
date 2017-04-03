-- Inter-Prediction Interpolator Filter
-- see ITU Std. 8.4.2.2.1 and 8.4.2.2.2

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;

entity half_pixel_interpolator_fir is 
port(
    x0  :  in  std_logic_vector(7 downto 0);
    x1  :  in  std_logic_vector(7 downto 0);
    x2  :  in  std_logic_vector(7 downto 0);
    x3  :  in  std_logic_vector(7 downto 0);
    x4  :  in  std_logic_vector(7 downto 0);
    x5  :  in  std_logic_vector(7 downto 0);
    y   :  out std_logic_vector(7 downto 0)
);
end entity half_pixel_interpolator_fir;

architecture dsp of half_pixel_interpolator_fir is
    --interpolation equation
    --y_1 = x0 -5*x1 + 20*x2 + 20*x3 - 5*x4 + x5
    --y   = clip1((y_1 + 16)>>5)
     
    signal x0_u : unsigned(31 downto 0);
    signal x1_u : unsigned(15 downto 0);
    signal x2_u : unsigned(15 downto 0);
    signal x3_u : unsigned(15 downto 0);
    signal x4_u : unsigned(15 downto 0);
    signal x5_u : unsigned(31 downto 0);
    
    signal y_a  : unsigned(31 downto 0);
    signal y_b  : unsigned(31 downto 0);
    signal y_c  : std_logic_vector(31 downto 0);
     
     
begin

    x0_u <= unsigned(X"000000" & x0);
    x1_u <= unsigned(X"00"     & x1);
    x2_u <= unsigned(X"00"     & x2);
    x3_u <= unsigned(X"00"     & x3);
    x4_u <= unsigned(X"00"     & x4);
    x5_u <= unsigned(X"000000" & x5);
    
    y_a <= x0_u                       - 
           to_unsigned(5, 16)  * x1_u + 
           to_unsigned(20, 16) * x2_u + 
           to_unsigned(20, 16) * x3_u - 
           to_unsigned(5, 16)  * x4_u + 
           x5_u;
             
    y_b <= shift_right(y_a, 5);
    
    y_c <= std_logic_vector(y_b);
    
    y <= y_c(7 downto 0)                     when y_b >= to_unsigned(0, 16) and y_b <= to_unsigned(255, 16) else
         std_logic_vector(to_unsigned(0, 8)) when y_b <  to_unsigned(0, 16) else
         std_logic_vector(to_unsigned(255, 8));  
    

end architecture dsp;

