//===========================================================================
// $Id: crc32_lib.v,v 1.15 2001-08-30 10:08:45 bbeaver Exp $
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
//          CRC generator, the MSB corresponds to the earliest data to arrive
//          across a serial interface.
// NOTE:  The code also assumes that the data shifts into bit 0 of the shift
//          register, and shifts out of bit 31.
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
//          received no errors.
//
//        That means that each clock a new bit comes in, you have to shift
//          all the 32 running state bits 1 bit higher and drop the MSB.
//          PLUS you have to XOR in (new bit ^ MSB) to locations
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
// NOTE:  The idea is simple, so I may include a program to print out
//          formulas at the end of this code.  The module SHOULD be improved
//          to group the terms into an XOR tree, with parantheses.  That can
//          be left for a new person.
//
// NOTE: WORKING: Make routines which capture ALL input data in flops immediately.
//                  All outputs are already latched.  So this module is flop-to-flop.
//                This lets the module be synthesized and layed out independently
//                  of all other modules when trying to meet timing.
//                This also lets the modules which calculate with more than 32
//                  input bits per clock have an internal pipeline stage where
//                  the Data component of the new CRC is calculate.  But be
//                  careful!  An extra layer of pipelining changes when data
//                  becomes available.
//                Might also make versions which let a non-F CRC be loaded.  This
//                  would be useful if a CRC needed to be calculated incrementally,
//                  which is the case when calculating AAL-5 checksums, for instance.
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
  parameter NUMBER_OF_BITS_APPLIED = 8;
  input   use_F_for_CRC;
  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [NUMBER_OF_BITS_APPLIED - 1 : 0] data_in_8;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

  wire    X7, X6, X5, X4, X3, X2, X1, X0;
  assign  {X7, X6, X5, X4, X3, X2, X1, X0} = data_in_8[NUMBER_OF_BITS_APPLIED - 1 : 0]
         ^ (   present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : `NUMBER_OF_BITS_IN_CRC - NUMBER_OF_BITS_APPLIED]
             | {NUMBER_OF_BITS_APPLIED{use_F_for_CRC}});

  wire    C23, C22, C21, C20, C19, C18, C17, C16;
  wire    C15, C14, C13, C12, C11, C10, C9, C8, C7, C6, C5, C4, C3, C2, C1, C0;
  assign  {C23, C22, C21, C20, C19, C18, C17, C16, C15, C14, C13, C12,
           C11, C10, C9,  C8,  C7,  C6,  C5,  C4,  C3,  C2,  C1,  C0} =
           present_crc[`NUMBER_OF_BITS_IN_CRC - NUMBER_OF_BITS_APPLIED - 1 : 0]
         | {(`NUMBER_OF_BITS_IN_CRC - NUMBER_OF_BITS_APPLIED){use_F_for_CRC}};

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
  parameter NUMBER_OF_BITS_APPLIED = 16;
  input   use_F_for_CRC;
  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [NUMBER_OF_BITS_APPLIED - 1 : 0] data_in_16;
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
           data_in_16[NUMBER_OF_BITS_APPLIED - 1 : 0]
         ^ (   present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : `NUMBER_OF_BITS_IN_CRC - NUMBER_OF_BITS_APPLIED]
             | {NUMBER_OF_BITS_APPLIED{use_F_for_CRC}});

// State Bits are shifted over by the width of the input, then XOR's into the X terms.
  wire    C15, C14, C13, C12, C11, C10, C9, C8, C7, C6, C5, C4, C3, C2, C1, C0;
  assign  {C15, C14, C13, C12, C11, C10, C9, C8, C7, C6, C5, C4, C3, C2, C1, C0} =
           present_crc[`NUMBER_OF_BITS_IN_CRC - NUMBER_OF_BITS_APPLIED - 1 : 0]
         | {(`NUMBER_OF_BITS_IN_CRC - NUMBER_OF_BITS_APPLIED){use_F_for_CRC}};

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
    { (C15_5  ^ X8_9)   ^ X11_15,
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

module crc_32_24_private (
  use_F_for_CRC,
  present_crc,
  data_in_24,
  next_crc
);
  parameter NUMBER_OF_BITS_APPLIED = 24;
  input   use_F_for_CRC;
  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [NUMBER_OF_BITS_APPLIED - 1 : 0] data_in_24;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

/* State Variables depend on input bit number (bigger is earlier) :
{
C7                           ^ X5           ^ X8       ^ X9                   ^ X11 ^ X15                                           ^ X23,
C6                      ^ X4           ^ X7 ^ X8                  ^ X10 ^ X14                                                 ^ X22 ^ X23,
C5                 ^ X3           ^ X6 ^ X7            ^ X9 ^ X13                                                       ^ X21 ^ X22 ^ X23,
C4            ^ X2           ^ X5 ^ X6      ^ X8 ^ X12                                                            ^ X20 ^ X21 ^ X22      ,
C3       ^ X1           ^ X4 ^ X5      ^ X7                                   ^ X11                         ^ X19 ^ X20 ^ X21       ^ X23,
C2  ^ X0           ^ X3 ^ X4      ^ X6                            ^ X10                               ^ X18 ^ X19 ^ X20       ^ X22 ^ X23,
C1            ^ X2 ^ X3                     ^ X8                              ^ X11 ^ X15       ^ X17 ^ X18 ^ X19       ^ X21 ^ X22      ,
C0       ^ X1 ^ X2                     ^ X7                       ^ X10 ^ X14             ^ X16 ^ X17 ^ X18       ^ X20 ^ X21            ,
 0  ^ X0 ^ X1                     ^ X6                 ^ X9 ^ X13                   ^ X15 ^ X16 ^ X17       ^ X19 ^ X20                  ,
 0  ^ X0                                         ^ X12 ^ X9             ^ X14 ^ X11       ^ X16       ^ X18 ^ X19                   ^ X23,
 0                           ^ X5                      ^ X9 ^ X13 ^ X10                         ^ X17 ^ X18                   ^ X22      ,
 0                      ^ X4                ^ X8 ^ X12 ^ X9                               ^ X16 ^ X17                   ^ X21       ^ X23,
 0                 ^ X3                ^ X7 ^ X8                              ^ X11 ^ X15 ^ X16                   ^ X20       ^ X22      ,
 0            ^ X2                ^ X6 ^ X7                       ^ X10 ^ X14       ^ X15                   ^ X19       ^ X21       ^ X23,
 0       ^ X1                ^ X5 ^ X6                 ^ X9 ^ X13       ^ X14                         ^ X18       ^ X20       ^ X22 ^ X23,
 0  ^ X0                ^ X4 ^ X5           ^ X8 ^ X12      ^ X13                               ^ X17       ^ X19       ^ X21 ^ X22      ,
 0                 ^ X3 ^ X4 ^ X5      ^ X7 ^ X8 ^ X12 ^ X9                         ^ X15 ^ X16       ^ X18       ^ X20 ^ X21            ,
 0            ^ X2 ^ X3 ^ X4      ^ X6 ^ X7 ^ X8                        ^ X14 ^ X11 ^ X15       ^ X17       ^ X19 ^ X20             ^ X23,
 0       ^ X1 ^ X2 ^ X3      ^ X5 ^ X6 ^ X7                 ^ X13 ^ X10 ^ X14             ^ X16       ^ X18 ^ X19             ^ X22      ,
 0  ^ X0 ^ X1 ^ X2      ^ X4 ^ X5 ^ X6           ^ X12 ^ X9 ^ X13                   ^ X15       ^ X17 ^ X18             ^ X21            ,
 0  ^ X0 ^ X1      ^ X3 ^ X4                     ^ X12 ^ X9             ^ X14       ^ X15 ^ X16 ^ X17             ^ X20                  ,
 0  ^ X0      ^ X2 ^ X3      ^ X5                      ^ X9 ^ X13       ^ X14             ^ X16             ^ X19                        ,
 0       ^ X1 ^ X2      ^ X4 ^ X5                ^ X12 ^ X9 ^ X13             ^ X11                   ^ X18                         ^ X23,
 0  ^ X0 ^ X1      ^ X3 ^ X4                ^ X8 ^ X12            ^ X10       ^ X11             ^ X17                         ^ X22 ^ X23,
 0  ^ X0      ^ X2 ^ X3      ^ X5      ^ X7 ^ X8                  ^ X10             ^ X15 ^ X16                         ^ X21 ^ X22 ^ X23,
 0       ^ X1 ^ X2      ^ X4 ^ X5 ^ X6 ^ X7 ^ X8                        ^ X14 ^ X11                               ^ X20 ^ X21 ^ X22      ,
 0  ^ X0 ^ X1      ^ X3 ^ X4 ^ X5 ^ X6 ^ X7                 ^ X13 ^ X10                                     ^ X19 ^ X20 ^ X21            ,
 0  ^ X0      ^ X2 ^ X3 ^ X4      ^ X6      ^ X8 ^ X12                        ^ X11 ^ X15             ^ X18 ^ X19 ^ X20                  ,
 0       ^ X1 ^ X2 ^ X3                ^ X7 ^ X8       ^ X9       ^ X10 ^ X14       ^ X15       ^ X17 ^ X18 ^ X19                        ,
 0  ^ X0 ^ X1 ^ X2                ^ X6 ^ X7 ^ X8       ^ X9 ^ X13       ^ X14             ^ X16 ^ X17 ^ X18                              ,
 0  ^ X0 ^ X1                     ^ X6 ^ X7      ^ X12 ^ X9 ^ X13             ^ X11       ^ X16 ^ X17                                    ,
 0  ^ X0                          ^ X6           ^ X12 ^ X9       ^ X10                   ^ X16                                          
}
*/
// There are 2 obvious ways to implement these functions:
// 1) XOR the State bits with the Input bits, then calculate the XOR's
// 2) Independently calculate a result for Inputs and State variables,
//    then XOR the results together.
// The second idea seems to take much more logic, but to have no benefit.

// Single numbered terms are calculated in 1 XOR time.
  wire    X23, X22, X21, X20, X19, X18, X17, X16;
  wire    X15, X14, X13, X12, X11, X10, X9, X8, X7, X6, X5, X4, X3, X2, X1, X0;
  assign  {X23, X22, X21, X20, X19, X18, X17, X16, X15, X14, X13, X12,
                        X11, X10, X9, X8, X7, X6, X5, X4, X3, X2, X1, X0} =
           data_in_24[NUMBER_OF_BITS_APPLIED - 1 : 0]
         ^ (   present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : `NUMBER_OF_BITS_IN_CRC - NUMBER_OF_BITS_APPLIED]
             | {NUMBER_OF_BITS_APPLIED{use_F_for_CRC}});

// State Bits are shifted over by the width of the input, then XOR's into the X terms.
  wire    C7, C6, C5, C4, C3, C2, C1, C0;
  assign  {C7, C6, C5, C4, C3, C2, C1, C0} =
           present_crc[`NUMBER_OF_BITS_IN_CRC - NUMBER_OF_BITS_APPLIED - 1 : 0]
         | {(`NUMBER_OF_BITS_IN_CRC - NUMBER_OF_BITS_APPLIED){use_F_for_CRC}};

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
// back to simple ordering
                                 wire    X15_16 = X15 ^ X16;
  wire    X16_17 = X16 ^ X17;    wire    X17_18 = X17 ^ X18;
  wire    X18_19 = X18 ^ X19;    wire    X19_20 = X19 ^ X20;
  wire    X20_21 = X20 ^ X21;    wire    X21_22 = X21 ^ X22;
  wire    X22_23 = X22 ^ X23;

// Calculate terms which might have a single use.  They are calculated here
//   so that the parity trees can be balanced.
  wire    C7_5   = C7  ^ X5;     wire    C6_4   = C6  ^ X4;
  wire    C5_3   = C5  ^ X3;     wire    C4_2   = C4  ^ X2;
  wire    C3_1   = C3  ^ X1;     wire    C2_0   = C2  ^ X0;
  wire    C1_8   = C1  ^ X8;     wire    C0_7   = C0  ^ X7;
// Some of these could be matched with other terms to share 1 input in a CLB.
  wire    X8_9   = X8  ^ X9;     wire    X7_11  = X7  ^ X11;
  wire    X6_10  = X6  ^ X10;    wire    X21_23 = X21 ^ X23;
  wire    X6_17  = X6  ^ X17;    wire    X0_16  = X0  ^ X16;
  wire    X5_10  = X5  ^ X10;    wire    X4_9   = X4  ^ X9;
  wire    X3_16  = X3  ^ X16;    wire    X20_22 = X20 ^ X22;
  wire    X15_19 = X15 ^ X19;    wire    X1_9   = X1  ^ X9;
  wire    X13_14 = X13 ^ X14;    wire    X18_20 = X18 ^ X20;
  wire    X0_8   = X0  ^ X8;     wire    X12_13 = X12 ^ X13;
  wire    X17_19 = X17 ^ X19;    wire    X5_18  = X5  ^ X18;
  wire    X4_8   = X4  ^ X8;     wire    X15_17 = X15 ^ X17;
  wire    X3_7   = X3  ^ X7;     wire    X2_6   = X2  ^ X6;
  wire    X14_17 = X14 ^ X17;    wire    X0_5   = X0  ^ X5;
  wire    X14_16 = X14 ^ X16;    wire    X13_15 = X13 ^ X15;
  wire    X0_4   = X0  ^ X4;     wire    X0_6   = X0  ^ X6;
  wire    X3_9   = X3  ^ X9;     wire    X2_8   = X2  ^ X8;
  wire    X13_11 = X13 ^ X11;    wire    X16_23 = X16 ^ X23;
  wire    X10_11 = X10 ^ X11;    wire    X10_15 = X10 ^ X15;
  wire    X8_22  = X8  ^ X22;    wire    X14_18 = X14 ^ X18;
  wire    X6_20  = X6  ^ X20;    wire    X7_21  = X7  ^ X21;

// NOTE: 5 terms can be implemented in a CLB, as long as the other Flop
//         doesn't use logic.  This would be perfect if the data_in_24
//         was registered as an input to the module in that CLB.
  assign  next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
    { (C7_5  ^ X8_9)  ^ (X11_15 ^ X23),
      (C6_4  ^ X7_8)  ^ (X10_14 ^ X22_23),
     ((C5_3  ^ X6_7)  ^ (X9_13  ^ X21_22)) ^ X23,
     ((C4_2  ^ X5_6)  ^ (X8_12  ^ X20_21)) ^ X22,
     ((C3_1  ^ X4_5)  ^ (X7_11  ^ X19_20)) ^ X21_23,
     ((C2_0  ^ X3_4)  ^ (X6_10  ^ X18_19)) ^  (X20 ^ X22_23),
     ((C1_8  ^ X2_3)  ^ (X11_15 ^ X17_18)) ^  (X19 ^ X21_22),
     ((C0_7  ^ X1_2)  ^ (X10_14 ^ X16_17)) ^  (X18 ^ X20_21),
     ((X0_1  ^ X6_17) ^ (X9_13  ^ X15_16)) ^ X19_20,
     ((X0_16 ^ X12_9) ^ (X14_11 ^ X18_19)) ^ X23,
      (X5_10 ^ X9_13) ^ (X17_18 ^ X22),
      (X4_9  ^ X8_12) ^ (X16_17 ^ X21_23),
      (X3_16 ^ X7_8)  ^ (X11_15 ^ X20_22),
     ((X2    ^ X6_7)  ^ (X10_14 ^ X15_19)) ^ X21_23,
     ((X1_9  ^ X5_6)  ^ (X13_14 ^ X18_20)) ^ X22_23,
     ((X0_8  ^ X4_5)  ^ (X12_13 ^ X17_19)) ^ X21_22,
     ((X3_4  ^ X5_18) ^ (X7_8   ^ X12_9))  ^  (X15_16 ^ X20_21),
     ((X2_3  ^ X4_8)  ^ (X6_7   ^ X14_11)) ^ ((X15_17 ^ X19_20) ^ X23),
     ((X1_2  ^ X3_7)  ^ (X5_6   ^ X13_10)) ^ ((X14_16 ^ X18_19) ^ X22),
     ((X0_1  ^ X2_6)  ^ (X4_5   ^ X12_9))  ^ ((X13_15 ^ X17_18) ^ X21),
     ((X0_1  ^ X3_4)  ^ (X12_9  ^ X14_17)) ^  (X15_16 ^ X20),
     ((X0_5  ^ X2_3)  ^ (X9_13  ^ X14))    ^  (X16    ^ X19),
     ((X1_2  ^ X4_5)  ^ (X12_9  ^ X13_11)) ^  (X18    ^ X23),
     ((X0_1  ^ X3_4)  ^ (X8_12  ^ X10_11)) ^  (X17    ^ X22_23),
     ((X0_5  ^ X2_3)  ^ (X7_8   ^ X10_15)) ^  (X16_23 ^ X21_22),
     ((X1_2  ^ X4_5)  ^ (X6_7   ^ X8_22))  ^  (X14_11 ^ X20_21),
     ((X0_1  ^ X3_4)  ^ (X5_6   ^ X7_21))  ^  (X13_10 ^ X19_20),
     ((X0_4  ^ X2_3)  ^ (X6_20  ^ X8_12))  ^  (X11_15 ^ X18_19),
     ((X1_2  ^ X3_9)  ^ (X7_8   ^ X10_14)) ^  (X15_19 ^ X17_18),
     ((X0_1  ^ X2_8)  ^ (X6_7   ^ X9_13))  ^  (X14_18 ^ X16_17),
     ((X0_1  ^ X6_7)  ^ (X12_9  ^ X13_11)) ^ X16_17,
      (X0_6  ^ X12_9) ^ (X10    ^ X16)
    };
endmodule

module crc_32_32_private (
  use_F_for_CRC,
  present_crc,
  data_in_32,
  next_crc
);
  parameter NUMBER_OF_BITS_APPLIED = 32;
  input   use_F_for_CRC;
  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [NUMBER_OF_BITS_APPLIED - 1 : 0] data_in_32;
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
           data_in_32[NUMBER_OF_BITS_APPLIED - 1 : 0]
         ^ (   present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : `NUMBER_OF_BITS_IN_CRC - NUMBER_OF_BITS_APPLIED]
             | {NUMBER_OF_BITS_APPLIED{use_F_for_CRC}});

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
    {((X5   ^ X8_9)  ^ (X11_15 ^ X23_24)) ^ ((X25    ^ X27_28) ^ (X29_30 ^ X31)),
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

// Calculate the Data dependent part of the CRC-32 function with 64 inputs here in
//   a separate module so that the user can pipeline this one clock earlier.  This
//   MIGHT mean that the whole thing can run faster.  If not, use as a function!
module crc_32_64_data_private (
  data_in_64,
  data_part_1_out, data_part_2_out
);
  parameter NUMBER_OF_BITS_APPLIED = 64;
  input  [NUMBER_OF_BITS_APPLIED - 1 : 0] data_in_64;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] data_part_1_out;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] data_part_2_out;

