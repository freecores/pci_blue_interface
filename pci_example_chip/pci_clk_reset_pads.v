//===========================================================================
// $Id: pci_clk_reset_pads.v,v 1.3 2001-02-26 11:50:12 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  The IO pads used to receive the PCI Clock and PCI Reset
//           signals.  Since PCI Timing is critical, this module also
//           includes an example of an on-chip PCI PLL, which will
//           probably be needed for bus frequencies above 33 MHz.
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

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/10ps

module pci_clk_reset_pads (
  pci_ext_clk, pci_ext_reset_l,
  pci_pll_bypass,
  pci_reset_out_oe_comb,
  pci_clk, pci_reset_raw
);
  input   pci_ext_clk;
  inout   pci_ext_reset_l;
  input   pci_pll_bypass;
  input   pci_reset_out_oe_comb;
  output  pci_clk, pci_reset_raw;

// Receive the raw PCI clock
  wire    pci_clk_ref_in;
pci_clock_input_pad clock (
        .clk_ref_in      (pci_clk_ref_in),
        .clk_ext         (pci_ext_clk)
);

// Use a PLL to distribute the clock with small skew
  wire    pci_clk_pll_out, pci_clk_feedback;
pci_clock_pll pll (
        .clk_ref_in      (pci_clk_ref_in),
        .clk_feedback    (pci_clk_feedback),
        .pll_bypass      (pci_pll_bypass),
        .pci_clk         (pci_clk_pll_out)
);

// Distribute the clock to all flops with minimum skew
  wire    pci_clk_int;
pci_clock_tree pci_clock_tree (
        .pci_clk_pll_out (pci_clk_pll_out),
        .pci_clk         (pci_clk_int)
);

// Assign the output of the clock tree to the output port, to avoid using
//   it as both a module output and an internal input;
  assign  pci_clk = pci_clk_int;
  assign  pci_clk_feedback = pci_clk_int;

// Receive (or drive) the asynchronous PCI Reset signal
  wire    pci_reset_in_l;
pci_combinational_io_pad reset (
        .d_in_comb       (pci_reset_in_l),
        .d_out_comb      (1'b0),
        .d_out_oe_comb   (pci_reset_out_oe_comb),
        .d_ext           (pci_ext_reset_l)
);
  assign  pci_reset_raw = ~pci_reset_in_l;
endmodule

