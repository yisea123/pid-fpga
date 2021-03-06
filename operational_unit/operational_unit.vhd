library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.log_package.all;

--motor specs:
--max rpm = 201
--ppr = 374
--voltage = 6v

entity operational_unit is
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
--		
		load_user_rpm: in std_logic;
		load_pps_interrupt_in : in std_logic;
		load_current_rpm: in std_logic;
		load_total_error: in std_logic;
		load_last_error: in std_logic;
		load_kp_mult_reg: in std_logic;
		load_pid_res: in std_logic;
		
	
		--arithmetic blocks outputs
		--encoder
		--pps_diff_error: out std_logic;
		--const_mult_error: out std_logic;
 
		--pid
		--current_error_diff_error : out std_logic;			
		--kp_mult_error: out std_logic;			
		--ki_mult_error: out std_logic;		
		--kd_mult_error : out std_logic;
		--ki_sum_error : out std_logic;
		--kd_diff_error: out std_logic;		
		--ki_kd_sum_error: out std_logic;		
		--kp_ki_kd_sum_error: out std_logic; 
		--pid_fpconversion_error : out std_logic;
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
end entity;

architecture behavioral of operational_unit is

	--constants used in mux, they have relation to the rpm resolution (max_inputs_width)
	constant	mux_inputs: positive := 3;
   constant mux_inputs_width: positive := n_pwm_res;
	constant n_arithmetics_width : positive := 32; --number of bits used in almost all fixed/float calcs
	--this constant value stands for 60/ppr (0.1764) converted to IEEE-754 single format
	constant const_ppr : std_logic_vector (n_arithmetics_width - 1 downto 0) := ppr_constant; 
	constant min_pwm_value: std_logic_vector(n_pwm_res-1 downto 0) := (others=>'0'); --255 (2^8  - 1)
	constant max_pwm_value: std_logic_vector(n_pwm_res-1 downto 0) := (others=>'1'); --255 (2^8  - 1)
	
	--pid constants
	constant pid_kp : std_logic_vector (n_arithmetics_width-1 downto 0) :=  kp_constant; --0.5
	constant pid_ki : std_logic_vector (n_arithmetics_width-1 downto 0) :=  ki_constant; --0.3
	constant pid_kd : std_logic_vector (n_arithmetics_width-1 downto 0) :=  kd_constant; --1
	
	--internal signals: encoder
	signal user_pps_reg : std_logic_vector (n_arithmetics_width - 1 downto 0) := (others => '0');
	signal encoder_current_pps : std_logic_vector (n_arithmetics_width - 1 downto 0) := (others => '0');
   signal encoder_current_pps_fp : std_logic_vector (n_arithmetics_width - 1 downto 0) := (others => '0');
	signal encoder_current_pps_reg : std_logic_vector(n_arithmetics_width - 1 downto 0) := (others => '0');
	signal encoder_prev_pps : std_logic_vector(n_arithmetics_width - 1 downto 0) := (others => '0');
	signal current_rpm_sig : std_logic_vector(n_arithmetics_width - 1 downto 0) := (others => '0');
	signal pps_diff_res : std_logic_vector (n_arithmetics_width - 1 downto 0) := (others => '0');

	--internal signals: pid	
	signal user_rpm_reg_sig : std_logic_vector (n_pwm_res-1 downto 0) := (others=>'0');
	signal current_rpm_reg_sig : std_logic_vector (n_arithmetics_width-1 downto 0) := (others=>'0');
	signal current_error_diff_sig : std_logic_vector (n_arithmetics_width-1 downto 0) := (others=>'0');
	signal kp_mult_sig : std_logic_vector (n_arithmetics_width-1 downto 0) := (others=>'0');
	signal kp_mult_reg_sig : std_logic_vector (n_arithmetics_width-1 downto 0) := (others=>'0');
	signal ki_sum_sig : std_logic_vector (n_arithmetics_width-1 downto 0) := (others=>'0');
	signal total_error_reg_sig : std_logic_vector (n_arithmetics_width-1 downto 0) := (others=>'0');
	signal ki_mult_sig : std_logic_vector (n_arithmetics_width-1 downto 0) := (others=>'0');
	signal last_error_reg_sig : std_logic_vector (n_arithmetics_width-1 downto 0) := (others=>'0');
	signal pid_res_sig : std_logic_vector (7 downto 0) := (others=>'0');
	signal ki_kd_kp_sum_sig : std_logic_vector (n_arithmetics_width-1 downto 0) := (others=>'0');
	signal ki_kd_sum_sig : std_logic_vector (n_arithmetics_width-1 downto 0) := (others=>'0');
	signal kd_mult_sig : std_logic_vector (n_arithmetics_width-1 downto 0) := (others=>'0');
	signal kd_diff_sig : std_logic_vector (n_arithmetics_width-1 downto 0) := (others=>'0');	