/*
// Data Input dependencies
{
X5 ^X8^X9 ^X11 ^X15 ^X23^X24^X25 ^X27^X28^X29^X30^X31 ^X33 ^X36 ^X43^X44 ^X46^X47 ^X49 ^X52^X53^X54 ^X57 ^X59^X60 ^X62,
X4 ^X7^X8 ^X10 ^X14 ^X22^X23^X24 ^X26^X27^X28^X29^X30 ^X32 ^X35 ^X42^X43 ^X45^X46 ^X48 ^X51^X52^X53 ^X56 ^X58^X59 ^X61 ^X63,
X3 ^X6^X7 ^X9 ^X13 ^X21^X22^X23 ^X25^X26^X27^X28^X29 ^X31 ^X34 ^X41^X42 ^X44^X45 ^X47 ^X50^X51^X52 ^X55 ^X57^X58 ^X60 ^X62^X63,
X2 ^X5^X6 ^X8 ^X12 ^X20^X21^X22 ^X24^X25^X26^X27^X28 ^X30 ^X33 ^X40^X41 ^X43^X44 ^X46 ^X49^X50^X51 ^X54 ^X56^X57 ^X59 ^X61^X62^X63,
X1 ^X4^X5 ^X7 ^X11 ^X19^X20^X21 ^X23^X24^X25^X26^X27 ^X29 ^X32 ^X39^X40 ^X42^X43 ^X45 ^X48^X49^X50 ^X53 ^X55^X56 ^X58 ^X60^X61^X62^X63,
X0 ^X3^X4 ^X6 ^X10 ^X18^X19^X20 ^X22^X23^X24^X25^X26 ^X28 ^X31 ^X38^X39 ^X41^X42 ^X44 ^X47^X48^X49 ^X52 ^X54^X55 ^X57 ^X59^X60^X61^X62,
X2^X3 ^X8 ^X11 ^X15 ^X17^X18^X19 ^X21^X22 ^X28^X29 ^X31 ^X33 ^X36^X37^X38 ^X40^X41 ^X44 ^X48^X49 ^X51^X52 ^X56^X57^X58 ^X61^X62,
X1^X2 ^X7 ^X10 ^X14 ^X16^X17^X18 ^X20^X21 ^X27^X28 ^X30 ^X32 ^X35^X36^X37 ^X39^X40 ^X43 ^X47^X48 ^X50^X51 ^X55^X56^X57 ^X60^X61 ^X63,
X0^X1 ^X6 ^X9 ^X13 ^X15^X16^X17 ^X19^X20 ^X26^X27 ^X29 ^X31 ^X34^X35^X36 ^X38^X39 ^X42 ^X46^X47 ^X49^X50 ^X54^X55^X56 ^X59^X60 ^X62,
X0 ^X9 ^X11^X12 ^X14 ^X16 ^X18^X19 ^X23^X24 ^X26^X27 ^X29 ^X31 ^X34^X35^X36^X37^X38 ^X41 ^X43^X44^X45 ^X47^X48 ^X52 ^X55 ^X57^X58 ^X60^X61^X62,
X5 ^X9^X10 ^X13 ^X17^X18 ^X22 ^X24 ^X26^X27 ^X29 ^X31 ^X34^X35 ^X37 ^X40 ^X42 ^X49 ^X51^X52^X53 ^X56 ^X61^X62,
X4 ^X8^X9 ^X12 ^X16^X17 ^X21 ^X23 ^X25^X26 ^X28 ^X30 ^X33^X34 ^X36 ^X39 ^X41 ^X48 ^X50^X51^X52 ^X55 ^X60^X61,
X3 ^X7^X8 ^X11 ^X15^X16 ^X20 ^X22 ^X24^X25 ^X27 ^X29 ^X32^X33 ^X35 ^X38 ^X40 ^X47 ^X49^X50^X51 ^X54 ^X59^X60,
X2 ^X6^X7 ^X10 ^X14^X15 ^X19 ^X21 ^X23^X24 ^X26 ^X28 ^X31^X32 ^X34 ^X37 ^X39 ^X46 ^X48^X49^X50 ^X53 ^X58^X59,
X1 ^X5^X6 ^X9 ^X13^X14 ^X18 ^X20 ^X22^X23 ^X25 ^X27 ^X30^X31 ^X33 ^X36 ^X38 ^X45 ^X47^X48^X49 ^X52 ^X57^X58,
X0 ^X4^X5 ^X8 ^X12^X13 ^X17 ^X19 ^X21^X22 ^X24 ^X26 ^X29^X30 ^X32 ^X35 ^X37 ^X44 ^X46^X47^X48 ^X51 ^X56^X57,
X3^X4^X5 ^X7^X8^X9 ^X12 ^X15^X16 ^X18 ^X20^X21 ^X24 ^X27 ^X30 ^X33^X34 ^X44^X45 ^X49^X50 ^X52^X53^X54^X55^X56^X57 ^X59^X60 ^X62,
X2^X3^X4 ^X6^X7^X8 ^X11 ^X14^X15 ^X17 ^X19^X20 ^X23 ^X26 ^X29 ^X32^X33 ^X43^X44 ^X48^X49 ^X51^X52^X53^X54^X55^X56 ^X58^X59 ^X61 ^X63,
X1^X2^X3 ^X5^X6^X7 ^X10 ^X13^X14 ^X16 ^X18^X19 ^X22 ^X25 ^X28 ^X31^X32 ^X42^X43 ^X47^X48 ^X50^X51^X52^X53^X54^X55 ^X57^X58 ^X60 ^X62,
X0^X1^X2 ^X4^X5^X6 ^X9 ^X12^X13 ^X15 ^X17^X18 ^X21 ^X24 ^X27 ^X30^X31 ^X41^X42 ^X46^X47 ^X49^X50^X51^X52^X53^X54 ^X56^X57 ^X59 ^X61 ^X63,
X0^X1 ^X3^X4 ^X9 ^X12 ^X14^X15^X16^X17 ^X20 ^X24^X25^X26^X27^X28 ^X31 ^X33 ^X36 ^X40^X41 ^X43^X44^X45 ^X47^X48 ^X50^X51 ^X54^X55^X56^X57^X58^X59,
X0 ^X2^X3 ^X5 ^X9 ^X13^X14 ^X16 ^X19 ^X26 ^X28^X29 ^X31^X32^X33 ^X35^X36 ^X39^X40 ^X42 ^X50 ^X52 ^X55^X56 ^X58^X59^X60 ^X62^X63,
X1^X2 ^X4^X5 ^X9 ^X11^X12^X13 ^X18 ^X23^X24 ^X29 ^X32^X33^X34^X35^X36 ^X38^X39 ^X41 ^X43^X44 ^X46^X47 ^X51^X52^X53 ^X55 ^X58 ^X60^X61,
X0^X1 ^X3^X4 ^X8 ^X10^X11^X12 ^X17 ^X22^X23 ^X28 ^X31^X32^X33^X34^X35 ^X37^X38 ^X40 ^X42^X43 ^X45^X46 ^X50^X51^X52 ^X54 ^X57 ^X59^X60 ^X63,
X0 ^X2^X3 ^X5 ^X7^X8 ^X10 ^X15^X16 ^X21^X22^X23^X24^X25 ^X28^X29 ^X32 ^X34 ^X37 ^X39 ^X41^X42^X43 ^X45^X46^X47 ^X50^X51^X52 ^X54 ^X56^X57^X58 ^X60,
X1^X2 ^X4^X5^X6^X7^X8 ^X11 ^X14 ^X20^X21^X22 ^X25 ^X29^X30 ^X38 ^X40^X41^X42^X43 ^X45 ^X47 ^X50^X51^X52 ^X54^X55^X56 ^X60 ^X62,
X0^X1 ^X3^X4^X5^X6^X7 ^X10 ^X13 ^X19^X20^X21 ^X24 ^X28^X29 ^X37 ^X39^X40^X41^X42 ^X44 ^X46 ^X49^X50^X51 ^X53^X54^X55 ^X59 ^X61 ^X63,
X0 ^X2^X3^X4 ^X6 ^X8 ^X11^X12 ^X15 ^X18^X19^X20 ^X24^X25 ^X29^X30^X31 ^X33 ^X38^X39^X40^X41 ^X44^X45^X46^X47^X48 ^X50 ^X57^X58^X59 ^X63,
X1^X2^X3 ^X7^X8^X9^X10 ^X14^X15 ^X17^X18^X19 ^X25 ^X27 ^X31^X32^X33 ^X36^X37^X38^X39^X40 ^X45 ^X52^X53^X54 ^X56 ^X58^X59^X60,
X0^X1^X2 ^X6^X7^X8^X9 ^X13^X14 ^X16^X17^X18 ^X24 ^X26 ^X30^X31^X32 ^X35^X36^X37^X38^X39 ^X44 ^X51^X52^X53 ^X55 ^X57^X58^X59,
X0^X1 ^X6^X7 ^X9 ^X11^X12^X13 ^X16^X17 ^X24 ^X27^X28 ^X33^X34^X35 ^X37^X38 ^X44 ^X46^X47 ^X49^X50^X51 ^X53 ^X56 ^X58^X59^X60 ^X62^X63,
X0 ^X6 ^X9^X10 ^X12 ^X16 ^X24^X25^X26 ^X28^X29^X30^X31^X32 ^X34 ^X37 ^X44^X45 ^X47^X48 ^X50 ^X53^X54^X55 ^X58 ^X60^X61 ^X63
}
*/
// Data terms depend ONLY on data in.
  wire    D63, D62, D61, D60, D59, D58, D57, D56, D55, D54, D53, D52;
  wire    D51, D50, D49, D48, D47, D46, D45, D44, D43, D42, D41, D40;
  wire    D39, D38, D37, D36, D35, D34, D33, D32;
  wire    D31, D30, D29, D28, D27, D26, D25, D24, D23, D22, D21, D20;
  wire    D19, D18, D17, D16, D15, D14, D13, D12, D11, D10, D9, D8;
  wire    D7, D6, D5, D4, D3, D2, D1, D0;
  assign  {D63, D62, D61, D60, D59, D58, D57, D56, D55, D54, D53, D52,
           D51, D50, D49, D48, D47, D46, D45, D44, D43, D42, D41, D40,
           D39, D38, D37, D36, D35, D34, D33, D32,
           D31, D30, D29, D28, D27, D26, D25, D24, D23, D22, D21, D20,
           D19, D18, D17, D16, D15, D14, D13, D12, D11, D10, D9, D8,
           D7, D6, D5, D4, D3, D2, D1, D0} =
           data_in_64[63 : 0];

