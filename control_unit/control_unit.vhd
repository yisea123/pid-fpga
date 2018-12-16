library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit is

	port (
		--common
		clk, rst : in std_logic;
		rst_pps_interrupt : out std_logic; --used at the moment the pwm is applied to the motor
		rst_encoder_pulse_counter : out std_logic;  

		--inputs
		cmd: in std_logic_vector(1 downto 0);
		cmd_send : in std_logic;
		
		--control inputs
      pps_interrupt_trigger : in std_logic; --1s interrupt to calculate pps
		delay_counter_trigger : in std_logic;  

		--error inputs
		--encoder
--		pps_diff_error: in std_logic;
--		const_mult_error: in std_logic;
--		--pid
--		current_error_diff_error : in std_logic;			
--		kp_mult_error: in std_logic;			
--		ki_mult_error: in std_logic;		
--		kd_mult_error : in std_logic;
--		ki_sum_error : in std_logic;
--		kd_diff_error: in std_logic;		
--		ki_kd_sum_error: in std_logic;		
--		kp_ki_kd_sum_error: in std_logic; 
--		pid_fpconversion_error : in std_logic;
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
end entity;

architecture behavioral of control_unit is

	 constant FP_CONVERSION_CYCLES : integer := 6;
	 constant FP_ADDSUB_CYCLES : integer := 7;
	 constant FP_MULT_CYCLES : integer := 5; 
	 constant PID_COMB_LOGIC_CYCLES : integer := 4;
	 
    type internal_state is (
	 ST_RESET, 
	 ST_IDLE,
	 ST_LOAD_USER_RPM,
	 ST_LOAD_PPS_INTERRUPT_IN,
	 ST_EN_PPS_COUNTER,
	 ST_WAIT_PPS_TRIGGER,
	 ST_LOAD_CURRENT_PPS,
	 ST_PPS_CONVERSION,
	 ST_WAIT_PPS_CONVERSION,
	 ST_DISABLE_DELAY_COUNTER_1,
	 ST_PPS_DIFF,
	 ST_WAIT_PPS_DIFF,
	 ST_DISABLE_DELAY_COUNTER_2,
	 ST_CONST_MULT,
	 ST_WAIT_CONST_MULT,
	 ST_DISABLE_DELAY_COUNTER_3,
	 ST_UPDATE_CURRENT_RPM,
	 ST_CURRENT_ERROR_DIFF,
	 ST_WAIT_CURRENT_ERROR_DIFF,
	 ST_DISABLE_DELAY_COUNTER_4,
	 ST_SUM_KI_DIFF_KD,
	 ST_WAIT_SUM_KI_DIFF_KD,
	 ST_DISABLE_DELAY_COUNTER_5,
	 ST_MULT_PID_CONST,
	 ST_WAIT_MULT_PID_CONST,
	 ST_DISABLE_DELAY_COUNTER_6,
	 ST_SUM_KI_KD,
	 ST_WAIT_SUM_KI_KD,
	 ST_DISABLE_DELAY_COUNTER_7,
	 ST_SUM_KP_KI_KD,
	 ST_WAIT_SUM_KP_KI_KD,
	 ST_DISABLE_DELAY_COUNTER_8,
	 ST_PID_INT_CONVERSION,
	 ST_WAIT_PID_INT_CONVERSION,
	 ST_DISABLE_DELAY_COUNTER_9,
	 ST_UPDATE_PID,
	 ST_WAIT_UPDATE_PID,
	 ST_DISABLE_DELAY_COUNTER_10,
	 ST_PID_COMB_LOGIC,
	 ST_DISABLE_DELAY_COUNTER_11,
	 ST_WAIT_USER_RPM_CONVERSION
	);
	 
	 
	 signal  current_state, next_state: internal_state; 
	 signal debug_state : std_logic_vector(7 downto 0) := (others=>'0');
	 signal operational_error_pid_sig : std_logic_vector(31 downto 0) := (others=>'0');
	 signal operational_error_encoder_sig : std_logic_vector(23 downto 0) := (others=>'0');
	 signal cmd_send_result : std_logic := '0';
	 
--	component debouncer 
--	generic(
--		counter_size  :  integer := 21); --counter size (21 bits gives 40ms with 50MHz clock)
--	port(
--		clk     : in  std_logic;  --input clock
--		rst     : in  std_logic;  --input rst
--		button  : in  std_logic;  --input signal to be debounced
--		result  : out std_logic); --debounced signal
--	end component;	
	
begin

--			debouncer_inst: debouncer
--		generic map (
--			counter_size  => 21) --counter size (21 bits gives 40ms with 50MHz clock)
--		port map(
--			clk     => clk,  --input clock
--			rst		=> rst, 
--			button  => cmd_send,  --input signal to be debounced
--			result  => cmd_send_result
--			); --debounced signal
     
     --next state logic
     NSL: process(current_state, pps_interrupt_trigger, delay_counter_trigger, cmd,  cmd_send) --cmd_send_result)
     begin
	  
        next_state <=  current_state;
		 
        case current_state  is
            when ST_RESET =>	 --0
                     next_state <= ST_IDLE;
							
            when ST_IDLE =>	--1
					--if (cmd_send_result = '1') then
					if (cmd_send = '1') then
						if (cmd = "01") then
							next_state <= ST_LOAD_USER_RPM;
						elsif (cmd = "10") then 
							next_state <= ST_LOAD_PPS_INTERRUPT_IN;
						elsif (cmd = "11" ) then
							next_state  <= ST_WAIT_USER_RPM_CONVERSION;
						end if;
					end if;
					 
				when ST_LOAD_USER_RPM => --2
					next_state <= ST_IDLE;
				
				when ST_LOAD_PPS_INTERRUPT_IN =>--3
					next_state <= ST_IDLE;
				
				when ST_WAIT_USER_RPM_CONVERSION => --4
					if delay_counter_trigger = '1' then
						next_state <= ST_DISABLE_DELAY_COUNTER_1;
					end if;	
					
				when ST_DISABLE_DELAY_COUNTER_1 => --5
					next_state <=	ST_EN_PPS_COUNTER;	
							
            when ST_EN_PPS_COUNTER =>	--6
                     next_state  <= ST_WAIT_PPS_TRIGGER;
						  
            when ST_WAIT_PPS_TRIGGER => --7
                if pps_interrupt_trigger = '1' then
                     next_state  <= ST_LOAD_CURRENT_PPS;
                end if;
				--	 
			   when ST_LOAD_CURRENT_PPS => --8
                 next_state  <= ST_PPS_CONVERSION;
					 
				when ST_PPS_CONVERSION =>  --9
					 next_state  <= ST_WAIT_PPS_CONVERSION;
					
				when ST_WAIT_PPS_CONVERSION => --10
					if delay_counter_trigger = '1' then
						next_state <= ST_DISABLE_DELAY_COUNTER_2;
					end if;
								
				when ST_DISABLE_DELAY_COUNTER_2 => --11
					next_state <=	ST_PPS_DIFF;
					
				when ST_PPS_DIFF =>  --12
					 next_state <= ST_WAIT_PPS_DIFF;
					
				when ST_WAIT_PPS_DIFF => --13
					if delay_counter_trigger = '1' then
						next_state <= ST_DISABLE_DELAY_COUNTER_3;
					end if;	
					
				when ST_DISABLE_DELAY_COUNTER_3 => --14
					next_state <=	ST_CONST_MULT;	
				
				when ST_CONST_MULT =>  --15
					 next_state <= ST_WAIT_CONST_MULT;					

				when ST_WAIT_CONST_MULT =>  --16
					if delay_counter_trigger = '1' then
						next_state <= ST_DISABLE_DELAY_COUNTER_4;
					end if;		
					
				when ST_DISABLE_DELAY_COUNTER_4 => --17
					next_state <=	ST_UPDATE_CURRENT_RPM;		
					
				when ST_UPDATE_CURRENT_RPM => --18
					 next_state <= ST_CURRENT_ERROR_DIFF;				
					
				when ST_CURRENT_ERROR_DIFF =>  --19
					 next_state <= ST_WAIT_CURRENT_ERROR_DIFF;
	
				when ST_WAIT_CURRENT_ERROR_DIFF =>  --20
					if delay_counter_trigger = '1' then
						next_state <= ST_DISABLE_DELAY_COUNTER_5;
					end if;
					
				when ST_DISABLE_DELAY_COUNTER_5 => --21
					next_state <=	ST_SUM_KI_DIFF_KD;	 	
					
				when ST_SUM_KI_DIFF_KD =>  --22
					 next_state <= ST_WAIT_SUM_KI_DIFF_KD;
					
				when ST_WAIT_SUM_KI_DIFF_KD =>  --23
					if delay_counter_trigger = '1' then
						next_state <= ST_DISABLE_DELAY_COUNTER_6;
					end if;
				
				when ST_DISABLE_DELAY_COUNTER_6 => --24
					next_state <=	ST_MULT_PID_CONST;	
				
				when ST_MULT_PID_CONST =>  --25
					 next_state <= ST_WAIT_MULT_PID_CONST;
					
				when ST_WAIT_MULT_PID_CONST => --26
					if delay_counter_trigger = '1' then
						next_state <= ST_DISABLE_DELAY_COUNTER_7;
					end if;
				
				when ST_DISABLE_DELAY_COUNTER_7 => --27
					next_state <= ST_SUM_KI_KD;	
					
				when ST_SUM_KI_KD => --28
					 next_state <= ST_WAIT_SUM_KI_KD;	
				
					
				when ST_WAIT_SUM_KI_KD =>  --29
					if delay_counter_trigger = '1' then
						next_state <= ST_DISABLE_DELAY_COUNTER_8;
					end if;
					
				when ST_DISABLE_DELAY_COUNTER_8 => --30
					next_state <=	ST_SUM_KP_KI_KD;	
					
				when ST_SUM_KP_KI_KD => --31
					 next_state <= ST_WAIT_SUM_KP_KI_KD;	
					
				when ST_WAIT_SUM_KP_KI_KD => --32
					if delay_counter_trigger = '1' then
						next_state <= ST_DISABLE_DELAY_COUNTER_9;
					end if;
				
				when ST_DISABLE_DELAY_COUNTER_9 => --33
					next_state <=	ST_PID_INT_CONVERSION;		
				
				when ST_PID_INT_CONVERSION => --34
					 next_state <= ST_WAIT_PID_INT_CONVERSION;
				
				when ST_WAIT_PID_INT_CONVERSION =>  --35
					if delay_counter_trigger = '1' then
						next_state <= ST_DISABLE_DELAY_COUNTER_10;
					end if;
					
				when ST_DISABLE_DELAY_COUNTER_10 => --36
					next_state <=	ST_UPDATE_PID;	
					
				when ST_UPDATE_PID =>  --37
					 next_state <= ST_WAIT_UPDATE_PID;
					
				when ST_WAIT_UPDATE_PID =>  --38
					if delay_counter_trigger = '1' then
						next_state <= ST_DISABLE_DELAY_COUNTER_11;
					end if;
					
				when ST_DISABLE_DELAY_COUNTER_11 => --39
					next_state <=	ST_PID_COMB_LOGIC;		
				
				when ST_PID_COMB_LOGIC => --40
					 next_state <= ST_WAIT_PPS_TRIGGER;	

				when others => next_state <= null;
        end case;
     end process;

    
    --memory element (sequential) -- never changes, ever!
    process(clk, rst) is
    begin 
        if rst='1' then
            current_state <= ST_RESET;
        elsif rising_edge(clk) then
				current_state <= next_state;
        end if;
    end process;
    
	
	-- output logic
	process (current_state, cmd, delay_counter_trigger)
	
	begin
				delay_counter_in <= (others=>'0');
				en_delay_counter <= '0';
				debug_state <= (others=>'0');
				
				--encoder
				rst_encoder_pulse_counter <= '0';
				rst_pps_interrupt <= '0';
				en_pps_interrupt <= '0';
				load_prev_pps <= '0';
				en_const_mult <= '0';
				en_pps_diff <= '0';
				en_pps_conversion <= '0';
				en_user_rpm_conversion <= '0';
				
				--pid
				en_diff_current_error <= '0';
				en_sum_ki <= '0';
				en_diff_kd <= '0';
				en_mult <= '0';
				en_sum_ki_kd  <= '0';
				en_sum_kp_ki_kd  <= '0'; 
				en_pid_fpconversion <= '0';
				en_pwm_complement <= '0';
				
				load_user_rpm <= '0';
				load_current_rpm <= '0';
				load_current_pps <= '0';
				load_total_error <= '0';
				load_last_error <= '0';		  
				load_kp_mult_reg <= '0';
				load_pps_interrupt_in <= '0';
				load_pid_res <= '0';
								
		case current_state  is
			when ST_RESET =>
				debug_state <= (others=>'0');
				rst_pps_interrupt <= '1';
				rst_encoder_pulse_counter <= '1';
				delay_counter_in <= (others=>'0');
				load_prev_pps <= '0';

				en_delay_counter <= '0';
				en_pps_interrupt <= '0';
				en_const_mult <= '0';
				en_pps_diff <= '0';
				en_pps_conversion <= '0';
				en_user_rpm_conversion <= '0';
				
				en_diff_current_error <= '0';
				en_sum_ki <= '0';
				en_diff_kd <= '0';
				en_mult <= '0';
				en_sum_ki_kd  <= '0';
				en_sum_kp_ki_kd  <= '0'; 
				en_pid_fpconversion <= '0';
				en_pwm_complement <= '0';
				
				load_pps_interrupt_in <= '0';
				load_user_rpm <= '0';
				load_current_rpm <= '0';
				load_total_error <= '0';
				load_last_error <= '0';		  
				load_kp_mult_reg <= '0';
				load_pid_res <= '0';
				
				
			when ST_IDLE =>
				debug_state <= std_logic_vector(to_unsigned(1, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in'length));
				rst_pps_interrupt <='0';
				rst_encoder_pulse_counter <= '0';
				
			when ST_LOAD_USER_RPM =>
				debug_state <= std_logic_vector(to_unsigned(2, debug_state'length));
				load_user_rpm <= '1';
					
			when ST_LOAD_PPS_INTERRUPT_IN =>
				debug_state <= std_logic_vector(to_unsigned(3, debug_state'length));		
				load_pps_interrupt_in <= '1';		
			
			when ST_WAIT_USER_RPM_CONVERSION =>
				en_user_rpm_conversion <= '1';
				en_delay_counter <= '1';
				debug_state <= std_logic_vector(to_unsigned(4, debug_state'length));
				delay_counter_in <=  std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in'length));	
			
					
			 when ST_DISABLE_DELAY_COUNTER_1 =>
				en_user_rpm_conversion <= '1';
				debug_state <= std_logic_vector(to_unsigned(5, debug_state'length));
				
			when ST_EN_PPS_COUNTER => --cmd="11"
				debug_state <= std_logic_vector(to_unsigned(6, debug_state'length));
				en_pps_interrupt <= '1';
				en_user_rpm_conversion <= '1';
				
			when ST_WAIT_PPS_TRIGGER =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				debug_state <= std_logic_vector(to_unsigned(7, debug_state'length));
				
			when ST_LOAD_CURRENT_PPS =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				load_current_pps <= '1';
				debug_state <= std_logic_vector(to_unsigned(8, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in'length));

				
			when ST_PPS_CONVERSION =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_pps_conversion <= '1';
				en_delay_counter <= '1';
				rst_encoder_pulse_counter <= '1';
				debug_state <= std_logic_vector(to_unsigned(9, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in'length));

				
			when ST_WAIT_PPS_CONVERSION =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_pps_conversion <= '1';
				en_delay_counter <= '1';
				debug_state <= std_logic_vector(to_unsigned(10, debug_state'length));
				delay_counter_in <=  std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in'length));
				
		   when ST_DISABLE_DELAY_COUNTER_2 =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_pps_conversion <= '1';
				debug_state <= std_logic_vector(to_unsigned(11, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));	--delay pps diff

			when ST_PPS_DIFF =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_pps_conversion <= '1';
				en_pps_diff <= '1';
				en_delay_counter <= '1';
				debug_state <= std_logic_vector(to_unsigned(12, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));	--delay pps diff
				
			
			when ST_WAIT_PPS_DIFF =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_pps_conversion <= '1';
				en_pps_diff <= '1';
				en_delay_counter <= '1';
				
				debug_state <= std_logic_vector(to_unsigned(13, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));
	
			when ST_DISABLE_DELAY_COUNTER_3 =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_pps_conversion <= '1';
				en_pps_diff <= '1';
				debug_state <= std_logic_vector(to_unsigned(14, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_MULT_CYCLES, delay_counter_in'length));	--delay pps diff
	
	
			when ST_CONST_MULT =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_pps_conversion <= '1';
				en_pps_diff <= '1';
				en_delay_counter <= '1';
				en_const_mult <= '1';
			  debug_state <= std_logic_vector(to_unsigned(15, debug_state'length));
			  delay_counter_in <= std_logic_vector(to_unsigned(FP_MULT_CYCLES, delay_counter_in'length)); -- delay const mult
			
			
			when ST_WAIT_CONST_MULT=>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_pps_conversion <= '1';
				en_pps_diff <= '1';
				en_delay_counter <= '1';
				en_const_mult <= '1';
				debug_state <= std_logic_vector(to_unsigned(16, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_MULT_CYCLES, delay_counter_in'length));

			when ST_DISABLE_DELAY_COUNTER_4 =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_pps_conversion <= '1';
				en_pps_diff <= '1';
				en_const_mult <= '1';
				debug_state <= std_logic_vector(to_unsigned(17, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));	--delay pps diff
	
				
			when ST_UPDATE_CURRENT_RPM =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_pps_conversion <= '1';--
				en_pps_diff <= '1';--
				en_const_mult <= '1';--
				load_current_rpm <= '1';
				debug_state <= std_logic_vector(to_unsigned(18, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));
				--encoder block endpoint
				
			
			when ST_CURRENT_ERROR_DIFF =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_delay_counter <= '1';
				load_prev_pps <= '1';
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));	--delay current error
				debug_state <= std_logic_vector(to_unsigned(19, debug_state'length));
			
			when ST_WAIT_CURRENT_ERROR_DIFF =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_delay_counter <= '1';
				debug_state <= std_logic_vector(to_unsigned(20, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));

			when ST_DISABLE_DELAY_COUNTER_5 =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				debug_state <= std_logic_vector(to_unsigned(21, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));	--delay pps diff

			
			when ST_SUM_KI_DIFF_KD =>	
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_delay_counter <= '1';
		
				debug_state <= std_logic_vector(to_unsigned(22, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));	--delay sumki_diffkd
				
			when ST_WAIT_SUM_KI_DIFF_KD =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_delay_counter <= '1';
			
				debug_state <= std_logic_vector(to_unsigned(23, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));
	
			when ST_DISABLE_DELAY_COUNTER_6 =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				debug_state <= std_logic_vector(to_unsigned(24, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_MULT_CYCLES, delay_counter_in'length));	--delay pps diff
	
			when ST_MULT_PID_CONST =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_delay_counter <= '1';
				debug_state <= std_logic_vector(to_unsigned(25, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_MULT_CYCLES, delay_counter_in'length));
				
			
			when ST_WAIT_MULT_PID_CONST =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_delay_counter <= '1';
				debug_state <= std_logic_vector(to_unsigned(26, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_MULT_CYCLES, delay_counter_in'length));

			when ST_DISABLE_DELAY_COUNTER_7 =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				debug_state <= std_logic_vector(to_unsigned(27, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));	--delay pps diff
		
				
			when ST_SUM_KI_KD =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_sum_ki_kd <= '1';
				en_delay_counter <= '1';
				load_kp_mult_reg <= '1';
				debug_state <= std_logic_vector(to_unsigned(28, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));
			
			when ST_WAIT_SUM_KI_KD =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_sum_ki_kd <= '1';
				en_delay_counter <= '1';
				debug_state <= std_logic_vector(to_unsigned(29, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));		
			
			when ST_DISABLE_DELAY_COUNTER_8 =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_sum_ki_kd <= '1';
				debug_state <= std_logic_vector(to_unsigned(30, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));	--delay pps diff

			
			when ST_SUM_KP_KI_KD =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_sum_ki_kd <= '1';
				en_sum_kp_ki_kd <= '1';
				en_delay_counter <= '1';
			
				debug_state <= std_logic_vector(to_unsigned(31, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));
			
			
			when ST_WAIT_SUM_KP_KI_KD =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_sum_ki_kd <= '1';
				en_sum_kp_ki_kd <= '1';
				en_delay_counter <= '1';
				debug_state <= std_logic_vector(to_unsigned(32, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in'length));

			
			when ST_DISABLE_DELAY_COUNTER_9 => --31
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_sum_ki_kd <= '1';
				en_sum_kp_ki_kd <= '1';
				debug_state <= std_logic_vector(to_unsigned(33, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_ADDSUB_CYCLES, delay_counter_in'length));	--delay pps diff
			
			
			when ST_PID_INT_CONVERSION =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_sum_ki_kd <= '1';
				en_sum_kp_ki_kd <= '1';
				en_pid_fpconversion <= '1';
				en_delay_counter <= '1';
				debug_state <= std_logic_vector(to_unsigned(34, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in'length));

				
			when ST_WAIT_PID_INT_CONVERSION =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_sum_ki_kd <= '1';
				en_sum_kp_ki_kd <= '1';
				en_pid_fpconversion <= '1';
				en_delay_counter <= '1';
				debug_state <= std_logic_vector(to_unsigned(35, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(FP_CONVERSION_CYCLES, delay_counter_in'length));
						
			when ST_DISABLE_DELAY_COUNTER_10 =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_sum_ki_kd <= '1';
				en_sum_kp_ki_kd <= '1';
				en_pid_fpconversion <= '1';
				debug_state <= std_logic_vector(to_unsigned(36, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(PID_COMB_LOGIC_CYCLES, delay_counter_in'length));
			
			
			when ST_UPDATE_PID => 
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_sum_ki_kd <= '1';
				en_sum_kp_ki_kd <= '1';
				en_pid_fpconversion <= '1';
				en_pwm_complement <= '1';
				en_delay_counter <= '1';
				load_pid_res <= '1';
				load_total_error <= '1';
				load_last_error <= '1';
				debug_state <= std_logic_vector(to_unsigned(37, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(PID_COMB_LOGIC_CYCLES, delay_counter_in'length));

				
			when ST_WAIT_UPDATE_PID =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_sum_ki_kd <= '1';
				en_sum_kp_ki_kd <= '1';
				en_pid_fpconversion <= '1';
				en_pwm_complement <= '1';
				en_delay_counter <= '1';
				debug_state <= std_logic_vector(to_unsigned(38, debug_state'length));
				delay_counter_in <= std_logic_vector(to_unsigned(PID_COMB_LOGIC_CYCLES, delay_counter_in'length));			

			when ST_DISABLE_DELAY_COUNTER_11 =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				en_diff_current_error <= '1';
				en_diff_kd <= '1';
				en_sum_ki <= '1';
				en_mult <= '1';
				en_sum_ki_kd <= '1';
				en_sum_kp_ki_kd <= '1';
				en_pid_fpconversion <= '1';
				en_pwm_complement <= '1';
				debug_state <= std_logic_vector(to_unsigned(39, debug_state'length));
					
				
			when ST_PID_COMB_LOGIC =>
				en_user_rpm_conversion <= '1';
				en_pps_interrupt <= '1';
				debug_state <= std_logic_vector(to_unsigned(40, debug_state'length));

				
			when others => debug_state <= std_logic_vector(to_unsigned(41, debug_state'length));
		end case;
	end process;
	

	state_debug <= debug_state;
	operational_error_encoder_sig <= kp_mult_zero & kp_mult_nan & kp_mult_udf & kp_mult_ovf
																& current_error_zero & current_error_nan & current_error_udf & current_error_ovf
																& "00000000" 
																& const_mult_zero & const_mult_nan & const_mult_udf & const_mult_ovf 
																& pps_diff_zero & pps_diff_nan & pps_diff_udf & pps_diff_ovf;
	 
	operational_error_pid_sig  <=  pwm_complement_ovf & "000" 
															& pid_fpconversion_neg & pid_fpconversion_nan & pid_fpconversion_udf & pid_fpconversion_ovf
															& kp_ki_kd_sum_zero & kp_ki_kd_sum_nan & kp_ki_kd_sum_udf & kp_ki_kd_sum_ovf  
															& ki_kd_sum_zero & ki_kd_sum_nan & ki_kd_sum_udf & ki_kd_sum_ovf  
															& kd_mult_zero & kd_mult_nan & kd_mult_udf & kd_mult_ovf 
															& ki_mult_zero & ki_mult_nan & ki_mult_udf & ki_mult_ovf
															& ki_sum_zero & ki_sum_nan & ki_sum_udf & ki_sum_ovf
															& kd_diff_zero & kd_diff_nan & kd_diff_udf & kd_diff_ovf;
	
	operational_error_encoder <= operational_error_encoder_sig;
	operational_error_pid <= operational_error_pid_sig;
--	pps_diff_error or const_mult_error or current_error_diff_error or kp_mult_error or
--							ki_mult_error or kd_mult_error or ki_sum_error or kd_diff_error or ki_kd_sum_error or
--							kp_ki_kd_sum_error or pid_fpconversion_error or pwm_complement_ovf;
	
end behavioral;