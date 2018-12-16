/* Quartus II 64-Bit Version 15.0.0 Build 145 04/22/2015 SJ Web Edition */
JedecChain;
	FileRevision(JESD32A);
	DefaultMfr(6E);

	P ActionCode(Ign)
		Device PartName(SOCVHPS) MfrSpec(OpMask(0));
	P ActionCode(Cfg)
		Device PartName(5CSEBA6) Path("C:/Users/VictorSantos/Documents/FPGA/projeto/projeto/pid_controller/output_files/") File("pid_controller.jic") MfrSpec(OpMask(1) SEC_Device(EPCS128) Child_OpMask(1 128));

ChainEnd;

AlteraBegin;
	ChainType(JTAG);
AlteraEnd;
