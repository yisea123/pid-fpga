
library ieee;                                               
use ieee.std_logic_1164.all;                                
use ieee.numeric_std.all;

entity tb_operational_unit is
end tb_operational_unit;
architecture behavioral of tb_operational_unit is

-- constants   
constant const_n_pwm_res : positive := 8;
constant const_n_arithmetics_width : positive := 32;      
constant const_n_pps_interrupt_counter : positive := 32;      
constant const_n_max_encoder_count : positive := 32;      

--frequency to generate an interrupt equivalent to 1s in real use (50e6)
constant counter_1kHz : unsigned(const_n_arithmetics_width-1 downto 0) := to_unsigned(50_000, const_n_pps_interrupt_counter);    
constant clk_period : time := 20 ns;          
signal motor_period : time := 588 ns; --double this to get motor real period (generates 680 pulses in 1s) -- 735ns:120RPM
--588 ns --150RPM
--signal motor_period : time := 0 ns; --double this to get motor real period (generates 680 pulses in 1s)

constant FP_CONVERSION_CYCLES : integer := 8; --6 + 1 due to the problem with counter reset
constant FP_ADDSUB_CYCLES : integer := 8; --7
constant FP_MULT_CYCLES : integer := 6; --5 
constant PID_COMB_LOGIC_CYCLES : integer := 5; --4

--pid constants
constant pid_kp : std_logic_vector (const_n_arithmetics_width-1 downto 0) :=  "00111111000000000000000000000000"; --0.5
constant pid_ki : std_logic_vector (const_n_arithmetics_width-1 downto 0) :=  "00111110100110011001100110011010"; --0.3
constant pid_kd : std_logic_vector (const_n_arithmetics_width-1 downto 0) :=  "00111111100000000000000000000000"; --1
constant const_ppr : std_logic_vector (const_n_arithmetics_width - 1 downto 0) := "00111110001101001010001000110100";
--  input signals                                                   
signal clk_sig : std_logic;
signal rst_sig : std_logic := '0';
signal encoder_in_sig : std_logic;
signal rst_pps_interrupt_sig : std_logic := '0';
signal en_pps_interrupt_sig : std_logic := '0';
signal user_rpm_sig : std_logic_vector(const_n_pwm_res-1 downto 0);
signal pps_interrupt_in_sig :std_logic_vector(const_n_pps_interrupt_counter-1 downto 0) := (others => '0');

signal current_rpm_sig : std_logic_vector(const_n_arithmetics_width-1 downto 0);
--signal en_diff_current_error_sig: std_logic := '0';
--signal en_sum_ki_sig: std_logic := '0';
--signal en_diff_kd_sig: std_logic := '0';
--signal en_mult_sig : std_logic := '0';
--signal en_sum_ki_kd_sig : std_logic := '0';
--signal en_sum_kp_ki_kd_sig : std_logic := '0';
--signal en_pwm_complement_sig: std_logic := '0';
--signal en_pid_fpconversion_sig : std_logic := '0';
--signal load_user_rpm_sig : std_logic := '0';
signal load_current_rpm_sig : std_logic := '0';
--signal load_total_error_sig : std_logic := '0';
--signal load_last_error_sig : std_logic := '0';
--signal load_kp_mult_reg_sig : std_logic := '0';
--signal load_pid_res_sig : std_logic := '0';
signal load_pps_interrupt_in_sig : std_logic := '0';


--control inputs
signal en_pps_diff_sig:  std_logic := '0';
signal en_const_mult_sig:  std_logic := '0';
signal en_pps_conversion_sig:  std_logic := '0';

signal load_current_pps_sig : std_logic := '0';
signal load_prev_pps_sig : std_logic := '0';

 --control outputs
signal pps_diff_error_sig : std_logic;
signal const_mult_error_sig : std_logic;
 
 --counter signals
 signal pps_interrupt_trigger_sig : std_logic;

 --control outputs
signal  delay_counter_in_sig : std_logic_vector(7 downto 0);
signal  en_delay_counter_sig : std_logic;
signal  delay_counter_trigger_sig : std_logic;

