
library ieee;
use ieee.std_logic_1164.all;                                
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

--library ieee_proposed;
--use ieee_proposed.float_pkg.all ;

library altera_mf;
use altera_mf.altera_mf_components.all;


entity tb_fsumadd is
end tb_fsumadd;

architecture behavioral of tb_fsumadd is
  
-- constants                                                 
-- signals  
signal reset : std_logic := '0';      
signal enable : std_logic := '0';      
signal  add_sub	: std_logic ;                                     
signal dataa :   std_logic_vector (31 downto 0) := (others => '0');
signal datab :   std_logic_vector (31 downto 0) := (others => '0');
signal overflow :   std_logic := '0';
signal underflow :   std_logic := '0';
signal zero :   std_logic := '0';
signal nan :   std_logic := '0';
signal clock : std_logic := '0';
signal result :   std_logic_vector (31 downto 0); 
   -- clock frequency and signal
constant clk_period : time := 20 ns;  
  
--signal sig_a, sig_b : float32;    
    
component fpsum
        port 
  ( 
	clk 	: in std_logic ;
    rst     : in std_logic;
	 en: in std_logic ;
    add_sub 	: in std_logic ;
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

 fpsum_inst : fpsum
 port map (
		clk 	 => clock,
        rst   => reset,
		  en => enable, 
        add_sub  => add_sub,
		a 	 => dataa,
		b 	 => datab,
		nan 	 => nan,
		ovf 	 => overflow,
		res 	 => result,
		udf 	 => underflow,
		zero 	 => zero
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
			
        add_sub <= '1';  --0: sub, 1: add 
		dataa <= "01000000111100000000000000000000"; --7.5
        datab <= "01000000111100000000000000000000"; --7.5
		  wait for 100 ns;
		  enable <= '1';
        wait for clk_period*10;
		  assert result="01000001011100000000000000000000" --15.0 ieee 754 single fp
            report "error: correct value for this sum is 01000001011100000000000000000000"
            severity error;
				
        dataa <= "01000000111100000000000000000000"; --7.5
        datab <= "00111111100000000000000000000000"; --1.0  
		  
        wait for clk_period*10;
		  assert result="01000001000010000000000000000000" --8.5 ieee 754 single fp
            report "error: correct value for this sum is 01000001000010000000000000000000"
            severity error;
		  
        dataa <= "01000000010010001111010111000011"; --3.14
        datab <= "01000001000000100001110010101100"; --8.132  
        wait for clk_period*10;
		  
		  assert result="01000001001101000101101000011101" --11.272 ieee 754 single fp
            report "error: correct value for this sum is 01000001001101000101101000011101"
            severity error;			
        dataa <= "01000000001000000000000000000000"; --2.5
		  datab <= "01000001100010110000000000000000"; --17.375  
		  wait for clk_period*10;
		  
		  assert result="01000001100111110000000000000000" --19.875 ieee 754 single fp
            report "error: correct value for this sum is 01000001100111110000000000000000"
            severity error;	  
				
        wait;            
    end process stim_proc;   

  
end behavioral;

