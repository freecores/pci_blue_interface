//===========================================================================
// $Id: grey_to_binary.v,v 1.2 2001-08-19 13:49:08 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  Example of how to convert Binary to Grey Code.
//           Example of how to convert Grey Code to Binary.
//
// USAGE NOTE: CRITICAL:  These functions produce combinational outputs
//           which have glitches.  To use these safely, the outputs
//           must be latched using the same clock before and after
//           the combinational function.
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
// NOTE:  There are other sequences of numbers which share the property
//          of Grey Code that only 1 bit transitions per value change.  The
//          sequence 0x00, 0x1, 0x3, 0x2, 0x6, 0x4 is one such sequence.
//        It should be possible to make a library which counts
//          in sequences less than 2**n long, yet still has this property.
//
//===========================================================================

`timescale 1ns/1ps

// Convert 2-bit up to 16-bit binary value into same sized grey-code value

module bin_to_grey_code (
  binary_in,
  grey_code_out
);
  parameter NUM_BITS = 1;  // instantiate as "bin_to_grey_code #(width) instance ()"

  input  [NUM_BITS - 1 : 0] binary_in;
  output [NUM_BITS - 1 : 0] grey_code_out;

// Consider the sequences
//   Binary  Grey Code
//     00       00
//     01       01
//     10       11
//     11       10
// It seems that G[1] = B[1], and G[0] = B[1] ^ B[0];
// Now consider the sequences
//   Binary  Grey Code
//     000      000
//     001      001
//     010      011
//     011      010
//     100      110
//     101      111
//     110      101
//     111      100
// It seems that G[2] = B[2], and
//               G[1] = B[2] ^ B[1], and
//               G[0] = B[1] ^ B[0];
//
// But how to write that using a parameter?  Well, instead of
//   figuring it out, how about just making somwthing which works
//   for a range of widths, like 2 to 16?

  wire   [15:0] widened_input = {binary_in[NUM_BITS - 1 : 0], {16 - NUM_BITS{1'b0}}};

  wire   [15:0] widened_output = {
                      widened_input[15],
                      widened_input[15] ^ widened_input[14],
                      widened_input[14] ^ widened_input[13],
                      widened_input[13] ^ widened_input[12],
                      widened_input[12] ^ widened_input[11],
                      widened_input[11] ^ widened_input[10],
                      widened_input[10] ^ widened_input[9],
                      widened_input[9]  ^ widened_input[8],
                      widened_input[8]  ^ widened_input[7],
                      widened_input[7]  ^ widened_input[6],
                      widened_input[6]  ^ widened_input[5],
                      widened_input[5]  ^ widened_input[4],
                      widened_input[4]  ^ widened_input[3],
                      widened_input[3]  ^ widened_input[2],
                      widened_input[2]  ^ widened_input[1],
                      widened_input[1]  ^ widened_input[0]
                  };

  assign  grey_code_out[NUM_BITS - 1 : 0] = widened_output[15 : 16 - NUM_BITS];

// synopsys translate_off
  initial
  begin
    if (NUM_BITS < 2) $display ("*** %m bin_to_grey_code Number of bits %d < 2", NUM_BITS);
    if (NUM_BITS > 16) $display ("*** %m bin_to_grey_code Number of bits %d > 16", NUM_BITS);
  end
endmodule

// Convert 2-bit up to 16-bit binary value into same sized grey-code value

module grey_code_to_bin (
  grey_code_in,
  binary_out
);
  parameter NUM_BITS = 1;  // instantiate as "grey_code_to_bin #(width) instance ()"

  input  [NUM_BITS - 1 : 0] grey_code_in;
  output [NUM_BITS - 1 : 0] binary_out;

// Consider the sequences
//   Grey Code   Binary
//       00        00
//       01        01
//       11        10
//       10        11
// It seems that B[1] = G[1], and B[0] = G[1] ^ G[0];
// Now consider the sequences
//   Grey Code   Binary
//      000       000
//      001       001
//      011       010
//      010       011
//      110       100
//      111       101
//      101       110
//      100       111
// It seems that B[2] = G[2], and
//               B[1] = G[2] ^ G[1], and
//               B[0] = G[2] ^ G[1] ^ G[0];
//
// But how to write that using a parameter?  Well, instead of
//   figuring it out, how about just making somwthing which works
//   for a range of widths, like 2 to 16?

  wire   [15:0] widened_input = {grey_code_in[NUM_BITS - 1 : 0], {16 - NUM_BITS{1'b0}}};
  wire    xor_15_12 = widened_input[15] ^ widened_input[14]
                    ^ widened_input[13] ^ widened_input[12];
  wire    xor_11_10 = widened_input[11] ^ widened_input[10];
  wire    xor_11_8  = widened_input[11] ^ widened_input[10]
                    ^ widened_input[9]  ^ widened_input[8];
  wire    xor_7_6   = widened_input[7]  ^ widened_input[6];
  wire    xor_7_4   = widened_input[7]  ^ widened_input[6]
                    ^ widened_input[5]  ^ widened_input[4];
  wire    xor_3_2   = widened_input[3]  ^ widened_input[2];
  wire    xor_1_0   = widened_input[1]  ^ widened_input[0];

  wire   [15:0] widened_output = {
                      widened_input[15],
                      widened_input[15] ^ widened_input[14],
                      widened_input[15] ^ widened_input[14] ^ widened_input[13],
                      xor_15_12,
                      xor_15_12 ^ widened_input[11],
                      xor_15_12 ^ xor_11_10,
                      xor_15_12 ^ xor_11_10 ^ widened_input[9],
                      xor_15_12 ^ xor_11_8,
                      xor_15_12 ^ xor_11_8 ^ widened_input[7],
                      xor_15_12 ^ xor_11_8 ^ xor_7_6,
                      xor_15_12 ^ xor_11_8 ^ xor_7_6 ^ widened_input[5],
                      xor_15_12 ^ xor_11_8 ^ xor_7_4,
                      xor_15_12 ^ xor_11_8 ^ xor_7_4 ^ widened_input[3],
                      xor_15_12 ^ xor_11_8 ^ xor_7_4 ^ xor_3_2,
                      xor_15_12 ^ xor_11_8 ^ xor_7_4 ^ xor_3_2 ^ widened_input[1],
                      xor_15_12 ^ xor_11_8 ^ xor_7_4 ^ xor_3_2 ^ xor_1_0
                  };

  assign  binary_out[NUM_BITS - 1 : 0] = widened_output[15 : 16 - NUM_BITS];

// synopsys translate_off
  initial
  begin
    if (NUM_BITS < 2) $display ("*** %m grey_code_to_bin Number of bits %d < 2", NUM_BITS);
    if (NUM_BITS > 16) $display ("*** %m grey_code_to_bin Number of bits %d > 16", NUM_BITS);
  end
endmodule

`ifdef TEST_GREY_CODE
module test;
  reg    [7:0] test_val;
  wire   [1:0] grey_2;
  wire   [2:0] grey_3;
  wire   [3:0] grey_4;

  wire   [1:0] bin_2;
  wire   [2:0] bin_3;
  wire   [3:0] bin_4;

  initial
  begin
    for (test_val = 8'h00; test_val < 8'h04; test_val = test_val + 8'h01)
    begin
      # 0; $display ("test val, result %x %x %x", test_val[1:0], grey_2[1:0], bin_2[1:0]);
    end
    $display (" ");
    for (test_val = 8'h00; test_val < 8'h08; test_val = test_val + 8'h01)
    begin
      # 0; $display ("test val, result %x %x %x", test_val[2:0], grey_3[2:0], bin_3[2:0]);
    end
    $display (" ");
    for (test_val = 8'h00; test_val < 8'h10; test_val = test_val + 8'h01)
    begin
      # 0; $display ("test val, result %x %x %x", test_val[3:0], grey_4[3:0], bin_4[3:0]);
    end

  end

  bin_to_grey_code #(2) bin_to_grey_code_2 (test_val[1:0], grey_2[1:0]);
  bin_to_grey_code #(3) bin_to_grey_code_3 (test_val[2:0], grey_3[2:0]);
  bin_to_grey_code #(4) bin_to_grey_code_4 (test_val[3:0], grey_4[3:0]);

  grey_code_to_bin #(2) grey_code_to_bin_2 (grey_2[1:0], bin_2[1:0]);
  grey_code_to_bin #(3) grey_code_to_bin_3 (grey_3[2:0], bin_3[2:0]);
  grey_code_to_bin #(4) grey_code_to_bin_4 (grey_4[3:0], bin_4[3:0]);

endmodule
`endif  // TEST_GREY_CODE

