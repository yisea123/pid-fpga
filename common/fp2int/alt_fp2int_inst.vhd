alt_fp2int_inst : alt_fp2int PORT MAP (
		aclr	 => aclr_sig,
		clk_en	 => clk_en_sig,
		clock	 => clock_sig,
		dataa	 => dataa_sig,
		nan	 => nan_sig,
		overflow	 => overflow_sig,
		result	 => result_sig,
		underflow	 => underflow_sig
	);
