//===========================================================================
// $Id: crc32_lib.v,v 1.7 2001-08-23 11:42:59 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  Calculate CRC-32 checksums by applying 8, 16, 32, and 64 bits of
//             new data.
//           CRC-32 needs to start out with a value of all F's.
//           When CRC-32 is applied to a block which ends with the CRC-32 of the
//             block, the resulting CRC-32 checksum is always 32'hCBF43926.
//
// NOTE:  The verilog these routines is started from scratch.  A new user might
//          want to look at a wonderful paper by Ross Williams, which seems to
//          be at ftp.adelaide.edu.au:/pub/rocksoft/crc_v3.txt
//        Also see http://www.easics.be/webtools/crctool
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
// NOTE:  I am greatly confused about the order in which the CRC should be
//          sent over the wire to a remote machine.  Bit 0 first?  Bit 31 first?
//          True or compliment values?  The user has got to figure this out in
//          order to interoperate with existing machines.
//
// NOTE:  Bit order matters in this code, of course.  The existing code on
//          the net assumes that when you present a multi-bit word to a parallel
//          CRC generator, the MSB corresponds to teh earliest data to arrive
//          across a serial interface.  Fine.  Go with it.
// NOTE:  The code also assumes that the data shifts into bit 0 of the shift
//          register, and shifts out of bit 31.  Fine.  Go with it.
//
// NOTE:  The math for the CRC-32 is beyond me.
//
// NOTE:  But they are pretty easy to use.
//          You initialize a CRC to a special value to keep from missing
//            initial 0 bytes.  That is 32'hFFFFFFFF for CRC-32.
//          You update a CRC as data comes in.
//          You append the calculated CRC to the end of your message.
//            You have to agree on logic sense and bit order with the
//            receiver, or everything you send will seem wrong.
//          The receiver calculates a CRC the same way, but receives a
//            message longer than the one you sent, due to the added CRC.
//          After the CRC is processed by the receiver, you either compare
//            the calculated CRC with the sent one, or look for a magic
//            final value which indicates that the message had no errors.
//
// NOTE:  Looking on the web, one finds a nice tutorial by Cypress entitled
//          "Parallel Cyclic Redundancy Check (CRC) for HOTLink(TM)".
//        This reminds me of how I learned to do this from a wonderful
//          CRC tutorial on the web, done by Ross N. Williams.
//
// NOTE:  The CRC-32 polynomial is:
//            X**0 + X**1 + X**2 + X**4 + X**5 + X**7 + X**8 + X**10
//          + X**11 + X**12 + X**16 + X**22 + X**23 + X**26 + X**32
//        You initialize it to the value 32'hFFFFFFFF
//        You append it to the end of the message.
//        The receiver sees the value 32'hC704DD7B when the message is
//          received no errors.  Bit reversed, that is 32'hDEBB20E3.
//        NOTE Some other DOCS SAY 32'hCBF43926!!!
//
//        That means that each clock a new bit comes in, you have to shift
//          all the 32 running state bits 1 bit higher and drop the MSB.
//          PLUS you have to XOR in (new bit ^ bit 31) to locations
//          0, 1, 2, 4, 5, 7, 8, 10, 11, 12, 16, 22, 23, and 26.
//
//        That is simple but slow.  If you keep track of the bits, you can
//          see that it might be possible to apply 1 bit, shift it, apply
//          another bit, shift THAT, and end up with a new formula of how
//          to update the shift register based on applyig 1 bits at once.
//
//        That is the general plan.  Figure out how to apply several bits
//          at a time.  Write out the big formula, then simplify it if possible.
//          Apply the bits, shift several bit locations at once, run faster.
//
//        But what are the formulas?  Good question.  Use a computer to figure
//          this out for you.  And Williams wrote a program!
//
// NOTE:  The idea is simple, so I may include one I wrote here too.  
//
//===========================================================================

`timescale 1ns/1ps

// Look up the CRC-32 polynomial on the web.
// The LSB corresponds to bit 0, the new input bit.
`define CRC           32'b0000_0100_1100_0001_0001_1101_1011_0111
`define CHECK_VALUE   32'b1100_1011_1111_0100_0011_1001_0010_0110
`define NUMBER_OF_BITS_IN_CRC   32

// Given a 32-bit CRC-32 running value, update it using 8 new bits of data.
// The way to make this fast is to find common sub-expressions.
//
// The user needs to supply external flops to make this work.

module crc_32_8_private (
  use_F_for_CRC,
  present_crc,
  data_in_8,
  next_crc
);
  input   use_F_for_CRC;
  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [7:0] data_in_8;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

  wire    X7, X6, X5, X4, X3, X2, X1, X0;
  assign  {X7, X6, X5, X4, X3, X2, X1, X0} = data_in_8[7:0]
                                           ^ (present_crc[31:24] | {8{use_F_for_CRC}});

  wire    C23, C22, C21, C20, C19, C18, C17, C16;
  wire    C15, C14, C13, C12, C11, C10, C9, C8, C7, C6, C5, C4, C3, C2, C1, C0;
  assign  {C23, C22, C21, C20, C19, C18, C17, C16, C15, C14, C13, C12,
           C11, C10, C9,  C8,  C7,  C6,  C5,  C4,  C3,  C2,  C1,  C0} =
                                present_crc[`NUMBER_OF_BITS_IN_CRC - 8 - 1 : 0]
                              | {(`NUMBER_OF_BITS_IN_CRC - 8){use_F_for_CRC}};

  assign  next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
    { C23                          ^ X5          ,
      C22                     ^ X4           ^ X7,
      C21                ^ X3           ^ X6 ^ X7,
      C20           ^ X2           ^ X5 ^ X6     ,
      C19      ^ X1           ^ X4 ^ X5      ^ X7,
      C18 ^ X0           ^ X3 ^ X4      ^ X6     ,
      C17           ^ X2 ^ X3                    ,
      C16      ^ X1 ^ X2                     ^ X7,
      C15 ^ X0 ^ X1                     ^ X6     ,
      C14 ^ X0                                   ,
      C13                           ^ X5         ,
      C12                     ^ X4               ,
      C11                ^ X3                ^ X7,
      C10           ^ X2                ^ X6 ^ X7,
      C9       ^ X1                ^ X5 ^ X6     ,
      C8  ^ X0                ^ X4 ^ X5          ,
      C7                 ^ X3 ^ X4 ^ X5      ^ X7,
      C6            ^ X2 ^ X3 ^ X4      ^ X6 ^ X7,
      C5       ^ X1 ^ X2 ^ X3      ^ X5 ^ X6 ^ X7,
      C4  ^ X0 ^ X1 ^ X2      ^ X4 ^ X5 ^ X6     ,
      C3  ^ X0 ^ X1      ^ X3 ^ X4               ,
      C2  ^ X0      ^ X2 ^ X3      ^ X5          ,
      C1       ^ X1 ^ X2      ^ X4 ^ X5          ,
      C0  ^ X0 ^ X1      ^ X3 ^ X4               ,
            X0      ^ X2 ^ X3      ^ X5      ^ X7,
                 X1 ^ X2      ^ X4 ^ X5 ^ X6 ^ X7,
            X0 ^ X1      ^ X3 ^ X4 ^ X5 ^ X6 ^ X7,
            X0      ^ X2 ^ X3 ^ X4      ^ X6     ,
                 X1 ^ X2 ^ X3                ^ X7,
            X0 ^ X1 ^ X2                ^ X6 ^ X7,
            X0 ^ X1                     ^ X6 ^ X7,
            X0                          ^ X6
     };
