//===========================================================================
// $Id: pci_blue_null_interface.v,v 1.6 2001-06-20 11:25:29 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  A Fake PCI Interface which never drives any Bus activity.
//           This is used to test the PCI Pad Sharing logic used to let two
//           independent on-chip PCI interfaces share a single set of external
//           PCI Pads, while letting the 2 interfaces talk to one-another.
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
// This code was developed using Verilogger Pro, by Synapticad.
// Their support is greatly appreciated.
//
// NOTE:  If there are 2 PCI controllers on-chip, they will both use the
//        same IO pads.  To simplify testing, this version of a PCI
//        interface has the same interface as a real PCI interface, but
//        it generates constants which never cause PCI activity.
//
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/10ps

module pci_blue_null_interface (
  pci_ad_in_reg,       pci_ad_out_next,       pci_ad_out_oe_next,
  pci_cbe_in_reg,      pci_cbe_out_next,      pci_cbe_out_oe_next,
  pci_par_in_reg,      pci_par_out_next,      pci_par_out_oe_next,
  pci_frame_in_reg,    pci_frame_out_next,    pci_frame_out_oe_next,
  pci_irdy_in_reg,     pci_irdy_out_next,     pci_irdy_out_oe_next,
  pci_devsel_in_reg,   pci_devsel_out_next,   pci_dts_out_oe_next,
  pci_trdy_in_reg,     pci_trdy_out_next,
  pci_stop_in_reg,     pci_stop_out_next,
  pci_perr_in_reg,     pci_perr_out_next,     pci_perr_out_oe_next,
  pci_serr_in_reg,                            pci_serr_out_oe_next,

`ifdef PCI_EXTERNAL_IDSEL
  pci_idsel_in_reg,
`endif // PCI_EXTERNAL_IDSEL
`ifdef PCI_EXTERNAL_INT
  pci_int_out,
`endif // PCI_EXTERNAL_INT
`ifdef PCI_MASTER
  pci_req_out_next,
  pci_gnt_in_reg,
`endif // PCI_MASTER
  pci_clk, pci_reset_comb
);
  input  [31:0] pci_ad_in_reg;
  output [31:0] pci_ad_out_next;
  output  pci_ad_out_oe_next;
  input  [3:0] pci_cbe_in_reg;
  output [3:0] pci_cbe_out_next;
  output [3:0] pci_cbe_out_oe_next;
  input   pci_par_in_reg;
  output  pci_par_out_next, pci_par_out_oe_next;
  input   pci_frame_in_reg;
  output  pci_frame_out_next, pci_frame_out_oe_next;
  input   pci_irdy_in_reg;
  output  pci_irdy_out_next, pci_irdy_out_oe_next;
  input   pci_devsel_in_reg;
  output  pci_devsel_out_next, pci_dts_out_oe_next;
  input   pci_trdy_in_reg;
  output  pci_trdy_out_next;
  input   pci_stop_in_reg;
  output  pci_stop_out_next;
  input   pci_perr_in_reg;
  output  pci_perr_out_next, pci_perr_out_oe_next;
  input   pci_serr_in_reg;
  output  pci_serr_out_oe_next;
`ifdef PCI_EXTERNAL_IDSEL
  input   pci_idsel_in_reg;
`endif // PCI_EXTERNAL_IDSEL
`ifdef PCI_EXTERNAL_INT
  output  pci_int_out;
`endif // PCI_EXTERNAL_INT
`ifdef PCI_MASTER
  output  pci_req_out_next;
  input   pci_gnt_in_reg;
`endif // PCI_MASTER

  input   pci_clk, pci_reset_comb;

  wire   [31:0] pci_ad_out_next = 32'h00000000;
  wire    pci_ad_out_oe_next =    1'b0;
  wire   [3:0] pci_cbe_out_next =   4'h0;
  wire   [3:0] pci_cbe_out_oe_next = 4'h0;
  wire    pci_par_out_next =      1'bx;
  wire    pci_par_out_oe_next =   1'b0;
  wire    pci_frame_out_next =    1'bx;
  wire    pci_frame_out_oe_next = 1'b0;
  wire    pci_irdy_out_next =     1'bx;
  wire    pci_irdy_out_oe_next =  1'b0;
  wire    pci_devsel_out_next =   1'bx;
  wire    pci_dts_out_oe_next =   1'b0;
  wire    pci_trdy_out_next =     1'bx;
  wire    pci_stop_out_next =     1'bx;
  wire    pci_perr_out_next =     1'bx;
  wire    pci_perr_out_oe_next =  1'b0;
  wire    pci_serr_out_oe_next =  1'b0;

endmodule

