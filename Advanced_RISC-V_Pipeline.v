`timescale 1ns / 1ps
`include "./config.vh"

module Advanced_RISCVpipeline(
`ifndef simulation
	input 	[ 4:0] key,
	input	 	[ 5:0] Switch,
	output 	[ 3:0] digit,
	output 	[ 7:0] fnd,
	output 	[15:0] LED,
`endif
	/////////////////////////////////////
	input 		  clk, rst
	);
	wire 			c;
	wire [ 1:0] LED_clk;
	
	wire [31:0] inf_pc;
	wire [31:0] inf_ins;
	
	wire [ 7:0] ind_ctl;
	wire [31:0] ind_pc;
	wire [ 4:0] ind_rs1;
	wire [ 4:0] ind_rs2;
	wire [ 4:0] ind_rd;
	wire [31:0] ind_data1;
	wire [31:0] ind_data2;
	wire [31:0] ind_imm;
	wire [ 6:0] ind_f7;
	wire [ 2:0] ind_f3;
	wire 	  		ind_jalr;
	wire 			ind_jal;
	
	wire [ 5:1] exe_ctl;
	wire [31:0] exe_pc;
	wire [ 4:0] exe_rd;
	wire [31:0] exe_data;
	wire [31:0] exe_addr;
	wire [31:0] exe_result;
	wire 			exe_zero;
	wire 			exe_jalr;
	wire 			exe_jal;
	
	wire [ 2:1] mem_ctl;
	wire [31:0] mem_pc;
	wire [ 4:0] mem_rd;
	wire [31:0] mem_data;
	wire [31:0] mem_addr;
	wire [31:0] mem_result;
	wire 			mem_jalr;
	wire 			mem_jal;
	wire 			mem_flush;
	wire 			mem_PCSrc;
	
	wire 			wb_ctl;
	wire [ 4:0] wb_rd;
	wire [31:0] wb_data;
	
	wire 			hzd_stall;
	wire [ 1:0] fwd_A;
	wire [ 1:0] fwd_B;	
	
	wire			ind_is_stack;
	wire			exe_is_stack;
	
`ifdef simulation
	wire	[31:0] data = clk_count;
	wire 	[31:0] RAM_address = exe_result;
`else
	assign 		 LED = {pass, data[30:16]};
	wire	[31:0] clk_address, clk_count;
	wire 	[31:0] data = (key[1])? mem_data : clk_count;
	wire 	[31:0] RAM_address = (key[1]) ? (clk_address<<2) : exe_result;
`endif	
//////////////////////////////////////////////////////////////////////////////////////
	LED_channel LED0(
	.data(data),							.digit(digit),
	.LED_clk(LED_clk),					.fnd(fnd));
//////////////////////////////////////////////////////////////////////////////////////
	counter A0_counter(
`ifndef simulation
	.key1(key[1]),
	.mem_data(mem_data),
	.pass(pass),
	.clk_address(clk_address),
	
	.Switch(Switch),
