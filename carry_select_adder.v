`timescale 1ns / 1ps

module fulladder(a,b,cin,cout,sum);
	input a,b,cin;
	output cout,sum;
	
	assign cout = (a&b)|(cin&a)|(cin&b);
	assign sum = a^b^cin;
endmodule

module mux(i,j,sel,out);
	input i,j,sel;
	output reg out;
	
	always @(*) begin
		case(sel)
			0: out=i;
			1: out=j;
			default: out=1'bx;
		endcase
	end
endmodule

module set1(cin1,a0,b0,a1,b1,s0,s1,cout1);
	input cin1,a0,b0,a1,b1;
	output cout1,s0,s1;
	wire temp0;
	
	fulladder fa1(.a(a0),.b(b0),.cin(cin1),.cout(temp0),.sum(s0));
	fulladder fa2(.a(a1),.b(b1),.cin(temp0),.cout(cout1),.sum(s1));
endmodule

module set2(cin2,a2,b2,a3,b3,s2,s3,cout2);
	input cin2,a2,b2,a3,b3;
	output cout2,s2,s3;
	wire temp1_c2, temp1_c3, temp2_c2, temp2_c3;
	wire temp1_s2, temp1_s3, temp2_s2, temp2_s3;
	
	//for carry=0
	fulladder fa3(.a(a2),.b(b2),.cin(1'b0),.cout(temp1_c2),.sum(temp1_s2));
	fulladder fa4(.a(a3),.b(b3),.cin(temp1_c2),.cout(temp1_c3),.sum(temp1_s3));
	
	//for carry=1
	fulladder fa5(.a(a2),.b(b2),.cin(1'b1),.cout(temp2_c2),.sum(temp2_s2));
	fulladder fa6(.a(a3),.b(b3),.cin(temp2_c2),.cout(temp2_c3),.sum(temp2_s3));
	
	//for mux top&bottom
	mux x1(.i(temp1_c3),.j(temp2_c3),.sel(cin2),.out(cout2));
	
	//for sum
	mux x2(.i(temp1_s2),.j(temp2_s2),.sel(cin2),.out(s2));
	mux x3(.i(temp1_s3),.j(temp2_s3),.sel(cin2),.out(s3));
endmodule
	
module set3(cin3,a4,b4,a5,b5,a6,b6,s4,s5,s6,cout3);
	input cin3,a4,b4,a5,b5,a6,b6;
	output s4,s5,s6,cout3;
	wire temp1_c4, temp1_c5, temp1_c6, temp2_c4, temp2_c5, temp2_c6; 
	wire temp1_s4, temp1_s5, temp1_s6, temp2_s4, temp2_s5, temp2_s6;
	
	//for carry=0
	fulladder fa7(.a(a4),.b(b4),.cin(1'b0),.cout(temp1_c4),.sum(temp1_s4));
	fulladder fa8(.a(a5),.b(b5),.cin(temp1_c4),.cout(temp1_c5),.sum(temp1_s5));
	fulladder fa9(.a(a6),.b(b6),.cin(temp1_c5),.cout(temp1_c6),.sum(temp1_s6));
	
	//for carry=1
	fulladder fa10(.a(a4),.b(b4),.cin(1'b1),.cout(temp2_c4),.sum(temp2_s4));
	fulladder fa11(.a(a5),.b(b5),.cin(temp2_c4),.cout(temp2_c5),.sum(temp2_s5));
	fulladder fa12(.a(a6),.b(b6),.cin(temp2_c5),.cout(temp2_c6),.sum(temp2_s6));
	
	//for mux top&bottom
	mux x4(.i(temp1_c6),.j(temp2_c6),.sel(cin3),.out(cout3));
	
	//for sum
	mux x5(.i(temp1_s4),.j(temp2_s4),.sel(cin3),.out(s4));
	mux x6(.i(temp1_s5),.j(temp2_s5),.sel(cin3),.out(s5));
	mux x7(.i(temp1_s6),.j(temp2_s6),.sel(cin3),.out(s6));
	
endmodule

module set4(cin4,a7,b7,a8,b8,a9,b9,a10,b10,s7,s8,s9,s10,cout4);
	input cin4,a7,b7,a8,b8,a9,b9,a10,b10;
	output s7,s8,s9,s10,cout4;
	wire temp1_c7, temp1_c8, temp1_c9, temp1_c10, temp2_c7, temp2_c8, temp2_c9, temp2_c10; 
	wire temp1_s7, temp1_s8, temp1_s9, temp1_s10, temp2_s7, temp2_s8, temp2_s9, temp2_s10;
	
	//for carry=0
	fulladder fa13(.a(a7),.b(b7),.cin(1'b0),.cout(temp1_c7),.sum(temp1_s7));
	fulladder fa14(.a(a8),.b(b8),.cin(temp1_c7),.cout(temp1_c8),.sum(temp1_s8));
	fulladder fa15(.a(a9),.b(b9),.cin(temp1_c8),.cout(temp1_c9),.sum(temp1_s9));
	fulladder fa16(.a(a10),.b(b10),.cin(temp1_c9),.cout(temp1_c10),.sum(temp1_s10));
	
	//for carry=1
	fulladder fa17(.a(a7),.b(b7),.cin(1'b1),.cout(temp2_c7),.sum(temp2_s7));
	fulladder fa18(.a(a8),.b(b8),.cin(temp2_c7),.cout(temp2_c8),.sum(temp2_s8));
	fulladder fa19(.a(a9),.b(b9),.cin(temp2_c8),.cout(temp2_c9),.sum(temp2_s9));
	fulladder fa20(.a(a10),.b(b10),.cin(temp2_c9),.cout(temp2_c10),.sum(temp2_s10));
	
	//for mux top&bottom
	mux x8(.i(temp1_c10),.j(temp2_c10),.sel(cin4),.out(cout4));
	
	//for sum
	mux x9(.i(temp1_s7),.j(temp2_s7),.sel(cin4),.out(s7));
	mux x10(.i(temp1_s8),.j(temp2_s8),.sel(cin4),.out(s8));
	mux x11(.i(temp1_s9),.j(temp2_s9),.sel(cin4),.out(s9));
	mux x12(.i(temp1_s10),.j(temp2_s10),.sel(cin4),.out(s10));

endmodule

module set5(cin5,a11,b11,a12,b12,a13,b13,a14,b14,a15,b15,s11,s12,s13,s14,s15,cout5);
	input cin5,a11,b11,a12,b12,a13,b13,a14,b14,a15,b15;
	output s11,s12,s13,s14,s15,cout5;
	wire temp1_c11, temp1_c12, temp1_c13, temp1_c14, temp1_c15, temp2_c11, temp2_c12, temp2_c13, temp2_c14, temp2_c15; 
	wire temp1_s11, temp1_s12, temp1_s13, temp1_s14, temp1_s15, temp2_s11, temp2_s12, temp2_s13, temp2_s14, temp2_s15;
	
	//for carry=0
	fulladder fa21(.a(a11),.b(b11),.cin(1'b0),.cout(temp1_c11),.sum(temp1_s11));
	fulladder fa22(.a(a12),.b(b12),.cin(temp1_c12),.cout(temp1_c12),.sum(temp1_s12));
	fulladder fa23(.a(a13),.b(b13),.cin(temp1_c13),.cout(temp1_c13),.sum(temp1_s13));
	fulladder fa24(.a(a14),.b(b14),.cin(temp1_c14),.cout(temp1_c14),.sum(temp1_s14));
	fulladder fa25(.a(a15),.b(b15),.cin(temp1_c15),.cout(temp1_c15),.sum(temp1_s15));
	
	//for carry=1
	fulladder fa26(.a(a11),.b(b11),.cin(1'b1),.cout(temp2_c11),.sum(temp2_s11));
	fulladder fa27(.a(a12),.b(b12),.cin(temp2_c12),.cout(temp2_c12),.sum(temp2_s12));
	fulladder fa28(.a(a13),.b(b13),.cin(temp2_c13),.cout(temp2_c13),.sum(temp2_s13));
	fulladder fa29(.a(a14),.b(b14),.cin(temp2_c14),.cout(temp2_c14),.sum(temp2_s14));
	fulladder fa30(.a(a15),.b(b15),.cin(temp2_c15),.cout(temp2_c15),.sum(temp2_s15));
	
	//for mux top&bottom
	mux x13(.i(temp1_c15),.j(temp2_c15),.sel(cin5),.out(cout5));
	
	//for sum
	mux x14(.i(temp1_s11),.j(temp2_s11),.sel(cin5),.out(s11));
	mux x15(.i(temp1_s12),.j(temp2_s12),.sel(cin5),.out(s12));
	mux x16(.i(temp1_s13),.j(temp2_s13),.sel(cin5),.out(s13));
	mux x17(.i(temp1_s14),.j(temp2_s14),.sel(cin5),.out(s14));	
	mux x18(.i(temp1_s15),.j(temp2_s15),.sel(cin5),.out(s15));
	
endmodule

// 18 muxs, 30 fulladders

module carry_select_adder(
	input [15:0] a,b,
	input carryin,
	output [15:0] s,
	output carryout
);
wire carry_temp1, carry_temp2, carry_temp3, carry_temp4;

set1 t1(.cin1(carryin),.a0(a[0]),.b0(b[0]),.a1(a[1]),.b1(b[1]),.s0(s[0]),.s1(s[1]),.cout1(carry_temp1));
set2 t2(.cin2(carry_temp1),.a2(a[2]),.b2(b[2]),.a3(a[3]),.b3(b[3]),.s2(s[2]),.s3(s[3]),.cout2(carry_temp2));
set3 t3(.cin3(carry_temp2),.a4(a[4]),.b4(b[4]),.a5(a[5]),.b5(b[5]),.a6(a[6]),.b6(b[6]),.s4(s[4]),.s5(s[5]),.s6(s[6]),.cout3(carry_temp3));
set4 t4(.cin4(carry_temp3),.a7(a[7]),.b7(b[7]),.a8(a[8]),.b8(b[8]),.a9(a[9]),.b9(b[9]),.a10(a[10]),.b10(b[10]),.s7(s[7]),.s8(s[8]),.s9(s[9]),.s10(s[10]),.cout4(carry_temp4));
set5 t5(.cin5(carry_temp4),.a11(a[11]),.b11(b[11]),.a12(a[12]),.b12(b[12]),.a13(a[13]),.b13(b[13]),.a14(a[14]),.b14(b[14]),.a15(a[15]),.b15(b[15]),.s11(s[11]),.s12(s[12]),.s13(s[13]),.s14(s[14]),.s15(s[15]),.cout5(carryout));

endmodule
