library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity n_adder_sub is
generic (n: positive :=8);
port (a, b : in std_logic_vector(n-1 downto 0);
      op: in std_logic; --0: addition / 1: subtraction
		en : in std_logic;
		ovf: out std_logic;
      s : out std_logic_vector(n-1 downto 0));
end n_adder_sub;

architecture behavioral of n_adder_sub is
signal temp: std_logic_vector (n downto 0);

begin
	with op select
         temp <= 	std_logic_vector(signed(a(n-1)&a) + signed(b(n-1)&b)) when '0',
						std_logic_vector(signed(a(n-1)&a) - signed(b(n-1)&b)) when others;
        s <= temp(n-1 downto 0) when en='1' else (others=>'0');		
		  ovf <= temp(n) xor temp(n-1);	
end behavioral;