-- 
--	signal pps_diff_ovf :  std_logic;
--	signal pps_diff_udf :  std_logic;
--	signal pps_diff_zero :  std_logic;
--	signal pps_diff_nan :  std_logic;
----			
--	signal const_mult_ovf :  std_logic;
--	signal const_mult_udf :  std_logic;
--	signal const_mult_zero :  std_logic;
--	signal const_mult_nan :  std_logic;
----
--	signal current_error_ovf : std_logic;
--	signal current_error_udf : std_logic;
--	signal current_error_zero : std_logic;
--	signal current_error_nan : std_logic;
--
--	signal kp_mult_ovf : std_logic;
--	signal kp_mult_udf : std_logic;
--	signal kp_mult_zero : std_logic;
--	signal kp_mult_nan : std_logic;
--	
--	signal ki_mult_ovf : std_logic;
--	signal ki_mult_udf: std_logic;
--	signal ki_mult_zero : std_logic;
--	signal ki_mult_nan: std_logic;
--	
--	signal kd_mult_ovf : std_logic;
--	signal kd_mult_udf : std_logic;
--	signal kd_mult_zero: std_logic;
--	signal kd_mult_nan : std_logic;
--	
--	signal ki_sum_ovf : std_logic;
--	signal ki_sum_udf : std_logic;
--	signal ki_sum_zero: std_logic;
--	signal ki_sum_nan : std_logic;		
--	
--	signal kd_diff_ovf : std_logic;
--	signal kd_diff_udf : std_logic;
--	signal kd_diff_zero: std_logic;
--	signal kd_diff_nan : std_logic;			
--	
--	signal ki_kd_sum_ovf : std_logic;
--	signal ki_kd_sum_udf : std_logic;
--	signal ki_kd_sum_zero: std_logic;
--	signal ki_kd_sum_nan : std_logic;			
--	
--	signal kp_ki_kd_sum_ovf : std_logic;
--	signal kp_ki_kd_sum_udf : std_logic;
--	signal kp_ki_kd_sum_zero: std_logic;
--	signal kp_ki_kd_sum_nan : std_logic;	
--
--	signal pid_fpconversion_udf : std_logic;
--	signal pid_fpconversion_nan : std_logic;			
	signal pid_fpconversion_ovf_sig : std_logic;
	signal pid_fpconversion_neg_sig : std_logic;
	
	signal mux_sel : std_logic_vector(1 downto 0);
	signal mux_in : std_logic_vector(0 to mux_inputs*mux_inputs_width -1) := (others=>'0');--"000000001111111100000000";
	signal mux_out: std_logic_vector(mux_inputs_width-1 downto 0) := (others =>'0');
	signal duty_sig: std_logic_vector(n_pwm_res-1 downto 0) := (others =>'0');
	signal converted_pid_sig : std_logic_vector(8 downto 0) := (others => '0');
	signal pwm_out_sig : std_logic;

	signal pps_interrupt_trigger_sig : std_logic;
	signal rpm_in_msb_zero : std_logic_vector(23 downto 0) := (others =>'0');
	signal rpm_converted_sig : std_logic_vector(n_arithmetics_width-1 downto 0) := (others=>'0');
	
	-- components declaration
	component n_register 
		generic (n : positive := 32);
		port (
			clk, rst, load : in std_logic;
			d : in std_logic_vector(n - 1 downto 0);
			q : out std_logic_vector(n - 1 downto 0)
		);
	end component; 
 
	component fpsum 
		port
			(
			clk : in std_logic;
			rst : in std_logic;
			en : in std_logic;
			add_sub : in std_logic;
			a : in std_logic_vector (31 downto 0);
			b : in std_logic_vector (31 downto 0);
			ovf : out std_logic;
			udf : out std_logic;
			zero : out std_logic;
			nan : out std_logic;
			res : out std_logic_vector (31 downto 0)
		);
	end component;
 
	component n_counter 
		generic (
			n : positive := 32); --210 rpm * 340 ppr
		port (
			clk : in std_logic; -- Input clock
			rst : in std_logic; -- Input rst
			dir : in std_logic; --0/1: up/down
			count : out std_logic_vector (n - 1 downto 0) -- Output of the counter
		);
	end component;
 
    component fpmult
        port (
            clk 	: in std_logic ;
            rst : in std_logic;
				en : in std_logic;
            a 	: in std_logic_vector (31 downto 0);
            b 	: in std_logic_vector (31 downto 0);
            ovf 	: out std_logic ;
            udf 	: out std_logic ;
            zero 	: out std_logic ;
            nan 	: out std_logic ;
            res 	: out std_logic_vector (31 downto 0)
        );
    end component;
 
     component int2fp
        port 
    ( 
		clk 	: in std_logic ;
      rst : in std_logic;
		en : in std_logic;
		int_in 	: in std_logic_vector (31 downto 0);
		fp_out 	: out std_logic_vector (31 downto 0)
    ); 
    end component;

    component n_trigger_counter 
    generic (n: positive :=32);
     port (
		  clk    :in  std_logic;                    -- Input clock	
	     rst  :in  std_logic;                      -- Input rst
        count : in std_logic_vector (n-1 downto 0);
	     en    : in std_logic; 
        trigger   :out std_logic -- reached count value
     );
    end component;   
    
    
	 
