library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity n_register is
 generic (n: positive :=32);
port (clk, rst, load : in std_logic;
	  d : in std_logic_vector(n-1 downto 0);
	  q : out std_logic_vector(n-1 downto 0));
end n_register;

architecture behavioral of n_register is
    subtype internal_state is  std_logic_vector(n-1 downto 0);
    signal current_reg : internal_state;
    signal next_reg : internal_state;

begin
	
    --memory element
    process(clk, rst)
	begin
		if(rst = '1') then
			current_reg <= (others=>'0');
		elsif(rising_edge(clk)) then
            current_reg <= next_reg;
		end if;
	end process;
    
    --next state logic
    next_reg <= d when load='1' else current_reg;
        
    --output logic
    q <= current_reg;
    
end behavioral;