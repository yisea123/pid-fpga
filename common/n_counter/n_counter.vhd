 library ieee;
 use ieee.std_logic_1164.all;
 use ieee.std_logic_unsigned.all;
 use ieee.numeric_std.all;
 
 entity n_counter is
    generic (n: positive :=8); --210 rpm * 340 PPR
     port (
		  clk    :in  std_logic;                    -- Input clock	
	      rst  :in  std_logic;                      -- Input rst
	      dir    : in std_logic; --0/1: up/down
         count   :out std_logic_vector (n-1 downto 0) -- Output of the counter
     );
 end entity;
 
 architecture behavioral of n_counter is
	 
    subtype internal_state is  unsigned (n-1 downto 0);
	 signal  current_counter, next_counter: internal_state; 
    constant max_count: unsigned (n -1 downto 0) := (others=>'1');
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
     process(current_counter, dir) begin
        if (dir = '0') then
            if (current_counter = max_count) then
                next_counter <= to_unsigned(1, next_counter'length);
            else
                next_counter <= current_counter + 1;
            end if;
        else
            if (current_counter = 1) then
                next_counter <= max_count;
            else
                next_counter <= current_counter-1;
            end if;
        end if;
    end process;
     
     --output logic
     count <= std_logic_vector(current_counter);
     
 end architecture;