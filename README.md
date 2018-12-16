<b> VHDL-based PID Controller for DC motors </b>
<br />
This project is under development. <br />
I was wondering get back to develop something using VHDL/FPGA, so I started this project to have some fun with it. The purpose is to control a DC motor using a quadrature encoder as the feedback source.
<br />
The project is purely written in VHDL, using the Altera Quartus 13.0 sp1 software. All the modules have a testbench or a stimulus file.
<br />
Also, the final step will be integrate the PID-Controller IP to the avalon bus and to Nios softcore processor.
<br />
Please take a look in the block-diagram figure in the root folder to get a better understanding about the project.
<br />
<br />
<b>Project details:</b> <br />
In this project I tried to follow the good practices for VHDL development, such as the same ones applied in Volnei Pedroni and Rafael Cancian examples (next-state combinational logic, memory element i.e flip-flop, output logic). <br />
In all the written modules you won't see a flip-flop infered inside the next-state FSM, for example.
 <br />
 <br />
<b>Currently state:</b> <br />
 <br />
The PID controller is running in the Modelsim simulation, but still don't works on the DE-10 board. <br />
The wrapper for avalon bus is already written, I just need to make the project work on the board before test it.<br />
