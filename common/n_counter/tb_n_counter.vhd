
library ieee;                                               
use ieee.std_logic_1164.all;                                
use ieee.numeric_std.all;

entity tb_n_counter is
end tb_n_counter;
architecture behavioral of tb_n_counter is
-- constants      
constant n_bits: positive := 8;      
-- signals                                                   
signal count_sig : std_logic_vector(n_bits-1 downto 0) := (others => '0');
signal dir_sig : std_logic := '0';
signal clock_sig : std_logic := '0';
signal reset_sig : std_logic := '0';

constant num_cycles : integer := 10; --simulating encoder pulses (max + 200)
constant clk_period : time := 20 ns;  

component n_counter
	generic (
      n: positive := n_bits
    );
	port (
		 clk    :in  std_logic;                     -- input clock
         rst    :in  std_logic;                     -- input reset
		 dir    : in std_logic; --0/1: up/down
         count   :out std_logic_vector (n-1 downto 0) -- output of the counter
	);
end component;

begin
	n_counter_inst : n_counter
	generic map (n=>n_bits)
	port map (
	clk => clock_sig, 
	rst => reset_sig,
	dir => dir_sig, 
	count => count_sig 
	);
	
	   -- clk_process :process
   -- begin
        -- clock_sig <= '0';
        -- wait for clk_period/2;
        -- clock_sig <= '1';
        -- wait for clk_period/2;
   -- end process clk_process; 
	
	
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
		  --reset_sig <= '1';
		  --wait for clk_period;
		  --reset_sig <= '0';
		  dir_sig <= '0';
		  
          --wait for 1431992461 ps;
			 wait for 12000 ns;
          dir_sig <= '1';
          
--      for i in 1 to num_cycles loop
--      clock_sig <= not clock_sig;
--      wait for clk_period/2;
--      clock_sig <= not clock_sig;
--      wait for clk_period/2;
--  end loop;
				
        wait;                                                        
    end process stim_proc;                                             
end behavioral;
