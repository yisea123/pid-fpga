
library ieee;                                               
use ieee.std_logic_1164.all;                                
use ieee.numeric_std.all;

entity tb_pid_controller is
end tb_pid_controller;
architecture behavioral of tb_pid_controller is     

-- constants   
constant const_n_pwm_res : positive := 8;
constant const_n_arithmetics_width : positive := 32;      
constant const_n_pps_interrupt_counter : positive := 32;      
constant const_n_max_encoder_count : positive := 32;      

--pid constants
constant pid_kp : std_logic_vector (const_n_arithmetics_width-1 downto 0) :=  "00111111000000000000000000000000"; --0.5
constant pid_ki : std_logic_vector (const_n_arithmetics_width-1 downto 0) :=  "00111110100110011001100110011010"; --0.3
constant pid_kd : std_logic_vector (const_n_arithmetics_width-1 downto 0) :=  "00111111100000000000000000000000"; --1
constant const_ppr : std_logic_vector (const_n_arithmetics_width - 1 downto 0) := "00111110001101001010001000110100";

--frequency to generate an interrupt equivalent to 1s in real use (50e6)
constant counter_1kHz : unsigned(const_n_arithmetics_width-1 downto 0) := to_unsigned(50_000, const_n_pps_interrupt_counter);    
constant clk_period : time := 20 ns;          
--constant motor_period : time := 735 ns; --double this to get motor real period (generates 680 pulses in 1s)

--signal motor_period : time := 735 ns; --double this to get motor real period (generates 680 pulses in 1s) --120RPM
--588 ns --150RPM
signal motor_period_0 : time := 0 ns; --double this to get motor real period (generates 680 pulses in 1s)
signal motor_period_120 : time := 735 ns; --double this to get motor real period (generates 680 pulses in 1s)
signal motor_period_150 : time := 680 ns; --double this to get motor real period (generates 680 pulses in 1s)


--  input signals                                                   
signal clk_sig : std_logic;
signal rst_sig : std_logic := '0';
signal cmd_send_sig : std_logic := '0';

signal encoder_count_sig:std_logic_vector(const_n_max_encoder_count-1 downto 0):= (others => '0');
signal encoder_in_sig : std_logic;
signal encoder_in_sig_0 : std_logic;
signal encoder_in_sig_120 : std_logic;
signal encoder_in_sig_150 : std_logic;


signal user_rpm_sig : std_logic_vector(const_n_pwm_res-1 downto 0) := (others => '0');
signal pps_interrupt_in_sig :std_logic_vector(const_n_pps_interrupt_counter-1 downto 0) := (others => '0');

signal cmd_sig:  std_logic_vector(1 downto 0) := (others=>'0');
signal current_rpm_sig : std_logic_vector(const_n_max_encoder_count-1 downto 0) := (others => '0');
signal pid_out_sig : std_logic_vector( 31 downto 0) := (others => '0');
signal pwm_out_sig : std_logic :='0'; 
signal state_debug_sig: std_logic_vector(7 downto 0) := (others =>'0');
signal operational_error_encoder_sig :  std_logic_vector( 31 downto 0) := (others => '0');
signal operational_error_pid_sig :  std_logic_vector( 31 downto 0) := (others => '0');

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
	cmd_send: in std_logic;
	user_rpm: in std_logic_vector(n_pwm_res-1 downto 0);
	--pps_interrupt_in : in std_logic_vector(n_pps_interrupt_counter-1 downto 0);
	encoder_in: in std_logic;
	
	--debug output
	encoder_count: out std_logic_vector(n_pps_interrupt_counter-1 downto 0);
	current_rpm : out std_logic_vector(n_pps_interrupt_counter - 1 downto 0);
	pid_out: out std_logic_vector(31 downto 0);
	state_debug: out std_logic_vector(7 downto 0);
	
	--block outputs
			operational_error_encoder : out std_logic_vector(31 downto 0);
		operational_error_pid: out std_logic_vector(31 downto 0);
	pwm_out: out std_logic
);
end component;