component superb_pwm 
    generic (n_bits: positive := 8);
    port ( clk : in  std_logic;
            rst: in std_logic;
           duty : in  std_logic_vector (n_bits-1 downto 0);
           pwm_out : out  std_logic
		);
end component;	 
	 
component fp2int 
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
end component;    
	
--component n_adder_sub
--generic (n: positive :=8);
--port (a, b : in std_logic_vector(n-1 downto 0);
--		en: std_logic;
--      op: in std_logic; --0: addition / 1: subtraction
--		ovf: out std_logic;
--      s : out std_logic_vector(n-1 downto 0));
--end component;	
	
 
    component mux_n_1
    generic (
      n_inputs: positive := 3;
      inputs_width: positive := 8
    );
      
    port(
         --a : in data_package.slv_array(0 to n_inputs-1)(inputs_width-1 downto 0); --vhdl2008 approach       
         a: in std_logic_vector(n_inputs*inputs_width-1 downto 0); --vhdl2003 compatible
         sel: in std_logic_vector(log2ceil(n_inputs)-1 downto 0);
         y : out std_logic_vector(inputs_width-1 downto 0)
        );
    end component; 
 
begin

	rpm_in_msb_zero  <= (others=>'0');
	
--encoder
	encoder_pps_counter : n_counter
	generic map(n => n_max_encoder_count)--71400: 340PPR * 210RPM
	port map(
		clk => encoder_in, 
		rst => rst_encoder_pulse_counter, 
		dir => '0', 
		count => encoder_current_pps
	);

	reg_current_pps : n_register
	generic map(n => n_arithmetics_width)
	port map(
		clk => clk, 
		rst => rst, 
		load => load_current_pps, --revolutions per second
		d => encoder_current_pps, 
		q => encoder_current_pps_reg
	);
	
	
    encoder_pps_conversion : int2fp
    port map (
		clk  => clk,
      rst => rst,
		en => en_pps_conversion,
		int_in => encoder_current_pps_reg,
		fp_out => encoder_current_pps_fp --debug
    );
    
 
	reg_prev_pps : n_register
	generic map(n => n_arithmetics_width)
	port map(
		clk => clk, 
		rst => rst, 
		load => load_prev_pps, 
		d => encoder_current_pps_fp, 
		q => encoder_prev_pps
	);
 
	pps_difference : fpsum
	port map(
        clk => clk,
        rst => rst,
		  en => en_pps_diff,
        add_sub => '0', --0 sub/ 1 add
		  a => encoder_current_pps_fp, 
		  b => encoder_prev_pps, 
		  ovf => pps_diff_ovf,
        udf => pps_diff_udf,
        zero => pps_diff_zero,
        nan => pps_diff_nan,
        res => pps_diff_res
        ); 
 
	const_mult : fpmult
	port map(
		clk => clk, 
      rst  => rst,
		en => en_const_mult, 
		a => pps_diff_res, 
		b => const_ppr, 
		ovf => const_mult_ovf, 
		udf => const_mult_udf, 
		zero => const_mult_zero, 
		nan => const_mult_nan, 
		res => current_rpm_sig
	);

    
	pps_counter_reg : n_register
	generic map(n => n_arithmetics_width)
	port map(
		clk => clk, 
		rst => rst, 
		load => load_pps_interrupt_in, 
		d => pps_interrupt_in, 
		q => user_pps_reg
	); 
	 
    pps_trigger_counter : n_trigger_counter
    generic map(n => n_arithmetics_width)
	port map(
		clk => clk, 
      rst  => rst_pps_interrupt,
		count => user_pps_reg, 
		en => en_pps_interrupt, 
		trigger => pps_interrupt_trigger_sig
	);
    
	--last block of encoder part, stores the current rpm
	--based on the encoder pulses
	current_rpm_reg : n_register
	generic map(n => n_arithmetics_width)
	port map(
		clk => clk, 
		rst => rst, 
		load => load_current_rpm, 
		d => current_rpm_sig, 
		q => current_rpm_reg_sig
	); 
	

