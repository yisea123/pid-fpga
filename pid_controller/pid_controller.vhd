library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pid_controller is 

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
	cmd_send: in std_logic;
	user_rpm: in std_logic_vector(n_pwm_res-1 downto 0);
	--pps_interrupt_in : in std_logic_vector(n_pps_interrupt_counter-1 downto 0);
	encoder_in: in std_logic;
	
	--debug output
	--encoder_count: out std_logic_vector(n_pps_interrupt_counter-1 downto 0);
	--current_rpm : out std_logic_vector(n_pps_interrupt_counter - 1 downto 0);
	pid_out: out std_logic_vector(31 downto 0);
	state_debug: out std_logic_vector(7 downto 0);
	
	--block outputs
	operational_error_encoder : out std_logic_vector(23 downto 0);
	operational_error_pid: out std_logic_vector(31 downto 0);
	pwm_out: out std_logic
);
end pid_controller;

architecture behavioral of pid_controller is

	signal 	current_rpm_temp :  std_logic_vector(n_max_encoder_count - 1 downto 0);
	signal	pid_out_temp:  std_logic_vector(31 downto 0);
	signal	encoder_count_temp:  std_logic_vector(n_max_encoder_count-1 downto 0);
	signal	pps_interrupt_in_temp : std_logic_vector(n_pps_interrupt_counter-1 downto 0) := "01001100001111101011110000100000";
	
component control_unit
port (
		--common
		clk, rst : in std_logic;
		rst_pps_interrupt : out std_logic; --used at the moment the pwm is applied to the motor
		rst_encoder_pulse_counter : out std_logic;  

		--inputs
		cmd: in std_logic_vector(1 downto 0);
		cmd_send: in std_logic;

		--control inputs
      pps_interrupt_trigger : in std_logic; --1s interrupt to calculate pps
		delay_counter_trigger : in std_logic;  

		--error inputs
		--encoder
			pps_diff_ovf : in std_logic;
		pps_diff_udf : in std_logic;
		pps_diff_nan : in std_logic;
		pps_diff_zero : in std_logic;
		const_mult_ovf : in std_logic;
		const_mult_udf : in std_logic;
		const_mult_nan : in std_logic;
		const_mult_zero : in std_logic;
		
		current_error_ovf : in std_logic;
		current_error_udf : in std_logic;
		current_error_nan : in std_logic;
		current_error_zero : in std_logic;
		
		kp_mult_ovf : in std_logic;
		kp_mult_udf : in std_logic;
		kp_mult_nan : in std_logic;
		kp_mult_zero : in std_logic;
		
		ki_mult_ovf : in std_logic;
		ki_mult_udf : in std_logic;
		ki_mult_nan : in std_logic;
		ki_mult_zero : in std_logic;
		
		kd_mult_ovf : in std_logic;
		kd_mult_udf : in std_logic;
		kd_mult_nan : in std_logic;
		kd_mult_zero : in std_logic;
		
		ki_sum_ovf : in std_logic;
		ki_sum_udf : in std_logic;		
		ki_sum_nan : in std_logic;
		ki_sum_zero : in std_logic;
		
		kd_diff_ovf : in std_logic;
		kd_diff_udf : in std_logic;
		kd_diff_nan : in std_logic;
		kd_diff_zero : in std_logic;
		
		ki_kd_sum_ovf : in std_logic;
		ki_kd_sum_udf : in std_logic;
		ki_kd_sum_nan : in std_logic;
		ki_kd_sum_zero : in std_logic;
		
		kp_ki_kd_sum_ovf : in std_logic;
		kp_ki_kd_sum_udf : in std_logic;
		kp_ki_kd_sum_nan : in std_logic;
		kp_ki_kd_sum_zero : in std_logic;	
		
		pid_fpconversion_ovf : in std_logic;
		pid_fpconversion_udf : in std_logic;
		pid_fpconversion_nan : in std_logic;
		pid_fpconversion_neg : in std_logic;
		pwm_complement_ovf: in std_logic;
		
		--control outputs
		--encoder
		en_pps_interrupt : out std_logic;
 		en_pps_diff: out std_logic;
		en_const_mult: out std_logic;
		en_pps_conversion: out std_logic;
		en_pid_fpconversion: out std_logic;
		en_pwm_complement : out std_logic;
		en_user_rpm_conversion : out std_logic;
		
		load_current_pps : out std_logic; --rps stands for revolutions per seconds
		load_prev_pps : out std_logic;
	
		--pid
		en_diff_current_error: out std_logic;
		en_sum_ki: out std_logic;
		en_diff_kd: out std_logic;
		en_mult : out std_logic;
		en_sum_ki_kd : out std_logic;
		en_sum_kp_ki_kd : out std_logic;
		
		load_user_rpm: out std_logic;
		load_pps_interrupt_in: out std_logic;
		load_current_rpm: out std_logic;
		load_total_error: out std_logic;
		load_last_error: out std_logic;
		load_kp_mult_reg: out std_logic;
		load_pid_res: out std_logic;
		
		--control the number of waiting cycles per arith operation
      en_delay_counter : out std_logic; 
		delay_counter_in: out std_logic_vector(7 downto 0);

		--block output
		operational_error_encoder : out std_logic_vector(23 downto 0);
		operational_error_pid: out std_logic_vector(31 downto 0);
		
		--debug output
		state_debug: out std_logic_vector(7 downto 0)
	);
