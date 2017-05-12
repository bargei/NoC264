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

--architecture rtl of half_pixel_interpolator_fir is
--    
--    --interpolation equation
--    --y_1 = x0 -5*x1 + 20*x2 + 20*x3 - 5*x4 + x5
--    --y   = clip1((y_1 + 16)>>5)
--    signal x0_times_1  : unsigned(15 downto 0);
--    signal x1_times_4  : unsigned(9 downto 0);
--    signal x1_times_5  : unsigned(15 downto 0);
--    signal x2_times_4  : unsigned(9 downto 0);
--    signal x2_times_16 : unsigned(11 downto 0);
--    signal x2_times_20 : unsigned(15 downto 0);
--    signal x3_times_4  : unsigned(9 downto 0);
--    signal x3_times_16 : unsigned(11 downto 0);
--    signal x3_times_20 : unsigned(15 downto 0);
--    signal x4_times_4  : unsigned(9 downto 0);
--    signal x4_times_5  : unsigned(15 downto 0);    
--    signal x5_times_1  : unsigned(15 downto 0);
--    
--    signal y_1         : unsigned(15 downto 0);
--    signal y_1_sr_5    : unsigned(15 downto 0);
--    signal y_candidate : std_logic_vector(15 downto 0);
--begin
--    
--    x0_times_1  <= unsigned("00000000" & x0);
--    
--    x1_times_4  <= shift_left(unsigned("00" & x1),2);
--    x1_times_5  <= unsigned("00000000" & x1) + x1_times_4;
--    
--    x2_times_4  <= shift_left(unsigned("00" & x2), 2); 
--    x2_times_16 <= shift_left(unsigned("0000" & x2), 4); 
--    x2_times_20 <= unsigned("0000" & std_logic_vector(x2_times_16)) + x2_times_4;
--    
--    x3_times_4  <= shift_left(unsigned("00" & x3  ), 2); 
--    x3_times_16 <= shift_left(unsigned("0000" & x3), 4); 
--    x3_times_20 <= unsigned("0000" & std_logic_vector(x3_times_16)) + x3_times_4;
--
--    x4_times_4  <= shift_left(unsigned("00" & x4), 2);
--    x4_times_5  <= unsigned("00000000" & x4) + x4_times_4;
--
--    x5_times_1  <= unsigned("00000000" & x5);
--    
--    y_1 <= x0_times_1 - x1_times_5 + x2_times_20 + x3_times_20 - x4_times_5 + x5_times_1;
--    y_1_sr_5 <= shift_right(y_1, 5);
--    y_candidate <= std_logic_vector(y_1_sr_5);
--    y <= y_candidate(7 downto 0)             when y_1_sr_5 >= to_unsigned(0, 16) and y_1_sr_5 <= to_unsigned(255, 16) else
--         std_logic_vector(to_unsigned(0, 8)) when y_1_sr_5 <  to_unsigned(0, 16) else
--         std_logic_vector(to_unsigned(255, 8));         
--    
--end architecture rtl;

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