endmodule

module crc_32_16_private (
  use_F_for_CRC,
  present_crc,
  data_in_16,
  next_crc
);
  input   use_F_for_CRC;
  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [15:0] data_in_16;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

/* State Variables depend on input bit number (bigger is earlier) :
{
31 : C15                           ^ X5           ^ X8       ^ X9                   ^ X11 ^ X15,
30 : C14                      ^ X4           ^ X7 ^ X8                  ^ X10 ^ X14            ,
29 : C13                 ^ X3           ^ X6 ^ X7            ^ X9 ^ X13                        ,
28 : C12            ^ X2           ^ X5 ^ X6      ^ X8 ^ X12                                   ,
27 : C11       ^ X1           ^ X4 ^ X5      ^ X7                                   ^ X11      ,
26 : C10  ^ X0           ^ X3 ^ X4      ^ X6                            ^ X10                  ,
25 : C9             ^ X2 ^ X3                     ^ X8                              ^ X11 ^ X15,
24 : C8        ^ X1 ^ X2                     ^ X7                       ^ X10 ^ X14            ,
23 : C7   ^ X0 ^ X1                     ^ X6                 ^ X9 ^ X13                   ^ X15,
22 : C6   ^ X0                                         ^ X12 ^ X9             ^ X14 ^ X11      ,
21 : C5                            ^ X5                      ^ X9 ^ X13 ^ X10                  ,
20 : C4                       ^ X4                ^ X8 ^ X12 ^ X9                              ,
19 : C3                  ^ X3                ^ X7 ^ X8                              ^ X11 ^ X15,
18 : C2             ^ X2                ^ X6 ^ X7                       ^ X10 ^ X14       ^ X15,
17 : C1        ^ X1                ^ X5 ^ X6                 ^ X9 ^ X13       ^ X14            ,
16 : C0   ^ X0                ^ X4 ^ X5           ^ X8 ^ X12      ^ X13                        ,
15 :  0                  ^ X3 ^ X4 ^ X5      ^ X7 ^ X8 ^ X12 ^ X9                         ^ X15,
14 :  0             ^ X2 ^ X3 ^ X4      ^ X6 ^ X7 ^ X8                        ^ X14 ^ X11 ^ X15,
13 :  0        ^ X1 ^ X2 ^ X3      ^ X5 ^ X6 ^ X7                 ^ X13 ^ X10 ^ X14            ,
12 :  0   ^ X0 ^ X1 ^ X2      ^ X4 ^ X5 ^ X6           ^ X12 ^ X9 ^ X13                   ^ X15,
11 :  0   ^ X0 ^ X1      ^ X3 ^ X4                     ^ X12 ^ X9             ^ X14       ^ X15,
10 :  0   ^ X0      ^ X2 ^ X3      ^ X5                      ^ X9 ^ X13       ^ X14            ,
 9 :  0        ^ X1 ^ X2      ^ X4 ^ X5                ^ X12 ^ X9 ^ X13             ^ X11      ,
 8 :  0   ^ X0 ^ X1      ^ X3 ^ X4                ^ X8 ^ X12            ^ X10       ^ X11      ,
 7 :  0   ^ X0      ^ X2 ^ X3      ^ X5      ^ X7 ^ X8                  ^ X10             ^ X15,
 6 :  0        ^ X1 ^ X2      ^ X4 ^ X5 ^ X6 ^ X7 ^ X8                        ^ X14 ^ X11      ,
 5 :  0   ^ X0 ^ X1      ^ X3 ^ X4 ^ X5 ^ X6 ^ X7                 ^ X13 ^ X10                  ,
 4 :  0   ^ X0      ^ X2 ^ X3 ^ X4      ^ X6      ^ X8 ^ X12                        ^ X11 ^ X15,
 3 :  0        ^ X1 ^ X2 ^ X3                ^ X7 ^ X8       ^ X9       ^ X10 ^ X14       ^ X15,
 2 :  0   ^ X0 ^ X1 ^ X2                ^ X6 ^ X7 ^ X8       ^ X9 ^ X13       ^ X14            ,
 1 :  0   ^ X0 ^ X1                     ^ X6 ^ X7      ^ X12 ^ X9 ^ X13             ^ X11      ,
 0 :  0   ^ X0                          ^ X6           ^ X12 ^ X9       ^ X10                  
}
*/
// There are 2 obvious ways to implement these functions:
// 1) XOR the State bits with the Input bits, then calculate the XOR's
// 2) Independently calculate a result for Inputs and State variables,
//    then XOR the results together.
// The second idea seems to take much more logic, but to have no benefit.