// Calculate higher_order terms, to make parity trees.
// NOTE: In a Xilinx chip, it would be fine to constrain D0 and D0_1 to
//       be calculated in the same CLB, and so on for all bits.
  wire    D0_1   = D0  ^ D1;     wire    D1_2   = D1  ^ D2;
  wire    D2_3   = D2  ^ D3;     wire    D3_4   = D3  ^ D4;
  wire    D4_5   = D4  ^ D5;     wire    D5_6   = D5  ^ D6;
  wire    D6_7   = D6  ^ D7;     wire    D7_8   = D7  ^ D8;
  wire    D8_9   = D8  ^ D9;     wire    D9_10  = D9  ^ D10;
  wire    D10_11 = D10 ^ D11;    wire    D11_12 = D11 ^ D12;
  wire    D12_13 = D12 ^ D13;    wire    D13_14 = D13 ^ D14;
  wire    D14_15 = D14 ^ D15;    wire    D15_16 = D15 ^ D16;
  wire    D16_17 = D16 ^ D17;    wire    D17_18 = D17 ^ D18;
  wire    D18_19 = D18 ^ D19;    wire    D19_20 = D19 ^ D20;
  wire    D20_21 = D20 ^ D21;    wire    D21_22 = D21 ^ D22;
  wire    D22_23 = D22 ^ D23;    wire    D23_24 = D23 ^ D24;
  wire    D24_25 = D24 ^ D25;    wire    D25_26 = D25 ^ D26;
  wire    D26_27 = D26 ^ D27;    wire    D27_28 = D27 ^ D28;
  wire    D28_29 = D28 ^ D29;    wire    D29_30 = D29 ^ D30;
  wire    D30_31 = D30 ^ D31;    wire    D31_32 = D31 ^ D32;
  wire    D32_33 = D32 ^ D33;    wire    D33_34 = D33 ^ D34;
  wire    D34_35 = D34 ^ D35;    wire    D35_36 = D35 ^ D36;
  wire    D36_37 = D36 ^ D37;    wire    D37_38 = D37 ^ D38;
  wire    D38_39 = D38 ^ D39;    wire    D39_40 = D39 ^ D40;
  wire    D40_41 = D40 ^ D41;    wire    D41_42 = D41 ^ D42;
  wire    D42_43 = D42 ^ D43;    wire    D43_44 = D43 ^ D44;
  wire    D44_45 = D44 ^ D45;    wire    D45_46 = D45 ^ D46;
  wire    D46_47 = D46 ^ D47;    wire    D47_48 = D47 ^ D48;
  wire    D48_49 = D48 ^ D49;    wire    D49_50 = D49 ^ D50;
  wire    D50_51 = D50 ^ D51;    wire    D51_52 = D51 ^ D52;
  wire    D52_53 = D52 ^ D53;    wire    D53_54 = D53 ^ D54;
  wire    D54_55 = D54 ^ D55;    wire    D55_56 = D55 ^ D56;
  wire    D56_57 = D56 ^ D57;    wire    D57_58 = D57 ^ D58;
  wire    D58_59 = D58 ^ D59;    wire    D59_60 = D59 ^ D60;
  wire    D60_61 = D60 ^ D61;    wire    D61_62 = D61 ^ D62;
  wire    D62_63 = D62 ^ D63;

