//===========================================================================
// $Id: crc32_lib.v,v 1.4 2001-08-21 11:08:00 bbeaver Exp $
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
  present_crc,
  data_in_8,
  next_crc
);

  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [7:0] data_in_8;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

/* State Variables depend on input bit number (bigger is earlier) :
          0 :  0                      6    
          1 :  0  1                  6  7
          2 :  0  1  2              6  7
          3 :      1  2  3              7
          4 :  0      2  3  4      6    
          5 :  0  1      3  4  5  6  7
          6 :      1  2      4  5  6  7
          7 :  0      2  3      5      7
          8 :  0  1      3  4            
          9 :      1  2      4  5        
         10 :  0      2  3      5        
         11 :  0  1      3  4            
         12 :  0  1  2      4  5  6    
         13 :      1  2  3      5  6  7
         14 :          2  3  4      6  7
         15 :              3  4  5      7
         16 :  0              4  5        
         17 :      1              5  6    
         18 :          2              6  7
         19 :              3              7
         20 :                  4            
         21 :                      5        
         22 :  0                            
         23 :  0  1                  6    
         24 :      1  2                  7
         25 :          2  3                
         26 :  0          3  4      6    
         27 :      1          4  5      7
         28 :          2          5  6    
         29 :              3          6  7
         30 :                  4          7
         31 :                      5        
*/
  wire   [7:0] X = data_in_8[7:0] ^ present_crc[31:24];
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] C = present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
  assign  next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
          { C[23]                                    ^ X[5],
            C[22]                             ^ X[4]               ^ X[7],
            C[21]                      ^ X[3]               ^ X[6] ^ X[7],
            C[20]               ^ X[2]               ^ X[5] ^ X[6],
            C[19]        ^ X[1]               ^ X[4] ^ X[5]        ^ X[7],
            C[18] ^ X[0]               ^ X[3] ^ X[4]        ^ X[6],
            C[17]               ^ X[2] ^ X[3],
            C[16]        ^ X[1] ^ X[2]                             ^ X[7],
            C[15] ^ X[0] ^ X[1]                             ^ X[6],
            C[14] ^ X[0],
            C[13]                                    ^ X[5],
            C[12]                             ^ X[4],
            C[11]                      ^ X[3]                      ^ X[7],
            C[10]               ^ X[2]                      ^ X[6] ^ X[7],
            C[9]         ^ X[1]                      ^ X[5] ^ X[6],
            C[8]  ^ X[0]                      ^ X[4] ^ X[5],
            C[7]                       ^ X[3] ^ X[4] ^ X[5]        ^ X[7],
            C[6]                ^ X[2] ^ X[3] ^ X[4]        ^ X[6] ^ X[7],
            C[5]         ^ X[1] ^ X[2] ^ X[3]        ^ X[5] ^ X[6] ^ X[7],
            C[4]  ^ X[0] ^ X[1] ^ X[2]        ^ X[4] ^ X[5] ^ X[6],
            C[3]  ^ X[0] ^ X[1]        ^ X[3] ^ X[4],
            C[2]  ^ X[0]        ^ X[2] ^ X[3]        ^ X[5],
            C[1]         ^ X[1] ^ X[2]        ^ X[4] ^ X[5],
            C[0]  ^ X[0] ^ X[1]        ^ X[3] ^ X[4],
                    X[0]        ^ X[2] ^ X[3]        ^ X[5]        ^ X[7],
                           X[1] ^ X[2]        ^ X[4] ^ X[5] ^ X[6] ^ X[7],
                    X[0] ^ X[1]        ^ X[3] ^ X[4] ^ X[5] ^ X[6] ^ X[7],
                    X[0]        ^ X[2] ^ X[3] ^ X[4]        ^ X[6],
                           X[1] ^ X[2] ^ X[3]                      ^ X[7],
                    X[0] ^ X[1] ^ X[2]                      ^ X[6] ^ X[7],
                    X[0] ^ X[1]                             ^ X[6] ^ X[7],
                    X[0]                                    ^ X[6]
           };
endmodule

module crc_32_16_private (
  present_crc,
  data_in_16,
  next_crc
);

  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [15:0] data_in_16;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

