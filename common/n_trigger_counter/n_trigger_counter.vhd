 library ieee;
 use ieee.std_logic_1164.all;
 use ieee.std_logic_unsigned.all;
 use ieee.numeric_std.all;
 
 
 entity n_trigger_counter is
    generic (n: positive :=8);
     port (
		  clk    :in  std_logic;                    -- Input clock	
	      rst  :in  std_logic;                      -- Input rst
         count : in std_logic_vector (n-1 downto 0);
	      en    : in std_logic; 
         trigger   :out std_logic -- reached count value
     );
 end entity;
 
 architecture behavioral of n_trigger_counter is
    subtype internal_state is  unsigned (n-1 downto 0);
    signal current_counter: internal_state;
    signal next_counter: internal_state;
 begin
 
     --always follows this template
     
    --memory element (sequential) -- never changes, ever!
    process (clk, rst) begin
         if (rst = '1') then
            current_counter <= (others => '0');
         elsif (rising_edge(clk)) then
            current_counter <= next_counter;
        end if;    
     end process;
     
     --next state logic
    process(current_counter, en, count) begin
	 
		next_counter <= current_counter;

		if (en = '1') then
--				if (current_counter = to_unsigned(0, current_counter'length)) then
--					next_counter <= to_unsigned(1, next_counter'length);
				if (current_counter < unsigned(count-1)) then
					next_counter <= current_counter + 1;
				else
					next_counter <= (others => '0');
				end if;
		end if;
    end process;

     --output logic
     trigger <= '1' when current_counter=unsigned(count-1) else 
                '0';
     
 end architecture;