// Calculate terms which might have a single use.  They are calculated here
//   so that the parity trees can be balanced.

  wire    D5_11  = D5  ^ D11;    wire    D15_23 = D15 ^ D23;
  wire    D4_10  = D4  ^ D10;    wire    D14_22 = D14 ^ D22;
  wire    D3_9   = D3  ^ D9;     wire    D13_21 = D13 ^ D21;
  wire    D2_8   = D2  ^ D8;     wire    D12_20 = D12 ^ D20;
  wire    D1_7   = D1  ^ D7;     wire    D11_19 = D11 ^ D19;
  wire    D0_6   = D0  ^ D6;     wire    D10_18 = D10 ^ D18;
  wire    D8_11  = D8  ^ D11;    wire    D15_17 = D15 ^ D17;
  wire    D7_10  = D7  ^ D10;    wire    D14_16 = D14 ^ D16;
  wire    D6_9   = D6  ^ D9;     wire    D13_15 = D13 ^ D15;
  wire    D0_9   = D0  ^ D9;
  wire    D5_13  = D5  ^ D13;    wire    D22_24 = D22 ^ D24;
  wire    D4_12  = D4  ^ D12;    wire    D21_23 = D21 ^ D23;
  wire    D3_11  = D3  ^ D11;    wire    D20_22 = D20 ^ D22;
  wire    D2_10  = D2  ^ D10;    wire    D19_21 = D19 ^ D21;
  wire    D1_9   = D1  ^ D9;     wire    D18_20 = D18 ^ D20;
  wire    D0_8   = D0  ^ D8;     wire    D17_19 = D17 ^ D19;
  wire    D5_7   = D5  ^ D7;     wire    D12_18 = D12 ^ D18;
  wire    D4_6   = D4  ^ D6;     wire    D11_17 = D11 ^ D17;
  wire    D3_5   = D3  ^ D5;     wire    D10_16 = D10 ^ D16;
  wire    D2_4   = D2  ^ D4;     wire    D9_15  = D9  ^ D15;
  wire    D29_31 = D29 ^ D31;    wire    D37_40 = D37 ^ D40;
  wire    D28_30 = D28 ^ D30;    wire    D36_39 = D36 ^ D39;
  wire    D27_29 = D27 ^ D29;    wire    D35_38 = D35 ^ D38;
  wire    D26_28 = D26 ^ D28;    wire    D34_37 = D34 ^ D37;
  wire    D25_27 = D25 ^ D27;    wire    D33_36 = D33 ^ D36;
  wire    D24_26 = D24 ^ D26;    wire    D32_35 = D32 ^ D35;
  wire    D31_33 = D31 ^ D33;    wire    D30_32 = D30 ^ D32;
  wire    D36_49 = D36 ^ D49;    wire    D54_57 = D54 ^ D57;
  wire    D35_48 = D35 ^ D48;    wire    D53_56 = D53 ^ D56;
  wire    D34_47 = D34 ^ D47;    wire    D52_55 = D52 ^ D55;
  wire    D33_46 = D33 ^ D46;    wire    D51_54 = D51 ^ D54;
  wire    D32_45 = D32 ^ D45;    wire    D50_53 = D50 ^ D53;
  wire    D31_44 = D31 ^ D44;    wire    D49_52 = D49 ^ D52;
  wire    D38_44 = D38 ^ D44;    wire    D37_43 = D37 ^ D43;
  wire    D36_42 = D36 ^ D42;    wire    D38_41 = D38 ^ D41;
  wire    D59_61 = D59 ^ D61;    wire    D61_63 = D61 ^ D63;
  wire    D58_60 = D58 ^ D60;    wire    D57_59 = D57 ^ D59;
  wire    D57_63 = D57 ^ D63;    wire    D56_62 = D56 ^ D62;
  wire    D45_52 = D45 ^ D52;    wire    D55_60 = D55 ^ D60;
  wire    D42_49 = D42 ^ D49;    wire    D41_48 = D41 ^ D48;
  wire    D40_47 = D40 ^ D47;    wire    D39_46 = D39 ^ D46;
  wire    D38_45 = D38 ^ D45;
  wire    D37_44 = D37 ^ D44;    wire    D48_51 = D48 ^ D51;
  wire    D24_27 = D24 ^ D27;    wire    D30_52 = D30 ^ D52;
  wire    D23_26 = D23 ^ D26;    wire    D29_51 = D29 ^ D51;
  wire    D22_25 = D22 ^ D25;    wire    D28_50 = D28 ^ D50;
  wire    D21_24 = D21 ^ D24;    wire    D27_49 = D27 ^ D49;
  wire    D57_62 = D57 ^ D62;    wire    D56_61 = D56 ^ D61;
  wire    D54_59 = D54 ^ D59;
  wire    D9_12  = D9  ^ D12;    wire    D20_24 = D20 ^ D24;
  wire    D36_43 = D36 ^ D43;
  wire    D0_5   = D0  ^ D5;     wire    D9_16  = D9  ^ D16;
  wire    D19_26 = D19 ^ D26;    wire    D33_42 = D33 ^ D42;
  wire    D50_52 = D50 ^ D52;
  wire    D9_11  = D9  ^ D11;    wire    D18_29 = D18 ^ D29;
  wire    D36_41 = D36 ^ D41;
  wire    D53_55 = D53 ^ D55;
  wire    D8_10  = D8  ^ D10;    wire    D17_28 = D17 ^ D28;
  wire    D35_40 = D35 ^ D40;    wire    D52_54 = D52 ^ D54;
  wire    D10_21 = D10 ^ D21;    wire    D32_34 = D32 ^ D34;
  wire    D37_39 = D37 ^ D39;    wire    D43_45 = D43 ^ D45;
  wire    D14_20 = D14 ^ D20;    wire    D25_38 = D25 ^ D38;
  wire    D45_47 = D45 ^ D47;    wire    D60_62 = D60 ^ D62;
  wire    D13_19 = D13 ^ D19;
  wire    D24_37 = D24 ^ D37;    wire    D44_46 = D44 ^ D46;
  wire    D51_53 = D51 ^ D53;
  wire    D0_2   = D0  ^ D2;     wire    D6_8   = D6  ^ D8;
  wire    D15_18 = D15 ^ D18;
  wire    D48_50 = D48 ^ D50;    wire    D59_63 = D59 ^ D63;
  wire    D3_17  = D3  ^ D17;    wire    D56_58 = D56 ^ D58;
  wire    D2_16  = D2  ^ D16;    wire    D44_51 = D44 ^ D51;
  wire    D55_57 = D55 ^ D57;
  wire    D24_33 = D24 ^ D33;    wire    D44_49 = D44 ^ D49;
  wire    D12_16 = D12 ^ D16;    wire    D58_63 = D58 ^ D63;


// Need to distribute this logic so that it can be fast.  The user can
//   use 1 or 2 outputs, just so long as their XOR is the final value.

  assign  data_part_1_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =  // first half of each formula
   {  (((D5_11 ^ D8_9)   ^ (D15_23 ^D24_25)) ^ ((D27_28 ^D29_30) ^ (D31_33 ^D36_49))),
      (((D4_10 ^ D7_8)   ^ (D14_22 ^D23_24)) ^ ((D26_27 ^D28_29) ^ (D30_32 ^D35_48))),
      (((D3_9  ^ D6_7)   ^ (D13_21 ^D22_23)) ^ ((D25_26 ^D27_28) ^ (D29_31 ^D34_47))),
      (((D2_8  ^ D5_6)   ^ (D12_20 ^D21_22)) ^ ((D24_25 ^D26_27) ^ (D28_30 ^D33_46))),
      (((D1_7  ^ D4_5)   ^ (D11_19 ^D20_21)) ^ ((D23_24 ^D25_26) ^ (D27_29 ^D32_45))),
      (((D0_6  ^ D3_4)   ^ (D10_18 ^D19_20)) ^ ((D22_23 ^D24_25) ^ (D26_28 ^D31_44))),
      (((D2_3  ^ D8_11)  ^ (D15_17 ^D18_19)) ^ ((D21_22 ^D28_29) ^ (D31_33 ^D36_37))),
      (((D1_2  ^ D7_10)  ^ (D14_16 ^D17_18)) ^ ((D20_21 ^D27_28) ^ (D30_32 ^D35_36))),
      (((D0_1  ^ D6_9)   ^ (D13_15 ^D16_17)) ^ ((D19_20 ^D26_27) ^ (D29_31 ^D34_35))),
      (((D0_9  ^ D11_12) ^ (D14_16 ^D18_19)) ^ ((D23_24 ^D26_27) ^ (D29_31 ^D34_35))),
      (((D5_13 ^ D9_10)  ^ (D17_18 ^D22_24)) ^ ((D26_27 ^D29_31) ^ (D34_35 ^D37_40))),
      (((D4_12 ^ D8_9)   ^ (D16_17 ^D21_23)) ^ ((D25_26 ^D28_30) ^ (D33_34 ^D36_39))),
      (((D3_11 ^ D7_8)   ^ (D15_16 ^D20_22)) ^ ((D24_25 ^D27_29) ^ (D32_33 ^D35_38))),
      (((D2_10 ^ D6_7)   ^ (D14_15 ^D19_21)) ^ ((D23_24 ^D26_28) ^ (D31_32 ^D34_37))),
      (((D1_9  ^ D5_6)   ^ (D13_14 ^D18_20)) ^ ((D22_23 ^D25_27) ^ (D30_31 ^D33_36))),
      (((D0_8  ^ D4_5)   ^ (D12_13 ^D17_19)) ^ ((D21_22 ^D24_26) ^ (D29_30 ^D32_35))),
      (((D3_4  ^ D5_7)   ^ (D8_9   ^D12_18)) ^ ((D15_16 ^D20_21) ^ (D24_27 ^D30_52))),
      (((D2_3  ^ D4_6)   ^ (D7_8   ^D11_17)) ^ ((D14_15 ^D19_20) ^ (D23_26 ^D29_51))),
      (((D1_2  ^ D3_5)   ^ (D6_7   ^D10_16)) ^ ((D13_14 ^D18_19) ^ (D22_25 ^D28_50))),
      (((D0_1  ^ D2_4)   ^ (D5_6   ^D9_15))  ^ ((D12_13 ^D17_18) ^ (D21_24 ^D27_49))),
      (((D0_1  ^ D3_4)   ^ (D9_12  ^D14_15)) ^ ((D16_17 ^D20_24) ^ (D25_26 ^D27_28))),
      (((D0_5  ^ D2_3)   ^ (D9_16  ^D13_14)) ^ ((D19_26 ^D28_29) ^ (D31_32 ^D33_42))),
      (((D1_2  ^ D4_5)   ^ (D9_11  ^D12_13)) ^ ((D18_29 ^D23_24) ^ (D32_33 ^D34_35))),
      (((D0_1  ^ D3_4)   ^ (D8_10  ^D11_12)) ^ ((D17_28 ^D22_23) ^ (D31_32 ^D33_34))),
      (((D0_5  ^ D2_3)   ^ (D7_8   ^D10_21)) ^ ((D15_16 ^D22_23) ^ (D24_25 ^D28_29))),
      (((D1_2  ^ D4_5)   ^ (D6_7   ^D8_11))  ^ ((D14_20 ^D21_22) ^ (D25_38 ^D29_30))),
      (((D0_1  ^ D3_4)   ^ (D5_6   ^D7_10))  ^ ((D13_19 ^D20_21) ^ (D24_37 ^D28_29))),
      (((D0_2  ^ D3_4)   ^ (D6_8   ^D11_12)) ^ ((D15_18 ^D19_20) ^ (D24_25 ^D29_30))),
      (((D1_2  ^ D3_17)  ^ (D7_8   ^D9_10))  ^ ((D14_15 ^D18_19) ^ (D25_27 ^D31_32))),
      (((D0_1  ^ D2_16)  ^ (D6_7   ^D8_9))   ^ ((D13_14 ^D17_18) ^ (D24_26 ^D30_31))),
      (((D0_1  ^ D6_7)   ^ (D9_11  ^D12_13)) ^ ((D16_17 ^D24_33) ^ (D27_28 ^D34_35))),
      (((D0_6  ^ D9_10)  ^ (D12_16 ^D24_25)) ^ ((D26_28 ^D29_30) ^ (D31_32 ^D34_37)))
    };

  assign  data_part_2_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
   {  (((D43_44 ^ D46_47) ^ (D52_53 ^ D54_57)) ^ ((D59_60 ^ D62))),
      (((D42_43 ^ D45_46) ^ (D51_52 ^ D53_56)) ^ ((D58_59 ^ D61_63))),
      (((D41_42 ^ D44_45) ^ (D50_51 ^ D52_55)) ^ ((D57_58 ^ D60)    ^  D62_63)),
      (((D40_41 ^ D43_44) ^ (D49_50 ^ D51_54)) ^ ((D56_57 ^ D59_61) ^  D62_63)),
      (((D39_40 ^ D42_43) ^ (D48_49 ^ D50_53)) ^ ((D55_56 ^ D58_60) ^ (D61_62 ^ D63))),
      (((D38_39 ^ D41_42) ^ (D47_48 ^ D49_52)) ^ ((D54_55 ^ D57_59) ^ (D60_61 ^ D62))),
      (((D38_44 ^ D40_41) ^ (D48_49 ^ D51_52)) ^ ((D56_57 ^ D58)    ^  D61_62)),
      (((D37_43 ^ D39_40) ^ (D47_48 ^ D50_51)) ^ ((D55_56 ^ D57_63) ^  D60_61)),
      (((D36_42 ^ D38_39) ^ (D46_47 ^ D49_50)) ^ ((D54_55 ^ D56_62) ^  D59_60)),
      (((D36_37 ^ D38_41) ^ (D43_44 ^ D45_52)) ^ ((D47_48 ^ D55_60) ^ (D57_58 ^ D61_62))),
      (((D42_49 ^ D51_52) ^ (D53_56 ^ D61_62))),
      (((D41_48 ^ D50_51) ^ (D52_55 ^ D60_61))),
      (((D40_47 ^ D49_50) ^ (D51_54 ^ D59_60))),
      (((D39_46 ^ D48_49) ^ (D50_53 ^ D58_59))),
      (((D38_45 ^ D47_48) ^ (D49_52 ^ D57_58))),
      (((D37_44 ^ D46_47) ^ (D48_51 ^ D56_57))),
      (((D33_34 ^ D44_45) ^ (D49_50 ^ D53_54)) ^ ((D55_56 ^ D57_62) ^  D59_60)),
      (((D32_33 ^ D43_44) ^ (D48_49 ^ D52_53)) ^ ((D54_55 ^ D56_61) ^ (D58_59 ^ D63))),
      (((D31_32 ^ D42_43) ^ (D47_48 ^ D51_52)) ^ ((D53_54 ^ D55_60) ^ (D57_58 ^ D62))),
      (((D30_31 ^ D41_42) ^ (D46_47 ^ D50_51)) ^ ((D52_53 ^ D54_59) ^ (D56_57 ^ D61_63))),
      (((D31_33 ^ D36_43) ^ (D40_41 ^ D44_45)) ^ ((D47_48 ^ D50_51) ^ (D54_55 ^ D56_57))) ^ D58_59,
      (((D35_36 ^ D39_40) ^ (D50_52 ^ D55_56)) ^ ((D58_59 ^ D60)    ^  D62_63)),
      (((D36_41 ^ D38_39) ^ (D43_44 ^ D46_47)) ^ ((D51_52 ^ D53_55) ^ (D58    ^ D60_61))),
      (((D35_40 ^ D37_38) ^ (D42_43 ^ D45_46)) ^ ((D50_51 ^ D52_54) ^ (D57_63 ^ D59_60))),
      (((D32_34 ^ D37_39) ^ (D41_42 ^ D43_45)) ^ ((D46_47 ^ D50_51) ^ (D52_54 ^ D56_57))) ^ D58_60,
      (((D40_41 ^ D42_43) ^ (D45_47 ^ D50_51)) ^ ((D52_54 ^ D55_56) ^  D60_62)),
      (((D39_40 ^ D41_42) ^ (D44_46 ^ D49_50)) ^ ((D51_53 ^ D54_55) ^ (D59    ^ D61_63))),
      (((D31_33 ^ D38_39) ^ (D40_41 ^ D44_45)) ^ ((D46_47 ^ D48_50) ^ (D57_58 ^ D59_63))),
      (((D33_36 ^ D37_38) ^ (D39_40 ^ D45_52)) ^ ((D53_54 ^ D56_58) ^  D59_60)),
      (((D32_35 ^ D36_37) ^ (D38_39 ^ D44_51)) ^ ((D52_53 ^ D55_57) ^  D58_59)),
      (((D37_38 ^ D44_49) ^ (D46_47 ^ D50_51)) ^ ((D53_56 ^ D58_59) ^ (D60    ^ D62_63))),
      (((D44_45 ^ D47_48) ^ (D50_53 ^ D54_55)) ^ ((D58_63 ^ D60_61)))
    };
