library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;


entity intra_prediction_core is
port(
    clk                 : in  std_logic;
    rst                 : in  std_logic;

    --interface to enable "set samples" command
    sample_data         : in  std_logic_vector(31 downto 0);
    sample_write_addr   : in  unsigned(7 downto 0);
    sample_write_enable : in  std_logic;

    --interface to enable "perform prediction" command
    block_size          : in  unsigned(7 downto   0);
    mode                : in  unsigned(7 downto   0);
    row_addr            : in  unsigned(7 downto   0);
    availible_mask      : in  std_logic_vector(31 downto 0);
    row_data            : out unsigned(127 downto 0)
);
end entity intra_prediction_core;

architecture rtl of intra_prediction_core is
    
    constant dc_default : unsigned := "0000000010000000";
    
    type row is array(15 downto 0) of unsigned(7 downto 0);
    type macroblock_type is array (15 downto 0) of row;
    signal macroblock : macroblock_type;
    
    type sample_reg is array(8 downto 0) of std_logic_vector(31 downto 0);
    signal samples_d, samples_q : sample_reg;
    
    type samples_type is array(32 downto 0) of std_logic_vector(7 downto 0);
    signal the_samples : samples_type;
    
    type sample_array_row is array(16 downto 0) of unsigned(9 downto 0);
    type sample_array_type     is array(16 downto 0) of sample_array_row;
    signal sample_array : sample_array_type;
    
    signal dc_4_value  : unsigned(15 downto 0);
    signal dc_8_value  : unsigned(15 downto 0);
    signal dc_16_value : unsigned(15 downto 0);
    signal dc_value    : unsigned(9  downto 0);
    
    type plane_value_row_type is array(16 downto 0) of signed(33 downto 0);
    type plane_value_array_type is array(16 downto 0) of plane_value_row_type;
    type plane_hv_type is array(7 downto 0) of signed(17 downto 0);
    signal h,v         : plane_hv_type;
    signal a,b,c       : signed(25 downto 0);
    
