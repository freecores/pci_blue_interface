//===========================================================================
// $Id: sha_1_digest.v,v 1.2 2001-08-30 10:08:46 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  Calculate SHA1 digest of some data.
//           This algorithm is specified in FIPS PUB 180-1
//           See: http://csrc.nist.gov/cryptval/shs.html
//           See also: http://csrc.nist.gov/cryptval/shs/sha1-vectors.zip
//           See also: http://www.w3.org/PICS/DSig/SHA1_1_0.html
//           See also: http://www.altera.com/literature/wp/wp_hcores_sha1.pdf
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
// NOTE:  Calculate a Message Digest as specified by the SHA-1 algorithm.
//        Return a 160-bit Digest.
//
// NOTE:  The SHA-1 algorithm applies to 512-BIT blocks.  Operations
//          are applied to 32-bit words.  Each block is 16 words long.
//
// NOTE:  The SHA-1 algorithm uses these following operations:
//        &, |, ^, ~, +, <<<> (shift left circular a constant distance)
//
// NOTE:  The first step applied to the Data is to pad it to a block boundry:
//         1) Take a message expressed as a string of BITS!
//         2) Append a 1'b1 to the end of the string
//         3) Append enough 1'b0s to fill the block up to
//              512 - 64 bits.
//         4) Append the number of bits in the ORIGINAL message,
//              expressed as a 64 bit number, MSB bit first, to
//              the message.
//
// NOTE:  A sequence of 80ogical Functions are defined:
//         1) Functions 0 thru 19:  f(t)(B,C,D) = (B & C) | (~B & D);
//         2) Functions 20 thru 39: f(t)(B,C,D) = B ^ C ^ D;
//         3) Functions 40 thru 59: f(t)(B,C,D) = (B & C) | (B & D) | (C & D);
//         4) Functions 60 thru 79: f(t)(B,C,D) = B ^ C ^ D;
//
// NOTE:  A sequence of 80 Constants are defined:
//         1) Constants 0 thru 19:  K(t) = 32'h5A827999;
//         2) Constants 20 thru 39: K(t) = 32'h6ED9EBA1;
//         3) Constants 40 thru 59: K(t) = 32'h8F1BBCDC;
//         4) Constants 60 thru 79: K(t) = 32'hCA62C1D6;
//
// NOTE:  The calculation of the Digest uses 2 buffers, each with 5 32-bit words.
//          The entries in the first buffer are called A, B, C, D, and E;
//          The entries in the second buffer are called H_0, H_1, H_2, H_3, H_4;
//        In addition, it uses a sequence of 80 32-bit words for state, called
//          W_0, W_1, ..., W_79;
//        A single 32-bit TEMP is also used.
//
// NOTE:  At the start of a Digest calculation, the H_* elements are initialized.
//         a) H_0 = 32'h67452301;
//            H_1 = 32'hEFCDAB89;
//            H_2 = 32'h98BADCFE;
//            H_3 = 32'h10325476;
//            H_4 = 32'hC3D2E1F0;
//
// NOTE:  Finally, each block (including the last padded block) is worked on:
//        Consider each block as 16 32-bit words.
//         b) Copy the block into the first 16 words of W memory, with W_0
//              the Most Significant word of the block.
//         c) For t = 16 to 79, W(t) = Shift Left Circular by 1 of
//              (W(t - 3) ^ W(t - 8) ^ W(t - 14) ^ W(t - 16));
//         d) Assign A = H_0; B = H_1; C = H_2; D = H_3; E = H_4;
//         e) For t = 0 thru 79, do:
//         f)   TEMP = shift left circular by 5 (A) + f(t)(B,C,D) + E + W(t) + K(t);
//         g)   E = D; D = C; C = shift left circular by 30 of (B); B = A; A = TEMP;
//         h) After each block, H_0 = H_0 + A, H_1 = H_1 + B; H_2 = H_2 + C; H_3 = H_3 + D, H_4 = H_4 + E;
//        After the last block is operated on, the Digest is {H_0, H_1, H_2, H_3, H_4};
//
// NOTE:  The standard gives an alternate method of comultation, in chapter 8, which
//          uses 16 words of storage instead of 80.  This is possible because the
//          entries in the W array are only written, read 4 times, and discarded.
//        It works this way:
//         b) Copy block into W memory as in b) above.
//         c) Assign A = H_0; B = H_1; C = H_2; D = H_3; E = H_4 as in d) above.
//         d) For t = 0 thru 15, do:
//         e)   Calculate a modified address s = t & 7'h0F;
//         f)   TEMP = shift left circular by 5 (A) + f(t)(B,C,D) + E + W(s) + K(t);
//         g)   E = D; D = C; C = shift left circular by 30 of (B); B = A; A = TEMP;
//         h) For t = 16 thru 79, do:
//         i)   Calculate a modified address s = t & 7'h0F;
//         j)   W(s) = shift left circular by 1 of
//                         (   W((s + 13) & 7'h0F) ^ W((s + 8) & 7'h0F)
//                           ^ W((s + 2)  & 7'h0F) ^ W((s + 0) & 7'h0F));
//         k)   TEMP = shift left circular by 5 (A) + f(t)(B,C,D) + E + W(s) + K(t);
//         l)   E = D; D = C; C = shift left circular by 30 of (B); B = A; A = TEMP;
//         m) After each block, H_0 = H_0 + A, H_1 = H_1 + B; H_2 = H_2 + C; H_3 = H_3 + D, H_4 = H_4 + E;
//        After the last block is operated on, the Digest is {H_0, H_1, H_2, H_3, H_4};
//
// NOTE:  There is one place above where 5 numbers are added together.  This might
//          turn out to be slow.  They can be done sequentially.  It might also be
//          possible to use 2 adders in parallel to do this faster.  It might finally
//          possible to use a Wallace Tree adder scheme.  This will unfortunately
//          NOT fit will into an FPGA with a fast adder built-in.
//
// NOTE:  The standard gives 2 example messages:
//        {8'h61, 8'h62, 8'h63} results in the digest
//        {32'hA9993E36, 32'h4706816A, 32'hBA3E2571, 32'h7850C26C, 32'h9CD0D89D}
//
//        The message with ascii representation (no parity bit)
//          "abcdbcdecdefdefgefghfghighijhijkijkljklmklnmlmnomnopnopq"
//        results in a 2-block message with digest
//        {32'h84983E44, 32'h1C3BD26E, 32'hBAAE4AA1, 32'hF95129E5, 32'hE54670F1}
//
//        The message consisting of 1 million "a" characters results in digest
//        {32'h34AA973C, 32'hD4C4DAA4, 32'hF61EEB2B, 32'hDBAD2731, 32'h6534016F}
//
//        More test messages are available via the reference at the top.
//
//===========================================================================

`timescale 1ns/1ps

module sha_1_digest (
  use_F_for_CRC,
  present_crc,
  data_in_8,
  next_crc
);
  input   use_F_for_CRC;
  input  [`NUMBER_OF_BITS_IN_CRC - 1 : 0] present_crc;
  input  [7:0] data_in_8;
  output [`NUMBER_OF_BITS_IN_CRC - 1 : 0] next_crc;

endmodule


