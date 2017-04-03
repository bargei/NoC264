library ieee;
use ieee.std_logic_1164.all;        
use ieee.numeric_std.all;

entity h264_deblock_filter_core is
    port(
        clk               : in  std_logic;
        rst               : in  std_logic;
        is_chroma         : in  std_logic;
        boundary_strength : in  signed(8 downto 0);
        p0                : in  signed(8 downto 0);
        p1                : in  signed(8 downto 0);
        p2                : in  signed(8 downto 0);
        p3                : in  signed(8 downto 0);
        q0                : in  signed(8 downto 0);
        q1                : in  signed(8 downto 0);
        q2                : in  signed(8 downto 0);
        q3                : in  signed(8 downto 0);
        alpha             : in  signed(8 downto 0);
        beta              : in  signed(8 downto 0);
        tc0               : in  signed(8 downto 0);
        p0_out            : out signed(8 downto 0);
        p1_out            : out signed(8 downto 0);
        p2_out            : out signed(8 downto 0);
        q0_out            : out signed(8 downto 0);
        q1_out            : out signed(8 downto 0);
        q2_out            : out signed(8 downto 0)
    );
end entity h264_deblock_filter_core;

architecture rtl of h264_deblock_filter_core is
    signal normal_filter          : boolean;
    signal strong_filter          : boolean;
    signal ap, aq                 : boolean;
    signal strong_filter_test     : boolean;
     
    signal basic_checks           : boolean; -- and of three test always needed
    signal extra_filter_normal_p  : boolean;
    signal extra_filter_normal_q  : boolean;
    
    signal p0_if_normal_filtd     : signed(15 downto 0);
    signal p1_if_normal_filtd     : signed(15 downto 0);
    signal q0_if_normal_filtd     : signed(15 downto 0);
    signal q1_if_normal_filtd     : signed(15 downto 0);
    
    signal p0_if_strong_filtd_0   : signed(15 downto 0);
    signal p1_if_strong_filtd_0   : signed(15 downto 0);
    signal p2_if_strong_filtd_0   : signed(15 downto 0);
    signal q0_if_strong_filtd_0   : signed(15 downto 0);
    signal q1_if_strong_filtd_0   : signed(15 downto 0);
    signal q2_if_strong_filtd_0   : signed(15 downto 0);
    
    signal p0_if_strong_filtd_1   : signed(15 downto 0);
    signal p1_if_strong_filtd_1   : signed(15 downto 0);
    signal p2_if_strong_filtd_1   : signed(15 downto 0);
    signal q0_if_strong_filtd_1   : signed(15 downto 0);
    signal q1_if_strong_filtd_1   : signed(15 downto 0);
    signal q2_if_strong_filtd_1   : signed(15 downto 0);
    
    signal p0_if_strong_filtd     : signed(15 downto 0);
    signal p1_if_strong_filtd     : signed(15 downto 0);
    signal p2_if_strong_filtd     : signed(15 downto 0);
    signal q0_if_strong_filtd     : signed(15 downto 0);
    signal q1_if_strong_filtd     : signed(15 downto 0);
    signal q2_if_strong_filtd     : signed(15 downto 0);
    
    signal delta_pre_clip         : signed(15 downto 0);
    signal delta                  : signed(15 downto 0);
    
    signal p1_pre_clip_component  : signed(15 downto 0);
    signal q1_pre_clip_component  : signed(15 downto 0);
    
    signal p1_post_clip_component : signed(15 downto 0);
    signal q1_post_clip_component : signed(15 downto 0);
    
    signal tc0_prime              : signed(8 downto  0);
     