--pid	
	 user_rpm_reg: n_register 
		generic map (n => n_pwm_res)
		port map ( 
			clk => clk,
			rst => rst, 
			load => load_user_rpm, 
			d => user_rpm,
			q => user_rpm_reg_sig
		);
		
   user_rpm_conversion : int2fp
    port map (
		clk  => clk,
      rst => rst,
		en => en_user_rpm_conversion,
		int_in => rpm_in_msb_zero & user_rpm_reg_sig,
		fp_out => rpm_converted_sig --debug
    );
		
		current_error_diff: fpsum 
      port map ( 
			clk => clk,
			rst => rst,
			en => en_diff_current_error,
			add_sub => '0', 	--0 sub/ 1 add
			a => rpm_converted_sig,
			b => current_rpm_reg_sig,
			ovf => current_error_ovf,
			udf => current_error_udf,
			zero => current_error_zero,
			nan => current_error_nan,
			res => current_error_diff_sig
		);
		
		kp_mult: fpmult
		port map (
			clk  => clk,
			rst  => rst,
			en => en_mult,
			a 	 => pid_kp,
			b 	 => current_error_diff_sig,
			ovf  => kp_mult_ovf,
			udf  => kp_mult_udf,
			zero => kp_mult_zero,
			nan  => kp_mult_nan,
			res  => kp_mult_sig
		);	

				
		kp_mult_reg: n_register 
		generic map (n => n_arithmetics_width)
		port map ( 
			clk => clk,
			rst => rst, 
			load => load_kp_mult_reg, 
			d => kp_mult_sig,
			q => kp_mult_reg_sig
		);
		
		total_error_reg: n_register 
		generic map (n => n_arithmetics_width)
		port map ( 
			clk => clk,
			rst => rst, 
			load => load_total_error, 
			d => ki_sum_sig,
			q => total_error_reg_sig
		);
				
		ki_sum: fpsum  
      port map ( 
			clk => clk,
			rst => rst,
			en => en_sum_ki,
			add_sub => '1', 	--0 sub/ 1 add
			a => current_error_diff_sig, 
			b => total_error_reg_sig,
			ovf => ki_sum_ovf,
			udf => ki_sum_udf,
			zero => ki_sum_zero,
			nan => ki_sum_nan,
			res => ki_sum_sig
		);
			
		ki_mult: fpmult
		port map (
			clk 	 => clk,
			rst => rst,
			en => en_mult,
			a 	 	 => pid_ki,
			b 	 	 => ki_sum_sig,
			ovf 	 => ki_mult_ovf,
			udf 	 => ki_mult_udf,
			zero 	 => ki_mult_zero,
			nan 	 => ki_mult_nan,
			res 	 => ki_mult_sig
		);	
				
		last_error_reg: n_register 
		generic map (n => n_arithmetics_width)
		port map ( 
			clk => clk,
			rst => rst, 
			load => load_last_error, 
			d => current_error_diff_sig,
			q => last_error_reg_sig
		);
				
		kd_diff: fpsum  
      port map ( 
			clk => clk,
			rst => rst,
			en => en_diff_kd,
			add_sub => '0', 	
			a => current_error_diff_sig,
			b => last_error_reg_sig,
			ovf => kd_diff_ovf,
			udf => kd_diff_udf,
			zero => kd_diff_zero,
			nan => kd_diff_nan,
			res => kd_diff_sig
		 );
		 
		
		kd_mult: fpmult
		port map (
			clk 	 => clk,
			rst => rst,
			en => en_mult,
			a 	 	 => pid_kd,
			b 	 	 => kd_diff_sig,
			ovf 	 => kd_mult_ovf,
			udf 	 => kd_mult_udf,
			zero 	 => kd_mult_zero,
			nan 	 => kd_mult_nan,
			res 	 => kd_mult_sig
		);	

		
		ki_kd_sum: fpsum 
		port map (
			clk 	 => clk,
			rst 	 => rst,
			en => en_sum_ki_kd,
			add_sub  => '1',	
			a 	 	 => ki_mult_sig,
			b 	 	 => kd_mult_sig,
			ovf 	 => ki_kd_sum_ovf,
			udf 	 => ki_kd_sum_udf,
			zero 	 => ki_kd_sum_zero,
			nan 	 => ki_kd_sum_nan,
			res 	 => ki_kd_sum_sig
		);
		
		ki_kd_kp_sum: fpsum 
		port map (
			clk 	 => clk,
			rst 	 => rst,
			en => en_sum_kp_ki_kd,
			add_sub  => '1',	
			a 	 	 => ki_kd_sum_sig,
			b 	 	 => kp_mult_reg_sig,
			ovf 	 => kp_ki_kd_sum_ovf,
			udf 	 => kp_ki_kd_sum_udf,
			zero 	 => kp_ki_kd_sum_zero,
			nan 	 => kp_ki_kd_sum_nan,
			res 	 => ki_kd_kp_sum_sig 
		);
		

		
	delay_counter : n_trigger_counter
   generic map(n => 8)
	port map(
		clk => clk, 
      rst  => rst,
		count => delay_counter_in, 
		en => en_delay_counter, 
		trigger => delay_counter_trigger
	);
	
	   --conversion from 32 bits float/fixed pointer to n_pwm_res bits integer
		pid_converter: fp2int  
      port map ( 
			clk => clk,
			rst => rst,
			en => en_pid_fpconversion,
			data_in => ki_kd_kp_sum_sig, 
			ovf => pid_fpconversion_ovf_sig,
			udf => pid_fpconversion_udf,
			nan => pid_fpconversion_nan,
			neg => pid_fpconversion_neg_sig,
			data_out => converted_pid_sig
		);
		
		pid_res_reg: n_register 
		generic map (n => n_pwm_res)
		port map ( 
			clk => clk,
			rst => rst, 
			load => load_pid_res, 
			d => converted_pid_sig(7 downto 0),
			q => pid_res_sig
		);

		pid_fpconversion_ovf <= pid_fpconversion_ovf_sig;
		pid_fpconversion_neg <= pid_fpconversion_neg_sig;
		
		mux_sel <= pid_fpconversion_neg_sig & pid_fpconversion_ovf_sig;
		--mux_in(0 to mux_inputs_width-1) <= pid_res_sig;
		mux_in(0 to mux_inputs*mux_inputs_width -1) <= pid_res_sig & max_pwm_value & min_pwm_value;
		
		boundaries_protection: mux_n_1 
      generic map (
        n_inputs => mux_inputs,
        inputs_width => mux_inputs_width
      )
      port map (
          a => mux_in,
          sel => mux_sel,
          y => mux_out
        );