end component;


component operational_unit
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
		rst_pps_interrupt : in std_logic; --used at the moment the pwm is applied to the motor
		rst_encoder_pulse_counter: in std_logic;


		--block inputs
		--common
		delay_counter_in: in std_logic_vector(7 downto 0);
		encoder_in : in std_logic;
		user_rpm: in std_logic_vector(n_pwm_res-1 downto 0);
		pps_interrupt_in : in std_logic_vector(n_pps_interrupt_counter-1 downto 0);
		
		--control inputs
		--common
		en_delay_counter : in std_logic;
		
		--encoder
		en_pps_interrupt : in std_logic;
		en_pps_diff: in std_logic;
		en_const_mult: in std_logic;
		en_pps_conversion: in std_logic;

		
		load_current_pps : in std_logic; --rps stands for revolutions per seconds
		load_prev_pps : in std_logic;
	
		--pid
		en_user_rpm_conversion : in std_logic;
		en_diff_current_error: in std_logic;
		en_sum_ki: in std_logic;
		en_diff_kd: in std_logic;
		en_mult : in std_logic;
		en_sum_ki_kd : in std_logic;
		en_sum_kp_ki_kd : in std_logic;
		en_pid_fpconversion: in std_logic;
		--en_pwm_complement : in std_logic;	
		
		load_user_rpm: in std_logic;
		load_pps_interrupt_in : in std_logic;
		load_current_rpm: in std_logic;
		load_total_error: in std_logic;
		load_last_error: in std_logic;
		load_kp_mult_reg: in std_logic;
		load_pid_res: in std_logic;
		
	
		--arithmetic blocks outputs
--pwm_complement_ovf: out std_logic;
		
		pps_diff_ovf : out std_logic;
		pps_diff_udf : out std_logic;
		pps_diff_nan : out std_logic;
		pps_diff_zero : out std_logic;
		const_mult_ovf : out std_logic;
		const_mult_udf : out std_logic;
		const_mult_nan : out std_logic;
		const_mult_zero : out std_logic;
		current_error_ovf : out std_logic;
		current_error_udf : out std_logic;
		current_error_nan : out std_logic;
		current_error_zero : out std_logic;
		kp_mult_ovf : out std_logic;
		kp_mult_udf : out std_logic;
		kp_mult_nan : out std_logic;
		kp_mult_zero : out std_logic;
		ki_mult_ovf : out std_logic;
		ki_mult_udf : out std_logic;
		ki_mult_nan : out std_logic;
		ki_mult_zero : out std_logic;
		kd_mult_ovf : out std_logic;
		kd_mult_udf : out std_logic;
		kd_mult_nan : out std_logic;
		kd_mult_zero : out std_logic;
		ki_sum_ovf : out std_logic;
		ki_sum_udf : out std_logic;		
		ki_sum_nan : out std_logic;
		ki_sum_zero : out std_logic;
		kd_diff_ovf : out std_logic;
		kd_diff_udf : out std_logic;
		kd_diff_nan : out std_logic;
		kd_diff_zero : out std_logic;
		ki_kd_sum_ovf : out std_logic;
		ki_kd_sum_udf : out std_logic;
		ki_kd_sum_nan : out std_logic;
		ki_kd_sum_zero : out std_logic;
		kp_ki_kd_sum_ovf : out std_logic;
		kp_ki_kd_sum_udf : out std_logic;
		kp_ki_kd_sum_nan : out std_logic;
		kp_ki_kd_sum_zero : out std_logic;				
		pid_fpconversion_ovf : out std_logic;
		pid_fpconversion_udf : out std_logic;
		pid_fpconversion_nan : out std_logic;
		pid_fpconversion_neg : out std_logic;
		
      --control outputs
      pps_interrupt_trigger : out std_logic; --1s interrupt to calculate encoder pps
		delay_counter_trigger : out std_logic;  --used to count clock cycles inside arithmetic processes
		
		--debug outputs
		current_rpm : out std_logic_vector(n_max_encoder_count - 1 downto 0);
		pid_out: out std_logic_vector(31 downto 0);
		encoder_count: out std_logic_vector(n_max_encoder_count-1 downto 0);
	
		--block outputs
		pwm_out: out std_logic

	);