begin

     -- normal filtering
    basic_checks <= (abs(p0-q0) < alpha) and 
                    (abs(p1-p0) < beta ) and
                    (abs(q1-q0) < beta );
                       
    extra_filter_normal_p  <= abs(p2-p0) < beta;
    extra_filter_normal_q  <= abs(q2-q0) < beta;
    
    tc0_prime              <= tc0                   when not (extra_filter_normal_p or extra_filter_normal_q) else
                              tc0 + to_signed(1, 9) when extra_filter_normal_p xor extra_filter_normal_q else
                              tc0 + to_signed(2, 9);
            
    delta_pre_clip         <= shift_right((shift_left((("0000000"&q0) - ("0000000"&p0)) , 2) +
                             (("0000000"&p1) - ("0000000"&q1)) + (to_signed(4, 16))) , 3);
                             
    delta                  <= delta_pre_clip         when delta_pre_clip > -tc0_prime and delta_pre_clip < tc0_prime else
                              "1111111"&(-tc0_prime) when delta_pre_clip < -tc0_prime else
                              "0000000"&tc0_prime;
    
    p1_pre_clip_component  <= shift_right((("0000000"&p2) + shift_right((("0000000"&p0) + ("0000000"&q0) + to_signed(1, 16)) , 1) - shift_left(("0000000"&p1) , 1)) , 1);
    
    p1_post_clip_component <= p1_pre_clip_component when p1_pre_clip_component > -tc0 and p1_pre_clip_component < tc0 else
                              "1111111"&(-tc0)        when p1_pre_clip_component < -tc0 else
                              "0000000"&tc0;
                                        
    q1_pre_clip_component  <= shift_right((("0000000"&q2) + shift_right((("0000000"&p0) + ("0000000"&q0) + to_signed(1, 16)) , 1) - shift_left(("0000000"&q1) , 1)) , 1);
    
    q1_post_clip_component <= q1_pre_clip_component when q1_pre_clip_component > -tc0 and q1_pre_clip_component < tc0 else
                              "1111111"&(-tc0)                  when q1_pre_clip_component < -tc0 else
                              "0000000"&tc0;
                                        
    p0_if_normal_filtd     <=  ("0000000"&p0) + delta;                               
    p1_if_normal_filtd     <= ("0000000"&p1) + p1_post_clip_component; 
    q0_if_normal_filtd     <= ("0000000"&q0) - delta;
    q1_if_normal_filtd     <= ("0000000"&q1) + q1_post_clip_component;
     
    normal_filter <= boundary_strength < to_signed(4, 9) and boundary_strength > to_signed(0, 9);
    
    --strong filtering
    ap <= extra_filter_normal_p;
    aq <= extra_filter_normal_q;
    strong_filter <= boundary_strength = to_signed(4, 9);
    strong_filter_test <= (abs((X"0"&p0) - (X"0"&q0)) < (shift_right(X"0"&alpha, 2) + to_signed(2, 13))) and (is_chroma = '0');
     
    p0_if_strong_filtd_0   <= shift_right(( shift_left("0000000"&p1, 1) + ("0000000"&p0) + ("0000000"&q1) + to_signed(2, 16) ) , 2);
    p1_if_strong_filtd_0   <= "0000000"&p1;
    p2_if_strong_filtd_0   <= "0000000"&p2;
                         
    q0_if_strong_filtd_0   <= shift_right(( shift_left("0000000"&q1, 1) + ("0000000"&q0) + ("0000000"&p1) + to_signed(2, 16) ) , 2);
    q1_if_strong_filtd_0   <= "0000000"&q1;
    q2_if_strong_filtd_0   <= "0000000"&q2;
    
    p0_if_strong_filtd_1   <= shift_right((("0000000"&p2) + shift_left("0000000"&p1, 1) + shift_left("0000000"&p0,1) + shift_left("0000000"&q0,1) + ("0000000"&q1) + to_signed(4, 16) ), 3);
    p1_if_strong_filtd_1   <= shift_right(( ("0000000"&p2) + ("0000000"&p1) + ("0000000"&p0) + ("0000000"&q0) + to_signed(2, 16) ), 2);
    p2_if_strong_filtd_1   <= shift_right((shift_left("0000000"&p3, 1) + (to_signed(3, 7)*p2) + ("0000000"&p1) + ("0000000"&p0) + ("0000000"&q0) + to_signed(4, 16) ) , 3);
    
    q0_if_strong_filtd_1   <= shift_right((("0000000"&q2) + shift_left("0000000"&q1, 1) + shift_left("0000000"&q0,1) + shift_left("0000000"&p0,1) + ("0000000"&p1) + to_signed(4, 16) ), 3);
    q1_if_strong_filtd_1   <= shift_right(( ("0000000"&q2) + ("0000000"&q1) + ("0000000"&q0) + ("0000000"&p0) + to_signed(2, 16) ), 2);
    q2_if_strong_filtd_1   <= shift_right((shift_left("0000000"&q3, 1) + (to_signed(3, 7)*q2) + ("0000000"&q1) + ("0000000"&q0) + ("0000000"&p0) + to_signed(4, 16) ) , 3);
     
    p0_if_strong_filtd     <= p0_if_strong_filtd_1 when strong_filter_test else p0_if_strong_filtd_0;
    p1_if_strong_filtd     <= p1_if_strong_filtd_1 when strong_filter_test else p1_if_strong_filtd_0;
    p2_if_strong_filtd     <= p2_if_strong_filtd_1 when strong_filter_test else p2_if_strong_filtd_0;

    q0_if_strong_filtd     <= q0_if_strong_filtd_1 when strong_filter_test else q0_if_strong_filtd_0;
    q1_if_strong_filtd     <= q1_if_strong_filtd_1 when strong_filter_test else q1_if_strong_filtd_0;
    q2_if_strong_filtd     <= q2_if_strong_filtd_1 when strong_filter_test else q2_if_strong_filtd_0;
    
    -- output (will need modifing once strong filtering is built)
    p0_out <= p0_if_normal_filtd(8 downto 0) when normal_filter and basic_checks else
              p0_if_strong_filtd(8 downto 0) when strong_filter and basic_checks else
              p0;
              
    p1_out <= p1_if_normal_filtd(8 downto 0) when normal_filter and basic_checks and extra_filter_normal_p else
              p1_if_strong_filtd(8 downto 0) when strong_filter and basic_checks else
              p1;
    
    p2_out <= p2_if_strong_filtd(8 downto 0) when strong_filter and basic_checks else p2;
    
    q0_out <= q0_if_normal_filtd(8 downto 0) when normal_filter and basic_checks else
              q0_if_strong_filtd(8 downto 0) when strong_filter and basic_checks else
              q0;

    q1_out <= q1_if_normal_filtd(8 downto 0) when normal_filter and basic_checks and extra_filter_normal_q else
              q1_if_strong_filtd(8 downto 0) when strong_filter and basic_checks else
              q1;

    q2_out <= q2_if_strong_filtd(8 downto 0) when strong_filter and basic_checks else q2;
    
end architecture rtl;