endmodule

module crc_32_64_crc_private (
  use_F_for_CRC,
  present_crc,
  crc_part_1_out, crc_part_2_out
);
  input   use_F_for_CRC;
  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] crc_part_1_out;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] crc_part_2_out;

/*
// CRC input dependencies
{
C1 ^C4 ^C11^C12 ^C14^C15 ^C17 ^C20^C21^C22 ^C25 ^C27^C28 ^C30,
C0 ^C3 ^C10^C11 ^C13^C14 ^C16 ^C19^C20^C21 ^C24 ^C26^C27 ^C29 ^C31,
C2 ^C9^C10 ^C12^C13 ^C15 ^C18^C19^C20 ^C23 ^C25^C26 ^C28 ^C30^C31,
C1 ^C8^C9 ^C11^C12 ^C14 ^C17^C18^C19 ^C22 ^C24^C25 ^C27 ^C29^C30^C31,
C0 ^C7^C8 ^C10^C11 ^C13 ^C16^C17^C18 ^C21 ^C23^C24 ^C26 ^C28^C29^C30^C31,
C6^C7 ^C9^C10 ^C12 ^C15^C16^C17 ^C20 ^C22^C23 ^C25 ^C27^C28^C29^C30,
C1 ^C4^C5^C6 ^C8^C9 ^C12 ^C16^C17 ^C19^C20 ^C24^C25^C26 ^C29^C30,
C0 ^C3^C4^C5 ^C7^C8 ^C11 ^C15^C16 ^C18^C19 ^C23^C24^C25 ^C28^C29 ^C31,
C2^C3^C4 ^C6^C7 ^C10 ^C14^C15 ^C17^C18 ^C22^C23^C24 ^C27^C28 ^C30,
C2^C3^C4^C5^C6 ^C9 ^C11^C12^C13 ^C15^C16 ^C20 ^C23 ^C25^C26 ^C28^C29^C30,
C2^C3 ^C5 ^C8 ^C10 ^C17 ^C19^C20^C21 ^C24 ^C29^C30,
C1^C2 ^C4 ^C7 ^C9 ^C16 ^C18^C19^C20 ^C23 ^C28^C29,
C0^C1 ^C3 ^C6 ^C8 ^C15 ^C17^C18^C19 ^C22 ^C27^C28,
C0 ^C2 ^C5 ^C7 ^C14 ^C16^C17^C18 ^C21 ^C26^C27,
C1 ^C4 ^C6 ^C13 ^C15^C16^C17 ^C20 ^C25^C26,
C0 ^C3 ^C5 ^C12 ^C14^C15^C16 ^C19 ^C24^C25,
C1^C2 ^C12^C13 ^C17^C18 ^C20^C21^C22^C23^C24^C25 ^C27^C28 ^C30,
C0^C1 ^C11^C12 ^C16^C17 ^C19^C20^C21^C22^C23^C24 ^C26^C27 ^C29 ^C31,
C0 ^C10^C11 ^C15^C16 ^C18^C19^C20^C21^C22^C23 ^C25^C26 ^C28 ^C30,
C9^C10 ^C14^C15 ^C17^C18^C19^C20^C21^C22 ^C24^C25 ^C27 ^C29 ^C31,
C1 ^C4 ^C8^C9 ^C11^C12^C13 ^C15^C16 ^C18^C19 ^C22^C23^C24^C25^C26^C27,
C0^C1 ^C3^C4 ^C7^C8 ^C10 ^C18 ^C20 ^C23^C24 ^C26^C27^C28 ^C30^C31,
C0^C1^C2^C3^C4 ^C6^C7 ^C9 ^C11^C12 ^C14^C15 ^C19^C20^C21 ^C23 ^C26 ^C28^C29,
C0^C1^C2^C3 ^C5^C6 ^C8 ^C10^C11 ^C13^C14 ^C18^C19^C20 ^C22 ^C25 ^C27^C28 ^C31,
C0 ^C2 ^C5 ^C7 ^C9^C10^C11 ^C13^C14^C15 ^C18^C19^C20 ^C22 ^C24^C25^C26 ^C28,
C6 ^C8^C9^C10^C11 ^C13 ^C15 ^C18^C19^C20 ^C22^C23^C24 ^C28 ^C30,
C5 ^C7^C8^C9^C10 ^C12 ^C14 ^C17^C18^C19 ^C21^C22^C23 ^C27 ^C29 ^C31,
C1 ^C6^C7^C8^C9 ^C12^C13^C14^C15^C16 ^C18 ^C25^C26^C27 ^C31,
C0^C1 ^C4^C5^C6^C7^C8 ^C13 ^C20^C21^C22 ^C24 ^C26^C27^C28,
C0 ^C3^C4^C5^C6^C7 ^C12 ^C19^C20^C21 ^C23 ^C25^C26^C27,
C1^C2^C3 ^C5^C6 ^C12 ^C14^C15 ^C17^C18^C19 ^C21 ^C24 ^C26^C27^C28 ^C30^C31,
C0 ^C2 ^C5 ^C12^C13 ^C15^C16 ^C18 ^C21^C22^C23 ^C26 ^C28^C29 ^C31        
}
 */
// CRC terms depend ONLY on CRC data from the previous clock
  wire    C31, C30, C29, C28, C27, C26, C25, C24, C23, C22, C21, C20, C19, C18, C17;
  wire    C16, C15, C14, C13, C12, C11, C10, C9, C8, C7, C6, C5, C4, C3, C2, C1, C0;
  assign  {C31, C30, C29, C28, C27, C26, C25, C24,
           C23, C22, C21, C20, C19, C18, C17, C16, C15, C14, C13, C12,
           C11, C10, C9,  C8,  C7,  C6,  C5,  C4,  C3,  C2,  C1,  C0} =
           present_crc[`NUMBER_OF_BITS_IN_CRC- 1 : 0]
         | {`NUMBER_OF_BITS_IN_CRC{use_F_for_CRC}};

  wire    C0_1   = C0  ^ C1;     wire    C1_2   = C1  ^ C2;
  wire    C2_3   = C2  ^ C3;     wire    C3_4   = C3  ^ C4;
  wire    C4_5   = C4  ^ C5;     wire    C5_6   = C5  ^ C6;
  wire    C6_7   = C6  ^ C7;     wire    C7_8   = C7  ^ C8;
  wire    C8_9   = C8  ^ C9;     wire    C9_10  = C9  ^ C10;
  wire    C10_11 = C10 ^ C11;    wire    C11_12 = C11 ^ C12;
  wire    C12_13 = C12 ^ C13;    wire    C13_14 = C13 ^ C14;
  wire    C14_15 = C14 ^ C15;    wire    C15_16 = C15 ^ C16;
  wire    C16_17 = C16 ^ C17;    wire    C17_18 = C17 ^ C18;
  wire    C18_19 = C18 ^ C19;    wire    C19_20 = C19 ^ C20;
  wire    C20_21 = C20 ^ C21;    wire    C21_22 = C21 ^ C22;
  wire    C22_23 = C22 ^ C23;    wire    C23_24 = C23 ^ C24;
  wire    C24_25 = C24 ^ C25;    wire    C25_26 = C25 ^ C26;
  wire    C26_27 = C26 ^ C27;    wire    C27_28 = C27 ^ C28;
  wire    C28_29 = C28 ^ C29;    wire    C29_30 = C29 ^ C30;
  wire    C30_31 = C30 ^ C31;