// Single numbered terms are calculated in 1 XOR time.
  wire    X15, X14, X13, X12, X11, X10, X9, X8, X7, X6, X5, X4, X3, X2, X1, X0;
  assign  {X15, X14, X13, X12, X11, X10, X9, X8, X7, X6, X5, X4, X3, X2, X1, X0} =
                            data_in_16[15 : 0]
                          ^ (   present_crc[31:16]
                              | {(`NUMBER_OF_BITS_IN_CRC - 16){use_F_for_CRC}});

// State Bits are shifted over by the width of the input, then XOR's into the X terms.
  wire    C15, C14, C13, C12, C11, C10, C9, C8, C7, C6, C5, C4, C3, C2, C1, C0;
  assign  {C15, C14, C13, C12, C11, C10, C9, C8, C7, C6, C5, C4, C3, C2, C1, C0} =
                                present_crc[`NUMBER_OF_BITS_IN_CRC - 16 - 1 : 0]
                              | {(`NUMBER_OF_BITS_IN_CRC - 16){use_F_for_CRC}};

// Calculate higher_order terms, to make parity trees.
// 2_numbered terms are calculated in 1 XOR times.
// NOTE: In a Xilinx chip, it would be fine to constrain X0 and X0_1 to
//       be calculated in the same CLB, and so on for all bits.
  wire    X0_1   = X0  ^ X1;     wire    X1_2   = X1  ^ X2;
  wire    X2_3   = X2  ^ X3;     wire    X3_4   = X3  ^ X4;
  wire    X4_5   = X4  ^ X5;     wire    X5_6   = X5  ^ X6;
  wire    X6_7   = X6  ^ X7;     wire    X7_8   = X7  ^ X8;
// Use odd-ordered XOR terms because it seems these might be useful
  wire    X8_12  = X8  ^ X12;    wire    X12_9  = X12 ^ X9;
  wire    X9_13  = X9  ^ X13;    wire    X13_10 = X13 ^ X10;
  wire    X10_14 = X10 ^ X14;    wire    X14_11 = X14 ^ X11;
  wire    X11_15 = X11 ^ X15;

// Calculate terms which might have a single use.  They are calculated here
//   so that the parity trees can be balanced.
  wire    C15_5  = C15 ^ X5;     wire    C14_4  = C14 ^ X4;
  wire    C13_3  = C13 ^ X3;     wire    C12_2  = C12 ^ X2;
  wire    C11_1  = C11 ^ X1;     wire    C10_0  = C10 ^ X0;
  wire    C9_8   = C9  ^ X8;     wire    C8_7   = C8  ^ X7;
  wire    C7_6   = C7  ^ X6;     wire    C6_0   = C6  ^ X0;
  wire    C5_5   = C5  ^ X5;     wire    C4_4   = C4  ^ X4;
  wire    C3_3   = C3  ^ X3;     wire    C2_2   = C2  ^ X2;
  wire    C1_1   = C1  ^ X1;     wire    C0_0   = C0  ^ X0;
// Some of these could be matched with other terms to share 1 input in a CLB.
  wire    X0_5   = X0  ^ X5;     wire    X0_6   = X0  ^ X6;
  wire    X2_6   = X2  ^ X6;     wire    X2_8   = X2  ^ X8;
  wire    X3_7   = X3  ^ X7;     wire    X3_9   = X3  ^ X9;
  wire    X4_8   = X4  ^ X8;
  wire    X5_15  = X5  ^ X15;   
  wire    X6_10  = X6  ^ X10; 
  wire    X7_11  = X7  ^ X11;
  wire    X8_9   = X8  ^ X9;
  wire    X10_11 = X10 ^ X11;    wire    X10_15 = X10 ^ X15;
  wire    X13_11 = X13 ^ X11;    wire    X13_15 = X13 ^ X15;
  wire    X14_15 = X14 ^ X15;

// NOTE: 5 terms can be implemented in a CLB, as long as the other Flop
//         doesn't use logic.  This would be perfect if the data_in_16
//         was registered as an input to the module in that CLB.
  assign  next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
    {
      (C15_5  ^ X8_9)   ^ X11_15,
      (C14_4  ^ X7_8)   ^ X10_14,
      (C13_3  ^ X6_7)   ^ X9_13,
      (C12_2  ^ X5_6)   ^ X8_12,
      (C11_1  ^ X4_5)   ^ X7_11,
      (C10_0  ^ X3_4)   ^ X6_10,
      (C9_8   ^ X2_3)   ^ X11_15,
      (C8_7   ^ X1_2)   ^ X10_14,
      (C7_6   ^ X0_1)   ^ (X9_13  ^ X15),
      (C6_0   ^ X12_9)  ^ X14_11,
      (C5_5   ^ X9_13)  ^ X10,
      (C4_4   ^ X8_12)  ^ X9,
      (C3_3   ^ X7_8)   ^ X11_15,
      (C2_2   ^ X6_7)   ^ (X14_15 ^ X10),
      (C1_1   ^ X5_6)   ^ (X9_13  ^ X14),
      (C0_0   ^ X4_5)   ^ (X8_12  ^ X13),
      (X3_4   ^ X5_15)  ^ (X7_8   ^ X12_9),
     ((X2_3   ^ X4_8)   ^ (X6_7   ^ X14_15)) ^ X11,
     ((X1_2   ^ X3_7)   ^ (X5_6   ^ X13_10)) ^ X14,
     ((X0_1   ^ X2_6)   ^ (X4_5   ^ X12_9))  ^ X13_15,
      (X0_1   ^ X3_4)   ^ (X12_9  ^ X14_15),
      (X0_5   ^ X2_3)   ^ (X9_13  ^ X14),
      (X1_2   ^ X4_5)   ^ (X12_9  ^ X13_11),
      (X0_1   ^ X3_4)   ^ (X8_12  ^ X10_11),
      (X0_5   ^ X2_3)   ^ (X7_8   ^ X10_15),
     ((X1_2   ^ X4_5)   ^ (X6_7   ^ X14_11)) ^ X8,
     ((X0_1   ^ X3_4)   ^ (X5_6   ^ X13_10)) ^ X7,
     ((X0_6   ^ X2_3)   ^ (X8_12  ^ X11_15)) ^ X4,
     ((X1_2   ^ X3_9)   ^ (X7_8   ^ X10_14)) ^ X15,
     ((X0_1   ^ X2_8)   ^ (X6_7   ^ X9_13))  ^ X14,
      (X0_1   ^ X6_7)   ^ (X12_9  ^ X13_11),
      (X0_6   ^ X12_9)  ^ X10                  
    };
endmodule

module crc_32_32_private (
  use_F_for_CRC,
  present_crc,
  data_in_32,
  next_crc
);
  input   use_F_for_CRC;
  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [31:0] data_in_32;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

/* State Variables depend on input bit number (bigger is earlier) :
{
                  ^ 5         ^ 8 ^ 9      ^ 11                ^ 15                                    ^ 23 ^ 24 ^ 25      ^ 27 ^ 28 ^ 29 ^ 30 ^ 31,
              ^ 4         ^ 7 ^ 8     ^ 10                ^ 14                                    ^ 22 ^ 23 ^ 24      ^ 26 ^ 27 ^ 28 ^ 29 ^ 30     ,
          ^ 3         ^ 6 ^ 7     ^ 9                ^ 13                                    ^ 21 ^ 22 ^ 23      ^ 25 ^ 26 ^ 27 ^ 28 ^ 29      ^ 31,
      ^ 2         ^ 5 ^ 6     ^ 8               ^ 12                                    ^ 20 ^ 21 ^ 22      ^ 24 ^ 25 ^ 26 ^ 27 ^ 28      ^ 30     ,
  ^ 1         ^ 4 ^ 5     ^ 7              ^ 11                                    ^ 19 ^ 20 ^ 21      ^ 23 ^ 24 ^ 25 ^ 26 ^ 27      ^ 29          ,
0         ^ 3 ^ 4     ^ 6             ^ 10                                    ^ 18 ^ 19 ^ 20      ^ 22 ^ 23 ^ 24 ^ 25 ^ 26      ^ 28           ^ 31,
      ^ 2 ^ 3                 ^ 8          ^ 11                ^ 15      ^ 17 ^ 18 ^ 19      ^ 21 ^ 22                          ^ 28 ^ 29      ^ 31,
  ^ 1 ^ 2                 ^ 7         ^ 10                ^ 14      ^ 16 ^ 17 ^ 18      ^ 20 ^ 21                          ^ 27 ^ 28      ^ 30     ,
0 ^ 1                 ^ 6         ^ 9                ^ 13      ^ 15 ^ 16 ^ 17      ^ 19 ^ 20                          ^ 26 ^ 27      ^ 29      ^ 31,
0                                 ^ 9      ^ 11 ^ 12      ^ 14      ^ 16      ^ 18 ^ 19                ^ 23 ^ 24      ^ 26 ^ 27      ^ 29      ^ 31,
                  ^ 5             ^ 9 ^ 10           ^ 13                ^ 17 ^ 18                ^ 22      ^ 24      ^ 26 ^ 27      ^ 29      ^ 31,
              ^ 4             ^ 8 ^ 9           ^ 12                ^ 16 ^ 17                ^ 21      ^ 23      ^ 25 ^ 26      ^ 28      ^ 30     ,
          ^ 3             ^ 7 ^ 8          ^ 11                ^ 15 ^ 16                ^ 20      ^ 22      ^ 24 ^ 25      ^ 27      ^ 29          ,
      ^ 2             ^ 6 ^ 7         ^ 10                ^ 14 ^ 15                ^ 19      ^ 21      ^ 23 ^ 24      ^ 26      ^ 28           ^ 31,
  ^ 1             ^ 5 ^ 6         ^ 9                ^ 13 ^ 14                ^ 18      ^ 20      ^ 22 ^ 23      ^ 25      ^ 27           ^ 30 ^ 31,
0             ^ 4 ^ 5         ^ 8               ^ 12 ^ 13                ^ 17      ^ 19      ^ 21 ^ 22      ^ 24      ^ 26           ^ 29 ^ 30     ,
          ^ 3 ^ 4 ^ 5     ^ 7 ^ 8 ^ 9           ^ 12           ^ 15 ^ 16      ^ 18      ^ 20 ^ 21           ^ 24           ^ 27           ^ 30     ,
      ^ 2 ^ 3 ^ 4     ^ 6 ^ 7 ^ 8          ^ 11           ^ 14 ^ 15      ^ 17      ^ 19 ^ 20           ^ 23           ^ 26           ^ 29          ,
  ^ 1 ^ 2 ^ 3     ^ 5 ^ 6 ^ 7         ^ 10           ^ 13 ^ 14      ^ 16      ^ 18 ^ 19           ^ 22           ^ 25           ^ 28           ^ 31,
0 ^ 1 ^ 2     ^ 4 ^ 5 ^ 6         ^ 9           ^ 12 ^ 13      ^ 15      ^ 17 ^ 18           ^ 21           ^ 24           ^ 27           ^ 30 ^ 31,
0 ^ 1     ^ 3 ^ 4                 ^ 9           ^ 12      ^ 14 ^ 15 ^ 16 ^ 17           ^ 20                ^ 24 ^ 25 ^ 26 ^ 27 ^ 28           ^ 31,
0     ^ 2 ^ 3     ^ 5             ^ 9                ^ 13 ^ 14      ^ 16           ^ 19                               ^ 26      ^ 28 ^ 29      ^ 31,
  ^ 1 ^ 2     ^ 4 ^ 5             ^ 9      ^ 11 ^ 12 ^ 13                     ^ 18                     ^ 23 ^ 24                     ^ 29          ,
0 ^ 1     ^ 3 ^ 4             ^ 8     ^ 10 ^ 11 ^ 12                     ^ 17                     ^ 22 ^ 23                     ^ 28           ^ 31,
0     ^ 2 ^ 3     ^ 5     ^ 7 ^ 8     ^ 10                     ^ 15 ^ 16                     ^ 21 ^ 22 ^ 23 ^ 24 ^ 25           ^ 28 ^ 29          ,
  ^ 1 ^ 2     ^ 4 ^ 5 ^ 6 ^ 7 ^ 8          ^ 11           ^ 14                          ^ 20 ^ 21 ^ 22           ^ 25                ^ 29 ^ 30     ,
0 ^ 1     ^ 3 ^ 4 ^ 5 ^ 6 ^ 7         ^ 10           ^ 13                          ^ 19 ^ 20 ^ 21           ^ 24                ^ 28 ^ 29          ,
0     ^ 2 ^ 3 ^ 4     ^ 6     ^ 8          ^ 11 ^ 12           ^ 15           ^ 18 ^ 19 ^ 20                ^ 24 ^ 25                ^ 29 ^ 30 ^ 31,
  ^ 1 ^ 2 ^ 3             ^ 7 ^ 8 ^ 9 ^ 10                ^ 14 ^ 15      ^ 17 ^ 18 ^ 19                          ^ 25      ^ 27                ^ 31,
0 ^ 1 ^ 2             ^ 6 ^ 7 ^ 8 ^ 9                ^ 13 ^ 14      ^ 16 ^ 17 ^ 18                          ^ 24      ^ 26                ^ 30 ^ 31,
0 ^ 1                 ^ 6 ^ 7     ^ 9      ^ 11 ^ 12 ^ 13           ^ 16 ^ 17                               ^ 24           ^ 27 ^ 28               ,
0                     ^ 6         ^ 9 ^ 10      ^ 12                ^ 16                                    ^ 24 ^ 25 ^ 26      ^ 28 ^ 29 ^ 30 ^ 31
}
*/
// There are 2 obvious ways to implement these functions:
// 1) XOR the State bits with the Input bits, then calculate the XOR's
// 2) Independently calculate a result for Inputs and State variables,
//    then XOR the results together.
// The second idea seems to take much more logic, but to have no benefit.

  wire    X31, X30, X29, X28, X27, X26, X25, X24, X23, X22, X21, X20;
  wire    X19, X18, X17, X16, X15, X14, X13, X12, X11, X10, X9, X8;
  wire    X7, X6, X5, X4, X3, X2, X1, X0;
  assign  {X31, X30, X29, X28, X27, X26, X25, X24, X23, X22, X21, X20,
           X19, X18, X17, X16, X15, X14, X13, X12, X11, X10, X9, X8,
           X7, X6, X5, X4, X3, X2, X1, X0} =
                                data_in_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]
                              ^ (   present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]
                                  | {`NUMBER_OF_BITS_IN_CRC{use_F_for_CRC}});
// Calculate higher_order terms, to make parity trees.
// NOTE: In a Xilinx chip, it would be fine to constrain X0 and X0_1 to
//       be calculated in the same CLB, and so on for all bits.
  wire    X0_1   = X0  ^ X1;     wire    X1_2   = X1  ^ X2;
  wire    X2_3   = X2  ^ X3;     wire    X3_4   = X3  ^ X4;
  wire    X4_5   = X4  ^ X5;     wire    X5_6   = X5  ^ X6;
  wire    X6_7   = X6  ^ X7;     wire    X7_8   = X7  ^ X8;
// Use odd-ordered XOR terms because it seems these might be useful
  wire    X8_12  = X8  ^ X12;    wire    X12_9  = X12 ^ X9;
  wire    X9_13  = X9  ^ X13;    wire    X13_10 = X13 ^ X10;
  wire    X10_14 = X10 ^ X14;    wire    X14_11 = X14 ^ X11;
  wire    X11_15 = X11 ^ X15;
// back to simple ordering
                                 wire    X15_16 = X15 ^ X16;
  wire    X16_17 = X16 ^ X17;    wire    X17_18 = X17 ^ X18;
  wire    X18_19 = X18 ^ X19;    wire    X19_20 = X19 ^ X20;
  wire    X20_21 = X20 ^ X21;    wire    X21_22 = X21 ^ X22;
  wire    X22_23 = X22 ^ X23;    wire    X23_24 = X23 ^ X24;
  wire    X24_25 = X24 ^ X25;    wire    X25_26 = X25 ^ X26;
  wire    X26_27 = X26 ^ X27;    wire    X27_28 = X27 ^ X28;
  wire    X28_29 = X28 ^ X29;    wire    X29_30 = X29 ^ X30;
  wire    X30_31 = X30 ^ X31;

// Calculate terms which might have a single use.  They are calculated here
//   so that the parity trees can be balanced.
  wire    X8_9   = X8 ^ X9;      wire    X29_31 = X29 ^ X31;
  wire    X28_30 = X28 ^ X30;    wire    X28_31 = X28 ^ X31;
  wire    X27_29 = X27 ^ X29;    wire    X4_6   = X4 ^ X6;
  wire    X7_11  = X7 ^ X11;     wire    X6_10  = X6 ^ X10;
  wire    X22_24 = X22 ^ X24;    wire    X21_23 = X21 ^ X23;
  wire    X20_22 = X20 ^ X22;    wire    X19_21 = X19 ^ X21;
  wire    X18_20 = X18 ^ X20;    wire    X17_19 = X17 ^ X19;
  wire    X24_27 = X24 ^ X27;    wire    X23_26 = X23 ^ X26;
  wire    X22_25 = X22 ^ X25;    wire    X21_24 = X21 ^ X24;

  wire    X20_26 = X20 ^ X26;    wire    X25_27 = X25 ^ X27;
  wire    X24_26 = X24 ^ X26;    wire    X18_30 = X18 ^ X30;
  wire    X15_17 = X15 ^ X17;    wire    X14_16 = X14 ^ X16;
  wire    X13_15 = X13 ^ X15;    wire    X13_11 = X13 ^ X11;
  wire    X10_11 = X10 ^ X11;    wire    X10_15 = X10 ^ X15;
  wire    X3_5  = X3 ^ X5;       wire    X2_4   = X2 ^ X4;
  wire    X3_9  = X3 ^ X9;       wire    X0_5  = X0 ^ X5;
  wire    X17_20 = X17 ^ X20;    wire    X16_19 = X16 ^ X19;
  wire    X16_21 = X16 ^ X21;    wire    X15_19 = X15 ^ X19;
  wire    X27_31 = X27 ^ X31;    wire    X20_31 = X20 ^ X31;
  wire    X2_8   = X2 ^ X8;
  wire    X14_18 = X14 ^ X18;
  wire    X0_6   = X0 ^ X6;
  wire    X10_16 = X10 ^ X16;

  assign  next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
    {
     ((X5   ^ X8_9)  ^ (X11_15 ^ X23_24)) ^ ((X25    ^ X27_28) ^ (X29_30 ^ X31)),
     ((X4   ^ X7_8)  ^ (X10_14 ^ X22_23)) ^ ((X24    ^ X26_27) ^ (X28_29 ^ X30)),
     ((X3   ^ X6_7)  ^ (X9_13  ^ X21_22)) ^ ((X23    ^ X25_26) ^ (X27_28 ^ X29_31)),
     ((X2   ^ X5_6)  ^ (X8_12  ^ X20_21)) ^ ((X22    ^ X24_25) ^ (X26_27 ^ X28_30)),
     ((X1   ^ X4_5)  ^ (X7_11  ^ X19_20)) ^ ((X21    ^ X23_24) ^ (X25_26 ^ X27_29)),
     ((X0   ^ X3_4)  ^ (X6_10  ^ X18_19)) ^ ((X20_26 ^ X22_23) ^ (X24_25 ^ X28_31)),
     ((X2_3 ^ X8)    ^ (X11_15 ^ X17_18)) ^ ((X19    ^ X21_22) ^ (X28_29 ^ X31)),
     ((X1_2 ^ X7)    ^ (X10_14 ^ X16_17)) ^ ((X18    ^ X20_21) ^ (X27_28 ^ X30)),
     ((X0_1 ^ X6)    ^ (X9_13  ^ X15_16)) ^ ((X17    ^ X19_20) ^ (X26_27 ^ X29_31)),
     ((X0   ^ X12_9) ^ (X14_11 ^ X16))    ^ ((X18_19 ^ X23_24) ^ (X26_27 ^ X29_31)),
     ((X5   ^ X9_13) ^ (X10    ^ X17_18)) ^ ((X22_24 ^ X26_27) ^ (X29_31)),
     ((X4   ^ X8_12) ^ (X9     ^ X16_17)) ^ ((X21_23 ^ X25_26) ^ (X28_30)),
     ((X3   ^ X7_8)  ^ (X11_15 ^ X16))    ^ ((X20_22 ^ X24_25) ^ (X27_29)),
     ((X2   ^ X6_7)  ^ (X10_14 ^ X15))    ^ ((X19_21 ^ X23_24) ^ (X26    ^ X28_31)),
     ((X1   ^ X5_6)  ^ (X9_13  ^ X14))    ^ ((X18_20 ^ X22_23) ^ (X25_27 ^ X30_31)),
     ((X0   ^ X4_5)  ^ (X8_12  ^ X13))    ^ ((X17_19 ^ X21_22) ^ (X24_26 ^ X29_30)),
     ((X3_4 ^ X5)    ^ (X7_8   ^ X12_9))  ^ ((X15_16 ^ X18_30) ^ (X20_21 ^ X24_27)),
     ((X2_3 ^ X4_6)  ^ (X7_8   ^ X14_11)) ^ ((X15_17 ^ X19_20) ^ (X23_26 ^ X29)),
     ((X1_2 ^ X3_5)  ^ (X6_7   ^ X13_10)) ^ ((X14_16 ^ X18_19) ^ (X22_25 ^ X28_31)),
     ((X0_1 ^ X2_4)  ^ (X5_6   ^ X12_9))  ^ ((X13_15 ^ X17_18) ^ (X21_24 ^ X27))    ^ X30_31,
     ((X0_1 ^ X3_4)  ^ (X12_9  ^ X14))    ^ ((X15_16 ^ X17_20) ^ (X24_25 ^ X26_27)) ^ X28_31,
     ((X0_5 ^ X2_3)  ^ (X9_13  ^ X14))    ^ ((X16_19 ^ X26)    ^ (X28_29 ^ X31)),
     ((X1_2 ^ X4_5)  ^ (X12_9  ^ X13_11)) ^ ((X18    ^ X23_24) ^ (X29)),
     ((X0_1 ^ X3_4)  ^ (X8_12  ^ X10_11)) ^ ((X17    ^ X22_23) ^ (X28_31)),
     ((X0_5 ^ X2_3)  ^ (X7_8   ^ X10_15)) ^ ((X16_21 ^ X22_23) ^ (X24_25 ^ X28_29)),
     ((X1_2 ^ X4_5)  ^ (X6_7   ^ X8))     ^ ((X14_11 ^ X20_21) ^ (X22_25 ^ X29_30)),
     ((X0_1 ^ X3_4)  ^ (X5_6   ^ X7))     ^ ((X13_10 ^ X19_20) ^ (X21_24 ^ X28_29)),
     ((X0   ^ X2_3)  ^ (X4_6   ^ X8_12))  ^ ((X11_15 ^ X18_19) ^ (X20_31 ^ X24_25)) ^ X29_30,
     ((X1_2 ^ X3_9)  ^ (X7_8   ^ X10_14)) ^ ((X15_19 ^ X17_18) ^ (X25    ^ X27_31)),
     ((X0_1 ^ X2_8)  ^ (X6_7   ^ X9_13))  ^ ((X14_18 ^ X16_17) ^ (X24_26 ^ X30_31)),
     ((X0_1 ^ X6_7)  ^ (X12_9  ^ X13_11)) ^ ((X16_17 ^ X24)    ^ (X27_28)),
     ((X0_6 ^ X12_9) ^ (X10_16 ^ X24_25)) ^ ((X26    ^ X28_29) ^ (X30_31))
    };
endmodule

module crc_32_64_private (
  present_crc,
  data_in_64,
  next_crc
);

  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [63:0] data_in_64;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

endmodule


// Try to make a program which will generate formulas for how to do CRC-32
//   several bits at a time.
// The idea is to get a single-bit implementation which works.  (!)
// Then apply an initial value for state and an input data stream.
// The initial value will have a single bit set, and the data stream
//   will have a single 1-bit followed by 0 bits.
// Grind the state machine forward the desired number of bits N, and
//   look at the stored state.  Each place in the shift register where
//   there is a 1'b1, that is a bit which is sensitive to the input
//   or state bit in a parallel implementation N bits wide.

// `define CALCULATE_FUNCTIONAL_DEPENDENCE_ON_INPUT_AND_STATE
`ifdef CALCULATE_FUNCTIONAL_DEPENDENCE_ON_INPUT_AND_STATE
module print_out_formulas ();

  parameter NUM_BITS_TO_DO_IN_PARALLEL = 8'h20;

  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] running_state;
  reg    [31:0] input_vector;
  reg     xor_value;
  integer i, j;

  reg    [2047:0] corner_turner;  // 32 bits * 64 shifts

  initial
  begin
    $display ("Calculating functional dependence on input bits.  Rightmost bit is State Bit 0.");
    for (i = 0; i < NUM_BITS_TO_DO_IN_PARALLEL; i = i + 1)
    begin
      running_state = {`NUMBER_OF_BITS_IN_CRC{1'b0}};
      input_vector = 32'h80000000;  // MSB first for this program
      for (j = 0; j < i + 1; j = j + 1)
      begin
        xor_value = input_vector[31] ^ running_state[`NUMBER_OF_BITS_IN_CRC - 1];
        running_state[`NUMBER_OF_BITS_IN_CRC - 1 : 0] = xor_value
                  ? {running_state[`NUMBER_OF_BITS_IN_CRC - 2 : 0], 1'b0} ^ `CRC
                  : {running_state[`NUMBER_OF_BITS_IN_CRC - 2 : 0], 1'b0};
        input_vector[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                    {input_vector[`NUMBER_OF_BITS_IN_CRC - 2 : 0], 1'b0};
      end
      $display ("input bit number (bigger is earlier) %d, dependence %b",
                   i, running_state[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
// First entry, which gets shifted the most in corner_turner, is the last bit loaded                    
      corner_turner[2047:0] = {corner_turner[2047 - `NUMBER_OF_BITS_IN_CRC : 0],
                                      running_state[`NUMBER_OF_BITS_IN_CRC - 1:0]};
    end

// Plan: reverse the order bits are reported in
// Add C23 terms to first 24 terms
// Insert ^ X

// NOTE: WORKING: count out formulas in the opposite order, write out valid formulas.
    $display ("Each term called out means the formula depends on a term data_in[N] ^ State[N].");
    $display ("State Variables depend on input bit number (bigger is earlier) :");
// try to read out formulas by sweeping a 1-bit through the corner_turner array.
    $display ("{");
    for (i = `NUMBER_OF_BITS_IN_CRC - 1; i >= NUM_BITS_TO_DO_IN_PARALLEL; i = i - 1)
    begin  // Bits which depend on shifted state bits directly
      $write ("%d : C%0d ", i, i - NUM_BITS_TO_DO_IN_PARALLEL);
      for (j = 0; j < NUM_BITS_TO_DO_IN_PARALLEL; j = j + 1)
      begin
        if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                            != 1'b0)
          $write (" ^ X%0d", j[5:0]);
        else if (j >= 10) $write ("      "); else $write ("     ");
      end
      $write (",\n");
    end

    for (i = NUM_BITS_TO_DO_IN_PARALLEL - 1; i >= 0; i = i - 1)
    begin  // bits which only depend on shifted XOR'd bits
      $write ("%d :  0 ", i);
      for (j = 0; j < NUM_BITS_TO_DO_IN_PARALLEL; j = j + 1)
      begin
        if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                            != 1'b0)
          $write (" ^ X%0d", j[5:0]);
        else if (j >= 10) $write ("      "); else $write ("     ");
      end
      if (i != 0) $write (",\n"); else $write ("\n");
    end
    $display ("}");

// Write out bits in a different order, to make it easier to group terms.
    if (NUM_BITS_TO_DO_IN_PARALLEL >= 16)
    begin
      $display ("{");
      for (i = `NUMBER_OF_BITS_IN_CRC - 1; i >= NUM_BITS_TO_DO_IN_PARALLEL; i = i - 1)
      begin  // Bits which depend on shifted state bits directly
        $write ("%d : C%0d ", i, i - NUM_BITS_TO_DO_IN_PARALLEL);
        for (j = 0; j <= 8; j = j + 1)
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 12;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 9;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 13;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 10;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 14;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 11;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 15;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        for (j = 16; j < NUM_BITS_TO_DO_IN_PARALLEL; j = j + 1)
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                            != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        $write (",\n");
      end
    
      for (i = NUM_BITS_TO_DO_IN_PARALLEL - 1; i >= 0; i = i - 1)
      begin  // bits which only depend on shifted XOR'd bits
        $write ("%d :  0 ", i);
        for (j = 0; j <= 8; j = j + 1)
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 12;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 9;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 13;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 10;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 14;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 11;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        j = 15;
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                              != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        for (j = 16; j < NUM_BITS_TO_DO_IN_PARALLEL; j = j + 1)
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                            != 1'b0)
            $write (" ^ X%0d", j[5:0]);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        if (i != 0) $write (",\n"); else $write ("\n");
      end
      $display ("}");
    end  // if width >= 16

    $display ("All terms beyond the width of the input data are each dependent on State");
    $display ("bits the shift distance towards the LSB of the polynomial.  For instance,");
    $display ("if the shift distance is 16, State Bit 16 has a term containing old state bit 0.");
  end
endmodule
`endif  // CALCULATE_FUNCTIONAL_DEPENDENCE_ON_INPUT_AND_STATE

 `define SERIAL_VERSION_FOR_DEBUG
`ifdef SERIAL_VERSION_FOR_DEBUG
// a slow one to make sure I did things right.
module crc_32_1_bit_at_a_time (
  use_F_for_CRC,
  present_crc,
  data_in_1,
  next_crc
);
  input   use_F_for_CRC;
  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input   data_in_1;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] resettable_crc;
  assign  resettable_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                         {`NUMBER_OF_BITS_IN_CRC{use_F_for_CRC}}
                       | present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0];

  wire    xor_value = data_in_1 ^ resettable_crc[`NUMBER_OF_BITS_IN_CRC - 1];

  assign  next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] = xor_value
                     ? {resettable_crc[`NUMBER_OF_BITS_IN_CRC - 2 : 0], 1'b0} ^ `CRC
                     : {resettable_crc[`NUMBER_OF_BITS_IN_CRC - 2 : 0], 1'b0};
endmodule

module test_crc_1 ();

  integer i, j;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;
  reg     use_F_for_CRC;
  reg    [7:0] data_in;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc_8;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc_8;
  reg    [15:0] data_in_16;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc_16;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc_16;
  reg    [31:0] data_in_32;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc_32;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc_32;


// Assign data_in before invoking.  This consumes data MSB first
task apply_byte_to_crc;
  integer j;
  begin
    #0 ;
    present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                            next_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =  // remember: apply 16 bits
                            next_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =  // remember: apply 32 bits
                            next_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    for (j = 0; j < 8; j = j + 1)  // apply data bit at a time
    begin
      #0 ;
      present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                            next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
      data_in[7:0] = {data_in[6:0], 1'b0};  // Shift byte out MSB first
      use_F_for_CRC = 1'b0;
    end
  end
endtask

  initial
  begin
    #10;
    $display ("running serial version of code");
    use_F_for_CRC = 1'b1;
    for (i = 0; i < 43; i = i + 1)
    begin
      data_in[7:0] = 8'h00;
      apply_byte_to_crc;
    end
    data_in[7:0] = 8'h28;
    apply_byte_to_crc;
    if (~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'h864D7F99)
      $display ("*** 1-bit after 40 bytes of 1'b0, I want 32'h864D7F99, I get 32\`h%x",
                 ~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    if (~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'h864D7F99)
      $display ("*** 8-bit after 40 bytes of 1'b0, I want 32'h864D7F99, I get 32\`h%x",
                 ~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in[7:0] = 8'h86;
    apply_byte_to_crc;
    data_in[7:0] = 8'h4D;
    apply_byte_to_crc;
    data_in[7:0] = 8'h7F;
    apply_byte_to_crc;
    data_in[7:0] = 8'h99;
    apply_byte_to_crc;
//        The receiver sees the value 32'hC704DD7B when the message is
//          received no errors.  Bit reversed, that is 32'hDEBB20E3.
    if (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 1-bit 0's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    if (present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 8-bit 0's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    for (i = 0; i < 21; i = i + 1)
    begin
      data_in_16[15:0] = 16'h0000;
      apply_byte_to_crc;
    end
    data_in_16[15:0] = 16'h0028;
    apply_byte_to_crc;
    if (~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'h864D7F99)
      $display ("*** 16-bit after 40 bytes of 1'b0, I want 32'h864D7F99, I get 32\`h%x",
                 ~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_16[15:0] = 16'h864D;
    apply_byte_to_crc;
    data_in_16[15:0] = 16'h7F99;
    apply_byte_to_crc;
    if (present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 16-bit 0's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    for (i = 0; i < 10; i = i + 1)
    begin
      data_in_32[31:0] = 32'h00000000;
      apply_byte_to_crc;
    end
    data_in_32[31:0] = 32'h00000028;
    apply_byte_to_crc;
    if (~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'h864D7F99)
      $display ("*** 32-bit after 40 bytes of 1'b0, I want 32'h864D7F99, I get 32\`h%x",
                 ~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_32[31:0] = 32'h864D7F99;
    apply_byte_to_crc;
    if (present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 32-bit 0's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);


    use_F_for_CRC = 1'b1;
    for (i = 0; i < 40; i = i + 1)
    begin
      data_in[7:0] = 8'hFF;
      apply_byte_to_crc;
    end
    for (i = 0; i < 3; i = i + 1)
    begin
      data_in[7:0] = 8'h00;
      apply_byte_to_crc;
    end
    data_in[7:0] = 8'h28;
    apply_byte_to_crc;
    if (~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC55E457A)
      $display ("*** 1-bit after 40 bytes of 1'b1, I want 32'hC55E457A, I get 32\`h%x",
                 ~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    if (~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC55E457A)
      $display ("*** 8-bit after 40 bytes of 1'b1, I want 32'hC55E457A, I get 32\`h%x",
                 ~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in[7:0] = 8'hC5;
    apply_byte_to_crc;
    data_in[7:0] = 8'h5E;
    apply_byte_to_crc;
    data_in[7:0] = 8'h45;
    apply_byte_to_crc;
    data_in[7:0] = 8'h7A;
    apply_byte_to_crc;
    if (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 1-bit 1's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    if (present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 8-bit 1's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    for (i = 0; i < 20; i = i + 1)
    begin
      data_in_16[15:0] = 16'hFFFF;
      apply_byte_to_crc;
    end
    data_in_16[15:0] = 16'h0000;
    apply_byte_to_crc;
    data_in_16[15:0] = 16'h0028;
    apply_byte_to_crc;
    if (~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC55E457A)
      $display ("*** 16-bit after 40 bytes of 1'b1, I want 32'hC55E457A, I get 32\`h%x",
                 ~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_16[15:0] = 16'hC55E;
    apply_byte_to_crc;
    data_in_16[15:0] = 16'h457A;
    apply_byte_to_crc;
    if (present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 16-bit 1's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    for (i = 0; i < 10; i = i + 1)
    begin
      data_in_32[31:0] = 32'hFFFFFFFF;
      apply_byte_to_crc;
    end
    data_in_32[31:0] = 32'h00000028;
    apply_byte_to_crc;
    if (~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC55E457A)
      $display ("*** 32-bit after 40 bytes of 1'b1, I want 32'hC55E457A, I get 32\`h%x",
                 ~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_32[31:0] = 32'hC55E457A;
    apply_byte_to_crc;
    if (present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 32-bit 1's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    for (i = 0; i < 40; i = i + 1)
    begin
      data_in[7:0] = i + 1;
      apply_byte_to_crc;
      use_F_for_CRC = 1'b0;
    end
    for (i = 0; i < 3; i = i + 1)
    begin
      data_in[7:0] = 8'h00;
      apply_byte_to_crc;
    end
    data_in[7:0] = 8'h28;
    apply_byte_to_crc;
    if (~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hBF671ED0)
      $display ("*** 1-bit after 40 bytes of i+1, I want 32'hBF671ED0, I get 32\`h%x",
                 ~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    if (~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hBF671ED0)
      $display ("*** 8-bit after 40 bytes of i+1, I want 32'hBF671ED0, I get 32\`h%x",
                 ~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in[7:0] = 8'hBF;
    apply_byte_to_crc;
    data_in[7:0] = 8'h67;
    apply_byte_to_crc;
    data_in[7:0] = 8'h1E;
    apply_byte_to_crc;
    data_in[7:0] = 8'hD0;
    apply_byte_to_crc;
    if (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 1-bit i+1 after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    if (present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 8-bit i+1 after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    for (i = 0; i < 20; i = i + 1)
    begin
      data_in_16[15:0] = (((2 * i) + 1) << 8) | ((2 * i) + 2);
      apply_byte_to_crc;
    end
    data_in_16[15:0] = 16'h0000;
    apply_byte_to_crc;
    data_in_16[15:0] = 16'h0028;
    apply_byte_to_crc;
    if (~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hBF671ED0)
      $display ("*** 16-bit after 40 bytes of i+1, I want 32'hBF671ED0, I get 32\`h%x",
                 ~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_16[15:0] = 16'hBF67;
    apply_byte_to_crc;
    data_in_16[15:0] = 16'h1ED0;
    apply_byte_to_crc;
    if (present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 16-bit i+1 after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    for (i = 0; i < 10; i = i + 1)
    begin
      data_in_32[31:0] = (((4 * i) + 1) << 24) | (((4 * i) + 2) << 16)
                       | (((4 * i) + 3) << 8)  |  ((4 * i) + 4);
      apply_byte_to_crc;
    end
    data_in_32[31:0] = 32'h00000028;
    apply_byte_to_crc;
    if (~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hBF671ED0)
      $display ("*** 32-bit after 40 bytes of i+1, I want 32'hBF671ED0, I get 32\`h%x",
                 ~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_32[31:0] = 32'hBF671ED0;
    apply_byte_to_crc;
    if (present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 32-bit i+1 after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

  end

crc_32_1_bit_at_a_time test_1_bit (
  .use_F_for_CRC              (use_F_for_CRC),
  .present_crc                (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_in_1                  (data_in[7]),
  .next_crc                   (next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

crc_32_8_private test_8_bit (
  .use_F_for_CRC              (use_F_for_CRC),
  .present_crc                (present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_in_8                  (data_in[7:0]),
  .next_crc                   (next_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

crc_32_16_private test_16_bit (
  .use_F_for_CRC              (use_F_for_CRC),
  .present_crc                (present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_in_16                 (data_in_16[15:0]),
  .next_crc                   (next_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

crc_32_32_private test_16_bit (
  .use_F_for_CRC              (use_F_for_CRC),
  .present_crc                (present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_in_32                 (data_in_32[31:0]),
  .next_crc                   (next_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

//  Angie Tso's CRC-32 Test Cases
//  tsoa@ttc.com
//  Angie Tso
//  Telecommunications Techniques Corp.     E-mail: tsoa@ttc.com
//  20400 Observation Drive,                Voice : 301-353-1550 ext.4061
//  Germantown, MD 20876-4023               Fax   : 301-353-1536 Mail Stop O
//  
//  Angie posted the following on the cell-relay list Mon, 24 Oct 1994 18:33:11 GMT=20
//  --------------------------------------------------------------------------------
//  
//  Here are the examples of valid AAL-5 CS-PDU in I.363:
//     (There are three examples in I.363)
//  
//  40 Octets filled with "0"
//  CPCS-UU = 0, CPI = 0, Length = 40, CRC-32 = 864d7f99
//  char pkt_data[48]={0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
//                     0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
//                     0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
//                     0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
//                     0x00,0x00,0x00,0x28,0x86,0x4d,0x7f,0x99};
//  
//  40 Octets filled with "1"
//  CPCS-UU = 0, CPI = 0, Length = 40, CRC-32 = c55e457a
//  char pkt_data[48]={0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
//                     0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
//                     0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
//                     0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
//                     0x00,0x00,0x00,0x28,0xc5,0x5e,0x45,0x7a};
//  
//  40 Octets counting: 1 to 40
//  CPCS-UU = 0, CPI = 0, Length = 40, CRC-32 = bf671ed0
//  char pkt_data[48]={0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,
//                     0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x11,0x12,0x13,0x14,
//                     0x15,0x16,0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,
//                     0x1f,0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,
//                     0x00,0x00,0x00,0x28,0xbf,0x67,0x1e,0xd0};
//  
//  Here is one out of my calculation for your reference:
//  
//  40 Octets counting: 1 to 40
//  CPCS-UU = 11, CPI = 22, CRC-32 = acba602a
//  char pkt_data[48]={0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,
//                     0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x11,0x12,0x13,0x14,
//                     0x15,0x16,0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,
//                     0x1f,0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,
//                     0x11,0x22,0x00,0x28,0xac,0xba,0x60,0x2a};

endmodule
`endif  // SERIAL_VERSION_FOR_DEBUG

