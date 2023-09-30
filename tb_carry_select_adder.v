`timescale 1ns / 1ps

module tb_carry_select_adder;

	// Inputs
	reg [15:0] a;
	reg [15:0] b;
	reg carryin;

	// Outputs
	wire [15:0] s;
	wire carryout;
	integer i,j,error;

	// Instantiate the Unit Under Test (UUT)
	carry_select_adder uut (
		.a(a), 
		.b(b), 
		.carryin(carryin), 
		.s(s), 
		.carryout(carryout)
	);

	initial begin
		// Initialize Inputs
		a = 0;
		b = 0;
		error = 0;
		
		//for carryin=0
		carryin = 0;
		for(i=0;i<3000;i=i+1) begin
			for(j=0;j<3000;j=j+1) begin
				a = i; b = j;
				#10;
				if({carryout,s}!=(i+j)) error<=error+1;
			end
		end
		
		//for carryin=1
		carryin = 1;
		for(i=0;i<3000;i=i+1) begin
			for(j=0;j<3000;j=j+1) begin
				a = i; b = j;
				#10;
				if({carryout,s}!=(i+j+1)) error<=error+1;
			end
		end

	end
      
endmodule