--signal  current_error_diff_error_sig : std_logic; 
--signal  kp_mult_error_sig : std_logic;
--signal  ki_mult_error_sig : std_logic;
--signal  kd_mult_error_sig : std_logic;
--signal  ki_sum_error_sig : std_logic;
--signal  kd_diff_error_sig : std_logic;
--signal  ki_kd_sum_error_sig : std_logic;
--signal  kp_ki_kd_sum_error_sig : std_logic;
--signal  pid_fpconversion_error_sig:  std_logic;		
--signal  pwm_complement_ovf_sig : std_logic;

 --signal	pid_out_sig : std_logic_vector(const_n_arithmetics_width - 1 downto 0);
 signal rst_encoder_pulse_counter_sig : std_logic;
 signal encoder_count_sig:std_logic_vector(const_n_max_encoder_count-1 downto 0);
 --signal pwm_out_sig : std_logic; 
 --signal en_user_rpm_conversion_sig : std_logic;
 --signal enable_motor_period : std_logic := '0';
 
component operational_unit 
	generic (
       n_pps_interrupt_counter : positive := const_n_pps_interrupt_counter; --need to count up to 50e6 (using 50MHz clock) to 1s interrupt
       n_max_encoder_count : positive := const_n_pwm_res; --max: 71400 -> 340PPR*210 rpm
		 n_pwm_res : positive :=const_n_pwm_res; --read-only
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
--		en_user_rpm_conversion : in std_logic;
--		en_diff_current_error: in std_logic;
--		en_sum_ki: in std_logic;
--		en_diff_kd: in std_logic;
--		en_mult : in std_logic;
--		en_sum_ki_kd : in std_logic;
--		en_sum_kp_ki_kd : in std_logic;
--		en_pid_fpconversion: in std_logic;
--		en_pwm_complement : in std_logic;	
--		
--		load_user_rpm: in std_logic;
   	load_pps_interrupt_in : in std_logic;
		load_current_rpm: in std_logic;
--		load_total_error: in std_logic;
--		load_last_error: in std_logic;
--		load_kp_mult_reg: in std_logic;
--		load_pid_res: in std_logic;
		
	
		--arithmetic blocks outputs
		--encoder
		pps_diff_error: out std_logic;
		const_mult_error: out std_logic;
 
--		--pid
--		current_error_diff_error : out std_logic;			
--		kp_mult_error: out std_logic;			
--		ki_mult_error: out std_logic;		
--		kd_mult_error : out std_logic;
--		ki_sum_error : out std_logic;
--		kd_diff_error: out std_logic;		
--		ki_kd_sum_error: out std_logic;		
--		kp_ki_kd_sum_error: out std_logic; 
--		pid_fpconversion_error : out std_logic;
--		pwm_complement_ovf: out std_logic;
--		
      --control outputs
      pps_interrupt_trigger : out std_logic; --1s interrupt to calculate encoder pps
		delay_counter_trigger : out std_logic;  --used to count clock cycles inside arithmetic processes
		
		--debug outputs
		current_rpm : out std_logic_vector(n_max_encoder_count - 1 downto 0);
		--pid_out: out std_logic_vector(31 downto 0);
		encoder_count: out std_logic_vector(n_max_encoder_count-1 downto 0)
	
		--block outputs
		--pwm_out: out std_logic

	);
end component;