end component;

   

--  input signals                                                   
signal rst_pps_interrupt_sig : std_logic;
signal en_pps_interrupt_sig : std_logic;
signal user_rpm_sig : std_logic_vector(n_pwm_res-1 downto 0);
signal pps_interrupt_in_sig :std_logic_vector(n_pps_interrupt_counter-1 downto 0);
signal en_user_rpm_conversion_sig: std_logic;
signal current_rpm_sig : std_logic_vector(n_max_encoder_count-1 downto 0);
signal en_diff_current_error_sig: std_logic;
signal en_sum_ki_sig: std_logic;
signal en_diff_kd_sig: std_logic;
signal en_mult_sig : std_logic;
signal en_sum_ki_kd_sig : std_logic;
signal en_sum_kp_ki_kd_sig : std_logic;
signal en_pwm_complement_sig: std_logic;
signal en_pid_fpconversion_sig : std_logic;
signal load_user_rpm_sig : std_logic;
signal load_current_rpm_sig : std_logic;
signal load_total_error_sig : std_logic;
signal load_last_error_sig : std_logic;
signal load_kp_mult_reg_sig : std_logic;
signal load_pid_res_sig : std_logic;
signal load_pps_interrupt_in_sig : std_logic;

--control inputs
signal en_pps_diff_sig:  std_logic;
signal en_const_mult_sig:  std_logic;
signal en_pps_conversion_sig:  std_logic;

signal load_current_pps_sig : std_logic;
signal load_prev_pps_sig : std_logic;

 --control outputs
signal pps_diff_error_sig : std_logic;
signal const_mult_error_sig : std_logic;
 
 --counter signals
 signal pps_interrupt_trigger_sig : std_logic;

 --control outputs
signal  delay_counter_in_sig : std_logic_vector(7 downto 0);
signal  en_delay_counter_sig : std_logic;
signal  delay_counter_trigger_sig : std_logic;

signal  pwm_complement_ovf_sig : std_logic;

