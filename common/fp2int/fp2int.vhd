

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity fp2int is
	port (
			clk 	: in std_logic ;
         rst     : in std_logic;
			en : in std_logic;
         data_in 	: in std_logic_vector (31 downto 0);
			ovf 	: out std_logic ;
			udf 	: out std_logic ;
			nan 	: out std_logic ;
			neg : out std_logic;
			data_out 	: out std_logic_vector (8 downto 0)
	);
end fp2int;


architecture behavioral of fp2int is
	signal data_out_sig : std_logic_vector (8 downto 0);
	signal temp  : signed (8 downto 0);
	
   	component alt_fp2int
	port (
         clock	: in std_logic ;
         aclr		: in std_logic ;
			clk_en : in std_logic;
         dataa	: in std_logic_vector (31 downto 0);
			overflow	: out std_logic ;
			underflow	: out std_logic ;
			nan	: out std_logic ;
			result	: out std_logic_vector (8 downto 0)
	);
	end component; 
    
begin

alt_fp2int_inst : alt_fp2int port map (
		
		clock	 => clk,
      aclr	 => rst,
		clk_en	 => en,
		dataa	 => data_in,
      overflow	 => ovf,
		underflow	 => udf,
		nan	 => nan,
		result	 => data_out_sig
	);
	data_out <= data_out_sig; 
	
	temp <= signed(data_out_sig); 
	 
	neg <= '1' when (temp < 0) else
			'0';
	

end behavioral;