// Calculate terms which might have a single use.  They are calculated here
//   so that the parity trees can be balanced.
  wire    C1_4 =   C1  ^ C4;     wire    C0_3   = C0  ^ C3;
  wire    C0_2 =   C0  ^ C2;     wire    C5_7   = C5  ^ C7;
  wire    C17_20 = C17 ^ C20;    wire    C25_30 = C25 ^ C30;
  wire    C16_19 = C16 ^ C19;    wire    C24_31 = C24 ^ C31;
  wire    C2_15  = C2  ^ C15;    wire    C18_23 = C18 ^ C23;
  wire    C1_14  = C1  ^ C14;    wire    C17_22 = C17 ^ C22;
  wire    C0_13  = C0  ^ C13;    wire    C16_21 = C16 ^ C21;
  wire    C27_29 = C27 ^ C29;    wire    C12_15 = C12 ^ C15;
  wire    C20_25 = C20 ^ C25;    wire    C12_24 = C12 ^ C24; 
  wire    C11_23 = C11 ^ C23;    wire    C4_10  = C4  ^ C10;  
  wire    C24_30 = C24 ^ C30;    wire    C6_9   = C6  ^ C9;
  wire    C13_20 = C13 ^ C20;    wire    C23_28 = C23 ^ C28; 
  wire    C5_8   = C5  ^ C8;     wire    C10_17 = C10 ^ C17; 
  wire    C21_24 = C21 ^ C24;    wire    C4_7   = C4  ^ C7;
  wire    C9_16  = C9  ^ C16;    wire    C20_23 = C20 ^ C23;
  wire    C3_6   = C3  ^ C6;     wire    C8_15  = C8  ^ C15; 
  wire    C19_22 = C19 ^ C22;    wire    C14_16 = C14 ^ C16; 
  wire    C6_13 =  C6  ^ C13;    wire    C15_20 = C15 ^ C20; 
  wire    C5_12 =  C5  ^ C12;    wire    C14_19 = C14 ^ C19; 
  wire    C29_31 = C29 ^ C31;    wire    C28_30 = C28 ^ C30;
  wire    C10_18 = C10 ^ C18;    wire    C20_26 = C20 ^ C26; 
  wire    C4_9   = C4  ^ C9;     wire    C21_23 = C21 ^ C23;
  wire    C8_18  = C8  ^ C18;    wire    C22_25 = C22 ^ C25;
  wire    C11_13 = C11 ^ C13;    wire    C20_22 = C20 ^ C22; 
  wire    C26_28 = C26 ^ C28;    wire    C15_18 = C15 ^ C18;
  wire    C14_17 = C14 ^ C17;    wire    C23_27 = C23 ^ C27; 
  wire    C1_12  = C1  ^ C12;    wire    C18_25 = C18 ^ C25; 
  wire    C8_13  = C8  ^ C13;    wire    C22_24 = C22 ^ C24;
  wire    C12_19 = C12 ^ C19;    wire    C23_25 = C23 ^ C25;
  wire    C3_12  = C3  ^ C12;    wire    C19_21 = C19 ^ C21;
  wire    C24_26 = C24 ^ C26;    wire    C5_18  = C5  ^ C18;
  wire    C23_26 = C23 ^ C26;   

  assign  crc_part_1_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
    { 
     (C1_4  ^ C11_12) ^ (C14_15 ^ C17_20),
     (C0_3  ^ C10_11) ^ (C13_14 ^ C16_19),
     (C2_15 ^ C9_10)  ^ (C12_13 ^ C18_23),
     (C1_14 ^ C8_9)   ^ (C11_12 ^ C17_22),
     (C0_13 ^ C7_8)   ^ (C10_11 ^ C16_21),
     (C6_7  ^ C9_10)  ^ (C12_15 ^ C16_17),
     (C1_4  ^ C5_6)   ^ (C8_9   ^ C12_24),
     (C0_3  ^ C4_5)   ^ (C7_8   ^ C11_23),
     (C2_3  ^ C4_10)  ^ (C6_7   ^ C14_15),
     (C2_3  ^ C4_5)   ^ (C6_9   ^ C11_12),
     (C2_3  ^ C5_8)   ^ (C10_17 ^ C19_20),
     (C1_2  ^ C4_7)   ^ (C9_16  ^ C18_19),
     (C0_1  ^ C3_6)   ^ (C8_15  ^ C17_18),
     (C0_2  ^ C5_7)   ^ (C14_16 ^ C17_18),
     (C1_4  ^ C6_13)  ^ (C15_20 ^ C16_17),
     (C0_3  ^ C5_12)  ^ (C14_19 ^ C15_16),
     (C1_2  ^ C12_13) ^ (C17_18 ^ C20_21),
     (C0_1  ^ C11_12) ^ (C16_17 ^ C19_20),
     (C0    ^ C10_11) ^ (C15_16 ^ C18_19),
     (C9_10 ^ C14_15) ^ (C17_18 ^ C19_20),
     (C1_4  ^ C8_9)   ^ (C11_12 ^ C13),
     (C0_1  ^ C3_4)   ^ (C7_8   ^ C10_18),
     (C0_1  ^ C2_3)   ^ (C4_9   ^ C6_7),
     (C0_1  ^ C2_3)   ^ (C5_6   ^ C8_18),
     (C0_2  ^ C5_7)   ^ (C9_10  ^ C11_13),
     (C6_13 ^ C8_9)   ^ (C10_11 ^ C15_18),
     (C5_12 ^ C7_8)   ^ (C9_10  ^ C14_17),
     (C1_12 ^ C6_7)   ^ (C8_9   ^ C13_14),
     (C0_1  ^ C4_5)   ^ (C6_7   ^ C8_13),
     (C0_3  ^ C4_5)   ^ (C6_7   ^ C12_19),
     (C1_2  ^ C3_12)  ^ (C5_6   ^ C14_15),
     (C0_2  ^ C5_18)  ^ (C12_13 ^ C15_16)
    };

  assign  crc_part_2_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
    {
     (C21_22 ^ C25_30) ^ (C27_28         ),
     (C20_21 ^ C24_31) ^ (C26_27 ^ C29   ),
     (C19_20 ^ C25_26) ^ (C28    ^ C30_31),
     (C18_19 ^ C24_25) ^ (C27_29 ^ C30_31),
     (C17_18 ^ C23_24) ^ (C26    ^ C28_29) ^ (C30_31),
     (C20_25 ^ C22_23) ^ (C27_28 ^ C29_30),
     (C16_17 ^ C19_20) ^ (C25_26 ^ C29_30),
     (C15_16 ^ C18_19) ^ (C24_25 ^ C28_29) ^ (C31),
     (C17_18 ^ C22_23) ^ (C24_30 ^ C27_28),
     (C13_20 ^ C15_16) ^ (C23_28 ^ C25_26) ^ (C29_30),
     (C21_24 ^ C29_30),
     (C20_23 ^ C28_29),
     (C19_22 ^ C27_28),
     (C21    ^ C26_27),
     (C25_26),
     (C24_25),
     (C22_23 ^ C24_25) ^ (C27_28 ^ C30),
     (C21_22 ^ C23_24) ^ (C26_27 ^ C29_31),
     (C20_21 ^ C22_23) ^ (C25_26 ^ C28_30),
     (C21_22 ^ C24_25) ^ (C27    ^ C29_31),
     (C15_16 ^ C18_19) ^ (C22_23 ^ C24_25) ^ (C26_27),
     (C20_26 ^ C23_24) ^ (C27_28 ^ C30_31),
     (C11_12 ^ C14_15) ^ (C19_20 ^ C21_23) ^ (C26 ^ C28_29),
     (C10_11 ^ C13_14) ^ (C19_20 ^ C22_25) ^ (C27_28 ^ C31),
     (C14_15 ^ C18_19) ^ (C20_22 ^ C24_25) ^ (C26_28),
     (C19_20 ^ C22_23) ^ (C24    ^ C28_30),
     (C18_19 ^ C21_22) ^ (C23_27 ^ C29_31),
     (C15_16 ^ C18_25) ^ (C26_27 ^ C31),
     (C20_21 ^ C22_24) ^ (C26_27 ^ C28),
     (C20_21 ^ C23_25) ^ (C26_27),
     (C17_18 ^ C19_21) ^ (C24_26 ^ C27_28) ^ (C30_31),
     (C21_22 ^ C23_26) ^ (C28_29 ^ C31)     
    };
endmodule

module crc_32_64_private (
  use_F_for_CRC,
  present_crc,
  data_in_64,
  next_crc
);
  parameter NUMBER_OF_BITS_APPLIED = 64;
  input   use_F_for_CRC;
  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [NUMBER_OF_BITS_APPLIED - 1 : 0] data_in_64;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

// There are 2 obvious ways to implement these functions:
// 1) XOR the State bits with the Input bits, then calculate the XOR's
// 2) Independently calculate a result for Inputs and State variables,
//    then XOR the results together.
// Once the applied data width > CRC size, it seems best to use the second technique.
// The formulas for each output term are seen to have a large number of
//   terms depending on input data, and a smaller number of terms dependent
//   on the initial value of the CRC.
// Calculate the Data component of the dependency.  This can be done in
//   a pipelined fashion, since it doesn't matter how long it takes.
// Calculate the CRC component of the dependency.  Each clock this must
//   be XOR'd with the correctly time-aligned Data component, and the
//   results must be put back in the running CRC latches.
// It looks like 64 bits per clock may be FASTER than 32 bits per clock,
//   because the Data dependency can be done in several clocks.

// Instantiate the Data part of the dependency.
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] data_part_1_out;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] data_part_2_out;

crc_32_64_data_private crc_32_64_data_part (
  .data_in_64                 (data_in_64[NUMBER_OF_BITS_APPLIED - 1 : 0]),
  .data_part_1_out            (data_part_1_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_part_2_out            (data_part_2_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] data_depend_part =
                    data_part_1_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0]
                  ^ data_part_2_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0];

// Instantiate the CRC part of the dependency.
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] crc_part_1_out;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] crc_part_2_out;

