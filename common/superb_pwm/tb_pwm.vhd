
library ieee;
use ieee.std_logic_1164.all;                                
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

entity tb_pwm is
end tb_pwm;

architecture behavioral of tb_pwm is
  
-- constants    
constant const_n_bits : integer := 8;                                             
-- signals        
signal  rst_sig	: std_logic := '0';                                     
signal  clk_sig	: std_logic ;                                     
signal duty_sig :   std_logic_vector (const_n_bits-1 downto 0) := (others => '0');
signal pwm_out_sig : std_logic := '0';

   -- clock frequency and signal
constant clk_period : time := 20 ns;  
      
component superb_pwm
    generic (n_bits : positive := const_n_bits);
    port ( clk : in  std_logic;
            rst: in std_logic;
           duty : in  std_logic_vector (n_bits-1 downto 0);
           pwm_out : out  std_logic); 
end component;

begin

 superb_pwm_inst : superb_pwm
 generic map (
    n_bits => const_n_bits
 )
 port map (
        clk => clk_sig,
        rst => rst_sig,
		duty	 => duty_sig,
		pwm_out	 => pwm_out_sig 

 );
 
   clk_process :process
   begin
        clk_sig <= '0';
        wait for clk_period/2;
        clk_sig <= '1';
        wait for clk_period/2;
   end process clk_process; 
 
    stim_proc: process                                              
    begin    
      duty_sig <= "01000000"; --64
      wait for 100us;
      duty_sig <= "10000000"; --128
      wait for 100us;
      duty_sig <= "00010000"; --16
      wait for 100us;
      duty_sig <= "00000100"; --4
        wait;
   
    end process stim_proc;   

  
end behavioral;

