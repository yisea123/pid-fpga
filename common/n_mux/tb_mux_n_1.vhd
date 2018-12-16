
library ieee;
use ieee.std_logic_1164.all;
use work.log_package.all;
 
entity tb_mux_n_1 is
end tb_mux_n_1;
 
architecture behavior of tb_mux_n_1 is 
 
    -- component declaration for the unit under test (uut)
    component mux_n_1
    generic (
      n_inputs: positive := 3;
      inputs_width: positive := 8
    );
      
    port(
         --a : in data_package.slv_array(0 to n_inputs-1)(inputs_width-1 downto 0); --vhdl2008 approach       
         a: in std_logic_vector(n_inputs*inputs_width-1 downto 0); --vhdl2003 compatible
         sel: in std_logic_vector(log2ceil(n_inputs)-1 downto 0);
         y : out std_logic_vector(inputs_width-1 downto 0)
        );
    end component;
    
   constant entries_number: natural := 3;
   constant entries_width: natural := 8;
   
    	--outputs
   signal y : std_logic_vector(entries_width-1 downto 0) := (others => '0');
   --vhdl2003 compatible
   signal a : std_logic_vector(0 to entries_number*entries_width-1) := "000100011101001011001010"; --17, 210, 202
   --vhdl2008
   --signal a: data_package.slv_array(0 to entries_number-1)(entries_width-1 downto 0) := ("00010001", "11101001", "11001010");
   signal sel: std_logic_vector(log2ceil(entries_number)-1 downto 0) := (others => '0');
    

   -- no clocks detected in port list. replace clock below with 
   -- appropriate port name 
   constant clk_period : time := 100 ms;

begin

  -- instantiate the unit under test (uut)
   uut: mux_n_1 
      generic map (
        n_inputs => entries_number,
        inputs_width => entries_width
      )
      port map (
          a => a,
          sel => sel,
          y => y
        );
        
  -- stimulus process, apply inputs here.
  stim_proc: process
   begin
        sel <= (others => '0');
        wait for clk_period*5;
        sel <= (0 => '1', others => '0');
        wait for clk_period*5;
        sel <= ( 0 => '0', 1=> '1',  others => '0');
         wait for clk_period*5;
         sel <= ( 0 => '1', 1=> '1',  others => '0');
			        wait for clk_period*5;

			sel <= (0 => '1', others => '0');
        wait for clk_period*5;
		  sel <= ( 0 => '1', 1=> '1',  others => '0');
         wait for clk_period*5;
         sel <= ( 0 => '0', 1 => '0', 2=> '1',  others => '0');
         wait for clk_period*5;
         sel <= ( 0 => '1', 1 => '0', 2=> '1',  others => '0');
        wait;
    end process;
end;
