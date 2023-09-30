`timescale 1ns / 1ps

module fp_dot(
	input				[127:0]in_a,
	input				[127:0]in_b,
	input				clk, n_rst,
	output reg		[31:0]out_c
    );
	 
	reg				[31:0]a[0:3];
	reg				[31:0]b[0:3];
	integer			j;
	
	wire				[31:0]c[0:3];
	wire				[31:0]c01, c23, result;

// initialize a, b;	
// divide input into 4 parts
always @ (posedge clk or negedge n_rst) begin
	if(!n_rst) begin
		for(j=0;j<4;j=j+1) begin
			a[j] = 0;
			b[j] = 0;
		end
	end else begin
		for(j=0;j<4;j=j+1) begin
			a[j] = in_a[32*j+:31];
			b[j] = in_b[32*j+:31];
		end
	end
end

// apply FP multiplier (using booth algorithm)
genvar i;
generate
	for(i=0;i<4;i=i+1) begin : multiplication
		fp_mul mul(clk, n_rst, a[i], b[i], c[i]);
	end
endgenerate

// apply FP adder
fp_add add1(clk, n_rst, c[0], c[1], c01);
fp_add add2(clk, n_rst, c[2], c[3], c23);
fp_add add3(clk, n_rst, c01, c23, result);

// initialize out_c
// transfer result to out_c
always @ (posedge clk or negedge n_rst) begin
	if(!n_rst) begin
		out_c <= 0;
	end
	else begin
		out_c <= result;
	end
end

endmodule

/////////////////////////////////////////

// FP multiplier
module fp_mul(clk, n_rst, x, y, z);
	input			clk, n_rst;
	input			[31:0]x,y;
	output reg	[63:0]z;
	
	reg			sign;
	reg			[7:0]exp_sum;
	reg			[22:0]man_mul;
	
	reg			[24:0]M_i, Q_i;
	reg			[49:0]P_i, M_temp, Q_temp;
	reg			[3:0]temp;
	reg			[47:0]P;
	integer		i;
	
	
	always @ (posedge clk or negedge n_rst) begin
		if(!n_rst) begin
			exp_sum <= 0;
			sign <= 0;
		end else begin
			exp_sum <= x[30:23] + y[30:23] - 127; // add exponents
			sign <= x[31] ^ y[31]; // determine sign bit
		end
	end
	
	// multiply mantissa using booth's algorithm
	always @ (*) begin
		M_i = {2'b01, x[22:0]};
		Q_i = {2'b01, y[22:0]};
		P_i = 50'b0;
		M_temp = 0;
		Q_temp = {Q_i, 1'b0};
		
		for(i=0;i<=24;i=i+3) begin
			temp = Q_temp[3:0];
			case(temp)
				4'b0000:M_temp=0;
				4'b0001:M_temp=M_i;
				4'b0010:M_temp=M_i;
				4'b0011:M_temp=M_i<<1;
				4'b0100:M_temp=M_i<<1;
				4'b0101:M_temp=(M_i<<1)+M_i;
				4'b0110:M_temp=(M_i<<1)+M_i;
				4'b0111:M_temp=M_i<<2;
				4'b1000:M_temp=-(M_i<<2);
				4'b1001:M_temp=-((M_i<<1)+M_i);
				4'b1010:M_temp=-((M_i<<1)+M_i);
				4'b1011:M_temp=-(M_i<<1);
				4'b1100:M_temp=-(M_i<<1);
				4'b1101:M_temp=-M_i;
				4'b1110:M_temp=-M_i;
				4'b1111:M_temp=0;
			endcase
			
			Q_temp = Q_temp >> 3; // right shift (3-bit) after each operation
			M_temp = M_temp << i; // left shift (3-bit) after each operation
			P_i = P_i + M_temp; // partial product
		end
		P = P_i[47:0];
		
		//normalization
		if(P[47] == 1'b1) begin
			man_mul = P[46:24];
			exp_sum = exp_sum + 1;
		end else begin
			man_mul = P[45:23];
		end
	end
	
	// initialize z
	// transfer (sign, exp_sum, man_mul) to z
	always @ (posedge clk or negedge n_rst) begin
		if(!n_rst) begin
			z <= 0;
		end else begin
			z[31] 	<= sign;
			z[30:23] <= exp_sum;
			z[22:0]	<= man_mul;
		end
	end

endmodule 

// FP adder

module fp_add(clk, n_rst, u, v, w);
	input			clk, n_rst;
	input			[31:0]u, v;
	output reg	[31:0]w;
	
	wire		sign_u_1, sign_v_1;
	wire		[7:0]exp_u, exp_v;
	wire		[24:0]man_u, man_v;
	wire		[24:0]man_1_1, man_s;
	wire		[24:0]man_s_sr_1;
	wire		[7:0]exp_1_1, exp_s_1;
	wire		sign_max_1;
	
	reg		[7:0]exp_2;
	reg		sign_u_2, sign_v_2;
	reg		sign_max_2;
	wire		[25:0]v_ALU_result;
	
	reg		[24:0]man_s_sr_2, man_1_2;
	reg		[7:0]exp_3, exp_norm, exp_round;
	reg		[25:0]man_3, man_norm, man_round;
	reg		sign_max_3;
	
	integer 	i;
	
	//stage1 operation
	assign sign_u_1	= u[31];		assign sign_v_1	= v[31];
	assign exp_u		= u[30:23];	assign exp_v		= v[30:23];
	assign man_u		= {1'b1, u[22:0], 1'b0}; // MSB: bit for the 1+fraction, LSB: bit for the rounding
	assign man_v		= {1'b1, v[22:0], 1'b0};
	
	//compare exponent and determine Big ALU input
	assign man_1_1		=	(exp_u > exp_v) ? man_u:
								(exp_u < exp_v) ? man_v:
								(exp_u == exp_v) ? man_u: 25'bx;
	assign man_s		=	(exp_u < exp_v) ? man_u:
								(exp_u > exp_v) ? man_v:
								(exp_u == exp_v) ? man_v: 25'bx;
								
	//choose the larger exponent
	assign exp_1_1		=	(exp_u >= exp_v) ? exp_u:
								(exp_u < exp_v) ? exp_v: 8'bx;
	assign exp_s_1		=	(exp_u <= exp_v) ? exp_u:
								(exp_u > exp_v) ? exp_v: 8'bx;
								
	//shift right smaller
	assign man_s_sr_1	=	man_s >> (exp_1_1 - exp_s_1);

	//choose the larger sign bit
	assign sign_max_1 = 	(exp_u >= exp_v) ? sign_u_1:
								(exp_u < exp_v) ? sign_v_1: 1'bx;
								
	//pipeline
	always @ (posedge clk or negedge n_rst) begin
		if(!n_rst) begin
			exp_2 <= 0;
			man_s_sr_2 <= 0;	man_1_2 <= 0;
			sign_u_2 <= 0;		sign_v_2 <= 0;		sign_max_2 <= 0;
		end else begin
			exp_2 <= exp_1_1;
			man_s_sr_2 <= man_s_sr_1;	man_1_2 <= man_1_1;
			sign_u_2 <= sign_u_1;	sign_v_2 <= sign_v_1;	sign_max_2 <= sign_max_1;
		end
	end
	
	//stage2 operation
		// if two sign bits are equal, add the two mantissas
		// if two sign bits are not equal, subtract the smaller mantissa from the larger mantissa
		assign v_ALU_result = (sign_u_2 == sign_v_2) ? man_s_sr_2 + man_1_2:
									 (sign_u_2 != sign_v_2)&&(man_s_sr_2 > man_1_2) ? man_s_sr_2 - man_1_2: man_1_2 - man_s_sr_2;
									 
	//pipeline
	always @ (posedge clk or negedge n_rst) begin
		if(!n_rst) begin
			man_3 <= 0;					exp_3 <= 0;			sign_max_3 <= 0;
		end else begin
			man_3 <= v_ALU_result;	exp_3 <= exp_2;	sign_max_3 <= sign_max_2;
		end
	end
	
	//stage3 operation
	//normalization
	always @ (*) begin
		//normalization when overflow
		if (man_3[25] == 1'b1) begin
			man_norm = man_3 >> 1'b1;
			exp_norm = exp_3 + 1'b1;
			//rounding
			//overflow due to rounding
			if (man_norm == 26'b01_11111111_11111111_11111111) begin
				man_round = 26'b01_00000000_00000000_00000000;
				exp_round = exp_norm + 1'b1;
			end
			//no overflow after rounding
			else begin
				//rounding to nearest even number
				if(man_norm[1:0] == 2'b11) begin
					man_round = man_norm + 1'b1;
					exp_round = exp_norm;
				end else begin
					man_round = {man_norm[25:1], 1'b0};
					exp_round = exp_norm;
				end
			end
		end
		//normalization when no overflow
		else begin 
			man_norm = man_3;
			exp_norm = exp_3;
			for(i=0; ((i<=24)&&(man_norm[24] == 1'b0)&&(man_norm[25:1] != 26'b0)); i=i+1) begin
				man_norm = man_norm << 1'b1;
				exp_norm = exp_norm - 1'b1;
			end
			//rounding process
			//overflow due to rounding
			if (man_norm == 26'b01_11111111_11111111_11111111) begin
				man_round = 26'b01_00000000_00000000_00000000;
				exp_round = exp_norm + 1'b1;
			end	
			//no overflow after rounding
			else begin
				//rounding to nearest even number
				if(man_norm[1:0] == 2'b11) begin
					man_round = man_norm + 1'b1;
					exp_round = exp_norm;
				end else begin
					man_round = {man_norm[25:1], 1'b0};
					exp_round = exp_norm;
				end
			end
		end
	end
	
	//pipeline
	always @ (posedge clk) begin
		w[31] <= sign_max_3;
		w[30:23] <= exp_round;
		w[22:0] <= man_round[23:1];
	end
	
endmodule
