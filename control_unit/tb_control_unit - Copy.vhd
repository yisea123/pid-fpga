
library ieee;                                               
use ieee.std_logic_1164.all;                                
use ieee.numeric_std.all;
                            

entity tb_control_unit is
end tb_control_unit;
architecture controller_arch of tb_control_unit is

	 constant fp_conversion_cycles : integer := 6;
	 constant fp_addsub_cycles : integer := 7;
	 constant fp_mult_cycles : integer := 5; 
	 constant pid_comb_logic_cycles : integer := 4;
	 constant clk_period : time := 20 ns;   
	
	-- signals                                                   
	signal clk_sig, rst_sig :  std_logic;
		
	--inputs
	signal	cmd_sig:  std_logic_vector(1 downto 0) := (others=>'0');
		
	--encoder
	signal	pps_diff_error_sig:  std_logic :='0';
	signal	const_mult_error_sig:  std_logic:='0';
	--pid
	signal	current_error_diff_error_sig :  std_logic:='0';			
	signal	kp_mult_error_sig:  std_logic:='0';			
	signal	ki_mult_error_sig:  std_logic:='0';		
	signal	kd_mult_error_sig :  std_logic:='0';
	signal	ki_sum_error_sig :  std_logic:='0';
	signal	kd_diff_error_sig:  std_logic:='0';		
	signal	ki_kd_sum_error_sig:  std_logic:='0';		
	signal	kp_ki_kd_sum_error_sig:  std_logic:='0'; 
	signal	pid_fpconversion_error_sig :  std_logic:='0';
	signal	pwm_complement_ovf_sig:  std_logic:='0';
		
   --control inputs
	--encoder
   signal   pps_interrupt_trigger_sig :  std_logic:='0';
	signal	delay_counter_trigger_sig :  std_logic:='0';  
		
		--control outputs
		--encoder
	signal	rst_pps_interrupt_sig :  std_logic :='0'; --used at the moment the pwm is applied to the motor
	signal	en_pps_interrupt_sig :  std_logic :='0';
 	signal	en_pps_diff_sig:  std_logic :='0';
	signal	en_const_mult_sig:  std_logic :='0';
	signal	en_pps_conversion_sig:  std_logic :='0';
	signal	en_pid_fpconversion_sig:  std_logic :='0';
	signal	en_pwm_complement_sig :  std_logic :='0';
		
	signal	load_current_pps_sig :  std_logic :='0'; --rps stands for revolutions per seconds
	signal	load_prev_pps_sig :  std_logic :='0';
	
		--pid
	signal	en_diff_current_error_sig:  std_logic :='0';
	signal	en_sum_ki_sig:  std_logic :='0';
	signal	en_diff_kd_sig:  std_logic :='0';
	signal	en_mult_sig :  std_logic :='0';
	signal	en_sum_ki_kd_sig :  std_logic :='0';
	signal	en_sum_kp_ki_kd_sig :  std_logic :='0';
		
	signal	load_user_rpm_sig:  std_logic :='0';
	signal	load_pps_interrupt_in_sig:  std_logic :='0';
	signal	load_current_rpm_sig:  std_logic :='0';
	signal	load_total_error_sig:  std_logic :='0';
	signal	load_last_error_sig:  std_logic :='0';
	signal	load_kp_mult_reg_sig:  std_logic :='0';
	signal	load_pid_res_sig:  std_logic :='0';
		
		--delay counter
   signal  delay_counter_in_sig:  std_logic_vector(7 downto 0) := (others =>'0');
   signal  en_delay_counter_sig :  std_logic :='0';
		
	signal operational_error_sig :  std_logic :='0';
	signal state_debug_sig: std_logic_vector(7 downto 0) := (others =>'0');
	signal rst_encoder_pulse_counter_sig: std_logic := '0';
	signal en_user_rpm_conversion_sig: std_logic := '0';

component control_unit 

	port (
		--common
		clk, rst : in std_logic;
		rst_pps_interrupt : out std_logic; --used at the moment the pwm is applied to the motor
		rst_encoder_pulse_counter : out std_logic;  

		--inputs
		cmd: in std_logic_vector(1 downto 0);

		--control inputs
      pps_interrupt_trigger : in std_logic; --1s interrupt to calculate pps
		delay_counter_trigger : in std_logic;  

		--error inputs
		--encoder
		pps_diff_error: in std_logic;
		const_mult_error: in std_logic;
		--pid
		current_error_diff_error : in std_logic;			
		kp_mult_error: in std_logic;			
		ki_mult_error: in std_logic;		
		kd_mult_error : in std_logic;
		ki_sum_error : in std_logic;
		kd_diff_error: in std_logic;		
		ki_kd_sum_error: in std_logic;		
		kp_ki_kd_sum_error: in std_logic; 
		pid_fpconversion_error : in std_logic;
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
		operational_error : out std_logic;
		
		--debug output
		state_debug: out std_logic_vector(7 downto 0)
	);
