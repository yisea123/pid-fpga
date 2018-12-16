 library ieee;
 use ieee.std_logic_1164.all;
 
entity nios2_project_wrapper_de2 is
	port (
		CLOCK_50 : in std_logic;
		LEDG: out std_logic_vector(7 downto 0)
 );
 end entity;
 
 architecture behavioral of nios2_project_wrapper_de2 is
  
 component first_nios2_system is
        port (
            clk_clk                            : in  std_logic                    := 'X'; -- clk
            led_pio_external_connection_export : out std_logic_vector(7 downto 0);        -- export
            reset_reset_n                      : in  std_logic                    := 'X'  -- reset_n
        );
    end component first_nios2_system;
	 
begin
    u0 : component first_nios2_system
        port map (
            clk_clk                            => CLOCK_50,                            --                         clk.clk
            led_pio_external_connection_export => LEDG, -- led_pio_external_connection.export
            reset_reset_n                      => '1'                       --                       reset.reset_n
        );
end architecture;