begin
	pid_controller_inst : pid_controller
	generic map (
		 n_pps_interrupt_counter => const_n_pps_interrupt_counter,
       n_max_encoder_count => const_n_max_encoder_count,
		 n_pwm_res => const_n_pwm_res,
		 --vhdl2003 doesn't permit the use of one generic to parametrize another one
		 ppr_constant => const_ppr,
		 kp_constant => pid_kp,
		 ki_constant => pid_ki,
		 kd_constant => pid_kd 
	)
	
	port map (
	--common
	clk  => clk_sig,
	rst  => rst_sig,
	
	--inputs
	cmd  => cmd_sig,
	cmd_send => cmd_send_sig,
	user_rpm  => user_rpm_sig,
	encoder_in  => encoder_in_sig,
	--pps_interrupt_in => pps_interrupt_in_sig,

	--debug output
	encoder_count  => encoder_count_sig,
	current_rpm  => current_rpm_sig,
	pid_out  => pid_out_sig,
	state_debug  => state_debug_sig,
	
	--block outputs
	operational_error_encoder => operational_error_encoder_sig,
	operational_error_pid => operational_error_pid_sig,
	pwm_out => pwm_out_sig
			
);

    clk_proc : process 
    begin
        clk_sig <= '0';
        wait for clk_period/2;
        clk_sig <= '1';
        wait for clk_period/2;
    end process clk_proc;           
	 
	 
	 encoder_pulses_proc_120 : process 
    begin
        encoder_in_sig_120 <= '0';
        wait for motor_period_120;
        encoder_in_sig_120 <= '1';
        wait for motor_period_120;
    end process encoder_pulses_proc_120;    
	 
	 encoder_pulses_proc_150 : process 
    begin
        encoder_in_sig_150 <= '0';
        wait for motor_period_150;
        encoder_in_sig_150 <= '1';
        wait for motor_period_150;
    end process encoder_pulses_proc_150;    
--	 
	 
    stim_proc : process                                                                              
    begin 
		  encoder_in_sig <= '0';
		  encoder_in_sig_0 <= '0';
		  rst_sig <= '1'; 
		  wait for clk_period;
		  rst_sig <= '0';		  
 		  wait for 2*clk_period;
		  cmd_sig <="00";
		  encoder_in_sig <= encoder_in_sig_0;
		  cmd_send_sig <='0';
  		  user_rpm_sig <= std_logic_vector(to_unsigned(170, user_rpm_sig'length)); --170 rpm
		  wait for clk_period;
		  cmd_sig <= "01";
		  		  wait for clk_period;

		  cmd_send_sig <='1';
		  		  wait for 1*clk_period;

		  cmd_send_sig <= '0';
		  pps_interrupt_in_sig <= std_logic_vector(counter_1kHz); --1ms
		  wait for clk_period;
		  cmd_sig <= "10";
		  wait for clk_period;
		  cmd_send_sig <='1';
		  wait for 1*clk_period;
		  cmd_send_sig <= '0'; 
		  cmd_sig <= "11";
		  wait for clk_period;
		  cmd_send_sig <='1';
		  wait for 1*clk_period;
		  cmd_send_sig <= '0'; 
		  ------------------------
		  wait for 1300 us;
		  rst_sig <= '1'; 
		  wait for clk_period;
		  rst_sig <= '0';		  
 		  wait for 2*clk_period;
		  cmd_sig <="00";
		  wait for 2*clk_period;
		  cmd_sig <="00";
		  cmd_send_sig <='0';
		  wait for clk_period;
		  cmd_sig <= "01";
		  wait for clk_period;
		  cmd_send_sig <='1';
		  wait for clk_period;
		  cmd_send_sig <= '0';
		  pps_interrupt_in_sig <= std_logic_vector(counter_1kHz); --1ms
		  encoder_in_sig <= encoder_in_sig_120;
		  wait for clk_period;
		  cmd_sig <= "10";
		  wait for clk_period;
		  cmd_send_sig <='1';
		  wait for clk_period;
		  cmd_send_sig <= '0'; 
		  cmd_sig <= "11";
		  wait for clk_period;
		  cmd_send_sig <='1';
		  wait for clk_period;
		  cmd_send_sig <= '0';
		 ------------------------------
		 wait for 1300 us;
				  rst_sig <= '1'; 
		  wait for clk_period;
		  rst_sig <= '0';		  
 		  wait for 2*clk_period;
		  cmd_sig <="00";
		  wait for 2*clk_period;
		  cmd_sig <="00";
		  cmd_send_sig <='0';
		  wait for clk_period;
		  cmd_sig <= "01";
		  wait for clk_period;
		  cmd_send_sig <='1';
		  wait for clk_period;
		  cmd_send_sig <= '0';
		  pps_interrupt_in_sig <= std_logic_vector(counter_1kHz); --1ms
		  encoder_in_sig <= encoder_in_sig_150;
		  wait for clk_period;
		  cmd_sig <= "10";
		  wait for clk_period;
		  cmd_send_sig <='1';
		  wait for clk_period;
		  cmd_send_sig <= '0'; 
		  cmd_sig <= "11";
		  wait for clk_period;
		  cmd_send_sig <='1';
		  wait for clk_period;
		  cmd_send_sig <= '0';  
		  
    wait;                                                        
    end process stim_proc; 
  
end behavioral;