crc_32_64_crc_private crc_32_64_crc_part (
  .use_F_for_CRC              (use_F_for_CRC),
  .present_crc                (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .crc_part_1_out             (crc_part_1_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .crc_part_2_out             (crc_part_2_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] first_part =
                    data_depend_part[`NUMBER_OF_BITS_IN_CRC - 1 : 0]
                  ^ crc_part_1_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0];  // source depth 4 gates

  assign  next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                    first_part[`NUMBER_OF_BITS_IN_CRC - 1 : 0]
                  ^ crc_part_2_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0];  // source depth 5 gates
endmodule

module crc_32_64_pipelined_2 (
  use_F_for_CRC,
  data_in_64,
  running_crc,
  clk
);
  parameter NUMBER_OF_BITS_APPLIED = 64;
  input   use_F_for_CRC;
  input  [NUMBER_OF_BITS_APPLIED - 1 : 0] data_in_64;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] running_crc;
  input   clk;

// A pipelined version of the CRC_32 working on 64-bit operands.
// Latch all operands at Clock 1.
// Calculate the Data Dependency during Clock 2.
// Update the CRC during Clock 3.
// NOTE: The CRC comes out after Clock 3.

// Latch all operands at Clock 1.
  reg     use_F_for_CRC_latched;
  reg    [NUMBER_OF_BITS_APPLIED - 1 : 0] data_in_64_latched;

  always @(posedge clk)
  begin
    use_F_for_CRC_latched <= use_F_for_CRC;
    data_in_64_latched[NUMBER_OF_BITS_APPLIED - 1 : 0] <=
                  data_in_64[NUMBER_OF_BITS_APPLIED - 1 : 0];
  end

// Instantiate the Data part of the dependency.
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] data_part_1_out;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] data_part_2_out;

crc_32_64_data_private crc_32_64_data_part (
  .data_in_64                 (data_in_64[NUMBER_OF_BITS_APPLIED - 1 : 0]),
  .data_part_1_out            (data_part_1_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_part_2_out            (data_part_2_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

// Calculate the Data Dependency during Clock 2.
  reg     use_F_for_CRC_prev;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] data_part_1_latched;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] data_part_2_latched;

  always @(posedge clk)
  begin
    use_F_for_CRC_prev <= use_F_for_CRC_latched;
    data_part_1_latched[`NUMBER_OF_BITS_IN_CRC - 1 : 0] <=
                  data_part_1_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    data_part_2_latched[`NUMBER_OF_BITS_IN_CRC - 1 : 0] <=
                  data_part_2_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
  end

// Update the CRC during Clock 3.
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;

  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] crc_part_1_out;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] crc_part_2_out;