begin
	operational_unit_inst : operational_unit
    generic map (
	     n_pps_interrupt_counter => const_n_pps_interrupt_counter,--need to count up to 50e6 (using 50MHz clock) to 1s interrupt
		  n_max_encoder_count => const_n_max_encoder_count, --max: 71400 -> 340PPR*210 rpm
		  n_pwm_res => const_n_pwm_res, --read-only
		  --vhdl2003 doesn't permit the use of one generic to parametrize another one
		  ppr_constant => const_ppr, --0.1764 (60/PPR)
		  kp_constant => pid_kp, --0.5
		  ki_constant =>  pid_ki, --0.3
		  kd_constant =>  pid_kd --1
		  )
    
	port map (
		--common
      clk => clk_sig,
      rst => rst_sig,
	
		rst_pps_interrupt => rst_pps_interrupt_sig,
		rst_encoder_pulse_counter => rst_encoder_pulse_counter_sig,

		--block inputs
		--common
		delay_counter_in => delay_counter_in_sig,
		encoder_in => encoder_in_sig,
		user_rpm => user_rpm_sig,
		pps_interrupt_in => pps_interrupt_in_sig,
		
		--control inputs
		--common
		en_delay_counter => en_delay_counter_sig,
		
		--encoder
		--en_user_rpm_conversion => en_user_rpm_conversion_sig,
		en_pps_interrupt => en_pps_interrupt_sig,
		en_pps_diff => en_pps_diff_sig,
		en_const_mult => en_const_mult_sig,
		en_pps_conversion => en_pps_conversion_sig,

		load_current_pps => load_current_pps_sig, --rps stands for revolutions per seconds
		load_prev_pps => load_prev_pps_sig,
	
		--pid
--		en_diff_current_error => en_diff_current_error_sig,
--		en_sum_ki => en_sum_ki_sig,
--		en_diff_kd => en_diff_kd_sig,
--		en_mult => en_mult_sig,
--		en_sum_ki_kd => en_sum_ki_kd_sig,
--		en_sum_kp_ki_kd => en_sum_kp_ki_kd_sig,
--		en_pid_fpconversion => en_pid_fpconversion_sig,
--		en_pwm_complement => en_pwm_complement_sig,
		
--		load_user_rpm => load_user_rpm_sig,
		load_pps_interrupt_in => load_pps_interrupt_in_sig ,
		load_current_rpm => load_current_rpm_sig,
--		load_total_error => load_total_error_sig,
--		load_last_error => load_last_error_sig,
--		load_kp_mult_reg => load_kp_mult_reg_sig,
--		load_pid_res => load_pid_res_sig,
		
	
		--arithmetic blocks outputs
		--encoder
		pps_diff_error => pps_diff_error_sig,
		const_mult_error => const_mult_error_sig,
 
		--pid
--		current_error_diff_error => current_error_diff_error_sig,	
--		kp_mult_error => kp_mult_error_sig,		
--		ki_mult_error => ki_mult_error_sig,	
--		kd_mult_error => kd_mult_error_sig,
--		ki_sum_error => ki_sum_error_sig,
--		kd_diff_error => kd_diff_error_sig,
--		ki_kd_sum_error => ki_kd_sum_error_sig,
--		kp_ki_kd_sum_error => kp_ki_kd_sum_error_sig,
--		pid_fpconversion_error => pid_fpconversion_error_sig,
--		pwm_complement_ovf => pwm_complement_ovf_sig,
		
      --control outputs
      pps_interrupt_trigger => pps_interrupt_trigger_sig,--1s interrupt to calculate encoder pps
		delay_counter_trigger => delay_counter_trigger_sig,  --used to count clock cycles inside arithmetic processes
		
		--debug outputs
		current_rpm => current_rpm_sig,
		--pid_out => pid_out_sig,
		encoder_count => encoder_count_sig
	
		--block outputs
		--pwm_out => pwm_out_sig
			
);

    clk_proc : process 
    begin
        clk_sig <= '0';
        wait for clk_period/2;
        clk_sig <= '1';
        wait for clk_period/2;
    end process clk_proc;           

	 encoder_pulses_proc : process 
    begin
		--if(enable_motor_period='1') then
        encoder_in_sig <= '0';
        wait for motor_period;
        encoder_in_sig <= '1';
        wait for motor_period;
		--end if;
    end process encoder_pulses_proc;     
	 
	 
	 
    stim_proc : process                                              
                                    
    begin 
		  --RESET
		  --enable_motor_period <= '0';
		  --encoder_in_sig <= '0';
		  rst_sig <= '1'; --*
		  rst_pps_interrupt_sig <= '1';
		  rst_encoder_pulse_counter_sig <= '1';
		  delay_counter_in_sig <= (others=>'0');
        en_delay_counter_sig <= '0';
		  
        en_pps_interrupt_sig <= '0';
		  load_prev_pps_sig <= '0';
		  en_const_mult_sig <= '0';
		  en_pps_diff_sig <= '0';
		  en_pps_conversion_sig <= '0';
		  
		  --pid