/* State Variables depend on input bit number (bigger is earlier) :
          0 :  0                      6          9 10     12            
          1 :  0  1                  6  7      9     11 12 13        
          2 :  0  1  2              6  7  8  9             13 14    
          3 :      1  2  3              7  8  9 10             14 15
          4 :  0      2  3  4      6      8         11 12         15
          5 :  0  1      3  4  5  6  7         10         13        
          6 :      1  2      4  5  6  7  8         11         14    
          7 :  0      2  3      5      7  8     10                 15
          8 :  0  1      3  4              8     10 11 12            
          9 :      1  2      4  5              9     11 12 13        
         10 :  0      2  3      5              9             13 14    
         11 :  0  1      3  4                  9         12     14 15
         12 :  0  1  2      4  5  6          9         12 13     15
         13 :      1  2  3      5  6  7         10         13 14    
         14 :          2  3  4      6  7  8         11         14 15
         15 :              3  4  5      7  8  9         12         15
         16 :  0              4  5          8             12 13        
         17 :      1              5  6          9             13 14    
         18 :          2              6  7         10             14 15
         19 :              3              7  8         11             15
         20 :                  4              8  9         12            
         21 :                      5              9 10         13        
         22 :  0                                  9     11 12     14    
         23 :  0  1                  6          9             13     15
         24 :      1  2                  7         10             14    
         25 :          2  3                  8         11             15
         26 :  0          3  4      6             10                    
         27 :      1          4  5      7             11                
         28 :          2          5  6      8             12            
         29 :              3          6  7      9             13        
         30 :                  4          7  8     10             14    
         31 :                      5          8  9     11             15
*/
endmodule

module crc_32_32_private (
  present_crc,
  data_in_32,
  next_crc
);

  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [31:0] data_in_32;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

/* State Variables depend on input bit number (bigger is earlier) :
 0 :  0                      6          9 10     12             16                             24 25 26     28 29 30 31
 1 :  0  1                  6  7      9     11 12 13         16 17                         24         27 28            
 2 :  0  1  2              6  7  8  9             13 14     16 17 18                     24     26             30 31
 3 :      1  2  3              7  8  9 10             14 15     17 18 19                     25     27             31
 4 :  0      2  3  4      6      8         11 12         15         18 19 20             24 25             29 30 31
 5 :  0  1      3  4  5  6  7         10         13                     19 20 21         24             28 29        
 6 :      1  2      4  5  6  7  8         11         14                     20 21 22         25             29 30    
 7 :  0      2  3      5      7  8     10                 15 16                 21 22 23 24 25         28 29        
 8 :  0  1      3  4              8     10 11 12                 17                 22 23                 28         31
 9 :      1  2      4  5              9     11 12 13                 18                 23 24                 29        
10 :  0      2  3      5              9             13 14     16         19                         26     28 29     31
11 :  0  1      3  4                  9         12     14 15 16 17         20             24 25 26 27 28         31
12 :  0  1  2      4  5  6          9         12 13     15     17 18         21         24         27         30 31
13 :      1  2  3      5  6  7         10         13 14     16     18 19         22         25         28         31
14 :          2  3  4      6  7  8         11         14 15     17     19 20         23         26         29        
15 :              3  4  5      7  8  9         12         15 16     18     20 21         24         27         30    
16 :  0              4  5          8             12 13             17     19     21 22     24     26         29 30    
17 :      1              5  6          9             13 14             18     20     22 23     25     27         30 31
18 :          2              6  7         10             14 15             19     21     23 24     26     28         31
19 :              3              7  8         11             15 16             20     22     24 25     27     29        
20 :                  4              8  9         12             16 17             21     23     25 26     28     30    
21 :                      5              9 10         13             17 18             22     24     26 27     29     31
22 :  0                                  9     11 12     14     16     18 19             23 24     26 27     29     31
23 :  0  1                  6          9             13     15 16 17     19 20                     26 27     29     31
24 :      1  2                  7         10             14     16 17 18     20 21                     27 28     30    
25 :          2  3                  8         11             15     17 18 19     21 22                     28 29     31
26 :  0          3  4      6             10                             18 19 20     22 23 24 25 26     28         31
27 :      1          4  5      7             11                             19 20 21     23 24 25 26 27     29        
28 :          2          5  6      8             12                             20 21 22     24 25 26 27 28     30    
29 :              3          6  7      9             13                             21 22 23     25 26 27 28 29     31
30 :                  4          7  8     10             14                             22 23 24     26 27 28 29 30    
31 :                      5          8  9     11             15                             23 24 25     27 28 29 30 31
*/
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

  parameter NUM_BITS_TO_DO_IN_PARALLEL = 8'h08;

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

// NOTE: WORKING: count out formulas in the opposite order, write out valid formulas.
    $display ("Each term called out means the formula depends on a term data_in[N] ^ State[N].");
    $display ("State Variables depend on input bit number (bigger is earlier) :");