crc_32_64_crc_private crc_32_64_crc_part (
  .use_F_for_CRC              (use_F_for_CRC_prev),
  .present_crc                (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .crc_part_1_out             (crc_part_1_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .crc_part_2_out             (crc_part_2_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] data_depend_part =
                    data_part_1_latched[`NUMBER_OF_BITS_IN_CRC - 1 : 0]
                  ^ data_part_2_latched[`NUMBER_OF_BITS_IN_CRC - 1 : 0];  // source depth 2 gates

  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] first_crc_part =
                    data_depend_part[`NUMBER_OF_BITS_IN_CRC - 1 : 0]
                  ^ crc_part_1_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0];  // source depth 4 gates

  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc =
                    first_crc_part[`NUMBER_OF_BITS_IN_CRC - 1 : 0]
                  ^ crc_part_2_out[`NUMBER_OF_BITS_IN_CRC - 1 : 0];  // source depth 5 gates

  always @(posedge clk)
  begin
    present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] <=
                  next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
  end

  assign  running_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                  present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
endmodule


// `define CALCULATE_FUNCTIONAL_DEPENDENCE_ON_INPUT_AND_STATE
`ifdef CALCULATE_FUNCTIONAL_DEPENDENCE_ON_INPUT_AND_STATE

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

module print_out_formulas ();

  parameter NUM_BITS_TO_DO_IN_PARALLEL = 8'h40;

  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] running_state;
  reg    [63:0] input_vector;
  reg     xor_value;
  integer i, j, remaining_length;

  reg    [2047:0] corner_turner;  // 32 bits * 64 shifts

  initial
  begin
    $display ("Calculating functional dependence on input bits, for %d bits.  Rightmost bit is State Bit 0.",
                 NUM_BITS_TO_DO_IN_PARALLEL);
    for (i = 0; i < NUM_BITS_TO_DO_IN_PARALLEL; i = i + 1)
    begin
      running_state = {`NUMBER_OF_BITS_IN_CRC{1'b0}};
      input_vector = 64'h80000000_00000000;  // MSB first for this program
      for (j = 0; j < i + 1; j = j + 1)
      begin
        xor_value = input_vector[63] ^ running_state[`NUMBER_OF_BITS_IN_CRC - 1];
        running_state[`NUMBER_OF_BITS_IN_CRC - 1 : 0] = xor_value
                  ? {running_state[`NUMBER_OF_BITS_IN_CRC - 2 : 0], 1'b0} ^ `CRC
                  : {running_state[`NUMBER_OF_BITS_IN_CRC - 2 : 0], 1'b0};
        input_vector[63 : 0] =
                    {input_vector[62 : 0], 1'b0};
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

// Count out formulas in the opposite order, write out valid formulas.
    $display ("When the amount of data applied to the CRC is less than the length of the CRC itself,");
    $display ("  the Most Significant CRC_LEN - CRC_WIDTH terms are of the form data_in[N] ^ State[N].");
    $display ("The next CRC_WIDTH terms are NOT dependent on the CRC values, except in so much as");
    $display ("  they depend on CSR bits because of X = D ^ C terms.");
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

    if (NUM_BITS_TO_DO_IN_PARALLEL <= `NUMBER_OF_BITS_IN_CRC)
    begin
      remaining_length = NUM_BITS_TO_DO_IN_PARALLEL - 1;
    end
    else
    begin
      remaining_length = `NUMBER_OF_BITS_IN_CRC - 1;
    end
    for (i = remaining_length; i >= 0; i = i - 1)
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
   
      if (NUM_BITS_TO_DO_IN_PARALLEL <= `NUMBER_OF_BITS_IN_CRC)
      begin
        remaining_length = NUM_BITS_TO_DO_IN_PARALLEL - 1;
      end
      else
      begin
        remaining_length = `NUMBER_OF_BITS_IN_CRC - 1;
      end
      for (i = remaining_length; i >= 0; i = i - 1)
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

    if (NUM_BITS_TO_DO_IN_PARALLEL <= `NUMBER_OF_BITS_IN_CRC)
    begin
      $display ("Since the number of data bits applied is <= number of CRC bits, each");
      $display ("  X term in these formulas corresponds to X = Data_In ^ State");
    end
    else
    begin
      $display ("The number of bits being applied to the CRC is greater than the number of");
      $display ("  bits in the CRC.  Each X term in these formulas corersponds to a Data_In bit.");
      $display ("If the shift distance was small, the original CRC bits would be XOR'd with");
      $display ("  the new data.  In this case, the shift distance per clock is large, so the");
      $display ("  dependence on the original CRC bits has to be handled carefully.");
      $display ("Here is the plan: Calculate the contribution due to the incoming data based");
      $display ("  on the formulas produced for a particular shift distance.");
      $display ("Separately, calculate the data dependence due to the present CRC.");
      $display ("This is accomplished by using the HIGH numbered terms discovered when tracking");
      $display ("  data dependencies.  For instance, if the shift distance is");
      $display ("  64 and the CRC is 32 bits wide, the top 32 X terms of each of the formulas");
      $display ("  is re-interpreted as C (state) terms.");
      $display ("The terms depending on X63 : X32 are re-interpred to be terms depending on");
      $display ("  CSR bits 31 : 0 correspondingly");
      $display ("{");
      for (i = `NUMBER_OF_BITS_IN_CRC - 1; i >= 0; i = i - 1)
      begin  // Bits which depend on shifted state bits directly
        $write ("%d : ", i);
        for (j = `NUMBER_OF_BITS_IN_CRC;
             j < NUM_BITS_TO_DO_IN_PARALLEL +`NUMBER_OF_BITS_IN_CRC;
             j = j + 1)
        begin
          if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                            != 1'b0)
            $write (" ^ C%0d", j[5:0] - `NUMBER_OF_BITS_IN_CRC);
          else if (j >= 10) $write ("      "); else $write ("     ");
        end
        if (i != 0) $write (",\n"); else $write ("\n");
      end
      $display ("}");
    end
  end
endmodule
`endif  // CALCULATE_FUNCTIONAL_DEPENDENCE_ON_INPUT_AND_STATE


 `define COMPARE_PARALLEL_VERSIONS_AGAINST_SERIAL_VERSION_FOR_DEBUG
`ifdef COMPARE_PARALLEL_VERSIONS_AGAINST_SERIAL_VERSION_FOR_DEBUG
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
  reg    [7:0] data_in_8;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc_8;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc_8;
  reg    [15:0] data_in_16;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc_16;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc_16;
  reg    [23:0] data_in_24;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc_24;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc_24;
  reg    [31:0] data_in_32;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc_32;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc_32;
  reg    [63:0] data_in_64;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc_64;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc_64;


// Assign data_in_8 before invoking.  This consumes data MSB first
task apply_1_8_to_crc;
  integer j;
  begin
    #0 ;
    present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                            next_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    for (j = 0; j < 8; j = j + 1)  // apply data bit at a time
    begin
      #0 ;
      present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                            next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
      data_in_8[7:0] = {data_in_8[6:0], 1'b0};  // Shift byte out MSB first
      use_F_for_CRC = 1'b0;
    end
  end
endtask

task apply_16_to_crc;
  integer j;
  begin
    #0 ;
    present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =  // remember: apply 16 bits
                            next_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    use_F_for_CRC = 1'b0;
  end
endtask

task apply_24_to_crc;
  integer j;
  begin
    #0 ;
    present_crc_24[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =  // remember: apply 24 bits
                            next_crc_24[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    use_F_for_CRC = 1'b0;
  end
endtask

task apply_32_to_crc;
  integer j;
  begin
    #0 ;
    present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =  // remember: apply 32 bits
                            next_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    use_F_for_CRC = 1'b0;
  end
endtask

task apply_64_to_crc;
  integer j;
  begin
    #0 ;
    present_crc_64[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =  // remember: apply 64 bits
                            next_crc_64[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    use_F_for_CRC = 1'b0;
  end
endtask

  initial
  begin
    #10;
    $display ("running serial version of code against parallel versions");
    use_F_for_CRC = 1'b1;
    for (i = 0; i < 43; i = i + 1)
    begin
      data_in_8[7:0] = 8'h00;
      apply_1_8_to_crc;
    end
    data_in_8[7:0] = 8'h28;
    apply_1_8_to_crc;
    if (~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'h864D7F99)
      $display ("*** 1-bit after 40 bytes of 1'b0, I want 32'h864D7F99, I get 32\`h%x",
                 ~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    if (~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'h864D7F99)
      $display ("*** 8-bit after 40 bytes of 1'b0, I want 32'h864D7F99, I get 32\`h%x",
                 ~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_8[7:0] = 8'h86;
    apply_1_8_to_crc;
    data_in_8[7:0] = 8'h4D;
    apply_1_8_to_crc;
    data_in_8[7:0] = 8'h7F;
    apply_1_8_to_crc;
    data_in_8[7:0] = 8'h99;
    apply_1_8_to_crc;
//        The receiver sees the value 32'hC704DD7B when the message is
//          received no errors.  Bit reversed, that is 32'hDEBB20E3.
    if (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 1-bit 0's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    if (present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 8-bit 0's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    data_in_16[15:0] = 16'h0000;
    for (i = 0; i < 21; i = i + 1)
    begin
      apply_16_to_crc;
    end
    data_in_16[15:0] = 16'h0028;
    apply_16_to_crc;
    if (~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'h864D7F99)
      $display ("*** 16-bit after 40 bytes of 1'b0, I want 32'h864D7F99, I get 32\`h%x",
                 ~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_16[15:0] = 16'h864D;
    apply_16_to_crc;
    data_in_16[15:0] = 16'h7F99;
    apply_16_to_crc;
    if (present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 16-bit 0's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    data_in_24[23:0] = 24'h000000;
    for (i = 0; i < 14; i = i + 1)
    begin
      apply_24_to_crc;
    end
    present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                                  present_crc_24[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    data_in_16[15:0] = 16'h0028;
    apply_16_to_crc;
    if (~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'h864D7F99)
      $display ("*** 24-bit after 40 bytes of 1'b0, I want 32'h864D7F99, I get 32\`h%x",
                 ~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_16[15:0] = 16'h864D;
    apply_16_to_crc;
    data_in_16[15:0] = 16'h7F99;
    apply_16_to_crc;
    if (present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 24-bit 0's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    data_in_32[31:0] = 32'h00000000;
    for (i = 0; i < 10; i = i + 1)
    begin
      apply_32_to_crc;
    end
    data_in_32[31:0] = 32'h00000028;
    apply_32_to_crc;
    if (~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'h864D7F99)
      $display ("*** 32-bit after 40 bytes of 1'b0, I want 32'h864D7F99, I get 32\`h%x",
                 ~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_32[31:0] = 32'h864D7F99;
    apply_32_to_crc;
    if (present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 32-bit 0's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

// NOTE:  WORKING:  add 48

    use_F_for_CRC = 1'b1;
    data_in_64[63:0] = 64'h00000000_00000000;
    for (i = 0; i < 5; i = i + 1)
    begin
      apply_64_to_crc;
    end
    present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                                  present_crc_64[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    data_in_32[31:0] = 32'h00000028;
    apply_32_to_crc;
    if (~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'h864D7F99)
      $display ("*** 64-bit after 40 bytes of 1'b0, I want 32'h864D7F99, I get 32\`h%x",
                 ~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_32[31:0] = 32'h864D7F99;
    apply_32_to_crc;
    if (present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 64-bit 0's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);


    use_F_for_CRC = 1'b1;
    for (i = 0; i < 40; i = i + 1)
    begin
      data_in_8[7:0] = 8'hFF;
      apply_1_8_to_crc;
    end
    for (i = 0; i < 3; i = i + 1)
    begin
      data_in_8[7:0] = 8'h00;
      apply_1_8_to_crc;
    end
    data_in_8[7:0] = 8'h28;
    apply_1_8_to_crc;
    if (~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC55E457A)
      $display ("*** 1-bit after 40 bytes of 1'b1, I want 32'hC55E457A, I get 32\`h%x",
                 ~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    if (~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC55E457A)
      $display ("*** 8-bit after 40 bytes of 1'b1, I want 32'hC55E457A, I get 32\`h%x",
                 ~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_8[7:0] = 8'hC5;
    apply_1_8_to_crc;
    data_in_8[7:0] = 8'h5E;
    apply_1_8_to_crc;
    data_in_8[7:0] = 8'h45;
    apply_1_8_to_crc;
    data_in_8[7:0] = 8'h7A;
    apply_1_8_to_crc;
    if (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 1-bit 1's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    if (present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 8-bit 1's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    data_in_16[15:0] = 16'hFFFF;
    for (i = 0; i < 20; i = i + 1)
    begin
      apply_16_to_crc;
    end
    data_in_16[15:0] = 16'h0000;
    apply_16_to_crc;
    data_in_16[15:0] = 16'h0028;
    apply_16_to_crc;
    if (~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC55E457A)
      $display ("*** 16-bit after 40 bytes of 1'b1, I want 32'hC55E457A, I get 32\`h%x",
                 ~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_16[15:0] = 16'hC55E;
    apply_16_to_crc;
    data_in_16[15:0] = 16'h457A;
    apply_16_to_crc;
    if (present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 16-bit 1's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    data_in_24[23:0] = 24'hFFFFFF;
    for (i = 0; i < 13; i = i + 1)
    begin
      apply_24_to_crc;
    end
    present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                                  present_crc_24[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    data_in_8[7:0] = 8'hFF;
    apply_1_8_to_crc;
    present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                                  present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    data_in_16[15:0] = 16'h0000;
    apply_16_to_crc;
    data_in_16[15:0] = 16'h0028;
    apply_16_to_crc;
    if (~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC55E457A)
      $display ("*** 24-bit after 40 bytes of 1'b1, I want 32'hC55E457A, I get 32\`h%x",
                 ~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_16[15:0] = 16'hC55E;
    apply_16_to_crc;
    data_in_16[15:0] = 16'h457A;
    apply_16_to_crc;
    if (present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 24-bit 1's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    data_in_32[31:0] = 32'hFFFFFFFF;
    for (i = 0; i < 10; i = i + 1)
    begin
      apply_32_to_crc;
    end
    data_in_32[31:0] = 32'h00000028;
    apply_32_to_crc;
    if (~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC55E457A)
      $display ("*** 32-bit after 40 bytes of 1'b1, I want 32'hC55E457A, I get 32\`h%x",
                 ~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_32[31:0] = 32'hC55E457A;
    apply_32_to_crc;
    if (present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 32-bit 1's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

// NOTE:  WORKING:  add 48

    use_F_for_CRC = 1'b1;
    data_in_64[63:0] = 64'hFFFFFFFF_FFFFFFFF;
    for (i = 0; i < 5; i = i + 1)
    begin
      apply_64_to_crc;
    end
    present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                                  present_crc_64[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    data_in_32[31:0] = 32'h00000028;
    apply_32_to_crc;
    if (~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC55E457A)
      $display ("*** 64-bit after 40 bytes of 1'b1, I want 32'hC55E457A, I get 32\`h%x",
                 ~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_32[31:0] = 32'hC55E457A;
    apply_32_to_crc;
    if (present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 64-bit 1's after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);


    use_F_for_CRC = 1'b1;
    for (i = 0; i < 40; i = i + 1)
    begin
      data_in_8[7:0] = i + 1;
      apply_1_8_to_crc;
    end
    for (i = 0; i < 3; i = i + 1)
    begin
      data_in_8[7:0] = 8'h00;
      apply_1_8_to_crc;
    end
    data_in_8[7:0] = 8'h28;
    apply_1_8_to_crc;
    if (~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hBF671ED0)
      $display ("*** 1-bit after 40 bytes of i+1, I want 32'hBF671ED0, I get 32\`h%x",
                 ~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    if (~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hBF671ED0)
      $display ("*** 8-bit after 40 bytes of i+1, I want 32'hBF671ED0, I get 32\`h%x",
                 ~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_8[7:0] = 8'hBF;
    apply_1_8_to_crc;
    data_in_8[7:0] = 8'h67;
    apply_1_8_to_crc;
    data_in_8[7:0] = 8'h1E;
    apply_1_8_to_crc;
    data_in_8[7:0] = 8'hD0;
    apply_1_8_to_crc;
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
      apply_16_to_crc;
    end
    data_in_16[15:0] = 16'h0000;
    apply_16_to_crc;
    data_in_16[15:0] = 16'h0028;
    apply_16_to_crc;
    if (~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hBF671ED0)
      $display ("*** 16-bit after 40 bytes of i+1, I want 32'hBF671ED0, I get 32\`h%x",
                 ~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_16[15:0] = 16'hBF67;
    apply_16_to_crc;
    data_in_16[15:0] = 16'h1ED0;
    apply_16_to_crc;
    if (present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 16-bit i+1 after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    for (i = 0; i < 13; i = i + 1)
    begin
      data_in_24[23:0] = (((3 * i) + 1) << 16) | (((3 * i) + 2) << 8) | ((3 * i) + 3);
      apply_24_to_crc;
    end
    present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                                  present_crc_24[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    data_in_8[7:0] = 8'h28;
    apply_1_8_to_crc;
    present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                                  present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    data_in_16[15:0] = 16'h0000;
    apply_16_to_crc;
    data_in_16[15:0] = 16'h0028;
    apply_16_to_crc;
    if (~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hBF671ED0)
      $display ("*** 24-bit after 40 bytes of i+1, I want 32'hBF671ED0, I get 32\`h%x",
                 ~present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_16[15:0] = 16'hBF67;
    apply_16_to_crc;
    data_in_16[15:0] = 16'h1ED0;
    apply_16_to_crc;
    if (present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 24-bit i+1 after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    use_F_for_CRC = 1'b1;
    for (i = 0; i < 10; i = i + 1)
    begin
      data_in_32[31:0] = (((4 * i) + 1) << 24) | (((4 * i) + 2) << 16)
                       | (((4 * i) + 3) << 8)  |  ((4 * i) + 4);
      apply_32_to_crc;
    end
    data_in_32[31:0] = 32'h00000028;
    apply_32_to_crc;
    if (~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hBF671ED0)
      $display ("*** 32-bit after 40 bytes of i+1, I want 32'hBF671ED0, I get 32\`h%x",
                 ~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_32[31:0] = 32'hBF671ED0;
    apply_32_to_crc;
    if (present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 32-bit i+1 after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

// NOTE:  WORKING:  add 48

    use_F_for_CRC = 1'b1;
    for (i = 0; i < 5; i = i + 1)
    begin
      data_in_64[63:0] = (((8 * i) + 1) << 56) | (((8 * i) + 2) << 48)
                       | (((8 * i) + 3) << 40) | (((8 * i) + 4) << 32)
                       | (((8 * i) + 5) << 24) | (((8 * i) + 6) << 16)
                       | (((8 * i) + 7) << 8)  |  ((8 * i) + 8);
      apply_64_to_crc;
    end
    present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                                  present_crc_64[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    data_in_32[31:0] = 32'h00000028;
    apply_32_to_crc;
    if (~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hBF671ED0)
      $display ("*** 64-bit after 40 bytes of i+1, I want 32'hBF671ED0, I get 32\`h%x",
                 ~present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in_32[31:0] = 32'hBF671ED0;
    apply_32_to_crc;
    if (present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** 64-bit i+1 after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

  end

crc_32_1_bit_at_a_time test_1_bit (
  .use_F_for_CRC              (use_F_for_CRC),
  .present_crc                (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_in_1                  (data_in_8[7]),
  .next_crc                   (next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

crc_32_8_private test_8_bit (
  .use_F_for_CRC              (use_F_for_CRC),
  .present_crc                (present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_in_8                  (data_in_8[7:0]),
  .next_crc                   (next_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

crc_32_16_private test_16_bit (
  .use_F_for_CRC              (use_F_for_CRC),
  .present_crc                (present_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_in_16                 (data_in_16[15:0]),
  .next_crc                   (next_crc_16[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

crc_32_24_private test_24_bit (
  .use_F_for_CRC              (use_F_for_CRC),
  .present_crc                (present_crc_24[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_in_24                 (data_in_24[23:0]),
  .next_crc                   (next_crc_24[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

crc_32_32_private test_32_bit (
  .use_F_for_CRC              (use_F_for_CRC),
  .present_crc                (present_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_in_32                 (data_in_32[31:0]),
  .next_crc                   (next_crc_32[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

crc_32_64_private test_64_bit (
  .use_F_for_CRC              (use_F_for_CRC),
  .present_crc                (present_crc_64[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_in_64                 (data_in_64[63:0]),
  .next_crc                   (next_crc_64[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
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
`endif  // COMPARE_PARALLEL_VERSIONS_AGAINST_SERIAL_VERSION_FOR_DEBUG

