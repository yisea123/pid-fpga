
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.log_package.all;

entity mux_n_1 is
	 generic (
       n_inputs:    positive := 3;
       inputs_width: positive := 8        
    );
	  
	port (
		--a: in data_package.slv_array(0 to n_inputs-1)(inputs_width-1 downto 0); --vhdl2008 compatible
		--2d array adapted to 1d |___data1___|___data2___|...|___datan__|
      a: in std_logic_vector(0 to n_inputs*inputs_width-1 ); --works in ise 14.7 --vhdl2003 compatible
		sel: in std_logic_vector(log2ceil(n_inputs)-1 downto 0);
		y: out std_logic_vector(inputs_width-1 downto 0)
	);
end mux_n_1;

architecture behavioral of mux_n_1 is

	--constant sel_max : std_logic_vector(log2ceil(n_inputs)-1 downto 0) := (others =>'1');

begin

	sel_proc: process(sel, a)
	begin
--vhdl93 compatible
		y <= a(inputs_width*(to_integer(unsigned(sel))) to inputs_width*(to_integer(unsigned(sel))+1) - 1 );
--vhdl2008 compatible
--		if (sel >= sel_max) then
--			y <= a(to_integer(unsigned(sel))-1);
--		else
--			y <= a(to_integer(unsigned(sel)));
--		end if;
	end process sel_proc;
	
end behavioral;

