
library ieee;                                               
use ieee.std_logic_1164.all;                                
use ieee.numeric_std.all;

entity tb_n_adder_sub is
end tb_n_adder_sub;
architecture behavioral of tb_n_adder_sub is
-- constants      
constant n_bits: positive := 8;                                           
-- signals                                                   
signal a : std_logic_vector(n_bits-1 downto 0);
signal b : std_logic_vector(n_bits-1 downto 0);
signal op, ovf : std_logic;
signal s : std_logic_vector(n_bits-1 downto 0);

component n_adder_sub
	generic (
      n: positive := 8
    );
	port (
	a : in std_logic_vector(n-1 downto 0);
	b : in std_logic_vector(n-1 downto 0);
	op : in std_logic;
	ovf: out std_logic;
	s : out std_logic_vector(n-1 downto 0)
	);
end component;

begin
	addsub : n_adder_sub port map (a, b, op, ovf, s);
	
    always : process                                              
                                    
    begin                                                         
        -- code executes for every event on sensitivity list
		  op <= '0';
        a <= std_logic_vector(to_signed(-128, 8));
        b <= std_logic_vector(to_signed(-1, 8));
		  
        wait for 20 ns;
        assert ovf='1'
            report "overflow error, ovf = 1"
            severity error;
		  
		  a <= std_logic_vector(to_signed(127, 8));
        b <= std_logic_vector(to_signed(1, 8));
		  
        wait for 20 ns;
        assert ovf='1'
            report "overflow error, ovf = 1"
            severity error;
		  
		  a <= std_logic_vector(to_signed(-128, 8));
        b <= std_logic_vector(to_signed(0, 8));
		  
        wait for 20 ns;
        assert ovf='0'
            report "overflow error, ovf = 0"
            severity error;
		  a <= std_logic_vector(to_signed(-128, 8));
        b <= std_logic_vector(to_signed(1, 8));
		  
        wait for 20 ns;
        assert ovf='0'
            report "overflow error, ovf = 0"
            severity error;
		  
		  a <= std_logic_vector(to_signed(127, 8));
        b <= std_logic_vector(to_signed(0, 8));
		  
        wait for 20 ns;
        assert ovf='0'
            report "overflow error, ovf = 0"
            severity error;
		  
        op <= '1';
		  
		  a <= std_logic_vector(to_signed(-128, 8));
        b <= std_logic_vector(to_signed(-1, 8));
		  
        wait for 20 ns;
        assert ovf='0'
            report "overflow error, ovf = 0"
            severity error;
		
		a <= std_logic_vector(to_signed(127, 8));
        b <= std_logic_vector(to_signed(1, 8));
		  
        wait for 20 ns;
        assert ovf='0'
            report "overflow error, ovf = 0"
            severity error;
				
			a <= std_logic_vector(to_signed(127, 8));
        b <= std_logic_vector(to_signed(-1, 8));
		  
        wait for 20 ns;
        assert ovf='1'
            report "overflow error, ovf = 1"
            severity error;	
				
        wait;                                                        
    end process always;                                             
end behavioral;