end component;

begin
	control_unit_inst : control_unit

	port map (
-- list connections between master ports and signals
		clk => clk_sig,
		rst => rst_sig,
		rst_pps_interrupt => rst_pps_interrupt_sig, --used at the moment the pwm is applied to the motor
		rst_encoder_pulse_counter =>  rst_encoder_pulse_counter_sig,

		--inputs
		cmd => cmd_sig,
		
	   --control inputs
      pps_interrupt_trigger => pps_interrupt_trigger_sig,
		delay_counter_trigger => delay_counter_trigger_sig,  	
	
		--error inputs
		--encoder
		pps_diff_error => pps_diff_error_sig,
		const_mult_error => const_mult_error_sig,
		--pid
		current_error_diff_error => current_error_diff_error_sig,			
		kp_mult_error => kp_mult_error_sig,			
		ki_mult_error => ki_mult_error_sig,		
		kd_mult_error => kd_mult_error_sig,
		ki_sum_error => ki_sum_error_sig,
		kd_diff_error => kd_diff_error_sig,		
		ki_kd_sum_error => ki_kd_sum_error_sig,		
		kp_ki_kd_sum_error => kp_ki_kd_sum_error_sig, 
		pid_fpconversion_error => pid_fpconversion_error_sig,
		pwm_complement_ovf => pwm_complement_ovf_sig,
		
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
		operational_error => operational_error_sig, 
		
		--debug output
		state_debug => state_debug_sig
	);


clk_proc : process 
begin
    clk_sig <= '0';
    wait for clk_period/2;
    clk_sig <= '1';
    wait for clk_period/2;
end process clk_proc;           

                                          
always : process                                              
                                   
begin                                                         
	rst_sig <= '1';
	wait for 2*clk_period;
	rst_sig <= '0';
	wait for clk_period;
	cmd_sig <= "01";
	wait for 2*clk_period;
	cmd_sig <= "10";
	wait for 2*clk_period;
	cmd_sig <= "11";
	wait for 100 us;
	pps_interrupt_trigger_sig <= '1';
	wait for clk_period;
	pps_interrupt_trigger_sig <= '0';

	wait for fp_conversion_cycles*clk_period;
	delay_counter_trigger_sig <= '1';
	wait for clk_period;
	delay_counter_trigger_sig <= '0';
	
	wait for fp_addsub_cycles*clk_period;
	delay_counter_trigger_sig <= '1';
	wait for clk_period;
	delay_counter_trigger_sig <= '0';
	
	wait for fp_mult_cycles*clk_period;
	delay_counter_trigger_sig <= '1';
	wait for clk_period;
	delay_counter_trigger_sig <= '0';
	wait for clk_period;
	
	wait for fp_addsub_cycles*clk_period;
	delay_counter_trigger_sig <= '1';
	wait for clk_period;
	delay_counter_trigger_sig <= '0';
	
	wait for fp_addsub_cycles*clk_period;
	delay_counter_trigger_sig <= '1';
	wait for clk_period;
	delay_counter_trigger_sig <= '0';
	
	wait for fp_mult_cycles*clk_period;
	delay_counter_trigger_sig <= '1';
	wait for clk_period;
	delay_counter_trigger_sig <= '0';

	wait for fp_addsub_cycles*clk_period;
	delay_counter_trigger_sig <= '1';
	wait for clk_period;
	delay_counter_trigger_sig <= '0';
	
	wait for fp_addsub_cycles*clk_period;
	delay_counter_trigger_sig <= '1';
	wait for clk_period;
	delay_counter_trigger_sig <= '0';
	
	wait for fp_mult_cycles*clk_period;
	delay_counter_trigger_sig <= '1';
	wait for clk_period;
	delay_counter_trigger_sig <= '0';
	
	wait for clk_period;
		wait for pid_comb_logic_cycles*clk_period;
	delay_counter_trigger_sig <= '1';
	wait for clk_period;
	delay_counter_trigger_sig <= '0';
	
	wait for 10*clk_period;


wait;                                                        
end process always;                                          
end controller_arch;
