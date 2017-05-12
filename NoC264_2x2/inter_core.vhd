-- Inter-Prediction Interpolator Filter
-- see ITU Std. 8.4.2.2.1 and 8.4.2.2.2

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use ieee.math_real.all;

entity inter_core is 
generic(
    x_len       : integer := 4;
    y_len       : integer := 4;
    sample_size : integer := 8
);
port(
    samples : in  std_logic_vector((x_len+5)*(y_len+5)*sample_size-1 downto 0);
    sel     : in  std_logic_vector(7 downto 0);
    result  : out std_logic_vector(x_len*y_len*sample_size-1 downto 0)
);
end entity inter_core;

architecture rtl of inter_core is
    ---------------------------------------------------------------------------
    --- Components ------------------------------------------------------------
    ---------------------------------------------------------------------------
    component half_pixel_interpolator_fir is 
    port(
        x0  :  in  std_logic_vector(7 downto 0);
        x1  :  in  std_logic_vector(7 downto 0);
        x2  :  in  std_logic_vector(7 downto 0);
        x3  :  in  std_logic_vector(7 downto 0);
        x4  :  in  std_logic_vector(7 downto 0);
        x5  :  in  std_logic_vector(7 downto 0);
        y   :  out std_logic_vector(7 downto 0)
    );
    end component half_pixel_interpolator_fir;
    
    component avg2 is 
    port(
        x0  :  in  std_logic_vector(7 downto 0);
        x1  :  in  std_logic_vector(7 downto 0);
        y   :  out std_logic_vector(7 downto 0)
    );
    end component avg2;

    ---------------------------------------------------------------------------
    --- TYPES -----------------------------------------------------------------
    ---------------------------------------------------------------------------
    type sample_row   is array(x_len - 1 downto 0) of std_logic_vector(sample_size-1 downto 0);
    type sample_array is array(y_len - 1 downto 0) of sample_row;
    
    
    ---------------------------------------------------------------------------
    --- SIGNALS ---------------------------------------------------------------
    ---------------------------------------------------------------------------
    --input samples
    signal A_in : sample_array;
    signal B_in : sample_array;
    signal C_in : sample_array;
    signal D_in : sample_array;
    signal E_in : sample_array;
    signal F_in : sample_array;
    signal G_in : sample_array;
    signal H_in : sample_array;
    signal I_in : sample_array;
    signal J_in : sample_array;
    signal K_in : sample_array;
    signal L_in : sample_array;
    signal M_in : sample_array;
    signal N_in : sample_array;
    signal P_in : sample_array;
    signal Q_in : sample_array;
    signal R_in : sample_array;
    signal S_in : sample_array;
    signal T_in : sample_array;
    signal U_in : sample_array;
    
    -- intermediate interpolation results
    signal aa : sample_array;
    signal bb : sample_array;
    signal cc : sample_array;
    signal dd : sample_array;
    signal ee : sample_array;
    signal ff : sample_array;
    signal gg : sample_array;
    signal hh : sample_array;
    
    -- final interpolation results
    signal a : sample_array;
    signal b : sample_array;
    signal c : sample_array;
    signal d : sample_array;
    signal e : sample_array;
    signal f : sample_array;
    signal g : sample_array;
    signal h : sample_array;
    signal i : sample_array;
    signal j : sample_array;
    signal k : sample_array;
    signal m : sample_array; --apparently ITU hates the letter l...
    signal n : sample_array;
    signal p : sample_array;
    signal q : sample_array;
    signal r : sample_array;
    signal s : sample_array;
    
    -- selected interpolation result
    signal y : sample_array;

