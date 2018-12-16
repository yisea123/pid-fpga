library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity superb_pwm is
    generic (n_bits: positive := 8);
    port ( clk : in  std_logic;
            rst: in std_logic;
           duty : in  std_logic_vector (n_bits-1 downto 0);
           pwm_out : out  std_logic);
end superb_pwm;

architecture behavioral of superb_pwm is
    subtype internal_state is  unsigned (n_bits-1 downto 0);
    signal current_counter: internal_state;
    signal next_counter: internal_state;
    constant max_count : natural := 2**n_bits;
    constant zeros : std_logic_vector(n_bits -1 downto 0) := (others=>'0');
begin

    --memory element (sequential) -- never changes, ever!
    process (clk, rst) begin
         if (rst = '1') then
            current_counter <= (others => '0');
         elsif (rising_edge(clk)) then
            current_counter <= next_counter;
        end if;    
     end process;
     
     --next state logic
     next_counter <= unsigned(zeros) when current_counter = max_count-1 else
                    current_counter + 1;
        
     --output logic (mealy)
     pwm_out <= '0' when current_counter >  unsigned(duty) else
                '1' when unsigned(duty)/=unsigned(zeros) else
                '0'; --to not create memory element in output
     
     
end behavioral;