begin
    --register file for holding sample data
    reg_file: process(clk, rst) begin
         if rst = '1' then
              samples_q <= (others => (others => '0'));
         elsif rising_edge(clk) then
              samples_q <= samples_d;
         end if;
    end process;

    reg_file_update: for i in 8 downto 0 generate
         samples_d(i) <= sample_data when sample_write_enable = '1' and i = to_integer(unsigned(sample_write_addr))
                              else samples_q(i);
    end generate;

    --place neighbor samples into sample array
    --     y\x-->
    --     | \   |<--0--->|  |<--1--->|  |<--2--->|  |<--3--->|  |<-4->|
    --     |  \  0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16
    --     |   \___________________________________________________
    --___  V 0  |0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16
    --       1  |17 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    -- 5     2  |18 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    --       3  |19 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    --___    4  |20 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    --       5  |21 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    -- 6     6  |22 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    --       7  |23 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    --___    8  |24 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    --       9  |25 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    -- 7    10  |26 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    --      11  |27 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    --___   12  |28 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    --      13  |29 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    -- 8    14  |30 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    --      15  |31 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb
    --___   16  |32 mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb mb

    the_samples(0)  <= samples_q(0)(31 downto 24);
    the_samples(1)  <= samples_q(0)(23 downto 16);
    the_samples(2)  <= samples_q(0)(15 downto 8 );
    the_samples(3)  <= samples_q(0)(7  downto 0 );
    the_samples(4)  <= samples_q(1)(31 downto 24);
    the_samples(5)  <= samples_q(1)(23 downto 16);
    the_samples(6)  <= samples_q(1)(15 downto 8 );
    the_samples(7)  <= samples_q(1)(7  downto 0 );
    the_samples(8)  <= samples_q(2)(31 downto 24);
    the_samples(9)  <= samples_q(2)(23 downto 16);
    the_samples(10) <= samples_q(2)(15 downto 8 );
    the_samples(11) <= samples_q(2)(7  downto 0 );
    the_samples(12) <= samples_q(3)(31 downto 24);
    the_samples(13) <= samples_q(3)(23 downto 16);
    the_samples(14) <= samples_q(3)(15 downto 8 );
    the_samples(15) <= samples_q(3)(7  downto 0 );
    the_samples(16) <= samples_q(4)(7  downto 0 );
    the_samples(17) <= samples_q(5)(31 downto 24);
    the_samples(18) <= samples_q(5)(23 downto 16);
    the_samples(19) <= samples_q(5)(15 downto 8 );
    the_samples(20) <= samples_q(5)(7  downto 0 );
    the_samples(21) <= samples_q(6)(31 downto 24);
    the_samples(22) <= samples_q(6)(23 downto 16);
    the_samples(23) <= samples_q(6)(15 downto 8 );
    the_samples(24) <= samples_q(6)(7  downto 0 );
    the_samples(25) <= samples_q(7)(31 downto 24);
    the_samples(26) <= samples_q(7)(23 downto 16);
    the_samples(27) <= samples_q(7)(15 downto 8 );
    the_samples(28) <= samples_q(7)(7  downto 0 );
    the_samples(29) <= samples_q(8)(31 downto 24);
    the_samples(30) <= samples_q(8)(23 downto 16);
    the_samples(31) <= samples_q(8)(15 downto 8 );
    the_samples(32) <= samples_q(8)(7  downto 0 );



    sample_array( 0  )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 0  )));
    sample_array( 0  )( 1  ) <= unsigned(std_logic_vector'("00"&the_samples( 1  )));
    sample_array( 0  )( 2  ) <= unsigned(std_logic_vector'("00"&the_samples( 2  )));
    sample_array( 0  )( 3  ) <= unsigned(std_logic_vector'("00"&the_samples( 3  )));
    sample_array( 0  )( 4  ) <= unsigned(std_logic_vector'("00"&the_samples( 4  )));
    sample_array( 0  )( 5  ) <= unsigned(std_logic_vector'("00"&the_samples( 5  )));
    sample_array( 0  )( 6  ) <= unsigned(std_logic_vector'("00"&the_samples( 6  )));
    sample_array( 0  )( 7  ) <= unsigned(std_logic_vector'("00"&the_samples( 7  )));
    sample_array( 0  )( 8  ) <= unsigned(std_logic_vector'("00"&the_samples( 8  )));
    sample_array( 0  )( 9  ) <= unsigned(std_logic_vector'("00"&the_samples( 9  )));
    sample_array( 0  )( 10 ) <= unsigned(std_logic_vector'("00"&the_samples( 10 )));
    sample_array( 0  )( 11 ) <= unsigned(std_logic_vector'("00"&the_samples( 11 )));
    sample_array( 0  )( 12 ) <= unsigned(std_logic_vector'("00"&the_samples( 12 )));
    sample_array( 0  )( 13 ) <= unsigned(std_logic_vector'("00"&the_samples( 13 )));
    sample_array( 0  )( 14 ) <= unsigned(std_logic_vector'("00"&the_samples( 14 )));
    sample_array( 0  )( 15 ) <= unsigned(std_logic_vector'("00"&the_samples( 15 )));
    sample_array( 0  )( 16 ) <= unsigned(std_logic_vector'("00"&the_samples( 16 )));
    sample_array( 1  )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 17 )));
    sample_array( 2  )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 18 )));
    sample_array( 3  )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 19 )));
    sample_array( 4  )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 20 )));
    sample_array( 5  )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 21 )));
    sample_array( 6  )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 22 )));
    sample_array( 7  )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 23 )));
    sample_array( 8  )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 24 )));
    sample_array( 9  )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 25 )));
    sample_array( 10 )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 26 )));
    sample_array( 11 )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 27 )));
    sample_array( 12 )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 28 )));
    sample_array( 13 )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 29 )));
    sample_array( 14 )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 30 )));
    sample_array( 15 )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 31 )));
    sample_array( 16 )( 0  ) <= unsigned(std_logic_vector'("00"&the_samples( 32 )));

    --calculate dc values
    dc_4_value  <=  shift_right(("000000"&sample_array(1)(0)) +
                                ("000000"&sample_array(2)(0)) +
                                ("000000"&sample_array(3)(0)) +
                                ("000000"&sample_array(4)(0)) +
                                ("000000"&sample_array(0)(1)) +
                                ("000000"&sample_array(0)(2)) +
                                ("000000"&sample_array(0)(3)) +
                                ("000000"&sample_array(0)(4)) +
                                to_unsigned(4, 16), 3)        when (and_reduce(availible_mask(31 downto 28))         and
                                                                    and_reduce(availible_mask(15 downto 12))) = '1'  else
                    shift_right(("000000"&sample_array(1)(0)) +
                                ("000000"&sample_array(2)(0)) +
                                ("000000"&sample_array(3)(0)) +
                                ("000000"&sample_array(4)(0)) +
                                to_unsigned(2, 16), 2)        when and_reduce(availible_mask(31 downto 28)) = '1' else
                    shift_right(("000000"&sample_array(0)(1)) +
                                ("000000"&sample_array(0)(2)) +
                                ("000000"&sample_array(0)(3)) +
                                ("000000"&sample_array(0)(4)) +
                                to_unsigned(2, 16), 2)        when and_reduce(availible_mask(15 downto 12)) = '1' else
                    dc_default;
    --dc_8_value   <= shift_right(("000000"&sample_array(1)(0)) +
    --                            ("000000"&sample_array(2)(0)) +
    --                            ("000000"&sample_array(3)(0)) +
    --                            ("000000"&sample_array(4)(0)) +
    --                            ("000000"&sample_array(5)(0)) +
    --                            ("000000"&sample_array(6)(0)) +
    --                            ("000000"&sample_array(7)(0)) +
    --                            ("000000"&sample_array(8)(0)) +
    --                            ("000000"&sample_array(0)(1)) +
    --                            ("000000"&sample_array(0)(2)) +
    --                            ("000000"&sample_array(0)(3)) +
    --                            ("000000"&sample_array(0)(4)) +
    --                            ("000000"&sample_array(0)(5)) +
    --                            ("000000"&sample_array(0)(6)) +
    --                            ("000000"&sample_array(0)(7)) +
    --                            ("000000"&sample_array(0)(8)) +
    --                            to_unsigned(8, 16), 4)        when (and_reduce(availible_mask(31 downto 24)) and
    --                                                                            and_reduce(availible_mask(15 downto 8))) = '1'  else
    --                shift_right(("000000"&sample_array(1)(0)) +
    --                            ("000000"&sample_array(2)(0)) +
    --                            ("000000"&sample_array(3)(0)) +
    --                            ("000000"&sample_array(4)(0)) +
    --                            ("000000"&sample_array(4)(0)) +
    --                            ("000000"&sample_array(5)(0)) +
    --                            ("000000"&sample_array(6)(0)) +
    --                            ("000000"&sample_array(7)(0)) +
    --                            ("000000"&sample_array(8)(0)) +
    --                            to_unsigned(4, 16), 3)        when and_reduce(availible_mask(31 downto 24)) = '1' else
    --                 shift_right(("000000"&sample_array(0)(1)) +
    --                             ("000000"&sample_array(0)(2)) +
    --                             ("000000"&sample_array(0)(3)) +
    --                             ("000000"&sample_array(0)(4)) +
    --                             ("000000"&sample_array(0)(4)) +
    --                             ("000000"&sample_array(0)(5)) +
    --                             ("000000"&sample_array(0)(6)) +
    --                             ("000000"&sample_array(0)(7)) +
    --                             ("000000"&sample_array(0)(8)) +
    --                             to_unsigned(4, 16), 3)        when and_reduce(availible_mask(15 downto 8)) = '1' else
    --                        dc_default;
    dc_16_value <=  shift_right(("000000"&sample_array(1 )(0)) +
                                ("000000"&sample_array(2 )(0)) +
                                ("000000"&sample_array(3 )(0)) +
                                ("000000"&sample_array(4 )(0)) +
                                ("000000"&sample_array(5 )(0)) +
                                ("000000"&sample_array(6 )(0)) +
                                ("000000"&sample_array(7 )(0)) +
                                ("000000"&sample_array(8 )(0)) +
                                ("000000"&sample_array(9 )(0)) +
                                ("000000"&sample_array(10)(0)) +
                                ("000000"&sample_array(11)(0)) +
                                ("000000"&sample_array(12)(0)) +
                                ("000000"&sample_array(13)(0)) +
                                ("000000"&sample_array(14)(0)) +
                                ("000000"&sample_array(15)(0)) +
                                ("000000"&sample_array(16)(0)) +
                                ("000000"&sample_array(0)(1 )) +
                                ("000000"&sample_array(0)(2 )) +
                                ("000000"&sample_array(0)(3 )) +
                                ("000000"&sample_array(0)(4 )) +
                                ("000000"&sample_array(0)(5 )) +
                                ("000000"&sample_array(0)(6 )) +
                                ("000000"&sample_array(0)(7 )) +
                                ("000000"&sample_array(0)(8 )) +
                                ("000000"&sample_array(0)(9 )) +
                                ("000000"&sample_array(0)(10)) +
                                ("000000"&sample_array(0)(11)) +
                                ("000000"&sample_array(0)(12)) +
                                ("000000"&sample_array(0)(13)) +
                                ("000000"&sample_array(0)(14)) +
                                ("000000"&sample_array(0)(15)) +
                                ("000000"&sample_array(0)(16)) +
                                to_unsigned(16, 16), 5)        when and_reduce(availible_mask(31 downto 0)) = '1' else
                    shift_right(("000000"&sample_array(1 )(0)) +
                                ("000000"&sample_array(2 )(0)) +
                                ("000000"&sample_array(3 )(0)) +
                                ("000000"&sample_array(4 )(0)) +
                                ("000000"&sample_array(5 )(0)) +
                                ("000000"&sample_array(6 )(0)) +
                                ("000000"&sample_array(7 )(0)) +
                                ("000000"&sample_array(8 )(0)) +
                                ("000000"&sample_array(9 )(0)) +
                                ("000000"&sample_array(10)(0)) +
                                ("000000"&sample_array(11)(0)) +
                                ("000000"&sample_array(12)(0)) +
                                ("000000"&sample_array(13)(0)) +
                                ("000000"&sample_array(14)(0)) +
                                ("000000"&sample_array(15)(0)) +
                                ("000000"&sample_array(16)(0)) +
                                to_unsigned(8, 16), 4)        when and_reduce(availible_mask(31 downto 16)) = '1' else
                    shift_right(("000000"&sample_array(0)(1 )) +
                                ("000000"&sample_array(0)(2 )) +
                                ("000000"&sample_array(0)(3 )) +
                                ("000000"&sample_array(0)(4 )) +
                                ("000000"&sample_array(0)(5 )) +
                                ("000000"&sample_array(0)(6 )) +
                                ("000000"&sample_array(0)(7 )) +
                                ("000000"&sample_array(0)(8 )) +
                                ("000000"&sample_array(0)(9 )) +
                                ("000000"&sample_array(0)(10)) +
                                ("000000"&sample_array(0)(11)) +
                                ("000000"&sample_array(0)(12)) +
                                ("000000"&sample_array(0)(13)) +
                                ("000000"&sample_array(0)(14)) +
                                ("000000"&sample_array(0)(15)) +
                                ("000000"&sample_array(0)(16)) +
                                to_unsigned(8, 16), 4)        when and_reduce(availible_mask(15 downto 0)) = '1' else
                                dc_default;
                    
    dc_value    <= dc_4_value(9 downto 0)  when block_size = to_unsigned(4,  8) else
                   --dc_8_value(9 downto 0)  when block_size = to_unsigned(8,  8) else
                   dc_16_value(9 downto 0)  when block_size = to_unsigned(16, 8) else
                   "1010101010"; --make errors obvious

    -- some values needed for plane mode
    a <= signed(shift_left( ("0000000000000000"&sample_array(0)(16)) + ("000000000000000"&sample_array(16)(0)), 4)) when block_size = 16 else
	      signed(shift_left( ("0000000000000000"&sample_array(0)(8 )) + ("000000000000000"&sample_array(8 )(0)), 4));
			
    b <= shift_right( to_signed(5, 8)  * h(7) + to_signed(32, 26) , 6) when block_size = 16 else
	      shift_right( to_signed(34, 8) * h(7) + to_signed(32, 26) , 6);
			
			
    c <= shift_right( to_signed(5, 8)  * v(7) + to_signed(32, 26) , 6)  when block_size = 16 else
			shift_right( to_signed(34, 8) * v(7) + to_signed(32, 26) , 6);

    v(0) <= to_signed(1, 8) * (signed(sample_array(9)(0)) - signed(sample_array(7)(0))) when block_size = 16 else
	         to_signed(1, 8) * (signed(sample_array(5)(0)) - signed(sample_array(3)(0)));
				
    h(0) <= to_signed(1, 8) * (signed(sample_array(0)(9)) - signed(sample_array(0)(7))) when block_size = 16 else
	         to_signed(1, 8) * (signed(sample_array(0)(5)) - signed(sample_array(0)(3)));
    calc_h_v_plane: for xy in 7 downto 1 generate
         v(xy) <= v(xy-1) + to_signed(xy+1,8) * (signed(sample_array(9+xy)(0)) - signed(sample_array(7-xy)(0))) when block_size = 16 else
			         v(xy-1) + to_signed(xy+1,8) * (signed(sample_array(5+xy)(0)) - signed(sample_array(3-xy)(0))) when block_size = 8 and xy <= 3 else
						v(xy-1);
			
         h(xy) <= h(xy-1) + to_signed(xy+1,8) * (signed(sample_array(0)(9+xy)) - signed(sample_array(0)(7-xy))) when block_size = 16 else
			         h(xy-1) + to_signed(xy+1,8) * (signed(sample_array(0)(5+xy)) - signed(sample_array(0)(3-xy))) when block_size = 8 and xy <= 3 else
						h(xy-1);
    end generate;

    --calculate predicted samples
    calculate_samples_row: for i in 16 downto 1 generate
        calculate_samples_col: for j in 16 downto 1 generate
             constant x               : integer := j-1;
             constant y               : integer := i-1;
             constant zVR             : integer := 2 * x - y;
             constant zVR_mod_2       : integer := zVR mod 2;
             constant zVR_sign        : integer := integer(sign(real(zVR)));

             constant zHD             : integer := 2 * y - x;
             constant zHD_mod_2       : integer := zHD mod 2;
             constant zHD_sign        : integer := integer(sign(real(zHD)));

             constant y_mod_2         : integer := y mod 2;

             constant zHU             : integer := x + 2 * y;
             constant zHU_mod_2       : integer := zHU mod 2;
             constant zHU_13_comp     : integer := integer(sign(real(zHU-13)));
				 
				 
				 
				 
             signal   plane_pre_clip  : plane_value_array_type;
             signal   plane_value     : sample_array_type;

        begin
            plane_pre_clip(i)(j) <= shift_right(("00000000"&a) + b * to_signed(x-7, 8) + c * to_signed(y-7, 8)  + to_signed(16, 34) , 5) when block_size = 16 else
				                        shift_right(("00000000"&a) + b * to_signed(x-3, 8) + c * to_signed(y-3, 8)  + to_signed(16, 34) , 5);
            plane_value(i)(j) <= to_unsigned(0,   10) when plane_pre_clip(i)(j) < to_signed(0,   34) else
                                        to_unsigned(255, 10) when plane_pre_clip(i)(j) > to_signed(255, 34) else
                                        unsigned(plane_pre_clip(i)(j)(9 downto 0));

            sample_array(i)(j) <=
                --vertical
                sample_array(i-1)(j)                                                                                                                                                                                when mode = 0 else                                                                                            

                --horizontal
                sample_array(i)(j-1)                                                                                                                                                                                when mode = 1 else                                                                                           

                --dc prediction
                dc_value                                                                                                                                                                                            when mode = 2 else

                --diag down left
                shift_right(sample_array(0)(7)                      + to_unsigned(3,2) * sample_array(0)(8)(7 downto 0)                                                                     + to_unsigned(2,10) , 2) when mode = 3 and block_size = 4 and x = 3 and y = 3 else
                shift_right(sample_array(0)((y+x+1) mod 17)         + to_unsigned(2,2) * sample_array(0)((y+x+2) mod 17)(7 downto 0)           + sample_array(0)((y+x+3) mod 17)            + to_unsigned(2,10) , 2) when mode = 3 and block_size = 4 and (not(x = 3 and y = 3))  and ((y+x+3) <= 16) else
                --shift_right(sample_array(0)(15)                     + to_unsigned(3,2) * sample_array(0)(16)(7 downto 0)                                                                    + to_unsigned(2,10) , 2) when mode = 3 and block_size = 8 and x = 7 and y = 7 else
                --shift_right(sample_array(0)((y+x+1) mod 17)         + to_unsigned(2,2) * sample_array(0)((y+x+2) mod 17)(7 downto 0)           + sample_array(0)((y+x+3) mod 17)            + to_unsigned(2,10) , 2) when mode = 3 and block_size = 8 and (not(x = 7 and y = 7)) and ((y+x+3) <= 16) else

                --diag down right
                shift_right(sample_array(abs(y-x-1))(0)             + to_unsigned(2,2) * sample_array(abs(y-x))(0)(7 downto 0)                 + sample_array(abs(y-x+1))(0)                + to_unsigned(2,10) , 2) when mode = 4 and (block_size = 4) and (y > x) and ((y-x-1) >= 0)else
                shift_right(sample_array(0)(abs(x-y-1))             + to_unsigned(2,2) * sample_array(0)(abs(x-y))(7 downto 0)                 + sample_array(0)(abs(x-y+1))                + to_unsigned(2,10) , 2) when mode = 4 and (block_size = 4) and (y < x) and ((x-y-1) >= 0)else
                shift_right(sample_array(1)(0)                      + to_unsigned(2,2) * sample_array(0)(0)(7 downto 0)                        + sample_array(0)(1)                         + to_unsigned(2,10) , 2) when mode = 4 and (block_size = 4) and (y = x) else
 
                --vertical right
                shift_right(sample_array(0)(abs(x - y/2   ) mod 17) +                    sample_array(0)(abs(x - y/2 + 1) mod 17)(7 downto 0)                                               + to_unsigned(1,10) , 1) when mode = 5 and (block_size = 4) and (zVR_mod_2 = 0) and ((x - y/2 ) >= 0) else
                shift_right(sample_array(0)(abs(x - y/2 -1) mod 17) + to_unsigned(2,2) * sample_array(0)(abs(x - y/2    ) mod 17)(7 downto 0)  + sample_array(0)(abs(x - y/2+1) mod 17)     + to_unsigned(2,10) , 2) when mode = 5 and (block_size = 4) and (zVR_mod_2 = 1) and ((x - y/2 -1) >= 0) else
                shift_right(sample_array(1)(0)                      + to_unsigned(2,2) * sample_array(0)(0)(7 downto 0)                        + sample_array(0)(1)                         + to_unsigned(2,10) , 2) when mode = 5 and (block_size = 4) and (zVR = -1) else
                shift_right(sample_array(y)(0)                      + to_unsigned(2,2) * sample_array(y-1)(0)(7 downto 0)                      + sample_array(y-2)(0)                       + to_unsigned(2,10) , 2) when mode = 5 and (block_size = 4) and (zVR < -1) and ((y-2) >= 0) else
					 
					 --horizontal down
                shift_right(sample_array(abs(y - x/2) mod 17)(0)    +                    sample_array(abs(y - x/2 + 1) mod 17)(0)(7 downto 0)                                               + to_unsigned(1,10) , 1) when mode = 6 and (block_size = 4) and (zHD_mod_2 = 0) and (zHD >= 0) and ((y - x/2) >= 0)else
                shift_right(sample_array(abs(y - x/2-1) mod 17)(0)  + to_unsigned(2,2) * sample_array(abs(y - x/2    ) mod 17)(0)(7 downto 0)  + sample_array(abs(y - x/2 + 1) mod 17)(0)   + to_unsigned(2,10) , 2) when mode = 6 and (block_size = 4) and (zHD_mod_2 = 1) and (zHD >= 0) and ((y - x/2 - 1) >= 0) else
                shift_right(sample_array(0)(1)                      + to_unsigned(2,2) * sample_array(0)(0)(7 downto 0)                        + sample_array(1)(0)                         + to_unsigned(2,10) , 2) when mode = 6 and (block_size = 4) and (zHD = -1) else
                shift_right(sample_array(0)(x)                      + to_unsigned(2,2) * sample_array(0)(x-1)(7 downto 0)                      + sample_array(0)(x-2)                       + to_unsigned(2,10) , 2) when mode = 6 and (block_size = 4) and (zHD < -1) and ((x-2) >= 0) else
                
                --vertical left
                shift_right(sample_array(0)((x + y /2 + 1) mod 17)  +                    sample_array(0)((x+y/2+2) mod 17)(7 downto 0)                                                      + to_unsigned(1,10) , 1) when mode = 7 and (block_size = 4) and y_mod_2  = 0 and ((x + y/2+2) <= 16) else
                shift_right(sample_array(0)((x + y /2 + 1) mod 17)  + to_unsigned(2,2) * sample_array(0)((x+y/2+2) mod 17)(7 downto 0)         + sample_array(0)((x+y/2+3) mod 17)          + to_unsigned(2,10) , 2) when mode = 7 and (block_size = 4) and y_mod_2 /= 0 and ((x + y/2+3) <= 16) else

                --horizontal up
                shift_right(sample_array((y + x/2 + 1) mod 17)(0)   +                    sample_array((y+x/2+2) mod 17)(0)(7 downto 0)                                                      + to_unsigned(1,10) , 1) when mode = 8 and ((block_size = 4 and zHU < 5) ) and (zHU >= 0) and zHU_mod_2 = 0 else
                shift_right(sample_array((y + x/2 + 1) mod 17)(0)   + to_unsigned(2,2) * sample_array((y+x/2+2) mod 17)(0)(7 downto 0)         + sample_array((y+x/2+3) mod 17)(0)          + to_unsigned(2,10) , 2) when mode = 8 and ((block_size = 4 and zHU < 5) ) and (zHU >= 0) and zHU_mod_2 = 1 else
                --shift_right(sample_array(7)(0)                      + to_unsigned(3,2) * sample_array(8)(0)(7 downto 0)                                                                     + to_unsigned(2,10) , 2) when mode = 8 and block_size  = 8                    and zHU = 13                                   else
                shift_right(sample_array(3)(0)                      + to_unsigned(3,2) * sample_array(4)(0)(7 downto 0)                                                                     + to_unsigned(2,10) , 2) when mode = 8 and block_size  = 4                    and zHU = 5                                    else                
					 --sample_array(8)(0)                                                                                                                                                                                   when mode = 8 and block_size = 8                     and zHU > 13                                   else
					 sample_array(4)(0)                                                                                                                                                                                   when mode = 8 and block_size = 4                     and zHU > 5                                    else
                
					 --plane
                plane_value(i)(j)                                                                                                                                                                                    when mode = 3 and  (block_size = 16 or block_size = 8) else
                "0000000001";	
        end generate;
    end generate;

    --assign calculated samples to output macro block
    assign_smpls_2_mb_row: for i in 15 downto 0 generate
        assign_smpls_2_mb_col: for j in 15 downto 0 generate
            macroblock(i)(j) <= sample_array(i+1)(j+1)(7 downto 0);
        end generate;
    end generate;

    --output selected macroblock row
    row_data <= macroblock(0 )(0)&macroblock(0 )(1)&macroblock(0 )(2)&macroblock(0 )(3)&macroblock(0 )(4)&macroblock(0 )(5)&macroblock(0 )(6)&macroblock(0 )(7)&macroblock(0 )(8)&macroblock(0 )(9)&macroblock(0 )(10)&macroblock(0 )(11)&macroblock(0 )(12)&macroblock(0 )(13)&macroblock(0 )(14)&macroblock(0 )(15) when row_addr = to_unsigned(0 , 8) else
                macroblock(1 )(0)&macroblock(1 )(1)&macroblock(1 )(2)&macroblock(1 )(3)&macroblock(1 )(4)&macroblock(1 )(5)&macroblock(1 )(6)&macroblock(1 )(7)&macroblock(1 )(8)&macroblock(1 )(9)&macroblock(1 )(10)&macroblock(1 )(11)&macroblock(1 )(12)&macroblock(1 )(13)&macroblock(1 )(14)&macroblock(1 )(15) when row_addr = to_unsigned(1 , 8) else
                macroblock(2 )(0)&macroblock(2 )(1)&macroblock(2 )(2)&macroblock(2 )(3)&macroblock(2 )(4)&macroblock(2 )(5)&macroblock(2 )(6)&macroblock(2 )(7)&macroblock(2 )(8)&macroblock(2 )(9)&macroblock(2 )(10)&macroblock(2 )(11)&macroblock(2 )(12)&macroblock(2 )(13)&macroblock(2 )(14)&macroblock(2 )(15) when row_addr = to_unsigned(2 , 8) else
                macroblock(3 )(0)&macroblock(3 )(1)&macroblock(3 )(2)&macroblock(3 )(3)&macroblock(3 )(4)&macroblock(3 )(5)&macroblock(3 )(6)&macroblock(3 )(7)&macroblock(3 )(8)&macroblock(3 )(9)&macroblock(3 )(10)&macroblock(3 )(11)&macroblock(3 )(12)&macroblock(3 )(13)&macroblock(3 )(14)&macroblock(3 )(15) when row_addr = to_unsigned(3 , 8) else
                macroblock(4 )(0)&macroblock(4 )(1)&macroblock(4 )(2)&macroblock(4 )(3)&macroblock(4 )(4)&macroblock(4 )(5)&macroblock(4 )(6)&macroblock(4 )(7)&macroblock(4 )(8)&macroblock(4 )(9)&macroblock(4 )(10)&macroblock(4 )(11)&macroblock(4 )(12)&macroblock(4 )(13)&macroblock(4 )(14)&macroblock(4 )(15) when row_addr = to_unsigned(4 , 8) else
                macroblock(5 )(0)&macroblock(5 )(1)&macroblock(5 )(2)&macroblock(5 )(3)&macroblock(5 )(4)&macroblock(5 )(5)&macroblock(5 )(6)&macroblock(5 )(7)&macroblock(5 )(8)&macroblock(5 )(9)&macroblock(5 )(10)&macroblock(5 )(11)&macroblock(5 )(12)&macroblock(5 )(13)&macroblock(5 )(14)&macroblock(5 )(15) when row_addr = to_unsigned(5 , 8) else
                macroblock(6 )(0)&macroblock(6 )(1)&macroblock(6 )(2)&macroblock(6 )(3)&macroblock(6 )(4)&macroblock(6 )(5)&macroblock(6 )(6)&macroblock(6 )(7)&macroblock(6 )(8)&macroblock(6 )(9)&macroblock(6 )(10)&macroblock(6 )(11)&macroblock(6 )(12)&macroblock(6 )(13)&macroblock(6 )(14)&macroblock(6 )(15) when row_addr = to_unsigned(6 , 8) else
                macroblock(7 )(0)&macroblock(7 )(1)&macroblock(7 )(2)&macroblock(7 )(3)&macroblock(7 )(4)&macroblock(7 )(5)&macroblock(7 )(6)&macroblock(7 )(7)&macroblock(7 )(8)&macroblock(7 )(9)&macroblock(7 )(10)&macroblock(7 )(11)&macroblock(7 )(12)&macroblock(7 )(13)&macroblock(7 )(14)&macroblock(7 )(15) when row_addr = to_unsigned(7 , 8) else
                macroblock(8 )(0)&macroblock(8 )(1)&macroblock(8 )(2)&macroblock(8 )(3)&macroblock(8 )(4)&macroblock(8 )(5)&macroblock(8 )(6)&macroblock(8 )(7)&macroblock(8 )(8)&macroblock(8 )(9)&macroblock(8 )(10)&macroblock(8 )(11)&macroblock(8 )(12)&macroblock(8 )(13)&macroblock(8 )(14)&macroblock(8 )(15) when row_addr = to_unsigned(8 , 8) else
                macroblock(9 )(0)&macroblock(9 )(1)&macroblock(9 )(2)&macroblock(9 )(3)&macroblock(9 )(4)&macroblock(9 )(5)&macroblock(9 )(6)&macroblock(9 )(7)&macroblock(9 )(8)&macroblock(9 )(9)&macroblock(9 )(10)&macroblock(9 )(11)&macroblock(9 )(12)&macroblock(9 )(13)&macroblock(9 )(14)&macroblock(9 )(15) when row_addr = to_unsigned(9 , 8) else
                macroblock(10)(0)&macroblock(10)(1)&macroblock(10)(2)&macroblock(10)(3)&macroblock(10)(4)&macroblock(10)(5)&macroblock(10)(6)&macroblock(10)(7)&macroblock(10)(8)&macroblock(10)(9)&macroblock(10)(10)&macroblock(10)(11)&macroblock(10)(12)&macroblock(10)(13)&macroblock(10)(14)&macroblock(10)(15) when row_addr = to_unsigned(10, 8) else
                macroblock(11)(0)&macroblock(11)(1)&macroblock(11)(2)&macroblock(11)(3)&macroblock(11)(4)&macroblock(11)(5)&macroblock(11)(6)&macroblock(11)(7)&macroblock(11)(8)&macroblock(11)(9)&macroblock(11)(10)&macroblock(11)(11)&macroblock(11)(12)&macroblock(11)(13)&macroblock(11)(14)&macroblock(11)(15) when row_addr = to_unsigned(11, 8) else
                macroblock(12)(0)&macroblock(12)(1)&macroblock(12)(2)&macroblock(12)(3)&macroblock(12)(4)&macroblock(12)(5)&macroblock(12)(6)&macroblock(12)(7)&macroblock(12)(8)&macroblock(12)(9)&macroblock(12)(10)&macroblock(12)(11)&macroblock(12)(12)&macroblock(12)(13)&macroblock(12)(14)&macroblock(12)(15) when row_addr = to_unsigned(12, 8) else
                macroblock(13)(0)&macroblock(13)(1)&macroblock(13)(2)&macroblock(13)(3)&macroblock(13)(4)&macroblock(13)(5)&macroblock(13)(6)&macroblock(13)(7)&macroblock(13)(8)&macroblock(13)(9)&macroblock(13)(10)&macroblock(13)(11)&macroblock(13)(12)&macroblock(13)(13)&macroblock(13)(14)&macroblock(13)(15) when row_addr = to_unsigned(13, 8) else
                macroblock(14)(0)&macroblock(14)(1)&macroblock(14)(2)&macroblock(14)(3)&macroblock(14)(4)&macroblock(14)(5)&macroblock(14)(6)&macroblock(14)(7)&macroblock(14)(8)&macroblock(14)(9)&macroblock(14)(10)&macroblock(14)(11)&macroblock(14)(12)&macroblock(14)(13)&macroblock(14)(14)&macroblock(14)(15) when row_addr = to_unsigned(14, 8) else
                macroblock(15)(0)&macroblock(15)(1)&macroblock(15)(2)&macroblock(15)(3)&macroblock(15)(4)&macroblock(15)(5)&macroblock(15)(6)&macroblock(15)(7)&macroblock(15)(8)&macroblock(15)(9)&macroblock(15)(10)&macroblock(15)(11)&macroblock(15)(12)&macroblock(15)(13)&macroblock(15)(14)&macroblock(15)(15) when row_addr = to_unsigned(15, 8) else
                to_unsigned(0, 128);
    --row_data <= (others => '1');

end architecture rtl;