
library ieee;
use ieee.std_logic_1164.all;                                
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

library altera_mf;
use altera_mf.altera_mf_components.all;


entity tb_fmult is
end tb_fmult;

architecture behavioral of tb_fmult is
  
-- constants                                                 
-- signals  
signal reset : std_logic := '0';    
signal enable : std_logic := '0';            
signal clock : std_logic := '0';                                 
signal dataa :   std_logic_vector (31 downto 0) := (others => '0');
signal datab :   std_logic_vector (31 downto 0) := (others => '0');
signal overflow :   std_logic := '0';
signal underflow :   std_logic := '0';
signal zero :   std_logic := '0';
signal nan :   std_logic := '0';
signal result :   std_logic_vector (31 downto 0); 

   -- clock frequency and signal
constant clk_period : time := 20 ns;  
      
component fpmult
	port (
			clk 	: in std_logic ;
         rst : in std_logic;
			en : in std_logic;
			a 	: in std_logic_vector (31 downto 0);
			b 	: in std_logic_vector (31 downto 0);
			ovf 	: out std_logic ;
			udf 	: out std_logic ;
			zero 	: out std_logic ;
			nan 	: out std_logic ;
			res 	: out std_logic_vector (31 downto 0)
	);
end component;

begin

 fpmult_inst : fpmult
 port map (
		clk 	 => clock,
      rst  => reset, 
		en => enable,  
		a 	 => dataa,
		b 	 => datab,
		ovf 	 => overflow,
		udf 	 => underflow,
		zero 	 => zero,
		nan 	 => nan,
		res 	 => result
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
        -- code executes for every event on sensitivity list
--        dataa <= "00101010000000000000000110000100"; 
--        datab <= "00011011010000000010101000001010";
--        wait for clk_period*10;
--        dataa <= "00001001000000010100001110001000";
--        datab <= "00101010110000000001010100100010";        
--        wait;              

 --         sig_a <= to_float( 6.5, sig_a ); 
 --         sig_b <= to_float( 14.25, sig_b ); 
 --         dataa <= to_slv(sig_a);
 --         datab <= to_slv(sig_b);
 -- 
 --  
		  		  enable <= '0';

		  dataa <= "01000000111100000000000000000000"; --7.5
        datab <= "00000000000000000000000000000000"; --0
		  wait for 50 ns;
		  enable <= '1';
        wait for clk_period*10;
		  assert result="01000010011000010000000000000000" --56.25 ieee 754 single fp
            report "error: correct value for this sum is 01000010011000010000000000000000"
            severity error;
        dataa <= "01000000111100000000000000000000"; --7.5
        datab <= "00111111100000000000000000000000"; --1.0  
        wait for clk_period*10;
		  assert result="01000000111100000000000000000000" --7.5 ieee 754 single fp
            report "error: correct value for this sum is 01000000111100000000000000000000"
            severity error;
        dataa <= "01000000010010001111010111000011"; --3.14
        datab <= "01000001000000100001110010101100"; --8.132  
        wait for clk_period*10;
		  assert result="01000001110011000100011010011101" --25.534 ieee 754 single fp
            report "error: correct value for this sum is 01000001110011000100011010011101"
            severity error;
        dataa <= "01000000001000000000000000000000"; --2.5
        datab <= "01000001100010110000000000000000"; --17.375 
		  wait for clk_period*10;
		  assert result="01000010001011011100000000000000" --43.4375 ieee 754 single fp
            report "error: correct value for this sum is 01000010001011011100000000000000"
            severity error;		  
        wait;            
    end process stim_proc;   

  
end behavioral;

