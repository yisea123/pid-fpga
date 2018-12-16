library ieee;
use ieee.std_logic_1164.all;

entity decoder_3_4 is
 port(
 
 a : in std_logic_vector(2 downto 0);
 b : out std_logic_vector(3 downto 0)
 );
end decoder_3_4;

architecture behavioral of decoder_3_4 is
begin
	
	b(0) <= not a(2) and a(1) and a(0);
	b(1) <= a(2) and not a(1) and not a(0);
	b(2) <= a(2) and not a(1) and a(0);
	b(3) <= a(2) and a(1) and not a(0);
	
end behavioral;

