//===========================================================================
// $Id: ecc_hamming.v,v 1.1 2001-08-19 04:03:20 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  Calculate CRC-32 checksums by applying 8, 16, 32, and 64 bits of
//             new data.
//           CRC-32 needs to start out with a value of all F's.
//           When CRC-32 is applied to a block which ends with the CRC-32 of the
//             block, the resulting CRC-32 checksum is always ????
//
// IMPLEMENTATION NOTE: This is combinational logic.  The user needs to put
//           flops after this.  It is possible that the initial value might be
//           implemented as a preset to the flops, or as a clear with the flops
//           wrapped before and after with inverters.
//
// NOTE: The verilog these routines is based on comes from the nice web page:
//       http://www.easics.be/webtools/crctool
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
//          sequence 0x00, 0x1, 0x3, 0x7, 0x6, 0x4, 0x0 is one such
//          sequence.  It should be possible to make a library which counts
//          in sequences less than 2**n long, yet still has this property.
//
//===========================================================================

`timescale 1ns/1ps

// Given a 32-bit CRC-32 running value, update it using 8 new bits of data.
// The way to make this fast is to find common sub-expressions.
//
// The user needs to supply external flops to make this work.

module ecc_hamming (
  data_in,
  check_digits_in,
  data_out,
  single_error_corrected,
  error_address,
  double_bit_error_detected,
  clk
);

  parameter DATA_BITS = 64;  // do not override in the instantiation.
  parameter CHECK_BITS  8;

  input  [DATA_BITS - 1 : 0] data_in;
  input  [CHECK_BITS - 1 : 0] check_digits_in

  output [DATA_BITS - 1 : 0] data_out;

  output  single_error_corrected;
  output [6:0] error_address;

  output double_bit_error_detected;

  input   clk;

endmodule

