//===========================================================================
// $Id: rc5_encrypt.v,v 1.1 2001-08-24 07:21:09 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  Calculate either RC-4 or RC-5 encryption of some data.
//           I don't enough to even write the description (even though
//             I HAVE written RC5 code!
//           See: RFC 2040 for details about RC5.
//           Also see: ftp://ftp.rsasecurity.com/pub/rsalabs/rc5/
//           See: http://www.rsasecurity.com/rsalabs/faq/3-6-3.html
//           Also see: http://burtleburtle.net/bob/rand/isaac.html#RC4code
//           Also see: http://www.achtung.com/crypto/rc4.html
//           Want to do 1 or more bytes per clock.
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
// NOTE:  
//
//===========================================================================

`timescale 1ns/1ps

module rc5_encrypt (
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

module rc5_decrypt (
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



