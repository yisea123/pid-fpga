
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.log_package.all;

entity avalon_wrapper is
	generic (
		n_pps_interrupt_counter : positive := 32; --need to count up to 50e6 (using 50MHz clock) to 1s interrupt
		n_max_encoder_count : positive := 32; --max: 71400 -> 340PPR*210 rpm
		n_pwm_res : positive :=8; --read-only
		
		--vhdl2003 doesn't permit the use of one generic to parametrize another one
		ppr_constant: std_logic_vector (31 downto 0) := "00111110001101001010001000110100"; --0.1764 (60/PPR)
		kp_constant: std_logic_vector (31 downto 0) :=  "00111111000000000000000000000000"; --0.5
		ki_constant: std_logic_vector (31 downto 0) :=  "00111110100110011001100110011010"; --0.3
		kd_constant: std_logic_vector (31 downto 0) :=  "00111111100000000000000000000000" --1
	); 
	
	  
	port (
		clk, rst : in std_logic;
		encoder_in : in std_logic;
		pwm_out : out std_logic;
		address: in std_logic_vector(15 downto 0);
		read: in std_logic;
		writedata: std_logic_vector(31 downto 0);
		write: in std_logic;
		readdata: out std_logic_vector(31 downto 0)
	);
end avalon_wrapper;

architecture behavioral of avalon_wrapper is

	signal decoder_2_4_out : std_logic_vector(3 downto 0);
	signal decoder_3_4_out : std_logic_vector(3 downto 0);

	signal pps_interrupt_reg_out : std_logic_vector( 31 downto 0);
	signal rpm_in_reg_out : std_logic_vector( 31 downto 0);
	signal cmd_reg_out : std_logic_vector( 31 downto 0);
	signal mux_input : std_logic_vector(0 to 127 );
	
	signal current_rpm_sig : std_logic_vector(31 downto 0);
	signal pid_out_sig : std_logic_vector( 31 downto 0);
	signal encoder_count_sig:std_logic_vector( 31 downto 0);
	signal operational_error_sig:std_logic_vector( 31 downto 0) := (others => '0');
	signal encoder_in_sig : std_logic;
	signal pwm_out_sig : std_logic; 
	signal tmp_sel :std_logic_vector(3 downto 0)  := (others => '0');
	
	component decoder_2_4 
	port(
		a : in std_logic_vector(1 downto 0);
		b : out std_logic_vector(3 downto 0)
	);
	end component;

	component decoder_3_4 
	port(
		a : in std_logic_vector(2 downto 0);
		b : out std_logic_vector(3 downto 0)
	);
	end component;

	component n_register 
	generic (n : positive := 32);
		port (
			clk, rst, load : in std_logic;
			d : in std_logic_vector(n - 1 downto 0);
			q : out std_logic_vector(n - 1 downto 0)
		);
	end component;
	
	component mux_4_1
		generic (
			n_inputs:    positive := 4;
			inputs_width: positive := 32        
		);
		
		port (
			a: in std_logic_vector(n_inputs*inputs_width-1 downto 0); --works in ise 14.7 --vhdl2003 compatible
			sel: in std_logic_vector(3 downto 0);
			y: out std_logic_vector(inputs_width-1 downto 0)
		);
	end component;
	
	component pid_controller 
	
	generic (
			n_pps_interrupt_counter : positive := 32; --need to count up to 50e6 (using 50MHz clock) to 1s interrupt
			n_max_encoder_count : positive := 32; --max: 71400 -> 340PPR*210 rpm
			n_pwm_res : positive :=8; --read-only
			--vhdl2003 doesn't permit the use of one generic to parametrize another one
			ppr_constant: std_logic_vector (31 downto 0) := "00111110001101001010001000110100"; --0.1764 (60/PPR)
			kp_constant: std_logic_vector (31 downto 0) :=  "00111111000000000000000000000000"; --0.5
			ki_constant: std_logic_vector (31 downto 0) :=  "00111110100110011001100110011010"; --0.3
			kd_constant: std_logic_vector (31 downto 0) :=  "00111111100000000000000000000000" --1
	); 
	port (
		--common
		clk, rst : in std_logic;
		
		--inputs
		cmd: in std_logic_vector(1 downto 0);
		user_rpm: in std_logic_vector(n_pwm_res-1 downto 0);
		pps_interrupt_in : in std_logic_vector(n_pps_interrupt_counter-1 downto 0);
		encoder_in: in std_logic;
		
		--debug output
		encoder_count: out std_logic_vector(n_pps_interrupt_counter-1 downto 0);
		current_rpm : out std_logic_vector(n_pps_interrupt_counter - 1 downto 0);
		pid_out: out std_logic_vector(31 downto 0);
		
		--block outputs
		operational_error : out std_logic_vector(31 downto 0);
		pwm_out: out std_logic
	);
	end component;
	
begin

	input_address_decoder_inst: decoder_2_4 
	port map (
		a => address(3 downto 2),
		b => decoder_2_4_out
	);

	output_address_decoder_inst: decoder_3_4 
	port map (
		a => address(4 downto 2),
		b => decoder_3_4_out
	);
	
	pid_controller_inst : pid_controller
	generic map (
		 n_pps_interrupt_counter => n_pps_interrupt_counter,
       n_max_encoder_count => n_max_encoder_count,
		 n_pwm_res => n_pwm_res,
		 --vhdl2003 doesn't permit the use of one generic to parametrize another one
		 ppr_constant => ppr_constant,
		 kp_constant => kp_constant,
		 ki_constant => ki_constant,
		 kd_constant => kd_constant 
	)
	
	port map (
		--common
		clk  => clk,
		rst  => rst,
		
		--inputs
		cmd  => cmd_reg_out(1 downto 0),
		user_rpm  => rpm_in_reg_out(7 downto 0),
		encoder_in  => encoder_in,
		pps_interrupt_in => pps_interrupt_reg_out,
	
		--debug output
		encoder_count  => encoder_count_sig,
		current_rpm  => current_rpm_sig,
		pid_out  => pid_out_sig,
		
		--block outputs
		operational_error  => operational_error_sig,
		pwm_out => pwm_out
			
	);

	reg_pps_interrupt_in : n_register
	generic map(n => 32)
	port map(
		clk => clk, 
		rst => rst, 
		load => write and decoder_2_4_out(0), --revolutions per second
		d => writedata, 
		q => pps_interrupt_reg_out
	);

	reg_cmd : n_register
	generic map(n => 32)
	port map(
		clk => clk, 
		rst => rst, 
		load => write and decoder_2_4_out(1), --revolutions per second
		d => writedata, 
		q => cmd_reg_out
	);
	
	reg_rpm_in : n_register
	generic map(n => 32)
	port map(
		clk => clk, 
		rst => rst, 
		load => write and decoder_2_4_out(2), --revolutions per second
		d => writedata, 
		q => rpm_in_reg_out
	);
	
	
	mux_input <= current_rpm_sig & pid_out_sig & encoder_count_sig & operational_error_sig;
	tmp_sel <=  (read and decoder_3_4_out(3)) & (read and decoder_3_4_out(2)) & (read and decoder_3_4_out(1)) & (read and decoder_3_4_out(0));
	
	out_mut: mux_4_1 
   generic map (
     n_inputs => 4,
     inputs_width => 32
   )
   port map (
       a => mux_input,
       sel => tmp_sel,
       y => readdata
     );
	
	
	
end behavioral;