signal  pps_diff_ovf_sig : std_logic;
signal		pps_diff_udf_sig : std_logic;
signal		pps_diff_nan_sig : std_logic;
signal		pps_diff_zero_sig : std_logic;
signal		const_mult_ovf_sig : std_logic;
signal		const_mult_udf_sig : std_logic;
signal		const_mult_nan_sig : std_logic;
signal		const_mult_zero_sig : std_logic;
signal		current_error_ovf_sig : std_logic;
signal		current_error_udf_sig: std_logic;
signal		current_error_nan_sig: std_logic;
signal		current_error_zero_sig : std_logic;
signal		kp_mult_ovf_sig : std_logic;
signal		kp_mult_udf_sig : std_logic;
signal		kp_mult_nan_sig : std_logic;
signal		kp_mult_zero_sig : std_logic;
signal		ki_mult_ovf_sig : std_logic;
signal		ki_mult_udf_sig : std_logic;
signal		ki_mult_nan_sig : std_logic;
signal		ki_mult_zero_sig : std_logic;
signal		kd_mult_ovf_sig : std_logic;
signal		kd_mult_udf_sig : std_logic;
signal		kd_mult_nan_sig : std_logic;
signal		kd_mult_zero_sig : std_logic;
signal		ki_sum_ovf_sig : std_logic;
signal		ki_sum_udf_sig : std_logic;
signal		ki_sum_nan_sig : std_logic;
signal		ki_sum_zero_sig : std_logic;
signal		kd_diff_ovf_sig : std_logic;
signal		kd_diff_udf_sig : std_logic;
signal		kd_diff_nan_sig : std_logic;
signal		kd_diff_zero_sig: std_logic;
signal		ki_kd_sum_ovf_sig : std_logic;
signal		ki_kd_sum_udf_sig : std_logic;
signal		ki_kd_sum_nan_sig : std_logic;
signal		ki_kd_sum_zero_sig : std_logic;
signal		kp_ki_kd_sum_ovf_sig : std_logic;
signal		kp_ki_kd_sum_udf_sig : std_logic;
signal		kp_ki_kd_sum_nan_sig : std_logic;
signal		kp_ki_kd_sum_zero_sig : std_logic;
signal		pid_fpconversion_ovf_sig : std_logic;
signal		pid_fpconversion_udf_sig : std_logic;
signal		pid_fpconversion_nan_sig: std_logic;
signal		pid_fpconversion_neg_sig : std_logic;

 signal pid_out_sig : std_logic_vector( 31 downto 0);
 signal rst_encoder_pulse_counter_sig : std_logic;
 signal encoder_count_sig:std_logic_vector(n_max_encoder_count-1 downto 0);
 signal pwm_out_sig : std_logic; 
 
begin

	pps_interrupt_in_temp <= "01001100001111101011110000100000";
	
control_unit_inst : control_unit

	port map (
-- list connections between master ports and signals
		clk => clk,
		rst => rst,
		rst_pps_interrupt => rst_pps_interrupt_sig, --used at the moment the pwm is applied to the motor
		rst_encoder_pulse_counter =>  rst_encoder_pulse_counter_sig,

		--inputs
		cmd => cmd,
		cmd_send => cmd_send,
		
	   --control inputs
      pps_interrupt_trigger => pps_interrupt_trigger_sig,
		delay_counter_trigger => delay_counter_trigger_sig,  	
	
		--error inputs
				pwm_complement_ovf => pwm_complement_ovf_sig,
		
		pps_diff_ovf => pps_diff_ovf_sig,
		pps_diff_udf => pps_diff_udf_sig,
		pps_diff_nan => pps_diff_nan_sig,
		pps_diff_zero => pps_diff_zero_sig,
		const_mult_ovf => const_mult_ovf_sig,
		const_mult_udf => const_mult_udf_sig,
		const_mult_nan => const_mult_nan_sig,
		const_mult_zero => const_mult_zero_sig,
		current_error_ovf => current_error_ovf_sig,
		current_error_udf => current_error_udf_sig,
		current_error_nan => current_error_nan_sig,
		current_error_zero => current_error_zero_sig,
		kp_mult_ovf => kp_mult_ovf_sig,
		kp_mult_udf => kp_mult_udf_sig,
		kp_mult_nan => kp_mult_nan_sig,
		kp_mult_zero => kp_mult_zero_sig,
		ki_mult_ovf => ki_mult_ovf_sig,
		ki_mult_udf => ki_mult_udf_sig,
		ki_mult_nan => ki_mult_nan_sig,
		ki_mult_zero => ki_mult_zero_sig,
		kd_mult_ovf => kd_mult_ovf_sig,
		kd_mult_udf => kd_mult_udf_sig,
		kd_mult_nan => kd_mult_nan_sig,
		kd_mult_zero => kd_mult_zero_sig,
		ki_sum_ovf => ki_sum_ovf_sig,
		ki_sum_udf => ki_sum_udf_sig,
		ki_sum_nan => ki_sum_nan_sig,
		ki_sum_zero => ki_sum_zero_sig,
		kd_diff_ovf => kd_diff_ovf_sig,
		kd_diff_udf => kd_diff_udf_sig,
		kd_diff_nan => kd_diff_nan_sig,
		kd_diff_zero => kd_diff_zero_sig,
		ki_kd_sum_ovf => ki_kd_sum_ovf_sig,
		ki_kd_sum_udf => ki_kd_sum_udf_sig,
		ki_kd_sum_nan => ki_kd_sum_nan_sig,
		ki_kd_sum_zero => ki_kd_sum_zero_sig,
		kp_ki_kd_sum_ovf => kp_ki_kd_sum_ovf_sig,
		kp_ki_kd_sum_udf => kp_ki_kd_sum_udf_sig,
		kp_ki_kd_sum_nan => kp_ki_kd_sum_nan_sig,
		kp_ki_kd_sum_zero => kp_ki_kd_sum_zero_sig,	
		pid_fpconversion_ovf => pid_fpconversion_ovf_sig,
		pid_fpconversion_udf => pid_fpconversion_udf_sig,
		pid_fpconversion_nan => pid_fpconversion_nan_sig,
		pid_fpconversion_neg => pid_fpconversion_neg_sig,
		
		--control outputs
		--encoder
		en_pps_interrupt => en_pps_interrupt_sig,
 		en_pps_diff => en_pps_diff_sig,
		en_const_mult => en_const_mult_sig,
		en_pps_conversion => en_pps_conversion_sig,
		en_pid_fpconversion => en_pid_fpconversion_sig,
		en_pwm_complement => en_pwm_complement_sig,
		en_user_rpm_conversion => en_user_rpm_conversion_sig,
		
		load_current_pps => load_current_pps_sig, --rps stands for revolutions per seconds
		load_prev_pps => load_prev_pps_sig,
	
		--pid
		en_diff_current_error => en_diff_current_error_sig,
		en_sum_ki => en_sum_ki_sig,
		en_diff_kd => en_diff_kd_sig,
		en_mult => en_mult_sig,
		en_sum_ki_kd => en_sum_ki_kd_sig,
		en_sum_kp_ki_kd => en_sum_kp_ki_kd_sig,
		
		load_user_rpm => load_user_rpm_sig,
		load_pps_interrupt_in => load_pps_interrupt_in_sig,
		load_current_rpm => load_current_rpm_sig,
		load_total_error => load_total_error_sig,
		load_last_error => load_last_error_sig,
		load_kp_mult_reg=> load_kp_mult_reg_sig,
		load_pid_res => load_pid_res_sig,
		
		--control the number of waiting cycles per arith operation
      delay_counter_in => delay_counter_in_sig,
      en_delay_counter => en_delay_counter_sig,
		
		--block output
		operational_error_encoder => operational_error_encoder,
		operational_error_pid => operational_error_pid,
		--debug output
		state_debug => state_debug
	);	
	
