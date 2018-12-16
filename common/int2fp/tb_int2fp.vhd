
library ieee;
use ieee.std_logic_1164.all;                                
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

--library ieee_proposed;
--use ieee_proposed.float_pkg.all ;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity tb_int2fp is
end tb_int2fp;

architecture behavioral of tb_int2fp is
  
-- constants                                                 
-- signals                                                   
signal dataa :   std_logic_vector (31 downto 0) := (others => '0');
signal clock : std_logic := '0';
signal reset : std_logic := '0';
signal enable : std_logic := '1';

signal result :   std_logic_vector (31 downto 0); 
   -- clock frequency and signal
constant clk_period : time := 20 ns;  
constant	n_pwm_res: positive := 8;

signal user_rpm_sig: std_logic_vector(n_pwm_res-1 downto 0) := (others=>'0');	
signal rpm_in_msb_zero : std_logic_vector(23 downto 0) := (others =>'0');

--signal sig_a, sig_b : float32;    
    
component int2fp
port (
		clk 	: in std_logic ;
      rst : in std_logic;
		en : in std_logic;
		int_in 	: in std_logic_vector (31 downto 0);
		fp_out 	: out std_logic_vector (31 downto 0)
	);
end component;

begin

  int2fp_inst : int2fp
 port map (
		clk 	 => clock,
        rst => reset,
		  en => enable,
		int_in 	 => dataa,
		fp_out 	 => result
 );
 
   clk_process :process
   begin
        clock <= '0';
        wait for clk_period/2;
        clock <= '1';
        wait for clk_period/2;
   end process clk_process; 
 
    stim_proc: process                                              
    begin    
		user_rpm_sig <= std_logic_vector(to_unsigned(170, user_rpm_sig'length)); --170 rpm
		dataa <= "00000000000000000000000100111000"; --312
        wait for clk_period*10;
        dataa <= "00000000000000000000010111011000"; --1496
        wait for clk_period*10;
        dataa <= "11111111111111111111111100100011"; ---221
        wait for clk_period*10;
        dataa <= "00000000000000000000000001011110"; --94  
        wait for clk_period*10;
        dataa <= "00000000000000000000000010001001"; --137
		  wait for clk_period*10;
		  dataa <= rpm_in_msb_zero & user_rpm_sig;
        wait;            
    end process stim_proc;   

  
end behavioral;

