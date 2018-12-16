

library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity int2fp is
	port (
		clk 	: in std_logic ;
      rst : in std_logic;
		en : in std_logic;
		int_in 	: in std_logic_vector (31 downto 0);
		fp_out 	: out std_logic_vector (31 downto 0)
	);
end int2fp;


architecture behavioral of int2fp is


   	component alt_int2fp
	port (
		aclr		: in std_logic;
		clock		: in std_logic;
		clk_en : in std_logic;
		dataa		: in std_logic_vector (31 downto 0);
		result		: out std_logic_vector (31 downto 0)
	);
	end component; 
    
begin

alt_int2fp_inst : alt_int2fp port map (
		aclr	 => rst,
		clk_en	 => en,
		clock	 => clk,
		dataa	 => int_in,
		result	 => fp_out
	);



end behavioral;