operational_unit_inst : operational_unit
    generic map (
	     n_pps_interrupt_counter => n_pps_interrupt_counter,--need to count up to 50e6 (using 50MHz clock) to 1s interrupt
		  n_max_encoder_count => n_max_encoder_count, --max: 71400 -> 340PPR*210 rpm
		  n_pwm_res => n_pwm_res, --read-only
		  --vhdl2003 doesn't permit the use of one generic to parametrize another one
		  ppr_constant => ppr_constant, --0.1764 (60/PPR)
		  kp_constant => kp_constant, --0.5
		  ki_constant =>  ki_constant, --0.3
		  kd_constant =>  kd_constant --1
		  )
    
	port map (
		--common
      clk => clk,
      rst => rst,
	
		rst_pps_interrupt => rst_pps_interrupt_sig,
		rst_encoder_pulse_counter => rst_encoder_pulse_counter_sig,

		--block inputs
		--common
		delay_counter_in => delay_counter_in_sig,
		encoder_in => encoder_in,
		user_rpm => user_rpm,
		--pps_interrupt_in => pps_interrupt_in,
		pps_interrupt_in => pps_interrupt_in_temp,
		--control inputs
		--common
		en_delay_counter => en_delay_counter_sig,
		
		--encoder
		en_user_rpm_conversion => en_user_rpm_conversion_sig,
		en_pps_interrupt => en_pps_interrupt_sig,
		en_pps_diff => en_pps_diff_sig,
		en_const_mult => en_const_mult_sig,
		en_pps_conversion => en_pps_conversion_sig,

		load_current_pps => load_current_pps_sig, --rps stands for revolutions per seconds
		load_prev_pps => load_prev_pps_sig,
	
		--pid
		en_diff_current_error => en_diff_current_error_sig,
		en_sum_ki => en_sum_ki_sig,
		en_diff_kd => en_diff_kd_sig,
		en_mult => en_mult_sig,
		en_sum_ki_kd => en_sum_ki_kd_sig,
		en_sum_kp_ki_kd => en_sum_kp_ki_kd_sig,
		en_pid_fpconversion => en_pid_fpconversion_sig,
		--en_pwm_complement => en_pwm_complement_sig,
		
		load_user_rpm => load_user_rpm_sig,
		load_pps_interrupt_in => load_pps_interrupt_in_sig ,
		load_current_rpm => load_current_rpm_sig,
		load_total_error => load_total_error_sig,
		load_last_error => load_last_error_sig,
		load_kp_mult_reg => load_kp_mult_reg_sig,
		load_pid_res => load_pid_res_sig,
		
	
		--arithmetic blocks outputs
		--encoder
		--pwm_complement_ovf => pwm_complement_ovf_sig,
		
		pps_diff_ovf => pps_diff_ovf_sig,
		pps_diff_udf => pps_diff_udf_sig,
		pps_diff_nan => pps_diff_nan_sig,
		pps_diff_zero => pps_diff_zero_sig,
		const_mult_ovf => const_mult_ovf_sig,
		const_mult_udf => const_mult_udf_sig,
		const_mult_nan => const_mult_nan_sig,
		const_mult_zero => const_mult_zero_sig,
		current_error_ovf => current_error_ovf_sig,
		current_error_udf => current_error_udf_sig,
		current_error_nan => current_error_nan_sig,
		current_error_zero => current_error_zero_sig,
		kp_mult_ovf => kp_mult_ovf_sig,
		kp_mult_udf => kp_mult_udf_sig,
		kp_mult_nan => kp_mult_nan_sig,
		kp_mult_zero => kp_mult_zero_sig,
		ki_mult_ovf => ki_mult_ovf_sig,
		ki_mult_udf => ki_mult_udf_sig,
		ki_mult_nan => ki_mult_nan_sig,
		ki_mult_zero => ki_mult_zero_sig,
		kd_mult_ovf => kd_mult_ovf_sig,
		kd_mult_udf => kd_mult_udf_sig,
		kd_mult_nan => kd_mult_nan_sig,
		kd_mult_zero => kd_mult_zero_sig,
		ki_sum_ovf => ki_sum_ovf_sig,
		ki_sum_udf => ki_sum_udf_sig,
		ki_sum_nan => ki_sum_nan_sig,
		ki_sum_zero => ki_sum_zero_sig,
		kd_diff_ovf => kd_diff_ovf_sig,
		kd_diff_udf => kd_diff_udf_sig,
		kd_diff_nan => kd_diff_nan_sig,
		kd_diff_zero => kd_diff_zero_sig,
		ki_kd_sum_ovf => ki_kd_sum_ovf_sig,
		ki_kd_sum_udf => ki_kd_sum_udf_sig,
		ki_kd_sum_nan => ki_kd_sum_nan_sig,
		ki_kd_sum_zero => ki_kd_sum_zero_sig,
		kp_ki_kd_sum_ovf => kp_ki_kd_sum_ovf_sig,
		kp_ki_kd_sum_udf => kp_ki_kd_sum_udf_sig,
		kp_ki_kd_sum_nan => kp_ki_kd_sum_nan_sig,
		kp_ki_kd_sum_zero => kp_ki_kd_sum_zero_sig,	
		pid_fpconversion_ovf => pid_fpconversion_ovf_sig,
		pid_fpconversion_udf => pid_fpconversion_udf_sig,
		pid_fpconversion_nan => pid_fpconversion_nan_sig,
		pid_fpconversion_neg => pid_fpconversion_neg_sig,
		
      --control outputs
      pps_interrupt_trigger => pps_interrupt_trigger_sig,--1s interrupt to calculate encoder pps
		delay_counter_trigger => delay_counter_trigger_sig,  --used to count clock cycles inside arithmetic processes
		
		--debug outputs
		current_rpm => current_rpm_temp, --current_rpm,
		pid_out => pid_out,
		encoder_count => encoder_count_sig,
	
		--block outputs
		pwm_out => pwm_out
			
);

end behavioral;