--		  en_user_rpm_conversion_sig  <= '0';
--		  en_diff_current_error_sig <= '0';
--		  en_sum_ki_sig <= '0';
--		  en_diff_kd_sig <= '0';
--		  en_mult_sig <= '0';
--		  en_sum_ki_kd_sig  <= '0';
--		  en_sum_kp_ki_kd_sig  <= '0'; 
--		  en_pid_fpconversion_sig <= '0';
--		  en_pwm_complement_sig <= '0';
		  
		  load_pps_interrupt_in_sig <= '0';
--		  load_user_rpm_sig <= '0';
		  load_current_rpm_sig <= '0';
--		  load_total_error_sig <= '0';
--		  load_last_error_sig <= '0';		  
--		  load_kp_mult_reg_sig <= '0';
--		  load_pid_res_sig <= '0';
				  
		  wait for clk_period;

		  --IDLE
		  rst_sig <= '0';
		  rst_pps_interrupt_sig <= '0';
		  rst_encoder_pulse_counter_sig <= '0';
		  
 		  wait for clk_period;
  		  --user_rpm_sig <= std_logic_vector(to_unsigned(170, user_rpm_sig'length)); --170 rpm
		  pps_interrupt_in_sig <= std_logic_vector(counter_1kHz); --1ms
		  
		  wait for clk_period;
		  --load_user_rpm_sig <= '1';
		  load_pps_interrupt_in_sig <= '1';
		  
		  --EN_PPS_COUNTER 
		  wait for clk_period;
		  --load_user_rpm_sig <= '0';
		  load_pps_interrupt_in_sig <= '0';
		  --en_user_rpm_conversion_sig <= '1';
        en_pps_interrupt_sig <= '1';
		  
        wait until pps_interrupt_trigger_sig='1'; --count = 50E6 (1s)
		  		  
		  wait for clk_period;
		  
		  --SET_CURRENT_PPS
		  load_current_pps_sig <= '1';
		  wait for clk_period;
		  load_current_pps_sig <= '0';
		  rst_encoder_pulse_counter_sig <= '1';
		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in_sig'length));

		  wait for clk_period;
		  rst_encoder_pulse_counter_sig <= '0';
		  en_pps_conversion_sig <= '1';
		  en_delay_counter_sig <= '1';
		  		  
		  wait until delay_counter_trigger_sig='1'; 
		  en_delay_counter_sig <= '0';
		  wait for clk_period;
		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
		  en_pps_diff_sig <= '1';
		  en_delay_counter_sig <= '1';
		  
        wait until delay_counter_trigger_sig='1';
		  en_delay_counter_sig <= '0';
		  wait for clk_period;
		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_MULT_CYCLES, delay_counter_in_sig'length));
		  en_const_mult_sig <= '1';
		  en_delay_counter_sig <= '1';	  
        wait until delay_counter_trigger_sig='1';
		  en_delay_counter_sig <= '0';
		  wait for clk_period;
		  
		  load_current_rpm_sig <= '1';
		  wait for clk_period;
		  load_current_rpm_sig <= '0';
		  load_prev_pps_sig <= '1';
        wait for clk_period;
		  load_prev_pps_sig <= '0';
		  en_pps_diff_sig <= '0';
		  en_pps_conversion_sig <= '0';
		  en_const_mult_sig <= '0';
		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(0, delay_counter_in_sig'length));
		  --fim bloco do encoder
--		  
--		  --pid
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--		  en_diff_current_error_sig <= '1'; 
--		  en_delay_counter_sig <= '1';
--		  
--        wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--		  en_sum_ki_sig <= '1';
--		  en_diff_kd_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--        wait until delay_counter_trigger_sig='1';
--		   en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_MULT_CYCLES, delay_counter_in_sig'length));
--		  en_mult_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--        wait until delay_counter_trigger_sig='1';
--		    en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--	     en_sum_ki_kd_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--		  wait until delay_counter_trigger_sig='1';
--		    en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--		  load_kp_mult_reg_sig <= '1';
--		  wait for clk_period;
--		  
--		  load_kp_mult_reg_sig <= '0';
--		  en_sum_kp_ki_kd_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--		 wait until delay_counter_trigger_sig='1';
--		    en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in_sig'length));
--		  en_pid_fpconversion_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--		  wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  
--		  load_pid_res_sig <= '1';
--		  wait for clk_period;	
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(PID_COMB_LOGIC_CYCLES, delay_counter_in_sig'length));
--		  load_total_error_sig <= '1';
--		  load_last_error_sig <= '1';		
--		  load_pid_res_sig <= '0';
--		  en_pwm_complement_sig <= '1';
--		  
--		  wait for clk_period;
--		  load_total_error_sig <= '0';
--		  load_last_error_sig <= '0';	
--		
--		  en_diff_current_error_sig <= '0';
--		  en_sum_ki_sig <= '0';
--		  en_diff_kd_sig <= '0';		
--		  en_sum_kp_ki_kd_sig <= '0';
--		  en_mult_sig <= '0';
--		  en_sum_ki_kd_sig <= '0';
--		  en_delay_counter_sig <= '1';
--		  
--		  wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  
--		  
--		  motor_period <= 735 ns; --revolucao 1
--		  enable_motor_period <= '1';
--		  
--		  wait until pps_interrupt_trigger_sig='1'; --count = 50E6 (1s)
--		  		  
--		  wait for clk_period;
--		  
--		  --SET_CURRENT_PPS
--		  load_current_pps_sig <= '1';
--		  wait for clk_period;
--		  load_current_pps_sig <= '0';
--		  rst_encoder_pulse_counter_sig <= '1';
--		  wait for clk_period;
--		  rst_encoder_pulse_counter_sig <= '0';
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in_sig'length));
--		  en_pps_conversion_sig <= '1';
--		  en_delay_counter_sig <= '1';
--		  		  
--		  wait until delay_counter_trigger_sig='1'; 
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--		  en_pps_diff_sig <= '1';
--		  en_delay_counter_sig <= '1';
--		  
--        wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_MULT_CYCLES, delay_counter_in_sig'length));
--		  en_const_mult_sig <= '1';
--		  en_delay_counter_sig <= '1';	  
--        wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  
--		  load_current_rpm_sig <= '1';
--		  wait for clk_period;
--		  load_current_rpm_sig <= '0';
--		  load_prev_pps_sig <= '1';
--        wait for clk_period;
--		  load_prev_pps_sig <= '0';
--		  en_pps_diff_sig <= '0';
--		  en_pps_conversion_sig <= '0';
--		  en_const_mult_sig <= '0';
--		  --fim bloco do encoder
--		  
--		  --pid
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--		  en_diff_current_error_sig <= '1'; 
--		  en_delay_counter_sig <= '1';
--		  
--        wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--		  en_sum_ki_sig <= '1';
--		  en_diff_kd_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--        wait until delay_counter_trigger_sig='1';
--		   en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_MULT_CYCLES, delay_counter_in_sig'length));
--		  en_mult_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--        wait until delay_counter_trigger_sig='1';
--		    en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--	     en_sum_ki_kd_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--		  wait until delay_counter_trigger_sig='1';
--		    en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--		  load_kp_mult_reg_sig <= '1';
--		  wait for clk_period;
--		  
--		  load_kp_mult_reg_sig <= '0';
--		  en_sum_kp_ki_kd_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--		 wait until delay_counter_trigger_sig='1';
--		    en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in_sig'length));
--		  en_pid_fpconversion_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--		  wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  
--		  load_pid_res_sig <= '1';
--		  wait for clk_period;	
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(PID_COMB_LOGIC_CYCLES, delay_counter_in_sig'length));
--		  load_total_error_sig <= '1';
--		  load_last_error_sig <= '1';		
--		  load_pid_res_sig <= '0';
--		  en_pwm_complement_sig <= '1';
--		  
--		  wait for clk_period;
--		  load_total_error_sig <= '0';
--		  load_last_error_sig <= '0';	
--		
--		  en_diff_current_error_sig <= '0';
--		  en_sum_ki_sig <= '0';
--		  en_diff_kd_sig <= '0';		
--		  en_sum_kp_ki_kd_sig <= '0';
--		  en_mult_sig <= '0';
--		  en_sum_ki_kd_sig <= '0';
--		  en_delay_counter_sig <= '1';
--		  
--		  wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  
--		  motor_period <= 588 ns; --revolucao 2
--		  wait until pps_interrupt_trigger_sig='1'; --count = 50E6 (1s)
--		  		  
--		  wait for clk_period;
--		  
--		  --SET_CURRENT_PPS
--		  load_current_pps_sig <= '1';
--		  wait for clk_period;
--		  load_current_pps_sig <= '0';
--		  rst_encoder_pulse_counter_sig <= '1';
--		  wait for clk_period;
--		  rst_encoder_pulse_counter_sig <= '0';
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in_sig'length));
--		  en_pps_conversion_sig <= '1';
--		  en_delay_counter_sig <= '1';
--		  		  
--		  wait until delay_counter_trigger_sig='1'; 
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--		  en_pps_diff_sig <= '1';
--		  en_delay_counter_sig <= '1';
--		  
--        wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_MULT_CYCLES, delay_counter_in_sig'length));
--		  en_const_mult_sig <= '1';
--		  en_delay_counter_sig <= '1';	  
--        wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  
--		  load_current_rpm_sig <= '1';
--		  wait for clk_period;
--		  load_current_rpm_sig <= '0';
--		  load_prev_pps_sig <= '1';
--        wait for clk_period;
--		  load_prev_pps_sig <= '0';
--		  en_pps_diff_sig <= '0';
--		  en_pps_conversion_sig <= '0';
--		  en_const_mult_sig <= '0';
--		  --fim bloco do encoder
--		  
--		  --pid
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--		  en_diff_current_error_sig <= '1'; 
--		  en_delay_counter_sig <= '1';
--		  
--        wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--		  en_sum_ki_sig <= '1';
--		  en_diff_kd_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--        wait until delay_counter_trigger_sig='1';
--		   en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_MULT_CYCLES, delay_counter_in_sig'length));
--		  en_mult_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--        wait until delay_counter_trigger_sig='1';
--		    en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--	     en_sum_ki_kd_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--		  wait until delay_counter_trigger_sig='1';
--		    en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in_sig'length));
--		  load_kp_mult_reg_sig <= '1';
--		  wait for clk_period;
--		  
--		  load_kp_mult_reg_sig <= '0';
--		  en_sum_kp_ki_kd_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--		 wait until delay_counter_trigger_sig='1';
--		    en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in_sig'length));
--		  en_pid_fpconversion_sig <= '1';
--		  en_delay_counter_sig <= '1';
--
--		  wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
--		  
--		  load_pid_res_sig <= '1';
--		  wait for clk_period;	
--		  delay_counter_in_sig <=  std_logic_vector(to_unsigned(PID_COMB_LOGIC_CYCLES, delay_counter_in_sig'length));
--		  load_total_error_sig <= '1';
--		  load_last_error_sig <= '1';		
--		  load_pid_res_sig <= '0';
--		  en_pwm_complement_sig <= '1';
--		  
--		  wait for clk_period;
--		  load_total_error_sig <= '0';
--		  load_last_error_sig <= '0';	
--		
--		  en_diff_current_error_sig <= '0';
--		  en_sum_ki_sig <= '0';
--		  en_diff_kd_sig <= '0';		
--		  en_sum_kp_ki_kd_sig <= '0';
--		  en_mult_sig <= '0';
--		  en_sum_ki_kd_sig <= '0';
--		  en_delay_counter_sig <= '1';
--		  
--		  wait until delay_counter_trigger_sig='1';
--		  en_delay_counter_sig <= '0';
--		  wait for clk_period;
		  
    wait;                                                        
    end process stim_proc; 
  
end behavioral;

