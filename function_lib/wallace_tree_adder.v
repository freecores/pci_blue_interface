//===========================================================================
// $Id: wallace_tree_adder.v,v 1.2 2001-08-31 11:33:09 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  Demonstrate how to use a Wallace Tree Adder to convert
//             3 binary numbers which need to be added into 2 binary
//             numbers which need to be added ... without adding!
//
// This library is free software; you can distribute it and/or modify it
// under the terms of the GNU Lesser General Public License as published
// by the Free Software Foundation; either version 2.1 of the License, or
// (at your option) any later version.
//
// This library is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this library.  If not, write to
// Free Software Foundation, Inc.
// 59 Temple Place, Suite 330
// Boston, MA 02111-1307 USA
//
// Author's note about this license:  The intention of the Author and of
// the Gnu Lesser General Public License is that users should be able to
// use this code for any purpose, including combining it with other source
// code, combining it with other logic, translated it into a gate-level
// representation, or projected it into gates in a programmable or
// hardwired chip, as long as the users of the resulting source, compiled
// source, or chip are given the means to get a copy of this source code
// with no new restrictions on redistribution of this source.
//
// If you make changes, even substantial changes, to this code, or use
// substantial parts of this code as an inseparable part of another work
// of authorship, the users of the resulting IP must be given the means
// to get a copy of the modified or combined source code, with no new
// restrictions on redistribution of the resulting source.
//
// Separate parts of the combined source code, compiled code, or chip,
// which are NOT derived from this source code do NOT need to be offered
// to the final user of the chip merely because they are used in
// combination with this code.  Other code is not forced to fall under
// the GNU Lesser General Public License when it is linked to this code.
// The license terms of other source code linked to this code might require
// that it NOT be made available to users.  The GNU Lesser General Public
// License does not prevent this code from being used in such a situation,
// as long as the user of the resulting IP is given the means to get a
// copy of this component of the IP with no new restrictions on
// redistribution of this source.
//
// This code was developed using VeriLogger Pro, by Synapticad.
// Their support is greatly appreciated.
//
// NOTE:  I am not sure if a Carry-Save Adder is a Wallace Tree Adder,
//          or if a Wallace Tree Adder is a Carry-Save Adder.  Sorry.
//
// NOTE:  The idea of a 3-input Wallace Tree is very simple.
//          Start witb 3 N-Bit numbers to be added together.
//          You can do that with 2 full adders, resulting in
//            an N + 2 bit result.
//          But notice that in each bit location, there are 3
//            bits to be added.  There can be 0, 1, 2, or 3 bits
//            set to 1 in the 3 operands.
//          0, 1, 2, 3 can be represented as a 2-bit number!
//          It is possible to reduce the 3 numbers to 2 numbers
//            which later are added together to form the final sum.
//          And you can interate this trick to add up more numbers.
//
// NOTE:  A 3:2 Compression Adder seems to have a simple truth table.
//          A  B  C  Carry Data
//          0  0  0    0     0
//          0  0  1    0     1
//          0  1  0    0     1
//          1  0  0    0     1
//          0  1  1    1     0
//          1  0  1    1     0
//          1  1  0    1     0
//          1  1  1    1     1
//        Look familiar?  It's a full adder!
//
// NOTE:  You could also add up to 7 numbers together by considering
//          each bit location by itself, and using 3 binary weighted
//          result bits to encode the 0 to 7 bits set in the inputs.
//        You would then have to add the 3 numbers together to get the
//          final result.
//
// NOTE:  Reducing 3 numbers to 2 is done by a 3:2 Compression Adder.
//          It also seems to be called a Carry-Save adder.
//        Reducing 7 numbers to 3 is done by a 7:3 Compression Adder.
//
// NOTE:  What if you want to add 4 numbers together?  You might use
//          the 7:3 compression adder.  Too easy!
//        Instead, you can do a trick.  In each bit column, you can
//          have a carry out which goes to the next column.
//        Each bit column has 4 inputs plus the carry in from it's right.
//        Each bit column has 2 outputs plus the carry out to it's left.
//        Ignoring the Carry In for a second, there can be 0, 1, 2, 3, or 4
//          bits set in each bit location amongst the 4 numbers begin added.
//        The outputs of the block have weight 2 for carry, then 1 for data.
//          That gives enough bits to represent 0, 1, 2, or 3 bits set.
//        If 4 bits are set, you have to generate a carry to the next
//          higher bit column.  But since each bit in column N+1 represents
//          2 times as much as the bits in column N, you can only send
//          carries representing carries by 2 over there.
//        In bit column N+1, if you get a carry in, that is the same
//          as having a 5th input.  Now you have to represent 0 .. 5.
//        Again, with 2 binary weighted output bits, you can only
//          represent 0, 1, 2, or 3.  To get 4 and 5, you have to
//          send a carry to the NEXT higher bit.  But notice that
//          you have to send a carry indicating an excess of 2 bits
//          set in the 5 inputs.  Fortunately, 5 = 3 + 2, so you
//          can represent all the values you need.
//
// NOTE:  This can be written up as a truth table.
//        The first column is the number of 1 bits set in the 4 input
//          numbers.  The second column is the carry in from the bit
//          column to the right  (LSB).  The third column is the carry
//          out to the bit column to the left (MSB).  The next column
//          is the carry out to the final adder, and the last column is
//          the data bit to the final adder.  A 4:2 Compression Adder:
//
//         Num_Set   Carry_In  Carry_Out    Carry   Sum
//            0          0         0          0      0    // 0
//            1          0         0          0      1    // 1
//            2          0         0          1      0    // 2 (*)
//            3          0         1          0      1    // 1 + 2 carried to next bit  
//            4          0         1          1      0    // 2 + 2 carried to next bit      
//            0          1         0          0      1    // 1
//            1          1         0          1      0    // 2
//            2          1         0          1      1    // 3 (*) 
//            3          1         1          1      0    // 2 + 2 carried to next bit    
//            4          1         1          1      1    // 3 + 2 carried to next bit   
//
//        The two rows with (*) can have Carry_Out set instead of Carry, as long
//          as the two rows are the same.
//        This truth table has the feature that Carry_Out is NOT a function
//          of Carry_In.  It strictly depends on Num_Set.  So a giant array
//          of these 4:2 Compressor Adders do not result in a ripple carry.
//
// NOTE:  All that seems complicated.
//        An extremely simple way to look at this is to consider the inputs
//          A, B, and C as going into a 3:2 Compression Adder.  The Carry output
//          is sent to the next bit column as Carry_out.
//        The Data Output from the ABC adder plus the D input plus the Carry_in
//          input are sent to a second 3:2 Compression Adder.  The outputs of
//          that second adder are the Carry and Data output for the 4:2
//          Compression Adder.
//        This circuit makes it clear that a ripple carry can't occur.  The
//          Carry_out is only a function of A, B, and C.  The Carry_in
//          signal combines with the D input and the Data_out from the ABC
//          adder, resulting in the final Carry and Data signals.
//
// NOTE:  If the 4:2 Compression Adder is implemented as 2 cascaded 3:2 Compression
//          Adders, a new truth table is used.  It's actually the SAME truth table,
//          except the (*) terms are chosen to use BOTH encodings when appropriate.
//
//         ABC_Set   Carry_Out    D   Carry_In  Carry   Sum
//            0          0        0       0       0      0    // 0
//            1          0        0       0       0      1    // 1
//            2          1        0       0       0      0    // 2 (*)
//            3          1        0       0       0      1    // 1 + 2 carried to next bit  
//            0          0        1       0       0      1    // 1
//            1          0        1       0       1      0    // 2 (*)
//            2          1        1       0       0      1    // 1 + 2 carried to next bit  
//            3          1        1       0       1      0    // 2 + 2 carried to next bit 
//            0          0        0       1       0      1    // 1
//            1          0        0       1       1      0    // 2
//            2          1        0       1       0      1    // 3 (*) 
//            3          1        0       1       1      0    // 2 + 2 carried to next bit 
//            0          0        1       1       1      0    // 2
//            1          0        1       1       1      1    // 3 (*) 
//            2          1        1       1       1      0    // 2 + 2 carried to next bit
//            3          1        1       1       1      1    // 3 + 2 carried to next bit
//
// NOTE:  So what if you want to add more numbers together than just 3?  Say 9!
//        You can iterate this idea.  You can use a 3:2 Compression Adder to
//          reduce each group of 3 operands to 2.  You have 6 numbers remaining
//          to add.
//        You can take each group of 3 numbers from that 6 and apply another
//          3:2 Compression Adder to it, resulting in a total of 4 numbers to add.
//        You can then do the tricky 4:2 Compression Adder to get down to 2 numbers.
//        Finally, use the best adder you have to add up the last 2 numbers.
//
// NOTE:  You might instead use 2 4:2 Compression Adders to drop the original
//          9 numbers to 2 + 2 + 1.  Then use another 4:2 Compression Adder
//          to get down to 2 + 1 operands.  Use a 3:2 Compression Adder, and
//          a final fast adder to add up the last 2 numbers.
//
// NOTE:  When using the outputs of one set of Compression Adders as inputs
//          to another set of Compression Adders, make sure that the bits
//          with corresponding weights are added together.
//        It seems that using 3:2 Compression Adders results in long lines
//          as the layers of adders are hooked together, while 4:2 Compression
//          Adders hook up regularly.  I don't know if this is actually true.
//
// NOTE:  A 3:2 Compression Adder would fit in a CLB easily.
//        A 4:2 Compression Adder would not fit.  Too many outputs.
//
//===========================================================================