`endif
	
	.clk(clk),								.LED_clk(LED_clk),
	.rst(rst),								.clk_out(c),
	.pc_in(inf_pc),						.clk_count_out(clk_count));
//////////////////////////////////////////////////////////////////////////////////////
	InFetch A1_InFetch(
	.PCSrc(mem_PCSrc),					
	.PCWrite(hzd_stall), 				
//-----------------------------------------------------------------------------------
	.PC_ADDR_in(mem_addr),				.PC_out(inf_pc),
												.instruction_out(inf_ins),
	.rst(rst),
	.clk(c));					
//////////////////////////////////////////////////////////////////////////////////////
	InDecode A2_InDecode(
												.Ctl_ALUSrc_out(ind_ctl[0]),
												.Ctl_MemtoReg_out(ind_ctl[1]),
	.Ctl_RegWrite_in(wb_ctl),			.Ctl_RegWrite_out(ind_ctl[2]),
												.Ctl_MemRead_out(ind_ctl[3]),
												.Ctl_MemWrite_out(ind_ctl[4]),
												.Ctl_Branch_out(ind_ctl[5]),
												.Ctl_ALUOpcode1_out(ind_ctl[6]),
												.Ctl_ALUOpcode0_out(ind_ctl[7]),
												.is_stack(ind_is_stack),
//-----------------------------------------------------------------------------------
	.stall(hzd_stall), 					
	.flush(mem_PCSrc), 					
												.Rs1_out(ind_rs1),	
												.Rs2_out(ind_rs2),	
//-----------------------------------------------------------------------------------
	.PC_in(inf_pc),						.PC_out(ind_pc),
												.jalr_out(ind_jalr),
												.jal_out(ind_jal),
//-----------------------------------------------------------------------------------									
	.instruction_in(inf_ins),			.ReadData1_out(ind_data1),
												.ReadData2_out(ind_data2),
												.Immediate_out(ind_imm),
												.Rd_out(ind_rd),
												.funct7_out(ind_f7),
	.WriteReg(wb_rd),						.funct3_out(ind_f3),
	.WriteData(wb_data),					

	.rst(rst),
	.clk(c));
//////////////////////////////////////////////////////////////////////////////////////
	Execution A3_Execution(	
	.Ctl_ALUSrc_in(ind_ctl[0]),		//.Ctl_ALUSrc_out(exe_ctl[0]),
	.Ctl_MemtoReg_in(ind_ctl[1]),		.Ctl_MemtoReg_out(exe_ctl[1]),
	.Ctl_RegWrite_in(ind_ctl[2]),		.Ctl_RegWrite_out(exe_ctl[2]),
	.Ctl_MemRead_in(ind_ctl[3]),		.Ctl_MemRead_out(exe_ctl[3]),	
	.Ctl_MemWrite_in(ind_ctl[4]),		.Ctl_MemWrite_out(exe_ctl[4]),
	.Ctl_Branch_in(ind_ctl[5]),		.Ctl_Branch_out(exe_ctl[5]),
	.Ctl_ALUOpcode1_in(ind_ctl[6]),	//.Ctl_ALUOpcode1_out(exe_ctl[6]),
	.Ctl_ALUOpcode0_in(ind_ctl[7]),	//.Ctl_ALUOpcode0_out(exe_ctl[7]),
//-----------------------------------------------------------------------------------
	.ForwardA(fwd_A),  					.is_stack_in(ind_is_stack),
	.ForwardB(fwd_B),  					.is_stack(exe_is_stack),
	.before_data(exe_result),			
	.before_before_data(wb_data),		
	.flush(mem_PCSrc),					
//-----------------------------------------------------------------------------------
												.Address_out(exe_addr),
												.Zero_out(exe_zero),
												.ALUresult_out(exe_result),
												
	.PC_in(ind_pc),						.PC_out(exe_pc),
	.jalr_in(ind_jalr),					.jalr_out(exe_jalr),
	.jal_in(ind_jal),						.jal_out(exe_jal),
		
						
	.ReadData1_in(ind_data1),
	.ReadData2_in(ind_data2),			.ReadData2_out(exe_data),
	.Immediate_in(ind_imm),
	.Rd_in(ind_rd),						.Rd_out(exe_rd),
	.funct7_in(ind_f7),						
	.funct3_in(ind_f3),					
						
	.rst(rst),
	.clk(c));
//////////////////////////////////////////////////////////////////////////////////////				
	Memory A4_Memory( 		
	//.Ctl_ALUSrc_in(exe_ctl[0]),		.Ctl_ALUSrc_out(mem_ctl[0]),
	.Ctl_MemtoReg_in(exe_ctl[1]),		.Ctl_MemtoReg_out(mem_ctl[1]),
	.Ctl_RegWrite_in(exe_ctl[2]),		.Ctl_RegWrite_out(mem_ctl[2]),
	.Ctl_MemRead_in(exe_ctl[3]),		//.Ctl_MemRead_out(mem_ctl[3]),
	.Ctl_MemWrite_in(exe_ctl[4]),		//.Ctl_MemWrite_out(mem_ctl[4]),
	.Ctl_Branch_in(exe_ctl[5]),		//.Ctl_Branch_out(mem_ctl[5]),
	//.Ctl_ALUOpcode1_in(exe_ctl[6]),.Ctl_ALUOpcode1_out(mem_ctl[6]),
	//.Ctl_ALUOpcode0_in(exe_ctl[7]),.Ctl_ALUOpcode0_out(mem_ctl[7]),	
//-----------------------------------------------------------------------------------
	.PC_in(exe_pc),						.PC_out(mem_pc),
	.jalr_in(exe_jalr),					.jalr_out(mem_jalr),
	.jal_in(exe_jal),						.jal_out(mem_jal),											
												
	.Address_in(exe_addr),				.Address_out(mem_addr),
	.Zero_in(exe_zero),					.PCSrc(mem_PCSrc),
	.ALUresult_in(RAM_address),		.ALUresult_out(mem_result),
	.Write_Data(exe_data),				.Read_Data(mem_data),
	.Rd_in(exe_rd),						.Rd_out(mem_rd),
	
	.rst(rst), 
	.clk(c),									.is_stack(exe_is_stack));
//////////////////////////////////////////////////////////////////////////////////////
	WB A5_WB(
	//.Ctl_ALUSrc_in(mem_ctl[0]),		.Ctl_ALUSrc_out(wb_ctl[0]),
	.Ctl_MemtoReg_in(mem_ctl[1]),		//.Ctl_MemtoReg_out(wb_ctl[1]),
	.Ctl_RegWrite_in(mem_ctl[2]),		.Ctl_RegWrite_out(wb_ctl),
	//.Ctl_MemRead_in(mem_ctl[3]),	.Ctl_MemRead_out(wb_ctl[3]),
	//.Ctl_MemWrite_in(mem_ctl[4]),	.Ctl_MemWrite_out(wb_ctl[4]),
	//.Ctl_Branch_in(mem_ctl[5]),		.Ctl_Branch_out(wb_ctl[5]),
	//.Ctl_ALUOpcode1_in(mem_ctl[6]),.Ctl_ALUOpcode1_out(wb_ctl[6]),
	//.Ctl_ALUOpcode0_in(mem_ctl[7]),.Ctl_ALUOpcode0_out(wb_ctl[7]),			
//-----------------------------------------------------------------------------------		
	.PC_in(mem_pc),
	.jalr_in(mem_jalr),
	.jal_in(mem_jal),
						
	.ReadDatafromMem_in(mem_data),	.WriteDatatoReg_out(wb_data), 
	.ALUresult_in(mem_result),
	.Rd_in(mem_rd),						.Rd_out(wb_rd) 					
	);
//////////////////////////////////////////////////////////////////////////////////////
	Forwarding_unit A6_Forwarding (
	.mem_Ctl_RegWrite_in(exe_ctl[2]),
	.wb_Ctl_RegWrite_in(mem_ctl[2]),
						
	.Rs1_in(ind_rs1),
	.Rs2_in(ind_rs2),
	.mem_Rd_in(exe_rd),
	.wb_Rd_in(mem_rd),
						
												.ForwardA_out(fwd_A),
												.ForwardB_out(fwd_B)
	);
//////////////////////////////////////////////////////////////////////////////////////
	Hazard_detection_unit A7_Hazard (
	.exe_Ctl_MemRead_in(ind_ctl[3]),
	.Rd_in(ind_rd),
	.instruction_in(inf_ins[24:15]),
												.stall_out(hzd_stall)
	);
												
endmodule

module Forwarding_unit(
	input mem_Ctl_RegWrite_in, wb_Ctl_RegWrite_in,
	input [4:0] Rs1_in, Rs2_in, mem_Rd_in, wb_Rd_in,
	output [1:0] ForwardA_out, ForwardB_out
	);
	
	assign ForwardA_out = (mem_Ctl_RegWrite_in && (mem_Rd_in == Rs1_in)) ? 2'b10 :
									(wb_Ctl_RegWrite_in && (wb_Rd_in == Rs1_in)) ? 2'b01 :
																								  2'b00;
	assign ForwardB_out = (mem_Ctl_RegWrite_in && (mem_Rd_in == Rs2_in)) ? 2'b10 :
									(wb_Ctl_RegWrite_in && (wb_Rd_in == Rs2_in)) ? 2'b01 :
																								  2'b00;
									
endmodule

module Hazard_detection_unit(
	input			exe_Ctl_MemRead_in,
	input	[4:0]	Rd_in,
	input [9:0]	instruction_in,
	output		stall_out
	);
	
	wire	[4:0]	Rs1_in = instruction_in [4:0];
	wire	[4:0]	Rs2_in = instruction_in [9:5];
	
	assign stall_out = (exe_Ctl_MemRead_in && (Rd_in == Rs1_in || Rd_in == Rs2_in)) ? 1 : 0;
	
endmodule

module InFetch(
	input 		       clk, rst,
	input 		       PCSrc, 		// control signal
	input					 PCWrite,
	input 		[31:0] PC_ADDR_in, // PC + imm       
	output	 	[31:0] instruction_out,
	output reg	[31:0] PC_out
   );
	wire 			[31:0] PC;
	wire			[31:0] PC4 = (PCSrc) ? PC_ADDR_in : PC+4;
	
	PC B1_PC(
	.clk(clk),
	.PCWrite(PCWrite),
	.rst(rst),
	.PC_in(PC4),		.PC_out(PC));
	
	iMEM B2_iMEM(
	.clk(clk),
	.rst(rst),
	.IF_ID_Write(PCWrite),
	.PCSrc(PCSrc),
	.PC_in(PC),	.instruction_out(instruction_out));

	//IF/ID reg
	always@(posedge clk) begin
		if(rst || PCSrc)  PC_out <= 0;
		else if (PCWrite) PC_out <= PC_out;
		else					PC_out <= PC;
	end

endmodule
//////////////////////////////////////////////////////////////////////////////////
module PC(
	input 				 clk, rst,
	input					 PCWrite,
	input 		[31:0] PC_in,
	output reg	[31:0] PC_out
	);
	always @(posedge clk) begin
		if(rst)				PC_out <= 0;
		else if (PCWrite)		PC_out <= PC_out;
		else						PC_out <= PC_in;
	end
endmodule
//////////////////////////////////////////////////////////////////////////////////
module iMEM(
	input 				 clk, rst,
	input					 IF_ID_Write, PCSrc,	
	input			[31:0] PC_in,
	output reg	[31:0] instruction_out
	);
	parameter 			 ROM_size = 100;
	reg 			[31:0] ROM [0:ROM_size-1];
	integer i;
	initial begin
		for(i=0; i!=ROM_size; i=i+1) begin
			ROM[i] = 32'b0;
		end
		$readmemh("../src/quick.rom.mem",ROM);
	end

	// Instruction Fetch (BRAM)
	always @(posedge clk) begin
		if(!IF_ID_Write)
			if(rst||PCSrc)		instruction_out <= 32'b0;
			else					instruction_out <= ROM[PC_in[31:2]];
		end

endmodule

module InDecode(
	input clk, rst,
	// data hazard
	input stall,
	// control hazard
	input flush,
	// forwarding
	input Ctl_RegWrite_in, 	
	// control signal
	output reg Ctl_ALUSrc_out, Ctl_MemtoReg_out, Ctl_RegWrite_out, Ctl_MemRead_out, Ctl_MemWrite_out, Ctl_Branch_out, Ctl_ALUOpcode1_out, Ctl_ALUOpcode0_out,
	//
	input 		[ 4:0] WriteReg, //reg ּ  5bit = 32      ּ 
	input 		[31:0] PC_in, instruction_in, WriteData,
	
	output reg 	[ 4:0] Rd_out, Rs1_out, Rs2_out,
	output reg 	[31:0] PC_out, ReadData1_out, ReadData2_out, Immediate_out,
	output reg  [ 6:0] funct7_out, 	// RISC-V
	output reg 	[ 2:0] funct3_out,	// RISC-V
	output reg 			 jalr_out, jal_out,
	
	output reg			 is_stack
	);	
	wire [ 6:0] opcode = instruction_in[6:0];
	wire [ 6:0] funct7 = instruction_in[31:25];
	wire [ 2:0] funct3 = instruction_in[14:12];
	wire [ 4:0] Rd 	 = instruction_in[11:7];
	wire [ 4:0]	Rs1	 = instruction_in[19:15];
	wire [ 4:0] Rs2	 = instruction_in[24:20];
	wire 		  	jalr 	 = (opcode==7'b11001_11)?1:0; //JALR   opcode
	wire 		  	jal 	 = (opcode==7'b11011_11)?1:0; //JAL    opcode
	wire [ 7:0] Ctl_out;
	
	// control unit RISC-V
	Control_unit B0 (.opcode(instruction_in[6:0]), .Ctl_out(Ctl_out), .rst(rst));
	
	//Register
	integer i;
	parameter reg_size = 32;
	reg [31:0] Reg[0:reg_size-1]; //32bit reg
	always@(posedge clk) begin
		if (rst) begin
			for(i=0; i!=reg_size; i=i+1) begin
				Reg[i] <= 32'b0;
			end
		end
		else if(Ctl_RegWrite_in && WriteReg!=0)
			Reg[WriteReg] <= WriteData;
	end
	
	reg [7:0]	Control;
	always @(*)	begin
		Control = (flush)	?	1'b0:
					 (stall)	?	1'b0:	Ctl_out;
	end
	
	//Immediate Generator - sign extention RISC-V
	reg [31:0] Immediate;
	always@(*) begin
		case(opcode)
			7'b00000_11: Immediate	= $signed(instruction_in[31:20]); // I-type 
			7'b00100_11: Immediate	= $signed(instruction_in[31:20]); // I-type 
			7'b11001_11: Immediate	= $signed(instruction_in[31:20]); // I-type jalr     
			7'b01000_11: Immediate	= $signed({instruction_in[31:25],instruction_in[11:7]}); // S-type
			7'b11000_11: Immediate	= $signed({instruction_in[31],instruction_in[7],instruction_in[30:25],instruction_in[11:8]}); // SB-type
			7'b11011_11: Immediate	= $signed({instruction_in[31],instruction_in[19:12],instruction_in[20],instruction_in[30:21]}); // jal    
			default: 	 Immediate	= 32'bx;
		endcase
	end
	
	//ID/EX reg
	always@(posedge clk) begin
		// RISC-V		
		PC_out 			<= (rst) ? 0 : PC_in;
		funct7_out		<= (rst) ? 0 : funct7;
		funct3_out		<= (rst) ? 0 : funct3;
		Rd_out 			<= (rst) ? 0 : Rd;
		Rs1_out			<= (rst) ? 0 : Rs1;
		Rs2_out			<= (rst) ? 0 : Rs2;
		ReadData1_out 	<= (rst) ? 0 : (Ctl_RegWrite_in && WriteReg == Rs1) ? WriteData : Reg[Rs1];
		ReadData2_out 	<= (rst) ? 0 : (Ctl_RegWrite_in && WriteReg == Rs2) ? WriteData : Reg[Rs2];
		jalr_out			<= (rst) ? 0 : jalr;
		jal_out			<= (rst) ? 0 : jal;
		Ctl_ALUSrc_out 		<= (rst) ? 0 : Control[7];
		Ctl_MemtoReg_out 		<= (rst) ? 0 : Control[6];
		Ctl_RegWrite_out 		<= (rst) ? 0 : Control[5];
		Ctl_MemRead_out 		<= (rst) ? 0 : Control[4];
		Ctl_MemWrite_out 		<= (rst) ? 0 : Control[3];
		Ctl_Branch_out 		<= (rst) ? 0 : Control[2];
		Ctl_ALUOpcode1_out 	<= (rst) ? 0 : Control[1];
		Ctl_ALUOpcode0_out 	<= (rst) ? 0 : Control[0];
		Immediate_out			<= (rst) ? 0 : Immediate;
		is_stack					<= (rst) ? 0 : (Rs1 == 5'b00010)? 1:0;
	end
	
endmodule

////////////////////////////////////////////////////////////////////////////////////
module Control_unit(
	input [6:0] opcode,
	input rst,
	output reg [7:0] Ctl_out
	);

	always @(*) begin	
		if (rst) // control unit  ݵ   0     reset
			Ctl_out = 8'b0;
		else
			case(opcode)										//													[7]			[6]			[5]			[4]			[3]			[2]
				// add, sub, ... (ALU    )
				7'b01100_11 : Ctl_out = 8'b001000_10;	// R-type										-				-				RegWrite		-				-				-
				// addi, slli : shift left logical immediate rd = rs1 << imm (ALU    )
				7'b00100_11 : Ctl_out = 8'b101000_11;	// I-type    xxxi  rd, rs1,imm[11:0]	ALUSrc 		-				RegWrite 	-				-				-
				// lw (ALU    )
				7'b00000_11 : Ctl_out = 8'b111100_00;	// I-type    lxx   rd, rs1,imm[11:0]	ALUSrc 		MemtoReg 	RegWrite 	MemRead		-				-
				// sw (ALU    )
				7'b01000_11 : Ctl_out = 8'b100010_00;	// S-type    sxx   rs1,rs2,imm[11:0]	ALUSrc		-				-				-				MemWrite 	-			
				// beq : branch equal (ALU    )	: go to PC+imm<<1
				7'b11000_11 : Ctl_out = 8'b000001_01;	// SB-type   bcc   rs1,rs2,imm[12:1] 	-				-				-				-				-				Branch		// å     7'b11001_11       Ǿ          Ÿ   
				// jal : jump and link 				: rd = PC+4, 	go to PC+imm<<1 (ALU    X)
				7'b11011_11 : Ctl_out = 8'b001001_00;	// UJ-type   jal	 rd, imm[20:1] 		-				-				RegWrite		-				-				Branch
				// jalr : jump and link register : rd = PC+4, 	go to rs1+imm (ALU    )
				7'b11001_11 : Ctl_out = 8'b101001_11;	// I-type   jalr  rd, rs1,imm[11:0] 	ALUSrc 		-			 	RegWrite 	-				-				Branch
				
				default 		: Ctl_out = 8'b0; // control unit  ݵ   0         ó  
			endcase
	end
endmodule

module Execution(
	input 	clk, rst,
	input		flush,
	// control signal
	input 		Ctl_ALUSrc_in, Ctl_MemtoReg_in, 	Ctl_RegWrite_in,Ctl_MemRead_in, Ctl_MemWrite_in, Ctl_Branch_in, Ctl_ALUOpcode1_in, Ctl_ALUOpcode0_in,
	output reg						Ctl_MemtoReg_out, Ctl_RegWrite_out, Ctl_MemRead_out,	Ctl_MemWrite_out,	Ctl_Branch_out,
	// bypass
	input 		[ 4:0] Rd_in,
	output reg 	[ 4:0] Rd_out,
	input					 jal_in, jalr_in,
	output reg			 jal_out, jalr_out,
	// 
	input 		[31:0] Immediate_in, ReadData1_in, ReadData2_in, PC_in, 
	input 		[31:0] before_data, before_before_data, // ߰  forwarding
	input 		[ 6:0] funct7_in, 
	input 		[ 2:0] funct3_in,
	input			[ 1:0] ForwardA, ForwardB,
	output reg			 Zero_out,
	
	output reg 	[31:0] ALUresult_out, Address_out, ReadData2_out, PC_out,
	
	input					 is_stack_in,
	output reg			 is_stack
	);
	
	//RISC-V
	wire [3:0] ALU_ctl;
	wire [31:0] ALUresult;
	//wire Zero;
	
	wire [31:0] ALU_input1 = (ForwardA == 2'b10) ? before_data :
									 (ForwardA == 2'b01) ? before_before_data : ReadData1_in;
	wire [31:0] ForwardB_input = (ForwardB == 2'b10) ? before_data :
										  (ForwardB == 2'b01) ? before_before_data : ReadData2_in;
	wire [31:0] ALU_input2 = (Ctl_ALUSrc_in) ? Immediate_in : ForwardB_input; 
		
	ALU_control B0 (.ALUop({Ctl_ALUOpcode1_in, Ctl_ALUOpcode0_in}), .funct7(funct7_in), .funct3(funct3_in), .ALU_ctl(ALU_ctl));
	ALU B1 (.ALU_ctl(ALU_ctl), .in1(ALU_input1), .in2(ALU_input2), .out(ALUresult), .zero(Zero));
	
	always@(posedge clk) begin
		Ctl_MemtoReg_out	<= (rst||flush) ? 0: Ctl_MemtoReg_in;
		Ctl_RegWrite_out	<= (rst||flush) ? 0: Ctl_RegWrite_in;
		Ctl_MemRead_out	<= (rst||flush) ? 0: Ctl_MemRead_in;
		Ctl_MemWrite_out	<= (rst||flush) ? 0: Ctl_MemWrite_in;
		Ctl_Branch_out		<= (rst||flush) ? 0: Ctl_Branch_in;
		
		PC_out 				<= (rst)? 0: PC_in;
		jalr_out 			<= (rst)? 0: jalr_in;
		jal_out				<= (rst)? 0: jal_in;
		
		ReadData2_out		<= (rst)? 0: ForwardB_input;
		
		Rd_out				<= (rst||flush)? 0: Rd_in;
		Address_out			<= (rst)? 0: PC_in + (Immediate_in<<1);
		
		ALUresult_out		<= (rst)? 0: ALUresult;
		Zero_out				<= (rst)? 0: Zero;
		is_stack				<= (rst)? 0: is_stack_in;
	end
endmodule
//////////////////////////////////////////////////////////////////////////////////
module ALU_control(
	input [1:0] ALUop,
	input [6:0] funct7,
	input [2:0] funct3,
	output reg [3:0] ALU_ctl
	);
	
	//ALU_ctl	:	OPERATION
	//4'b0000	:	and	==>ReadData1&ReadData2
	//4'b0001	:	or		==>ReadData1|ReadData2
	//4'b0010	:	add	==>ReadData1+ReadData2(Immediate_in)
	//4'b0110	:	sub	==>ReadData1-ReadData2
	//4'b0111 	:	blt (branch if less than)
	//4'b1000 	:	bge (branch if greater equal)     // blt,bge   zero=1            ؼ  out=0          
	//4'b1100 	:	nor	==> ~(ReadData1|ReadData2)
	//4'b1001 	:	shift left
	//4'b1010 	:	shift right
	
	always @(*) begin
		casex ({ALUop,funct3,funct7})
			12'b00_xxx_xxxxxxx :	ALU_ctl	=	4'b0010;	// lb, lh, lw, sb, sh, sw 	=> ADDITION
			12'b01_00x_xxxxxxx : ALU_ctl	=	4'b0110;	// beq, bne 					=> SUBTRACT (funct3==3'b000)	||	(funct3==3'b001)
			12'b01_100_xxxxxxx :	ALU_ctl	=	4'b0111;	// blt							=> BLT(branch if less than) (funct3==3'b100)
			12'b01_101_xxxxxxx :	ALU_ctl	=	4'b1000;	// bge							=> BGE(branch if greater than) (funct3==3'b101)
			12'b10_000_0000000 :	ALU_ctl	=	4'b0010;	// add							=> ADDITION (funct3==3'b000 && funct7==7'b0000000)
			12'b10_000_0100000 :	ALU_ctl	=	4'b0110;	// sub							=> SUBTRACT (funct3==3'b000 && funct7==7'b0100000)
			12'b10_111_0000000 :	ALU_ctl	=	4'b0000;	// and							=> AND (funct3==3'b111 && funct7==7'b0000000)
			12'b10_110_0000000 :	ALU_ctl	=	4'b0001;	// or								=> OR (funct3==3'b110 && funct7==7'b0000000)
			12'b10_001_0000000 : ALU_ctl  = 	4'b1001;	// sll							=> SHIFT_LEFT (funct3==3'b001)
			12'b10_101_0000000 : ALU_ctl  = 	4'b1010;	// srl							=> SHIFT_RIGHT (funct3==3'b101)
			12'b11_000_xxxxxxx :	ALU_ctl  = 	4'b0010; // addi, jalr					=> ADDITION (funct3==3'b000)
			12'b11_111_xxxxxxx :	ALU_ctl  = 	4'b0000; // andi							=> AND (funct3==3'b111)	
			12'b11_001_0000000 :	ALU_ctl  = 	4'b1001; // slli							=> SHIFT_LEFT (funct3==3'b001)
			12'b11_101_0000000 :	ALU_ctl  = 	4'b1010; // srli							=> SHIFT_RIGHT (funct3==3'b101)
			default : ALU_ctl = 4'bx;
		endcase
	end

									
endmodule

//////////////////////////////////////////////////////////////////////////////////
module ALU(
	input [3:0] ALU_ctl,
	input signed [31:0] in1, in2,
	output reg [31:0] out, 
	output zero
	);
	
	always @(*) begin
		case (ALU_ctl)
			4'b0000 :	out = in1 & in2;				// and
			4'b0001 :	out = in1 | in2;				// or
			4'b0010 :	out = in1 + in2;				// add
			4'b0110 :	out = in1 - in2;				// sub
			4'b0111 :	out = (in1<in2) ? 0 : 1;	// blt (branch if less than)
			4'b1000 :	out = (in1>=in2) ? 0 : 1;	// bge (branch if greater equal) 
																// blt,bge   zero=1            ؼ  out=0          
			4'b1100 :	out = ~ (in1 || in2);			// nor
			4'b1001 :	out = in1 << in2[4:0]; 				// shift left
			4'b1010 :	out = in1 >> in2[4:0]; 			// shift right
			default :	out = 32'b0;
		endcase
	end
						
	assign zero = 	~|out;	//(ALU_ctl == 4'b0110) 			/ zero   beq,bne Ȯ       
									//(ALU_ctl == 4'b0111&1000) 	/blt,bge ==> mem stage     zero   branch signal   branch            .
endmodule

module Memory( 
	input 	rst, clk, 
	// control signal
	input 		Ctl_MemtoReg_in, 	Ctl_RegWrite_in, 	Ctl_MemRead_in, 	Ctl_MemWrite_in, 	Ctl_Branch_in,
	output reg	Ctl_MemtoReg_out, Ctl_RegWrite_out,
	// bypass
	input			is_stack,
	input 		[ 4:0] Rd_in,
	output reg 	[ 4:0] Rd_out,
	//
	input 				 jal_in, jalr_in, // ߰  jal
	input 				 Zero_in,
	input 		[31:0] Write_Data, ALUresult_in, Address_in, PC_in,
	output 				 PCSrc,
	
	output reg			 jal_out, jalr_out, // ߰  jal
	output reg	[31:0] Read_Data, ALUresult_out, PC_out,
	output 		[31:0] Address_out
   );
	parameter 			 RAM_size = 1000;
	reg 			[31:0] RAM [0:RAM_size-1];
	
	parameter			 stack_size = 1000;
	reg			[31:0] stack [0:stack_size-1];
	
	wire branch;
	//Branch:[4]
	or(branch, jalr_in, jal_in, Zero_in);
	and(PCSrc, Ctl_Branch_in, branch);
	
	integer i;
	//DataMemory 
	initial begin
		for(i=0; i!=RAM_size; i=i+1) begin
			RAM[i] = 32'b0;
		end
		for (i=0; i!=stack_size; i=i+1) begin
			stack[i] = 32'b0;
		end
		$readmemh("../src/darksocv.ram.mem",RAM);
	end
	
	always @(posedge clk) begin  
		if (Ctl_MemWrite_in)
			if (is_stack)
				stack[ALUresult_in>>2] <= Write_Data;
			else
				RAM[ALUresult_in>>2] <= Write_Data;
		if (rst)
			Read_Data <= 0;
		else
			if (is_stack)
				Read_Data <= stack[ALUresult_in>>2];
			else
				Read_Data <= RAM[ALUresult_in>>2];
	end

	
	// MEM/WB reg 
	always @(posedge clk) begin
			Rd_out <= Rd_in;
			Ctl_MemtoReg_out <= Ctl_MemtoReg_in;
			Ctl_RegWrite_out <= Ctl_RegWrite_in;
			ALUresult_out <= ALUresult_in;
			
			jalr_out				<= (rst) ? 1'b0 : jalr_in;
			jal_out				<= (rst) ? 1'b0 : jal_in;
			PC_out				<= (rst) ? 1'b0 : PC_in;
	end
	assign Address_out = (jalr_in) ? ALUresult_in : Address_in;
endmodule


module WB(
	// control signal
	input 		Ctl_RegWrite_in, 	Ctl_MemtoReg_in,
	output reg 	Ctl_RegWrite_out,
	//
	input					 jal_in, jalr_in,
	input 		[31:0] PC_in, 
	input 		[ 4:0] Rd_in,
	input 		[31:0] ReadDatafromMem_in, ALUresult_in,
	output reg 	[ 4:0] Rd_out,
	output reg 	[31:0] WriteDatatoReg_out
	);	

	always @(*) begin 
		Rd_out <= (Ctl_RegWrite_in) ? Rd_in : 5'b0;
		Ctl_RegWrite_out <= Ctl_RegWrite_in;
		
		if (Ctl_MemtoReg_in) 			WriteDatatoReg_out <= ReadDatafromMem_in;
		else if (jalr_in || jal_in)	WriteDatatoReg_out <= PC_in + 4;
		else									WriteDatatoReg_out <= ALUresult_in;
		end 
endmodule
