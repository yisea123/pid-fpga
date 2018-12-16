--------------------------------------------------------------------------------
--
--   filename:         debounce.vhd
--   dependencies:     none
--   design software:  quartus ii 32-bit version 11.1 build 173 sj full version
--
--   hdl code is provided "as is."  digi-key expressly disclaims any
--   warranty of any kind, whether express or implied, including but not
--   limited to, the implied warranties of merchantability, fitness for a
--   particular purpose, or non-infringement. in no event shall digi-key
--   be liable for any incidental, special, indirect or consequential
--   damages, lost profits or lost data, harm to your equipment, cost of
--   procurement of substitute goods, technology or services, any claims
--   by third parties (including but not limited to any defense thereof),
--   any claims for indemnity or contribution, or other similar costs.
--
--   version history
--   version 1.0 3/26/2012 scott larson
--     initial public release
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity debouncer is
  generic(
    counter_size  :  integer := 21); --counter size (21 bits gives 40ms with 50mhz clock)
  port(
    clk     : in  std_logic;  --input clock
	 rst		: in std_logic;
    button  : in  std_logic;  --input signal to be debounced
    result  : out std_logic); --debounced signal
end debouncer;

architecture logic of debouncer is
  signal flipflops   : std_logic_vector(1 downto 0); --input flip flops
  signal counter_set : std_logic;                    --sync reset to zero
  signal counter_out : std_logic_vector(counter_size downto 0) := (others => '0'); --counter output
begin

  counter_set <= flipflops(0) xor flipflops(1);   --determine when to start/reset counter
  
  process(clk, rst)
  begin
    if(rst = '1') then
			counter_out <= (others=>'0');
	 elsif(rising_edge(clk)) then
      flipflops(0) <= button;
      flipflops(1) <= flipflops(0);
      if(counter_set = '1') then                  --reset counter because input is changing
        counter_out <= (others => '0');
      elsif(counter_out(counter_size) = '0') then --stable input time is not yet met
        counter_out <= counter_out + 1;
      else                                        --stable input time is met
        result <= flipflops(1);
      end if;    
    end if;
  end process;
end logic;
