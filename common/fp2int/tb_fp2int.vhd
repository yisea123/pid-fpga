
library ieee;
use ieee.std_logic_1164.all;                                
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

--library ieee_proposed;
--use ieee_proposed.float_pkg.all ;

library altera_mf;
use altera_mf.altera_mf_components.all;


entity tb_conv is
end tb_conv;

architecture behavioral of tb_conv is
  
-- constants                                                 
-- signals                                                   
signal dataa :   std_logic_vector (31 downto 0) := (others => '0');
signal overflow :   std_logic := '0';
signal underflow :   std_logic := '0';
signal nan :   std_logic := '0';
signal clock : std_logic := '0';
signal en : std_logic := '1';
signal reset: std_logic := '0';
signal neg: std_logic := '0';
signal result :   std_logic_vector (7 downto 0); 
   -- clock frequency and signal
constant clk_period : time := 20 ns;  
  
--signal sig_a, sig_b : float32;    
    
component fp2int
	port (
		clk 	: in std_logic ;
        rst     : in std_logic;
		  en : in std_logic;
        data_in 	: in std_logic_vector (31 downto 0);
		ovf 	: out std_logic ;
		udf 	: out std_logic ;
		nan 	: out std_logic ;
		neg : out std_logic;
		data_out 	: out std_logic_vector (7 downto 0)
	);
end component;

begin

 fp2int_inst : fp2int
 port map (
		clk 	 => clock,
        rst      => reset,
		  en => en, 
		data_in 	 => dataa,
        ovf 	 => overflow,
		udf 	 => underflow,
		nan 	 => nan,
		neg => neg,
		data_out 	 => result
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
   
		dataa <= "01000000111100000000000000000000"; --7.5
        wait for clk_period*10;
        dataa <= "00111111100000000000000000000000"; --1.0  
        wait for clk_period*10;
        dataa <= "01000000010010001111010111000011"; --3.14
        wait for clk_period*10;
        dataa <= "01000001000000100001110010101100"; --8.132  
        wait for clk_period*10;
        dataa <= "01000000001000000000000000000000"; --2.5
        wait for clk_period*10;
        dataa <= "01000011101001000100010110000001"; --328.543    
          assert overflow='1' 
            report "Value greater than 255"
            severity error;
				        wait for clk_period*10;

		 dataa <= "00101111000001110011110101101100"; -- 123e-9
		 assert underflow='1' 
            report "Value lesser than 2e-8"
            severity error;
			--wait for clk_period*10;	
			--dataa <=	"00011000001100101011101001000100"; -- 231e-26
			--assert underflow='1' 
            --report "Value lesser than 231e-26"
            --severity error;
						wait for clk_period*10;	
			 dataa <= "00110101001110111110011110100010"; -- 7e-7
		 assert underflow='1' 
            report "Value lesser than 2e-8"
            severity error;
				
				wait for clk_period*10;	
			 dataa <= "00111101111110111110011101101101"; -- 0.123
		 assert underflow='1' 
            report "Value lesser than 2e-8"
            severity error;
				
			wait for clk_period*10;	
			 dataa <= "00111111011111110111110011101110"; -- 0.998
		 assert underflow='1' 
            report "Value lesser than 2e-8"
            severity error;		
				
				wait for clk_period*10;	
				dataa <= "11000000001000000000000000000000"; -- -2.5
				assert underflow='1' 
            report "Value lesser than 2e-8"
            severity error;	
				
        wait;            
    end process stim_proc;   

  
end behavioral;