`timescale 1ns/1ps

// NOTE:  This might be in a vendor-supplied library element.
module compression_adder_3_2_slice_private (
  A_in, B_in, C_in,
  Data_out, Carry_out
);
  input   A_in;
  input   B_in;
  input   C_in;
  output  Data_out;
  output  Carry_out;

  assign  Data_out = A_in ^ B_in ^ C_in;
  assign  Carry_out = (A_in & B_in) | (A_in & C_in) | (B_in & C_in);
endmodule

// A 4:2 Compression Adder seems more complicated.  One way to look at it
//   is as 2 cascaded 3:2 Compression Adders.  Is this the minimum logic way?

module compression_adder_4_2_slice_private (
  A_in, B_in, C_in, D_in, Carry_in_right,
  Data_out, Carry_out, Carry_out_left
);
  input   A_in, B_in, C_in;
  output  Data_out, Carry_out, Carry_out_left;

// First 3:2 Compression Adder
  wire    E_in = A_in ^ B_in ^ C_in;  // latest I think
  assign  Carry_out_left = (A_in & B_in) | (A_in & C_in) | (B_in & C_in);

// Second 3:2 Compression Adder
  assign  Data_out = E_in ^ (D_in ^ Carry_in_right);  // parens for speed?
  assign  Carry_out = (E_in & (D_in | Carry_in_right)) | (D_in & Carry_in_right);
endmodule

// NOTE:  WORKING:
module wallace_tree_adder_3_2 (
  A_in, B_in, C_in,
  Data_out
);
  parameter OPERAND_WIDTH = 0;

  input  [OPERAND_WIDTH - 1 : 0] A_in;
  input  [OPERAND_WIDTH - 1 : 0] B_in;
  input  [OPERAND_WIDTH - 1 : 0] C_in;
  output [OPERAND_WIDTH + 1 : 0] Data_out;

  assign  Data_out[OPERAND_WIDTH - 1 : 0] = A_in[OPERAND_WIDTH - 1 : 0]
                                       + B_in[OPERAND_WIDTH - 1 : 0];  // just kidding!
  assign  Carry_out[OPERAND_WIDTH : 1] = C_in[OPERAND_WIDTH - 1 : 0];
endmodule

// NOTE:  WORKING:
module wallace_tree_adder_4_2 (
  A_in, B_in, C_in, D_in,
  Data_out
);
  parameter OPERAND_WIDTH = 0;

  input  [OPERAND_WIDTH - 1 : 0] A_in;
  input  [OPERAND_WIDTH - 1 : 0] B_in;
  input  [OPERAND_WIDTH - 1 : 0] C_in;
  input  [OPERAND_WIDTH - 1 : 0] D_in;
  output [OPERAND_WIDTH + 1 : 0] Data_out;

  assign  Y_out[OPERAND_WIDTH - 1 : 0] = A_in[OPERAND_WIDTH - 1 : 0]
                                       + B_in[OPERAND_WIDTH - 1 : 0];  // just kidding!
  assign  Z_out[OPERAND_WIDTH - 1 : 0] = C_in[OPERAND_WIDTH - 1 : 0]
                                       + D_in[OPERAND_WIDTH - 1 : 0];  // just kidding!
endmodule

