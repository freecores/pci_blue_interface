//===========================================================================
// $Id: pci_master_pads.v,v 1.3 2001-02-26 11:50:13 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  The IO Pads needed to let 4 external PCI Masters request PCI
//           bus ownership from an on-chip PCI arbiter.
//           These pads will also let an on-chip Master request Bus Mastership
//           from an external Arbiter.
//
// This library is free software; you can distribute it and/or modify it
// under the terms of the GNU Lesser General Public License as published
// by the Free Software Foundation; either version 2.1 of the License, or
// (at your option) any later version.
//
// This library is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser
// General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this library; if not, write to the Free Software Foundation,
// Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.
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

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/1ps

module pci_master_pads (
  pci_ext_inta_l,
`ifdef PCI_EXTERNAL_MASTER
  pci_ext_req_l, pci_ext_gnt_l,
`else // PCI_EXTERNAL_MASTER
`endif // PCI_EXTERNAL_MASTER
  pci_ext_clk, pci_ext_reset_l,

  pci_int_a_in_prev, pci_int_a_out_next,
`ifdef PCI_EXTERNAL_MASTER
  pci_req_in_prev, pci_req_out_comb,
  pci_gnt_in_prev, pci_gnt_out_comb,
`else // PCI_EXTERNAL_MASTER
`endif // PCI_EXTERNAL_MASTER

  pci_clk_in, pci_clk_out, pci_clk_oe,
  pci_reset_l_in, pci_reset_l_out, pci_reset_oe,
  pci_clk, pci_reset_comb
);

  inout   pci_ext_inta_l;
`ifdef PCI_EXTERNAL_MASTER
  inout   pci_ext_req_l;
  inout   pci_ext_gnt_l;
`endif // PCI_EXTERNAL_MASTER
  inout   pci_ext_clk;
  inout   pci_ext_reset_l;

  input   pci_int_a_out_next;
  output  pci_int_a_in_prev;
`ifdef PCI_EXTERNAL_MASTER
  input   pci_req_out_comb;
  output  pci_req_in_prev;
  output  pci_gnt_in_prev;
  input   pci_gnt_out_comb;
`endif // PCI_EXTERNAL_MASTER

  output  pci_clk_in;
  input   pci_clk_out;
  input   pci_clk_oe;
  output  pci_reset_l_in;
  input   pci_reset_l_out;
  input   pci_reset_oe;
  input   pci_clk, pci_reset_comb;

  wire    discard_req_in, discard_gnt_in, discard_int_in;
  wire    discard_clock_prev, discard_reset_prev;

  wire    pci_req_in_l_prev, pci_gnt_in_l_prev, pci_int_a_in_l_prev;
  assign  pci_req_in_prev = ~pci_req_in_l_prev;
  assign  pci_gnt_in_prev = ~pci_gnt_in_l_prev;
  assign  pci_int_a_in_prev = ~pci_int_a_in_l_prev;

// this pad order follows the suggested pinout given in the PCI Revision 2.2
// specification figure 4-9.  Pads start in the middle left and count up.

`ifdef PCI_EXTERNAL_MASTER
pci_registered_io_pad req (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_req_in),      .pci_ad_in_prev     (pci_req_in_l_prev),
  .pci_ad_out_next   (1'b0),                .pci_ad_out_en_next (pci_ad_out_en),
  .pci_ad_out_oe_comb (pci_req_out_comb),   .pci_ad_ext         (pci_ext_req_l)
);
pci_registered_io_pad gnt (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_gnt_in),      .pci_ad_in_prev     (pci_gnt_in_l_prev),
  .pci_ad_out_next   (1'b0),                .pci_ad_out_en_next (pci_ad_out_en),
  .pci_ad_out_oe_comb (pci_gnt_out_comb),   .pci_ad_ext         (pci_ext_gnt_l)
);
`else // PCI_EXTERNAL_MASTER
`endif // PCI_EXTERNAL_MASTER
endmodule

