//===========================================================================
// $Id: ecc_hamming.v,v 1.5 2001-08-22 09:04:25 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  Using Hamming style functions, calculate 72 bits from 64 to make
//             a value which can be corrected back to the original 64 bits
//             of valid data if a single bit error is applied to the 72 bits.
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
// NOTE:  The plan seems to be the following:
//        Assign a binary Bit Address to each bit.
//        Calculate ECC check bits by XOR'ing the bits together which
//          correspond to 1's in each bit's Address Bit Address;
//          (For instance, ECC Check Digit bit 0 XORs together Data_In[1],
//           Data_In[3], and so on.)
//        You need 7 bits to have enough addresses for all 64 single-bit
//          errors, plus the value which covers the case of no errors.
//
// NOTE:  But wait, there's more!  What if a check bit fails?
//        The trick is to have the failing check digit call ITSELF out.
//        To achieve this, you have to distribute the check bits
//          so that they have nice binary Bit Addresses.
//
// NOTE:  There is even more.  Every single bit error results in a word
//          with wrong parity.  But what if 2 bits flip?  The parity goes
//          back to the original.  You can add a parity bit to everything,
//          and if the check bits say there is an error but the parity is
//          correct that means that 2 bits are wrong.
//        The parity bit becomes the 8th bit of the ECC check bits.
//
// NOTE:  The web pages discussing this seem to put the parity bit as bit 1
//          in the check bit calculation, the LSB check bit as bit 2, the
//          next check bit as bit 4, and so on.
//
// NOTE:  Since the parity bit is used to calculate the LSB of the
//          check bits, and since it is the XOR of all bits, you have
//          to calculate the XOR of the bits you least expect to calculate
//          the low-order check bit.  The ones with "0" as the LSB of their
//          bit address, not "1".
//
//===========================================================================