begin
    
    interpx: for nx in x_len-1 downto 0 generate 
    begin
        interpy: for ny in y_len-1 downto 0 generate 
            -- constants for parsing samples out of "samples"
            constant row_0_start     : integer := ny     * (x_len+5) + nx;
            constant row_1_start     : integer := (ny+1) * (x_len+5) + nx;
            constant row_2_start     : integer := (ny+2) * (x_len+5) + nx;
            constant row_3_start     : integer := (ny+3) * (x_len+5) + nx;
            constant row_4_start     : integer := (ny+4) * (x_len+5) + nx;
            constant row_5_start     : integer := (ny+5) * (x_len+5) + nx;
           
            constant g_in_row_pos    : integer := 2;
            constant g_in_row        : integer := row_2_start;
            constant g_in_sample_num : integer := g_in_row + g_in_row_pos;
            constant g_in_low        : integer := g_in_sample_num * sample_size;
            constant g_in_high       : integer := g_in_low + sample_size - 1;
            
            constant h_in_row_pos    : integer := 3;
            constant h_in_row        : integer := row_2_start;
            constant h_in_sample_num : integer := h_in_row + h_in_row_pos;
            constant h_in_low        : integer := h_in_sample_num * sample_size;
            constant h_in_high       : integer := h_in_low + sample_size - 1;
            
            constant m_in_row_pos    : integer := 2;
            constant m_in_row        : integer := row_3_start;
            constant m_in_sample_num : integer := m_in_row + m_in_row_pos;
            constant m_in_low        : integer := m_in_sample_num * sample_size;
            constant m_in_high       : integer := m_in_low + sample_size - 1;
      
            constant sample_0_0_in_row_pos    : integer := 0;
            constant sample_0_0_in_row        : integer := row_0_start;
            constant sample_0_0_in_sample_num : integer := sample_0_0_in_row + sample_0_0_in_row_pos;
            constant sample_0_0_in_low        : integer := sample_0_0_in_sample_num * sample_size;
            constant sample_0_0_in_high       : integer := sample_0_0_in_low + sample_size - 1;
            
            constant sample_0_1_in_row_pos    : integer := 1;
            constant sample_0_1_in_row        : integer := row_0_start;
            constant sample_0_1_in_sample_num : integer := sample_0_1_in_row + sample_0_1_in_row_pos;
            constant sample_0_1_in_low        : integer := sample_0_1_in_sample_num * sample_size;
            constant sample_0_1_in_high       : integer := sample_0_1_in_low + sample_size - 1;
            
            constant sample_0_2_in_row_pos    : integer := 2;
            constant sample_0_2_in_row        : integer := row_0_start;
            constant sample_0_2_in_sample_num : integer := sample_0_2_in_row + sample_0_2_in_row_pos;
            constant sample_0_2_in_low        : integer := sample_0_2_in_sample_num * sample_size;
            constant sample_0_2_in_high       : integer := sample_0_2_in_low + sample_size - 1;
            
            constant sample_0_3_in_row_pos    : integer := 3;
            constant sample_0_3_in_row        : integer := row_0_start;
            constant sample_0_3_in_sample_num : integer := sample_0_3_in_row + sample_0_3_in_row_pos;
            constant sample_0_3_in_low        : integer := sample_0_3_in_sample_num * sample_size;
            constant sample_0_3_in_high       : integer := sample_0_3_in_low + sample_size - 1;
            
            constant sample_0_4_in_row_pos    : integer := 4;
            constant sample_0_4_in_row        : integer := row_0_start;
            constant sample_0_4_in_sample_num : integer := sample_0_4_in_row + sample_0_4_in_row_pos;
            constant sample_0_4_in_low        : integer := sample_0_4_in_sample_num * sample_size;
            constant sample_0_4_in_high       : integer := sample_0_4_in_low + sample_size - 1;
            
            constant sample_0_5_in_row_pos    : integer := 5;
            constant sample_0_5_in_row        : integer := row_0_start;
            constant sample_0_5_in_sample_num : integer := sample_0_5_in_row + sample_0_5_in_row_pos;
            constant sample_0_5_in_low        : integer := sample_0_5_in_sample_num * sample_size;
            constant sample_0_5_in_high       : integer := sample_0_5_in_low + sample_size - 1;
            
            constant sample_1_0_in_row_pos    : integer := 0;
            constant sample_1_0_in_row        : integer := row_1_start;
            constant sample_1_0_in_sample_num : integer := sample_1_0_in_row + sample_1_0_in_row_pos;
            constant sample_1_0_in_low        : integer := sample_1_0_in_sample_num * sample_size;
            constant sample_1_0_in_high       : integer := sample_1_0_in_low + sample_size - 1;
            
            constant sample_1_1_in_row_pos    : integer := 1;
            constant sample_1_1_in_row        : integer := row_1_start;
            constant sample_1_1_in_sample_num : integer := sample_1_1_in_row + sample_1_1_in_row_pos;
            constant sample_1_1_in_low        : integer := sample_1_1_in_sample_num * sample_size;
            constant sample_1_1_in_high       : integer := sample_1_1_in_low + sample_size - 1;
            
            constant sample_1_2_in_row_pos    : integer := 2;
            constant sample_1_2_in_row        : integer := row_1_start;
            constant sample_1_2_in_sample_num : integer := sample_1_2_in_row + sample_1_2_in_row_pos;
            constant sample_1_2_in_low        : integer := sample_1_2_in_sample_num * sample_size;
            constant sample_1_2_in_high       : integer := sample_1_2_in_low + sample_size - 1;
            
            constant sample_1_3_in_row_pos    : integer := 3;
            constant sample_1_3_in_row        : integer := row_1_start;
            constant sample_1_3_in_sample_num : integer := sample_1_3_in_row + sample_1_3_in_row_pos;
            constant sample_1_3_in_low        : integer := sample_1_3_in_sample_num * sample_size;
            constant sample_1_3_in_high       : integer := sample_1_3_in_low + sample_size - 1;
            
            constant sample_1_4_in_row_pos    : integer := 4;
            constant sample_1_4_in_row        : integer := row_1_start;
            constant sample_1_4_in_sample_num : integer := sample_1_4_in_row + sample_1_4_in_row_pos;
            constant sample_1_4_in_low        : integer := sample_1_4_in_sample_num * sample_size;
            constant sample_1_4_in_high       : integer := sample_1_4_in_low + sample_size - 1;
            
            constant sample_1_5_in_row_pos    : integer := 5;
            constant sample_1_5_in_row        : integer := row_1_start;
            constant sample_1_5_in_sample_num : integer := sample_1_5_in_row + sample_1_5_in_row_pos;
            constant sample_1_5_in_low        : integer := sample_1_5_in_sample_num * sample_size;
            constant sample_1_5_in_high       : integer := sample_1_5_in_low + sample_size - 1;
            
            constant sample_2_0_in_row_pos    : integer := 0;
            constant sample_2_0_in_row        : integer := row_2_start;
            constant sample_2_0_in_sample_num : integer := sample_2_0_in_row + sample_2_0_in_row_pos;
            constant sample_2_0_in_low        : integer := sample_2_0_in_sample_num * sample_size;
            constant sample_2_0_in_high       : integer := sample_2_0_in_low + sample_size - 1;
            
            constant sample_2_1_in_row_pos    : integer := 1;
            constant sample_2_1_in_row        : integer := row_2_start;
            constant sample_2_1_in_sample_num : integer := sample_2_1_in_row + sample_2_1_in_row_pos;
            constant sample_2_1_in_low        : integer := sample_2_1_in_sample_num * sample_size;
            constant sample_2_1_in_high       : integer := sample_2_1_in_low + sample_size - 1;
            
            constant sample_2_2_in_row_pos    : integer := 2;
            constant sample_2_2_in_row        : integer := row_2_start;
            constant sample_2_2_in_sample_num : integer := sample_2_2_in_row + sample_2_2_in_row_pos;
            constant sample_2_2_in_low        : integer := sample_2_2_in_sample_num * sample_size;
            constant sample_2_2_in_high       : integer := sample_2_2_in_low + sample_size - 1;
            
            constant sample_2_3_in_row_pos    : integer := 3;
            constant sample_2_3_in_row        : integer := row_2_start;
            constant sample_2_3_in_sample_num : integer := sample_2_3_in_row + sample_2_3_in_row_pos;
            constant sample_2_3_in_low        : integer := sample_2_3_in_sample_num * sample_size;
            constant sample_2_3_in_high       : integer := sample_2_3_in_low + sample_size - 1;
            
            constant sample_2_4_in_row_pos    : integer := 4;
            constant sample_2_4_in_row        : integer := row_2_start;
            constant sample_2_4_in_sample_num : integer := sample_2_4_in_row + sample_2_4_in_row_pos;
            constant sample_2_4_in_low        : integer := sample_2_4_in_sample_num * sample_size;
            constant sample_2_4_in_high       : integer := sample_2_4_in_low + sample_size - 1;
            
            constant sample_2_5_in_row_pos    : integer := 5;
            constant sample_2_5_in_row        : integer := row_2_start;
            constant sample_2_5_in_sample_num : integer := sample_2_5_in_row + sample_2_5_in_row_pos;
            constant sample_2_5_in_low        : integer := sample_2_5_in_sample_num * sample_size;
            constant sample_2_5_in_high       : integer := sample_2_5_in_low + sample_size - 1;
            
            constant sample_3_0_in_row_pos    : integer := 0;
            constant sample_3_0_in_row        : integer := row_3_start;
            constant sample_3_0_in_sample_num : integer := sample_3_0_in_row + sample_3_0_in_row_pos;
            constant sample_3_0_in_low        : integer := sample_3_0_in_sample_num * sample_size;
            constant sample_3_0_in_high       : integer := sample_3_0_in_low + sample_size - 1;
            
            constant sample_3_1_in_row_pos    : integer := 1;
            constant sample_3_1_in_row        : integer := row_3_start;
            constant sample_3_1_in_sample_num : integer := sample_3_1_in_row + sample_3_1_in_row_pos;
            constant sample_3_1_in_low        : integer := sample_3_1_in_sample_num * sample_size;
            constant sample_3_1_in_high       : integer := sample_3_1_in_low + sample_size - 1;
            
            constant sample_3_2_in_row_pos    : integer := 2;
            constant sample_3_2_in_row        : integer := row_3_start;
            constant sample_3_2_in_sample_num : integer := sample_3_2_in_row + sample_3_2_in_row_pos;
            constant sample_3_2_in_low        : integer := sample_3_2_in_sample_num * sample_size;
            constant sample_3_2_in_high       : integer := sample_3_2_in_low + sample_size - 1;
            
            constant sample_3_3_in_row_pos    : integer := 3;
            constant sample_3_3_in_row        : integer := row_3_start;
            constant sample_3_3_in_sample_num : integer := sample_3_3_in_row + sample_3_3_in_row_pos;
            constant sample_3_3_in_low        : integer := sample_3_3_in_sample_num * sample_size;
            constant sample_3_3_in_high       : integer := sample_3_3_in_low + sample_size - 1;
            
            constant sample_3_4_in_row_pos    : integer := 4;
            constant sample_3_4_in_row        : integer := row_3_start;
            constant sample_3_4_in_sample_num : integer := sample_3_4_in_row + sample_3_4_in_row_pos;
            constant sample_3_4_in_low        : integer := sample_3_4_in_sample_num * sample_size;
            constant sample_3_4_in_high       : integer := sample_3_4_in_low + sample_size - 1;
            
            constant sample_3_5_in_row_pos    : integer := 5;
            constant sample_3_5_in_row        : integer := row_3_start;
            constant sample_3_5_in_sample_num : integer := sample_3_5_in_row + sample_3_5_in_row_pos;
            constant sample_3_5_in_low        : integer := sample_3_5_in_sample_num * sample_size;
            constant sample_3_5_in_high       : integer := sample_3_5_in_low + sample_size - 1;
            
            constant sample_4_0_in_row_pos    : integer := 0;
            constant sample_4_0_in_row        : integer := row_4_start;
            constant sample_4_0_in_sample_num : integer := sample_4_0_in_row + sample_4_0_in_row_pos;
            constant sample_4_0_in_low        : integer := sample_4_0_in_sample_num * sample_size;
            constant sample_4_0_in_high       : integer := sample_4_0_in_low + sample_size - 1;
            
            constant sample_4_1_in_row_pos    : integer := 1;
            constant sample_4_1_in_row        : integer := row_4_start;
            constant sample_4_1_in_sample_num : integer := sample_4_1_in_row + sample_4_1_in_row_pos;
            constant sample_4_1_in_low        : integer := sample_4_1_in_sample_num * sample_size;
            constant sample_4_1_in_high       : integer := sample_4_1_in_low + sample_size - 1;
            
            constant sample_4_2_in_row_pos    : integer := 2;
            constant sample_4_2_in_row        : integer := row_4_start;
            constant sample_4_2_in_sample_num : integer := sample_4_2_in_row + sample_4_2_in_row_pos;
            constant sample_4_2_in_low        : integer := sample_4_2_in_sample_num * sample_size;
            constant sample_4_2_in_high       : integer := sample_4_2_in_low + sample_size - 1;
            
            constant sample_4_3_in_row_pos    : integer := 3;
            constant sample_4_3_in_row        : integer := row_4_start;
            constant sample_4_3_in_sample_num : integer := sample_4_3_in_row + sample_4_3_in_row_pos;
            constant sample_4_3_in_low        : integer := sample_4_3_in_sample_num * sample_size;
            constant sample_4_3_in_high       : integer := sample_4_3_in_low + sample_size - 1;
            
            constant sample_4_4_in_row_pos    : integer := 4;
            constant sample_4_4_in_row        : integer := row_4_start;
            constant sample_4_4_in_sample_num : integer := sample_4_4_in_row + sample_4_4_in_row_pos;
            constant sample_4_4_in_low        : integer := sample_4_4_in_sample_num * sample_size;
            constant sample_4_4_in_high       : integer := sample_4_4_in_low + sample_size - 1;
            
            constant sample_4_5_in_row_pos    : integer := 5;
            constant sample_4_5_in_row        : integer := row_4_start;
            constant sample_4_5_in_sample_num : integer := sample_4_5_in_row + sample_4_5_in_row_pos;
            constant sample_4_5_in_low        : integer := sample_4_5_in_sample_num * sample_size;
            constant sample_4_5_in_high       : integer := sample_4_5_in_low + sample_size - 1;
            
            constant sample_5_0_in_row_pos    : integer := 0;
            constant sample_5_0_in_row        : integer := row_5_start;
            constant sample_5_0_in_sample_num : integer := sample_5_0_in_row + sample_5_0_in_row_pos;
            constant sample_5_0_in_low        : integer := sample_5_0_in_sample_num * sample_size;
            constant sample_5_0_in_high       : integer := sample_5_0_in_low + sample_size - 1;
            
            constant sample_5_1_in_row_pos    : integer := 1;
            constant sample_5_1_in_row        : integer := row_5_start;
            constant sample_5_1_in_sample_num : integer := sample_5_1_in_row + sample_5_1_in_row_pos;
            constant sample_5_1_in_low        : integer := sample_5_1_in_sample_num * sample_size;
            constant sample_5_1_in_high       : integer := sample_5_1_in_low + sample_size - 1;
            
            constant sample_5_2_in_row_pos    : integer := 2;
            constant sample_5_2_in_row        : integer := row_5_start;
            constant sample_5_2_in_sample_num : integer := sample_5_2_in_row + sample_5_2_in_row_pos;
            constant sample_5_2_in_low        : integer := sample_5_2_in_sample_num * sample_size;
            constant sample_5_2_in_high       : integer := sample_5_2_in_low + sample_size - 1;
            
            constant sample_5_3_in_row_pos    : integer := 3;
            constant sample_5_3_in_row        : integer := row_5_start;
            constant sample_5_3_in_sample_num : integer := sample_5_3_in_row + sample_5_3_in_row_pos;
            constant sample_5_3_in_low        : integer := sample_5_3_in_sample_num * sample_size;
            constant sample_5_3_in_high       : integer := sample_5_3_in_low + sample_size - 1;
            
            constant sample_5_4_in_row_pos    : integer := 4;
            constant sample_5_4_in_row        : integer := row_5_start;
            constant sample_5_4_in_sample_num : integer := sample_5_4_in_row + sample_5_4_in_row_pos;
            constant sample_5_4_in_low        : integer := sample_5_4_in_sample_num * sample_size;
            constant sample_5_4_in_high       : integer := sample_5_4_in_low + sample_size - 1;
            
            constant sample_5_5_in_row_pos    : integer := 5;
            constant sample_5_5_in_row        : integer := row_5_start;
            constant sample_5_5_in_sample_num : integer := sample_5_5_in_row + sample_5_5_in_row_pos;
            constant sample_5_5_in_low        : integer := sample_5_5_in_sample_num * sample_size;
            constant sample_5_5_in_high       : integer := sample_5_5_in_low + sample_size - 1;


        begin     
            
            --parse input samples out of the input vector samples
            G_in(ny)(nx) <= samples(g_in_high downto g_in_low);
            H_in(ny)(nx) <= samples(h_in_high downto h_in_low);
            M_in(ny)(nx) <= samples(m_in_high downto m_in_low);
            
            -- half pixel interpolation between whole pixel values
            fir_aa: component half_pixel_interpolator_fir port map(
                x0  => samples(sample_0_0_in_high downto sample_0_0_in_low),
                x1  => samples(sample_0_1_in_high downto sample_0_1_in_low),
                x2  => samples(sample_0_2_in_high downto sample_0_2_in_low),
                x3  => samples(sample_0_3_in_high downto sample_0_3_in_low),
                x4  => samples(sample_0_4_in_high downto sample_0_4_in_low),
                x5  => samples(sample_0_5_in_high downto sample_0_5_in_low),
                y   => aa(ny)(nx)
            );
            
            fir_bb: component half_pixel_interpolator_fir port map(
                x0  => samples(sample_1_0_in_high downto sample_1_0_in_low),
                x1  => samples(sample_1_1_in_high downto sample_1_1_in_low),
                x2  => samples(sample_1_2_in_high downto sample_1_2_in_low),
                x3  => samples(sample_1_3_in_high downto sample_1_3_in_low),
                x4  => samples(sample_1_4_in_high downto sample_1_4_in_low),
                x5  => samples(sample_1_5_in_high downto sample_1_5_in_low),
                y   => bb(ny)(nx)
            );
            
            fir_b:  component half_pixel_interpolator_fir port map(
                x0  => samples(sample_2_0_in_high downto sample_2_0_in_low),
                x1  => samples(sample_2_1_in_high downto sample_2_1_in_low),
                x2  => samples(sample_2_2_in_high downto sample_2_2_in_low),
                x3  => samples(sample_2_3_in_high downto sample_2_3_in_low),
                x4  => samples(sample_2_4_in_high downto sample_2_4_in_low),
                x5  => samples(sample_2_5_in_high downto sample_2_5_in_low),
                y   => b(ny)(nx)
            );
            
            fir_s:  component half_pixel_interpolator_fir port map(
                x0  => samples(sample_3_0_in_high downto sample_3_0_in_low),
                x1  => samples(sample_3_1_in_high downto sample_3_1_in_low),
                x2  => samples(sample_3_2_in_high downto sample_3_2_in_low),
                x3  => samples(sample_3_3_in_high downto sample_3_3_in_low),
                x4  => samples(sample_3_4_in_high downto sample_3_4_in_low),
                x5  => samples(sample_3_5_in_high downto sample_3_5_in_low),
                y   => s(ny)(nx)
            );
            
            fir_gg:  component half_pixel_interpolator_fir port map(
                x0  => samples(sample_4_0_in_high downto sample_4_0_in_low),
                x1  => samples(sample_4_1_in_high downto sample_4_1_in_low),
                x2  => samples(sample_4_2_in_high downto sample_4_2_in_low),
                x3  => samples(sample_4_3_in_high downto sample_4_3_in_low),
                x4  => samples(sample_4_4_in_high downto sample_4_4_in_low),
                x5  => samples(sample_4_5_in_high downto sample_4_5_in_low),
                y   => gg(ny)(nx)
            );
            
            fir_hh:  component half_pixel_interpolator_fir port map(
                x0  => samples(sample_5_0_in_high downto sample_5_0_in_low),
                x1  => samples(sample_5_1_in_high downto sample_5_1_in_low),
                x2  => samples(sample_5_2_in_high downto sample_5_2_in_low),
                x3  => samples(sample_5_3_in_high downto sample_5_3_in_low),
                x4  => samples(sample_5_4_in_high downto sample_5_4_in_low),
                x5  => samples(sample_5_5_in_high downto sample_5_5_in_low),
                y   => hh(ny)(nx)
            );
            
            fir_cc:  component half_pixel_interpolator_fir port map(
                x0  => samples(sample_0_0_in_high downto sample_0_0_in_low),
                x1  => samples(sample_1_0_in_high downto sample_1_0_in_low),
                x2  => samples(sample_2_0_in_high downto sample_2_0_in_low),
                x3  => samples(sample_3_0_in_high downto sample_3_0_in_low),
                x4  => samples(sample_4_0_in_high downto sample_4_0_in_low),
                x5  => samples(sample_5_0_in_high downto sample_5_0_in_low),
                y   => cc(ny)(nx)
            );
            
            fir_dd:  component half_pixel_interpolator_fir port map(
                x0  => samples(sample_0_1_in_high downto sample_0_1_in_low),
                x1  => samples(sample_1_1_in_high downto sample_1_1_in_low),
                x2  => samples(sample_2_1_in_high downto sample_2_1_in_low),
                x3  => samples(sample_3_1_in_high downto sample_3_1_in_low),
                x4  => samples(sample_4_1_in_high downto sample_4_1_in_low),
                x5  => samples(sample_5_1_in_high downto sample_5_1_in_low),
                y   => dd(ny)(nx)
            );
            
            fir_h:  component half_pixel_interpolator_fir port map(
                x0  => samples(sample_0_2_in_high downto sample_0_2_in_low),
                x1  => samples(sample_1_2_in_high downto sample_1_2_in_low),
                x2  => samples(sample_2_2_in_high downto sample_2_2_in_low),
                x3  => samples(sample_3_2_in_high downto sample_3_2_in_low),
                x4  => samples(sample_4_2_in_high downto sample_4_2_in_low),
                x5  => samples(sample_5_2_in_high downto sample_5_2_in_low),
                y   => h(ny)(nx)
            );
            
            fir_m:  component half_pixel_interpolator_fir port map(
                x0  => samples(sample_0_3_in_high downto sample_0_3_in_low),
                x1  => samples(sample_1_3_in_high downto sample_1_3_in_low),
                x2  => samples(sample_2_3_in_high downto sample_2_3_in_low),
                x3  => samples(sample_3_3_in_high downto sample_3_3_in_low),
                x4  => samples(sample_4_3_in_high downto sample_4_3_in_low),
                x5  => samples(sample_5_3_in_high downto sample_5_3_in_low),
                y   => m(ny)(nx)
            );
            
            fir_ee:  component half_pixel_interpolator_fir port map(
                x0  => samples(sample_0_4_in_high downto sample_0_4_in_low),
                x1  => samples(sample_1_4_in_high downto sample_1_4_in_low),
                x2  => samples(sample_2_4_in_high downto sample_2_4_in_low),
                x3  => samples(sample_3_4_in_high downto sample_3_4_in_low),
                x4  => samples(sample_4_4_in_high downto sample_4_4_in_low),
                x5  => samples(sample_5_4_in_high downto sample_5_4_in_low),
                y   => ee(ny)(nx)
            );
            
            fir_ff:  component half_pixel_interpolator_fir port map(
                x0  => samples(sample_0_5_in_high downto sample_0_5_in_low),
                x1  => samples(sample_1_5_in_high downto sample_1_5_in_low),
                x2  => samples(sample_2_5_in_high downto sample_2_5_in_low),
                x3  => samples(sample_3_5_in_high downto sample_3_5_in_low),
                x4  => samples(sample_4_5_in_high downto sample_4_5_in_low),
                x5  => samples(sample_5_5_in_high downto sample_5_5_in_low),
                y   => ff(ny)(nx)
            );
            
            -- half pixel interpolation from neighboring half pixel values
            fir_j:  component half_pixel_interpolator_fir port map(
                x0  => aa(ny)(nx),
                x1  => bb(ny)(nx),
                x2  =>  b(ny)(nx),
                x3  =>  s(ny)(nx),
                x4  => gg(ny)(nx),
                x5  => hh(ny)(nx),
                y   =>  j(ny)(nx)
            );
            
            -- quarter pixel interpolation
            avg_a:  component avg2 port map(x0 => G_in(ny)(nx),    x1 => b(ny)(nx), y => a(ny)(nx));
            avg_c:  component avg2 port map(x0 => H_in(ny)(nx),    x1 => b(ny)(nx), y => c(ny)(nx));
            avg_d:  component avg2 port map(x0 => G_in(ny)(nx),    x1 => h(ny)(nx), y => d(ny)(nx));
            avg_e:  component avg2 port map(x0 =>    b(ny)(nx)   , x1 => h(ny)(nx), y => e(ny)(nx));
            avg_f:  component avg2 port map(x0 =>    b(ny)(nx)   , x1 => j(ny)(nx), y => f(ny)(nx));
            avg_g:  component avg2 port map(x0 =>    b(ny)(nx)   , x1 => m(ny)(nx), y => g(ny)(nx));
            avg_i:  component avg2 port map(x0 =>    h(ny)(nx)   , x1 => j(ny)(nx), y => i(ny)(nx));
            avg_k:  component avg2 port map(x0 =>    j(ny)(nx)   , x1 => m(ny)(nx), y => k(ny)(nx));
            avg_n:  component avg2 port map(x0 => M_in(ny)(nx),    x1 => h(ny)(nx), y => n(ny)(nx));
            avg_p:  component avg2 port map(x0 =>    h(ny)(nx)   , x1 => s(ny)(nx), y => p(ny)(nx));
            avg_q:  component avg2 port map(x0 =>    j(ny)(nx)   , x1 => s(ny)(nx), y => q(ny)(nx));
            avg_r:  component avg2 port map(x0 =>    m(ny)(nx)   , x1 => s(ny)(nx), y => r(ny)(nx));
            
            --assign output
            y(ny)(nx) <= a(ny)(nx)    when sel = x"01" else
                         b(ny)(nx)    when sel = x"02" else
                         c(ny)(nx)    when sel = x"03" else
                         d(ny)(nx)    when sel = x"04" else
                         e(ny)(nx)    when sel = x"05" else
                         f(ny)(nx)    when sel = x"06" else
                         g(ny)(nx)    when sel = x"07" else
                         h(ny)(nx)    when sel = x"08" else
                         i(ny)(nx)    when sel = x"09" else
                         j(ny)(nx)    when sel = x"0A" else
                         k(ny)(nx)    when sel = x"0B" else
                         n(ny)(nx)    when sel = x"0C" else
                         p(ny)(nx)    when sel = x"0D" else
                         q(ny)(nx)    when sel = x"0E" else
                         r(ny)(nx)    when sel = x"0F" else
								 G_in(ny)(nx) when sel = x"00" else
                         X"00";
                                                  
        end generate;
    end generate;
    
    --result <= y(0)(0) & y(1)(0) & -- y(2)(0) & y(3)(0) &
    --          y(0)(1) & y(1)(1) ;--& y(2)(1) & y(3)(1) &
    --          --y(0)(2) & y(1)(2)  & y(2)(2) & y(3)(2) &
    --          --y(0)(3) & y(1)(3)  & y(2)(3) & y(3)(3);
	 
	 result <= y(0)(0) & y(0)(1) & y(0)(2) & y(0)(3) & y(1)(0) & y(1)(1) & y(1)(2) & y(1)(3);
    --result <= y(0)(0) & y(1)(0) & y(2)(0) & y(3)(0) &
    --          y(0)(1) & y(1)(1) & y(2)(1) & y(3)(1) &
    --          y(0)(2) & y(1)(2) & y(2)(2) & y(3)(2) &
    --          y(0)(3) & y(1)(3) & y(2)(3) & y(3)(3);
	 
	 --result <= y(0)(0) & y(0)(1) & y(0)(2) & y(0)(3) & y(0)(4) & y(0)(5) & y(0)(6) & y(0)(7) &
	 --			  y(1)(0) & y(1)(1) & y(1)(2) & y(1)(3) & y(1)(4) & y(1)(5) & y(1)(6) & y(1)(7);
	 
	 
end architecture rtl;

