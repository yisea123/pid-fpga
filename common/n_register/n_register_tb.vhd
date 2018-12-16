
library ieee;                                               
use ieee.std_logic_1164.all;                                
use ieee.numeric_std.all;


entity tb_n_register is
end tb_n_register;
architecture behavioral of tb_n_register is

-- constants      
constant n_bits: positive := 8;                                           
-- signals                                                   
signal d_sig : std_logic_vector(n_bits-1 downto 0) := (others => '0');
signal q_sig : std_logic_vector(n_bits-1 downto 0) := (others => '0');
signal load_sig : std_logic := '0';
signal clock_sig : std_logic := '0';
signal reset_sig : std_logic := '0';

constant num_cycles : integer := 20; --simulating encoder pulses (max + 200)
constant clk_period : time := 20 ns;  

component n_register
 generic (n: positive :=8);
port (clk : in std_logic;
		rst : in std_logic;
		load : in std_logic;
		d : in std_logic_vector(n-1 downto 0);
		q : out std_logic_vector(n-1 downto 0));
	  
end component;

begin
	n_register_inst : n_register port map (
	clk => clock_sig, 
	rst => reset_sig, 
	load => load_sig, 
	d => d_sig, 
	q => q_sig
	);
	
    clk_proc : process 
    begin
        clock_sig <= '0';
        wait for clk_period/2;
        clock_sig <= '1';
        wait for clk_period/2;
    end process clk_proc;    
    
    stim_proc : process                                              
                                    
    begin 
 -- code executes for every event on sensitivity list
		  reset_sig <= '1';
		  wait for clk_period;
		  reset_sig <= '0';
		  wait for clk_period;
		  d_sig <= "00100101";
		  load_sig <= '0'; 
        wait for clk_period;
        load_sig <= '1';
        wait for clk_period;
		  load_sig <= '0';
        wait for clk_period;
        d_sig <= "00100100";
		   wait for clk_period;
        load_sig <= '1';
        wait;                                                        
    end process stim_proc;                                             
end behavioral;