`timescale 1ns/1ps

// Given 64 bits, calculate 7 bits of ECC check bits and 1 bit of parity.
// NOTE: Why a module and not a function?  No idea.

module ecc_hamming_calculate_check_bits_private (
  data_in,
  check_bits_out,
  par_if_inserting_check_bits_out
);

  parameter NUM_DATA_BITS = 64;  // do not override in the instantiation.
  parameter NUM_CHECK_BITS = 8;

  input  [NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0] data_in;
  output [NUM_CHECK_BITS - 1 : 0] check_bits_out;
  output  par_if_inserting_check_bits_out;

// LSB of Check Bits depends on every other input bit.
  wire    parity_1_3_5_7     = data_in[1]  ^ data_in[3]  ^ data_in[5]  ^ data_in[7];
  wire    parity_9_11_13_15  = data_in[9]  ^ data_in[11] ^ data_in[13] ^ data_in[15];
  wire    parity_17_19_21_23 = data_in[17] ^ data_in[19] ^ data_in[21] ^ data_in[23];
  wire    parity_25_27_29_31 = data_in[25] ^ data_in[27] ^ data_in[29] ^ data_in[31];
  wire    parity_33_35_37_39 = data_in[33] ^ data_in[35] ^ data_in[37] ^ data_in[39];
  wire    parity_41_43_45_47 = data_in[41] ^ data_in[43] ^ data_in[45] ^ data_in[47];
  wire    parity_49_51_53_55 = data_in[49] ^ data_in[51] ^ data_in[53] ^ data_in[55];
  wire    parity_57_59_61_63 = data_in[57] ^ data_in[59] ^ data_in[61] ^ data_in[63];
  wire    parity_65_67_69_71 = data_in[65] ^ data_in[67] ^ data_in[69] ^ data_in[71];

  wire    parity_1_3_5_7_9_11_13_15_17_19_21_23 =
                 parity_1_3_5_7 ^ parity_9_11_13_15 ^ parity_17_19_21_23;
  wire    parity_25_27_29_31_33_35_37_39_41_43_45_47 =
                 parity_25_27_29_31 ^ parity_33_35_37_39 ^ parity_41_43_45_47;
  wire    parity_49_51_53_55_57_59_61_63_65_67_69_71 =
                 parity_49_51_53_55 ^ parity_57_59_61_63 ^ parity_65_67_69_71;

  assign  check_bits_out[0] = parity_1_3_5_7_9_11_13_15_17_19_21_23
                            ^ parity_25_27_29_31_33_35_37_39_41_43_45_47
                            ^ parity_49_51_53_55_57_59_61_63_65_67_69_71;

// second bit depends 2 out of 4 bits
  wire    parity_2_3_6_7 =     data_in[2]  ^ data_in[3]  ^ data_in[6]  ^ data_in[7];
  wire    parity_10_11_14_15 = data_in[10] ^ data_in[11] ^ data_in[14] ^ data_in[15];
  wire    parity_18_19_22_23 = data_in[18] ^ data_in[19] ^ data_in[22] ^ data_in[23];
  wire    parity_26_27_30_31 = data_in[26] ^ data_in[27] ^ data_in[30] ^ data_in[31];
  wire    parity_34_35_38_39 = data_in[34] ^ data_in[35] ^ data_in[38] ^ data_in[39];
  wire    parity_42_43_46_47 = data_in[42] ^ data_in[43] ^ data_in[46] ^ data_in[47];
  wire    parity_50_51_54_55 = data_in[50] ^ data_in[51] ^ data_in[54] ^ data_in[55];
  wire    parity_58_59_62_63 = data_in[58] ^ data_in[59] ^ data_in[62] ^ data_in[63];
  wire    parity_66_67_70_71 = data_in[66] ^ data_in[67] ^ data_in[70] ^ data_in[71];

  wire    parity_2_3_6_7_10_11_14_15_18_19_22_23 =
                 parity_2_3_6_7 ^ parity_10_11_14_15 ^ parity_18_19_22_23;
  wire    parity_26_27_30_31_34_35_38_39_42_43_46_47 =
                 parity_26_27_30_31 ^ parity_34_35_38_39 ^ parity_42_43_46_47;
  wire    parity_50_51_54_55_58_59_62_63_66_67_70_71 =
                 parity_50_51_54_55 ^ parity_58_59_62_63 ^ parity_66_67_70_71;

  assign  check_bits_out[1] = parity_2_3_6_7_10_11_14_15_18_19_22_23
                            ^ parity_26_27_30_31_34_35_38_39_42_43_46_47
                            ^ parity_50_51_54_55_58_59_62_63_66_67_70_71;

// Higher-numbered bits depend on groups of 4 adjacent input bits.
  wire    parity_0_3   = ^data_in[3:0];    // XOR reduction
  wire    parity_4_7   = ^data_in[7:4];    // XOR reduction
  wire    parity_8_11  = ^data_in[11:8];   // XOR reduction
  wire    parity_12_15 = ^data_in[15:12];  // XOR reduction
  wire    parity_16_19 = ^data_in[19:16];  // XOR reduction
  wire    parity_20_23 = ^data_in[23:20];  // XOR reduction
  wire    parity_24_27 = ^data_in[27:24];  // XOR reduction
  wire    parity_28_31 = ^data_in[31:28];  // XOR reduction
  wire    parity_32_35 = ^data_in[35:32];  // XOR reduction
  wire    parity_36_39 = ^data_in[39:36];  // XOR reduction
  wire    parity_40_43 = ^data_in[43:40];  // XOR reduction
  wire    parity_44_47 = ^data_in[47:44];  // XOR reduction
  wire    parity_48_51 = ^data_in[51:48];  // XOR reduction
  wire    parity_52_55 = ^data_in[55:52];  // XOR reduction
  wire    parity_56_59 = ^data_in[59:56];  // XOR reduction
  wire    parity_60_63 = ^data_in[63:60];  // XOR reduction
  wire    parity_64_67 = ^data_in[67:64];  // XOR reduction
  wire    parity_68_71 = ^data_in[71:68];  // XOR reduction

  wire    parity_4_7_12_15_20_23 =   parity_4_7 ^ parity_12_15 ^ parity_20_23;
  wire    parity_28_31_36_39_44_47 = parity_28_31 ^ parity_36_39 ^ parity_44_47;
  wire    parity_52_55_60_63_68_71 = parity_52_55 ^ parity_60_63 ^ parity_68_71;

  assign  check_bits_out[2] = parity_4_7_12_15_20_23
                            ^ parity_28_31_36_39_44_47
                            ^ parity_52_55_60_63_68_71;

  wire    parity_8_11_12_15_24_27 =  parity_8_11  ^ parity_12_15 ^ parity_24_27;
  wire    parity_28_31_40_43_44_47 = parity_28_31 ^ parity_40_43 ^ parity_44_47;
  wire    parity_56_59_60_63 =       parity_56_59 ^ parity_60_63;

  assign  check_bits_out[3] = parity_8_11_12_15_24_27
                            ^ parity_28_31_40_43_44_47
                            ^ parity_56_59_60_63;

  wire    parity_16_19_20_23_24_27 = parity_16_19 ^ parity_20_23 ^ parity_24_27;
  wire    parity_28_31_48_51_52_55 = parity_28_31 ^ parity_48_51 ^ parity_52_55;

  assign  check_bits_out[4] = parity_16_19_20_23_24_27
                            ^ parity_28_31_48_51_52_55
                            ^ parity_56_59_60_63;

  wire    parity_32_35_36_39_40_43 = parity_32_35 ^ parity_36_39 ^ parity_40_43;
  wire    parity_44_47_48_51_52_55 = parity_44_47 ^ parity_48_51 ^ parity_52_55;

  wire    parity_second_quarter = parity_32_35_36_39_40_43
                            ^ parity_44_47_48_51_52_55
                            ^ parity_56_59_60_63;

  assign  check_bits_out[5] = parity_second_quarter;

  wire    parity_third_quarter = parity_64_67 ^ parity_68_71;

  assign  check_bits_out[6] = parity_third_quarter;

// NOTE: In the generate case, the Check Bit inputs to this function come in
//         as all 0's.  The generator wants to calculate parity across all bits,
//         including Check Bits!
//       The slow, inexpensive way to do this is to calculate the odd parity of
//         the data including 0's for Check Bits, then XOR that with all of
//         the check bits to get the actual word checksum.
//       A faster way to do this is to calculate the final checksum directly.
//       This starts out by XOR'ing all the Data Bits together.  BUT notice
//         that the ECC bits contain XOR's of bits in the data.  If you
//         XOR the Check Bits with the XOR of the Data Bits, some of the
//         dependencies on certain data bits go away!
//       This function therefore only bothers to calculate the XOR of the bits
//         which are not rendered don't cares by the XORing of the check bits.

  wire    parity_0_3_5_6 =     data_in[0]  ^ data_in[3]  ^ data_in[5]  ^ data_in[6];
  wire    parity_9_10_12_15 =  data_in[9]  ^ data_in[10] ^ data_in[12] ^ data_in[15];
  wire    parity_17_18_20_23 = data_in[17] ^ data_in[18] ^ data_in[20] ^ data_in[23];
  wire    parity_24_27_29_30 = data_in[24] ^ data_in[27] ^ data_in[29] ^ data_in[30];
  wire    parity_33_34_36_39 = data_in[33] ^ data_in[34] ^ data_in[36] ^ data_in[39];
  wire    parity_40_43_45_46 = data_in[40] ^ data_in[43] ^ data_in[45] ^ data_in[46];
  wire    parity_48_51_53_54 = data_in[48] ^ data_in[51] ^ data_in[53] ^ data_in[54];
  wire    parity_57_58_60_63 = data_in[57] ^ data_in[58] ^ data_in[60] ^ data_in[63];
  wire    parity_65_66_68_71 = data_in[65] ^ data_in[66] ^ data_in[68] ^ data_in[71];

  wire    parity_0_3_5_6_9_10_12_15_17_18_20_23 =
                 parity_0_3_5_6 ^ parity_9_10_12_15 ^ parity_17_18_20_23;
  wire    parity_24_27_29_30_33_34_36_39_40_43_45_46 =
                 parity_24_27_29_30 ^ parity_33_34_36_39 ^ parity_40_43_45_46;
  wire    parity_48_51_53_54_57_58_60_63 =
                 parity_48_51_53_54 ^ parity_57_58_60_63 ^ parity_65_66_68_71;

  assign  par_if_inserting_check_bits_out =
                              parity_0_3_5_6_9_10_12_15_17_18_20_23
                            ^ parity_24_27_29_30_33_34_36_39_40_43_45_46
                            ^ parity_48_51_53_54_57_58_60_63;

// The module which checks ECC values actually has to look at all the data.
// Reuse calculations which have already been done.

  wire    parity_0_3_8_11_16_19 =    parity_0_3   ^ parity_8_11  ^ parity_16_19;
  wire    parity_24_27_28_31 =       parity_24_27 ^ parity_28_31;

  wire    parity_first_quarter = parity_0_3_8_11_16_19
                               ^ parity_4_7_12_15_20_23
                               ^ parity_24_27_28_31;

  assign  check_bits_out[7] = parity_first_quarter
                            ^ parity_second_quarter
                            ^ parity_third_quarter;
endmodule

// Given a 64-bit word (with no errors), calculate the 72-bit word which
//   will be stored to allow ECC to recover the original 64 bits in case of
//   a single bit error.

module ecc_hamming_generate_word_with_check_bits (
  data_in,
  data_plus_ecc_out,
  clk
);

  parameter NUM_DATA_BITS = 64;  // do not override in the instantiation.
  parameter NUM_CHECK_BITS = 8;

  input  [NUM_DATA_BITS - 1 : 0] data_in;
  output [NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0] data_plus_ecc_out;
  input   clk;

  wire   [NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0] input_vector =
              {data_in[63:57], 1'b0,   // check digit 6, bit 64
               data_in[56:26], 1'b0,   // check digit 5, bit 32
               data_in[25:11], 1'b0,   // check digit 4, bit 16
               data_in[10:4],  1'b0,   // check digit 3, bit 8
               data_in[3:1],   1'b0,   // check digit 2, bit 4
               data_in[0],     1'b0,   // check digit 1, bit 2
               1'b0,           1'b1};  // check digit 0, bit 0 == 1 says odd parity

  wire   [NUM_CHECK_BITS - 1 : 0] check_bits_out;
  wire    par_if_inserting_check_bits_out;

ecc_hamming_calculate_check_bits_private generate_ecc_bits (
  .data_in                    (input_vector[NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0]),
  .check_bits_out             (check_bits_out[NUM_CHECK_BITS - 1 : 0]),
  .par_if_inserting_check_bits_out (par_if_inserting_check_bits_out)
);

// Insert check bits into their nice power-of-2 locations, so they can call
//   themselves out if they read in error.
  wire   [NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0] reordered_data_plus_ecc =
              {data_in[63:57], check_bits_out[6],  // check digit 6, bit 64
               data_in[56:26], check_bits_out[5],  // check digit 5, bit 32
               data_in[25:11], check_bits_out[4],  // check digit 4, bit 16
               data_in[10:4],  check_bits_out[3],  // check digit 3, bit 8
               data_in[3:1],   check_bits_out[2],  // check digit 2, bit 4
               data_in[0],     check_bits_out[1],  // check digit 1, bit 2
               check_bits_out[0],                  // check digit 0, bit 1
                           par_if_inserting_check_bits_out};   // odd parity, bit 0

  reg    [NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0] data_plus_ecc_out;

  always @(posedge clk)
  begin
    data_plus_ecc_out[NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0] <=
                  reordered_data_plus_ecc[NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0];
  end
endmodule

// Given 64 bits, plus 7 bits of ECC check bits and 1 bit of parity,
//   discover if the data is correct.
// If 1 bit is wrong, correct it and report the problem.
// If 2 bits are wrong, report the problem.
// If an unexpected bit error position comes out, report that as an error.
// If more than 2 bits are wrong, you are hosed.  Most are not detected.
//
// The error_addressvalue is encoded.  It means this:
//  Error Value 0: no error
//  Error Value 1: check bit 0 is wrong
//  Error Value 2: check bit 1 is wrong
//  Error Value 3: data bit 0 is wrong
//  Error Value 4: check bit 2 is wrong
//  Error Values 7:5: data bits 3:1 are wrong
//  Error Value 8: check bit 3 is wrong
//  Error Values 15:9: data bits 10:4 are wrong
//  Error Value 16: check bit 4 is wrong
//  Error Values 31:17: data bits 25:11 are wrong
//  Error Value 32: check bit 5 is wrong
//  Error Values 63:32: data bits 56:26 are wrong
//  Error Value 64: check bit 6 is wrong
//  Error Values 71:65: data bits 63:57 are wrong
//  Error Value 72: check bit 7 is wrong

module ecc_hamming_correct (
  data_plus_ecc_in,
  corrected_data_out,
  corrected_check_bits_out,
  single_bit_error_corrected,
  double_bit_error_detected,
  error_address,
  clk
);

  parameter NUM_DATA_BITS = 64;  // do not override in the instantiation.
  parameter NUM_CHECK_BITS = 8;

  input  [NUM_DATA_BITS  + NUM_CHECK_BITS - 1 : 0] data_plus_ecc_in;

  output [NUM_DATA_BITS - 1 : 0] corrected_data_out;
  output [NUM_CHECK_BITS - 1 : 0] corrected_check_bits_out;

  output  single_bit_error_corrected;
  output  double_bit_error_detected;

  output [6:0] error_address;

  input   clk;

// If there is an error, the XOR of the calculated and stored Check Bits
//   gives the address of the failing bit.
// The calculate_check_bits module, when applied to a word containing check bits,
//   will do the XOR automatically.  The output is the address of the failing bit.
  wire   [NUM_CHECK_BITS - 1 : 0] check_bits;
  wire    par_if_inserting_check_bits_out;  // ignore

ecc_hamming_calculate_check_bits_private check_ecc_bits (
  .data_in                    (data_plus_ecc_in[NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0]),
  .check_bits_out             (check_bits[NUM_CHECK_BITS - 1 : 0]),
  .par_if_inserting_check_bits_out (par_if_inserting_check_bits_out)
);

  wire    parity_error_detected = ~check_bits[7];  // If data was Odd Parity, return 1'b1;

  wire    parity_bit_wrong = (check_bits[6:0] == 7'h00) & parity_error_detected;

  wire    correction_needed = (check_bits[6:0] != 7'h00)  // non-zero means correct!
                            | parity_bit_wrong;

  wire    unexpected_error_address = (check_bits[6:0] >= 8'h48);  // >= 72

// If there is an error, need to make a mask to XOR with the data in order to
//   get the corrected data back.
// Verilogger seems to be in a core-dumping mood with a straight-forward shift.
// Doing things manually will result in better logic, anyway.
  wire   [1:0] mask_0  = check_bits[0] ? 2'b10 : 2'b01;
  wire   [3:0] mask_1  = check_bits[1]
                         ? {mask_0[1:0], 2'b00}
                         : {2'b00, mask_0[1:0]};
  wire   [7:0] mask_2  = check_bits[2]
                         ? {mask_1[3:0], 4'h0}
                         : {4'h0, mask_1[3:0]};
  wire   [15:0] mask_3 = check_bits[3]
                         ? {mask_2[7:0], 8'h00}
                         : {8'h00, mask_2[7:0]};
  wire   [31:0] mask_4 = check_bits[4]
                         ? {mask_3[15:0], 16'h0000}
                         : {16'h0000, mask_3[15:0]};
  wire   [63:0] mask_5 = check_bits[5]
                         ? {mask_4[31:0], 32'h00000000}
                         : {32'h00000000, mask_4[31:0]};
  wire   [71:0] mask_6 = check_bits[6]
                         ? {mask_5[7:0], 64'h00000000_00000000}
                         : {8'h00, mask_5[63:0]};

  wire   [NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0] error_corrected_data =
              data_plus_ecc_in[NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0]
            ^ {mask_6[71:1], parity_bit_wrong};

  wire   [NUM_DATA_BITS - 1 : 0] reordered_corrected_data =
              {error_corrected_data[71:65],
               error_corrected_data[63:33],
               error_corrected_data[31:17],
               error_corrected_data[15:9],
               error_corrected_data[7:5],
               error_corrected_data[3]};

  wire   [NUM_CHECK_BITS - 1 : 0] reordered_corrected_check_bits =
              {error_corrected_data[0],
               error_corrected_data[64],
               error_corrected_data[32],
               error_corrected_data[16],
               error_corrected_data[8],
               error_corrected_data[4],
               error_corrected_data[2],
               error_corrected_data[1]};

  reg    [NUM_DATA_BITS - 1 : 0] corrected_data_out;
  reg    [NUM_CHECK_BITS - 1 : 0] corrected_check_bits_out;
  reg     single_bit_error_corrected;
  reg     double_bit_error_detected;
  reg    [6:0] error_address;

  always @(posedge clk)
  begin
    corrected_data_out[NUM_DATA_BITS - 1 : 0] <=
                                 reordered_corrected_data[NUM_DATA_BITS - 1 : 0];
    corrected_check_bits_out[NUM_CHECK_BITS - 1 : 0] <=
                          reordered_corrected_check_bits[NUM_CHECK_BITS - 1 : 0];
    single_bit_error_corrected <= correction_needed &  parity_error_detected;
    double_bit_error_detected <= (correction_needed & ~parity_error_detected)
                               | unexpected_error_address;
    error_address[6:0] <= parity_bit_wrong
                        ? 8'h48  // 72
                        : check_bits[6:0];
  end
endmodule

// `define TEST_ECC_CODE
`ifdef TEST_ECC_CODE
module test_ecc ();

  parameter NUM_DATA_BITS = 64;  // do not override in the instantiation.
  parameter NUM_CHECK_BITS = 8;

  reg     clk;
  reg    [NUM_DATA_BITS - 1 : 0] data_in;
  wire   [NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0] data_plus_ecc_out;
  wire   [NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0] data_plus_ecc_in;
  reg    [NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0] force_error;
  wire   [NUM_DATA_BITS - 1 : 0] corrected_data_out;
  wire   [NUM_CHECK_BITS - 1 : 0] corrected_check_bits_out;
  wire    single_bit_error_corrected;
  wire    double_bit_error_detected;
  wire   [6:0] error_address;

  reg    [NUM_DATA_BITS - 1 : 0] data_pattern;
  reg    [NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0] error_mask_1;
  reg    [NUM_DATA_BITS + NUM_CHECK_BITS - 1 : 0] error_mask_2;
  integer cnt;

task make_clk;
  begin
    # 1;
    clk = 1'b1;
    # 2;
    clk = 1'b0;
    # 1;
  end
endtask

  wire   [NUM_CHECK_BITS - 1 : 0] original_check_bits =
              {data_plus_ecc_out[0],
               data_plus_ecc_out[64],
               data_plus_ecc_out[32],
               data_plus_ecc_out[16],
               data_plus_ecc_out[8],
               data_plus_ecc_out[4],
               data_plus_ecc_out[2],
               data_plus_ecc_out[1]};

  initial
  begin
    clk = 1'b0;

    $display ("Walking a 1");
// need to check that walking 1 bit goes through correctly.
    for (data_pattern = 64'h00000000_00000001;
         data_pattern != 64'h0;
         data_pattern = data_pattern << 1)
    begin
      data_in = data_pattern;
      force_error = 72'h00_00000000_00000000;
      make_clk;
      make_clk;
      if (data_in !== corrected_data_out)
        $display ("*** Data In != Data Out %x %x", data_in, corrected_data_out);
      if (original_check_bits !== corrected_check_bits_out)
        $display ("*** Check Bits In != Check Bits Out %x %x", original_check_bits, corrected_check_bits_out);
      if (single_bit_error_corrected !== 1'b0)
        $display ("*** Unexpected Single Bit Error Detected %x %x %x",
                   single_bit_error_corrected, data_pattern, data_plus_ecc_in);
      if (double_bit_error_detected !== 1'b0)
        $display ("*** Unexpected Double Bit Error Detected %x %x %x",
                   double_bit_error_detected, data_pattern, data_plus_ecc_in);
    end

    $display ("Walking a 0");
// need to check that walking 0 bit goes through correctly.
    for (data_pattern = 64'h00000000_00000001;
         data_pattern != 64'h0;
         data_pattern = data_pattern << 1)
    begin
      data_in = ~data_pattern;
      force_error = 72'h00_00000000_00000000;
      make_clk;
      make_clk;
      if (corrected_data_out !== data_in)
        $display ("*** Data In != Data Out %x %x", data_in, corrected_data_out);
      if (original_check_bits !== corrected_check_bits_out)
        $display ("*** Check Bits In != Check Bits Out %x %x", original_check_bits, corrected_check_bits_out);
      if (single_bit_error_corrected !== 1'b0)
        $display ("*** Unexpected Single Bit Error Detected %x %x %x",
                   single_bit_error_corrected, data_pattern, data_plus_ecc_in);
      if (double_bit_error_detected !== 1'b0)
        $display ("*** Unexpected Double Bit Error Detected %x %x %x",
                   double_bit_error_detected, data_pattern, data_plus_ecc_in);
    end

    $display ("Sending Random Data");
// need to check that walking 0 bit goes through correctly.
    for (cnt = 0; cnt < 1000; cnt = cnt + 1)
    begin
      data_in = {$random, $random};
      force_error = 72'h00_00000000_00000000;
      make_clk;
      make_clk;
      if (corrected_data_out !== data_in)
        $display ("*** Data In != Data Out %x %x", data_in, corrected_data_out);
      if (original_check_bits !== corrected_check_bits_out)
        $display ("*** Check Bits In != Check Bits Out %x %x", original_check_bits, corrected_check_bits_out);
      if (single_bit_error_corrected !== 1'b0)
        $display ("*** Unexpected Single Bit Error Detected %x %x %x",
                   single_bit_error_corrected, data_pattern, data_plus_ecc_in);
      if (double_bit_error_detected !== 1'b0)
        $display ("*** Unexpected Double Bit Error Detected %x %x %x",
                   double_bit_error_detected, data_pattern, data_plus_ecc_in);
    end

    $display ("Making 0 go to 1, even parity, error check");
// need to check that 1 bit which should be 0 is detected correctly, even parity.
    for (error_mask_1 = 72'h00_00000000_00000001;
         error_mask_1 != 72'h0;
         error_mask_1 = error_mask_1 << 1)
    begin
      data_in = 64'h00000000_00000000;
      force_error = error_mask_1;
      make_clk;
      make_clk;
      if (corrected_data_out !== data_in)
        $display ("*** Data In != Data Out %x %x", data_in, corrected_data_out);
      if (original_check_bits !== corrected_check_bits_out)
        $display ("*** Check Bits In != Check Bits Out %x %x", original_check_bits, corrected_check_bits_out);
      if (single_bit_error_corrected !== 1'b1)
        $display ("*** Expected Single Bit Error Missed %x %x %x",
                   single_bit_error_corrected, error_mask_1, data_plus_ecc_in);
      if (double_bit_error_detected !== 1'b0)
        $display ("*** Unexpected Double Bit Error Detected %x %x %x",
                   double_bit_error_detected, error_mask_1, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h00_00000000_00000001)
           & (error_address != 8'h48) )
        $display ("*** Parity Error calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h00_00000000_00000001)
           & (error_address != 8'h48) )
        $display ("*** Bit 0 calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h80_00000000_00000000)
           & (error_address != 8'h47) )
        $display ("*** Bit 71 calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
    end

    $display ("Making 0 go to 1, odd parity, error check");
// need to check that 1 bit which should be 0 is detected correctly, odd parity.
    for (error_mask_1 = 72'h00_00000000_00000001;
         error_mask_1 != 72'h0;
         error_mask_1 = error_mask_1 << 1)
    begin
      data_in = 64'h10000000_00000000;
      force_error = error_mask_1;
      make_clk;
      make_clk;
      if (corrected_data_out !== data_in)
        $display ("*** Data In != Data Out %x %x", data_in, corrected_data_out);
      if (original_check_bits !== corrected_check_bits_out)
        $display ("*** Check Bits In != Check Bits Out %x %x", original_check_bits, corrected_check_bits_out);
      if (single_bit_error_corrected !== 1'b1)
        $display ("*** Expected Single Bit Error Missed %x %x %x",
                   single_bit_error_corrected, error_mask_1, data_plus_ecc_in);
      if (double_bit_error_detected !== 1'b0)
        $display ("*** Unexpected Double Bit Error Detected %x %x %x",
                   double_bit_error_detected, error_mask_1, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h00_00000000_00000001)
           & (error_address != 8'h48) )
        $display ("*** Parity Error calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h00_00000000_00000001)
           & (error_address != 8'h48) )
        $display ("*** Bit 0 calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h80_00000000_00000000)
           & (error_address != 8'h47) )
        $display ("*** Bit 71 calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
    end

    $display ("Making 1 go to 0, even parity, error check");
// need to check that 0 bit which should be 1 is detected correctly, even parity.
    for (error_mask_1 = 72'h00_00000000_00000001;
         error_mask_1 != 72'h0;
         error_mask_1 = error_mask_1 << 1)
    begin
      data_in = 64'hFFFFFFFF_FFFFFFFF;
      force_error = error_mask_1;
      make_clk;
      make_clk;
      if (corrected_data_out !== data_in)
        $display ("*** Data In != Data Out %x %x", data_in, corrected_data_out);
      if (original_check_bits !== corrected_check_bits_out)
        $display ("*** Check Bits In != Check Bits Out %x %x", original_check_bits, corrected_check_bits_out);
      if (single_bit_error_corrected !== 1'b1)
        $display ("*** Expected Single Bit Error Missed %x %x %x",
                   single_bit_error_corrected, error_mask_1, data_plus_ecc_in);
      if (double_bit_error_detected !== 1'b0)
        $display ("*** Unexpected Double Bit Error Detected %x %x %x",
                   double_bit_error_detected, error_mask_1, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h00_00000000_00000001)
           & (error_address != 8'h48) )
        $display ("*** Parity Error calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h00_00000000_00000001)
           & (error_address != 8'h48) )
        $display ("*** Bit 0 calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h80_00000000_00000000)
           & (error_address != 8'h47) )
        $display ("*** Bit 71 calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
    end

    $display ("Making 1 go to 0, odd parity, error check");
// need to check that 0 bit which should be 1 is detected correctly, odd parity.
    for (error_mask_1 = 72'h00_00000000_00000001;
         error_mask_1 != 72'h0;
         error_mask_1 = error_mask_1 << 1)
    begin
      data_in = 64'hFFFFFFFF_FFFFFFFE;
      force_error = error_mask_1;
      make_clk;
      make_clk;
      if (corrected_data_out !== data_in)
        $display ("*** Data In != Data Out %x %x", data_in, corrected_data_out);
      if (original_check_bits !== corrected_check_bits_out)
        $display ("*** Check Bits In != Check Bits Out %x %x", original_check_bits, corrected_check_bits_out);
      if (single_bit_error_corrected !== 1'b1)
        $display ("*** Expected Single Bit Error Missed %x %x %x",
                   single_bit_error_corrected, error_mask_1, data_plus_ecc_in);
      if (double_bit_error_detected !== 1'b0)
        $display ("*** Unexpected Double Bit Error Detected %x %x %x",
                   double_bit_error_detected, error_mask_1, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h00_00000000_00000001)
           & (error_address != 8'h48) )
        $display ("*** Parity Error calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h00_00000000_00000001)
           & (error_address != 8'h48) )
        $display ("*** Bit 0 calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h80_00000000_00000000)
           & (error_address != 8'h47) )
        $display ("*** Bit 71 calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
    end

    $display ("Walking error, random data, error check");
// need to check that 0 bit which should be 1 is detected correctly, odd parity.
    for (error_mask_1 = 72'h00_00000000_00000001;
         error_mask_1 != 72'h0;
         error_mask_1 = error_mask_1 << 1)
    begin
      for (cnt = 0; cnt < 25; cnt = cnt + 1)
      begin
        data_in = {$random, $random};
        force_error = error_mask_1;
        make_clk;
        make_clk;
        if (corrected_data_out !== data_in)
          $display ("*** Data In != Data Out %x %x", data_in, corrected_data_out);
        if (original_check_bits !== corrected_check_bits_out)
          $display ("*** Check Bits In != Check Bits Out %x %x", original_check_bits, corrected_check_bits_out);
        if (single_bit_error_corrected !== 1'b1)
          $display ("*** Expected Single Bit Error Missed %x %x %x",
                     single_bit_error_corrected, error_mask_1, data_plus_ecc_in);
        if (double_bit_error_detected !== 1'b0)
          $display ("*** Unexpected Double Bit Error Detected %x %x %x",
                     double_bit_error_detected, error_mask_1, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h00_00000000_00000001)
           & (error_address != 8'h48) )
        $display ("*** Parity Error calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h00_00000000_00000001)
           & (error_address != 8'h48) )
        $display ("*** Bit 0 calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
      if (   (error_mask_1 == 72'h80_00000000_00000000)
           & (error_address != 8'h47) )
        $display ("*** Bit 71 calls out wrong bit offset %x %x",
                   error_address, data_plus_ecc_in);
      end
    end

    $display ("testing 2-bit errors, random data, error check");
// need to check 2 bit errors detected.
    for (error_mask_1 = 72'h00_00000000_00000001;
         error_mask_1 != 72'h80_00000000_00000000;
         error_mask_1 = error_mask_1 << 1)
    begin
      for (error_mask_2 = error_mask_1 << 1;
           error_mask_2 != 72'h0;
           error_mask_2 = error_mask_2 << 1)
      begin
        if (error_mask_1 != error_mask_2)
        begin
          data_in = {$random, $random};
          force_error = error_mask_1 | error_mask_2;
          make_clk;
          make_clk;
          if (single_bit_error_corrected !== 1'b0)
            $display ("*** Unexpected Single Bit Error Detected %x %x %x",
                       single_bit_error_corrected, error_mask_1, data_plus_ecc_in);
          if (double_bit_error_detected !== 1'b1)
            $display ("*** Expected Double Bit Error Missed %x %x %x",
                       double_bit_error_detected, error_mask_1, data_plus_ecc_in);
        end
      end
    end
  end

ecc_hamming_generate_word_with_check_bits generate (
  .data_in                    (data_in),
  .data_plus_ecc_out          (data_plus_ecc_out),
  .clk                        (clk)
);

  assign  data_plus_ecc_in[71:0] = data_plus_ecc_out ^ force_error;

ecc_hamming_correct correct (
  .data_plus_ecc_in           (data_plus_ecc_in),
  .corrected_data_out         (corrected_data_out),
  .corrected_check_bits_out   (corrected_check_bits_out),
  .single_bit_error_corrected (single_bit_error_corrected),
  .double_bit_error_detected  (double_bit_error_detected),
  .error_address              (error_address),
  .clk                        (clk)
);

endmodule
`endif  // TEST_ECC_CODE

