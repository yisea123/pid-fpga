
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.log_package.all;

entity mux_4_1 is
	 generic (
       n_inputs:    positive := 4;
       inputs_width: positive := 32        
    );
	  
	port (
		a: in std_logic_vector(n_inputs*inputs_width-1 downto 0); --works in ise 14.7 --vhdl2003 compatible
		sel: in std_logic_vector(3 downto 0);
		y: out std_logic_vector(inputs_width-1 downto 0)
	);
end mux_4_1;


architecture behavioral of mux_4_1 is
	
begin

		y <= a(31 downto 0) when sel="0001" else
			  a(63 downto 32) when sel="0010" else
			  a(95 downto 64) when sel="0100" else
			  a(127 downto 96) when sel="1000" else
			  (others=>'0');
	
end behavioral;