--	pwm_complement : n_adder_sub
--	generic map(n => n_pwm_res)
--	port map (
--		a => max_pwm_value,
--		b => mux_out,
--		en => en_pwm_complement,
--      op => '1', --0: addition / 1: subtraction
--		ovf => pwm_complement_ovf,
--      s => duty_sig 
--		);		
		
	pwm_module: superb_pwm 
    generic map (n_bits => n_pwm_res)
    port map(
	 clk => clk,
    rst => rst,
    duty => mux_out, --duty_sig,
    pwm_out =>  pwm_out_sig 
	 );
		
 
--	pps_diff_error <= pps_diff_ovf or pps_diff_udf or pps_diff_nan or pps_diff_zero;
--	const_mult_error <= const_mult_ovf or const_mult_udf or const_mult_nan or const_mult_zero;
--	current_error_diff_error <= current_error_ovf or current_error_udf or current_error_nan or current_error_zero;
--	kp_mult_error <= kp_mult_ovf or kp_mult_udf or kp_mult_nan or kp_mult_zero;
--	ki_mult_error <= ki_mult_ovf or ki_mult_udf or ki_mult_nan or ki_mult_zero;
--	kd_mult_error <= kd_mult_ovf or kd_mult_udf or kd_mult_nan or kd_mult_zero;
--	ki_sum_error <= ki_sum_ovf or ki_sum_udf or ki_sum_nan or ki_sum_zero;
--	kd_diff_error <= kd_diff_ovf or kd_diff_udf or kd_diff_nan or kd_diff_zero;
--	ki_kd_sum_error <= ki_kd_sum_ovf or ki_kd_sum_udf or ki_kd_sum_nan or ki_kd_sum_zero;
--	kp_ki_kd_sum_error <= kp_ki_kd_sum_ovf or kp_ki_kd_sum_udf or kp_ki_kd_sum_nan or kp_ki_kd_sum_zero;
--	pid_fpconversion_error <= pid_fpconversion_ovf or pid_fpconversion_udf or pid_fpconversion_nan or pid_fpconversion_neg;
	
	--debug outputs
	encoder_count <= encoder_current_pps_reg;
	current_rpm <= current_rpm_reg_sig;
	pid_out <= ki_kd_kp_sum_sig;
	
	--block outputs
	pps_interrupt_trigger <= pps_interrupt_trigger_sig;
	pwm_out <= pwm_out_sig;

end architecture;