// try to read out formulas by sweeping a 1-bit through the corner_turner array.
    for (i = 0; i < `NUMBER_OF_BITS_IN_CRC; i = i + 1)  // each state bit depends on:
    begin
      $write ("%d :", i);
      for (j = 0; j < NUM_BITS_TO_DO_IN_PARALLEL; j = j + 1)
      begin
        if (corner_turner[(NUM_BITS_TO_DO_IN_PARALLEL-j-1)*`NUMBER_OF_BITS_IN_CRC + i]
                                                                            != 1'b0)
          $write (" %d", j[5:0]);
        else
          $write ("    ");
      end
      $write ("\n");
    end
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
  present_crc,
  data_in_1,
  next_crc
);

  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input   data_in_1;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

  wire    xor_value = data_in_1 ^ present_crc[`NUMBER_OF_BITS_IN_CRC - 1];

  assign  next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] = xor_value
                     ? {present_crc[`NUMBER_OF_BITS_IN_CRC - 2 : 0], 1'b0} ^ `CRC
                     : {present_crc[`NUMBER_OF_BITS_IN_CRC - 2 : 0], 1'b0};
endmodule

module test_crc_1 ();

  integer i, j;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;
  reg    [7:0] data_in;
  reg    [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc_8;
  wire   [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc_8;

// Assign data_in before invoking.  This consumes data MSB first
task apply_byte_to_crc;
  integer j;
  begin
    #0 ;
    present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                            next_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
    for (j = 0; j < 8; j = j + 1)
    begin
      #0 ;
      present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =
                            next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0];
      data_in[7:0] = {data_in[6:0], 1'b0};  // Shift byte out MSB first
    end
  end
endtask

  initial
  begin
    #10;
    $display ("running serial version of code");
    present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] =   {`NUMBER_OF_BITS_IN_CRC{1'b1}};
    present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] = {`NUMBER_OF_BITS_IN_CRC{1'b1}};
    data_in = 1'b0;
    for (i = 0; i < 43; i = i + 1)
    begin
      data_in[7:0] = 8'h00;
      apply_byte_to_crc;
    end
    data_in[7:0] = 8'h28;
    apply_byte_to_crc;
    if (~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'h864D7F99)
      $display ("*** after 40 bytes of 1'b0, I want 32'h864D7F99, I get 32\`h%x",
                 ~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    if (~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'h864D7F99)
      $display ("*** after 40 bytes of 1'b0, I want 32'h864D7F99, I get 32\`h%x",
                 ~present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in[7:0] = 8'h86;
    apply_byte_to_crc;
    data_in[7:0] = 8'h4D;
    apply_byte_to_crc;
    data_in[7:0] = 8'h7F;
    apply_byte_to_crc;
    data_in[7:0] = 8'h99;
    apply_byte_to_crc;
    if (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);


//        The receiver sees the value 32'hC704DD7B when the message is
//          received no errors.  Bit reversed, that is 32'hDEBB20E3.

    present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] = {`NUMBER_OF_BITS_IN_CRC{1'b1}};
    data_in = 1'b0;
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
      $display ("*** after 40 bytes of 1'b0, I want 32'hC55E457A, I get 32\`h%x",
                 ~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in[7:0] = 8'hC5;
    apply_byte_to_crc;
    data_in[7:0] = 8'h5E;
    apply_byte_to_crc;
    data_in[7:0] = 8'h45;
    apply_byte_to_crc;
    data_in[7:0] = 8'h7A;
    apply_byte_to_crc;
    if (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

    present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] = {`NUMBER_OF_BITS_IN_CRC{1'b1}};
    data_in = 1'b0;
    for (i = 0; i < 40; i = i + 1)
    begin
      data_in[7:0] = i + 1;
      apply_byte_to_crc;
    end
    for (i = 0; i < 3; i = i + 1)
    begin
      data_in[7:0] = 8'h00;
      apply_byte_to_crc;
    end
    data_in[7:0] = 8'h28;
    apply_byte_to_crc;
    if (~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hBF671ED0)
      $display ("*** after 40 bytes of 1'b0, I want 32'hBF671ED0, I get 32\`h%x",
                 ~present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);
    data_in[7:0] = 8'hBF;
    apply_byte_to_crc;
    data_in[7:0] = 8'h67;
    apply_byte_to_crc;
    data_in[7:0] = 8'h1E;
    apply_byte_to_crc;
    data_in[7:0] = 8'hD0;
    apply_byte_to_crc;
    if (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0] !== 32'hC704DD7B)
      $display ("*** after running CRC through, I want 32'hC704DD7B, I get 32\`h%x",
                  present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]);

  end

crc_32_1_bit_at_a_time test_1_bit (
  .present_crc                (present_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_in_1                  (data_in[7]),
  .next_crc                   (next_crc[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
);

crc_32_8_private test_8_bit (
  .present_crc                (present_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0]),
  .data_in_8                  (data_in[7:0]),
  .next_crc                   (next_crc_8[`NUMBER_OF_BITS_IN_CRC - 1 : 0])
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

