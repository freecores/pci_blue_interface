//===========================================================================
// $Id: pci_target_pads.v,v 1.8 2001-07-03 09:21:30 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  The pads used by a PCI Target.  For performance reasons,
//           the input and output data Flops are included in these
//           modules.  The OE signals are less timing-critical, so
//           those flops are not included here.
//           In the case that an on-chip PCI Master must talk to an
//           on-chip PCI Target, the IO pads must bypass data from the
//           output directly to the input; the target cannot use the
//           external signals.  This bypass mode is selected at compile
//           time by options in pci_blue_options.vh
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
// NOTE:  These pads are instantiated in the text here in the order
//        suggested for a 32-bit PCI chip in a PQFP package.
//        See the PCI Local Bus Spec Revision 2.2 section 4.6.2.
//
// NOTE:  Most of these pads produce input signals which are latched
//        in the IO pad.  Hopefully placement of the logic on-chip
//        will be less of a problem.
//
// NOTE:  In order to run with 0 wait states, the signals pci_ad_out_en_next,
//        and pci_cbe_out_en_next, are very critical.  These must be generated
//        with the minimum delay, and must be routed to the Enable signals of
//        the IO Flops as quickly as possible.  These signals have 3 nSec to
//        be received from the IRDY/TRDY/STOP signals, to get to the IO flops,
//        and to set up.
//        This timing will be very difficult to meet unless placement is good.
//
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/1ps

module pci_target_pads (
  pci_ext_ad, pci_ext_cbe_l, pci_ext_par,
  pci_ext_frame_l, pci_ext_irdy_l,
  pci_ext_devsel_l, pci_ext_trdy_l, pci_ext_stop_l,
  pci_ext_perr_l, pci_ext_serr_l,
`ifdef PCI_EXTERNAL_IDSEL
  pci_ext_idsel,
`endif // PCI_EXTERNAL_IDSEL
  pci_ad_in_prev,     pci_ad_out_next,     pci_ad_out_en_next,
                      pci_ad_out_oe_comb,
  pci_cbe_l_in_prev,  pci_cbe_l_in_comb,
                      pci_cbe_l_out_next,  pci_cbe_out_en_next,
                      pci_cbe_out_oe_comb,
  pci_par_in_prev,    pci_par_out_next,    pci_par_out_oe_comb,
  pci_frame_in_prev,  pci_frame_in_comb,
                      pci_frame_out_next,  pci_frame_out_oe_comb,
  pci_irdy_in_prev,   pci_irdy_in_comb,
                      pci_irdy_out_next,   pci_irdy_out_oe_comb,
  pci_devsel_in_prev, pci_devsel_out_next, pci_d_t_s_out_oe_comb,
  pci_trdy_in_prev,   pci_trdy_in_comb,
                      pci_trdy_out_next,
  pci_stop_in_prev,   pci_stop_in_comb,
                      pci_stop_out_next,
  pci_perr_in_prev,   pci_perr_out_next,   pci_perr_out_oe_comb,
  pci_serr_in_prev,                        pci_serr_out_oe_comb,
`ifdef PCI_EXTERNAL_IDSEL
  pci_idsel_in_prev,
`endif // PCI_EXTERNAL_IDSEL
  pci_clk
);

  inout  [`PCI_BUS_DATA_RANGE] pci_ext_ad;
  inout  [`PCI_BUS_CBE_RANGE] pci_ext_cbe_l;
  inout   pci_ext_par;
  inout   pci_ext_frame_l;
  inout   pci_ext_irdy_l;
  inout   pci_ext_devsel_l;
  inout   pci_ext_trdy_l;
  inout   pci_ext_stop_l;
  inout   pci_ext_perr_l;
  inout   pci_ext_serr_l;
`ifdef PCI_EXTERNAL_IDSEL
  input   pci_ext_idsel;
`endif // PCI_EXTERNAL_IDSEL

  output [`PCI_BUS_DATA_RANGE] pci_ad_in_prev;
  input  [`PCI_BUS_DATA_RANGE] pci_ad_out_next;
  input   pci_ad_out_en_next;
  input   pci_ad_out_oe_comb;
  output [`PCI_BUS_CBE_RANGE] pci_cbe_l_in_comb;
  output [`PCI_BUS_CBE_RANGE] pci_cbe_l_in_prev;
  input  [`PCI_BUS_CBE_RANGE] pci_cbe_l_out_next;
  input   pci_cbe_out_en_next;
  input   pci_cbe_out_oe_comb;
  output  pci_par_in_prev;
  input   pci_par_out_next, pci_par_out_oe_comb;
  output  pci_frame_in_prev, pci_frame_in_comb;
  input   pci_frame_out_next, pci_frame_out_oe_comb;
  output  pci_irdy_in_prev, pci_irdy_in_comb;
  input   pci_irdy_out_next, pci_irdy_out_oe_comb;
  output  pci_devsel_in_prev;
  input   pci_devsel_out_next, pci_d_t_s_out_oe_comb;
  output  pci_trdy_in_prev, pci_trdy_in_comb;
  input   pci_trdy_out_next;
  output  pci_stop_in_prev, pci_stop_in_comb;
  input   pci_stop_out_next;
  output  pci_perr_in_prev;
  input   pci_perr_out_next, pci_perr_out_oe_comb;
  output  pci_serr_in_prev;
  input                      pci_serr_out_oe_comb;
`ifdef PCI_EXTERNAL_IDSEL
  output  pci_idsel_in_prev;
`endif // PCI_EXTERNAL_IDSEL
  input   pci_clk;

// Capture wires, then invert to make all internal signals asserted HIGH.
  wire    pci_frame_l_in_prev, pci_frame_l_in_comb;
  wire    pci_irdy_l_in_prev, pci_irdy_l_in_comb;
  wire    pci_devsel_l_in_prev;
  wire    pci_trdy_l_in_prev, pci_trdy_l_in_comb;
  wire    pci_stop_l_in_prev, pci_stop_l_in_comb;
  wire    pci_perr_l_in_prev, pci_serr_l_in_prev;

  assign  pci_frame_in_prev = ~pci_frame_l_in_prev;
  assign  pci_frame_in_comb = ~pci_frame_l_in_comb;
  assign  pci_irdy_in_prev = ~pci_irdy_l_in_prev;
  assign  pci_irdy_in_comb = ~pci_irdy_l_in_comb;
  assign  pci_devsel_in_prev = ~pci_devsel_l_in_prev;
  assign  pci_trdy_in_prev = ~pci_trdy_l_in_prev;
  assign  pci_trdy_in_comb = ~pci_trdy_l_in_comb;
  assign  pci_stop_in_prev = ~pci_stop_l_in_prev;
  assign  pci_stop_in_comb = ~pci_stop_l_in_comb;
  assign  pci_perr_in_prev = ~pci_perr_l_in_prev;
  assign  pci_serr_in_prev = ~pci_serr_l_in_prev;

// Convert internal asserted HIGH signals to external asserted LOW signals
  wire    pci_frame_l_out_next, pci_irdy_l_out_next;
  wire    pci_devsel_l_out_next, pci_trdy_l_out_next, pci_stop_l_out_next;
  wire    pci_perr_l_out_next;

  assign  pci_frame_l_out_next =  ~pci_frame_out_next;
  assign  pci_irdy_l_out_next =   ~pci_irdy_out_next;
  assign  pci_devsel_l_out_next = ~pci_devsel_out_next;
  assign  pci_trdy_l_out_next =   ~pci_trdy_out_next;
  assign  pci_stop_l_out_next =   ~pci_stop_out_next;
  assign  pci_perr_l_out_next =   ~pci_perr_out_next;

// Make no-connect wires to connect to unused pad combinational outputs
  wire   [`PCI_BUS_DATA_RANGE] discard_data_in;
  wire    discard_par_in, discard_idsel_in;
  wire    discard_devsel_l_in;
  wire    discard_serr_l_in, discard_perr_l_in;

// This pad order follows the suggested pinout given in the PCI Revision 2.2
//   specification figure 4-9.  The first pad is to the far right, then next
//   pads are arranged clockwise.
pci_registered_io_pad ad00 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[0]),  .pci_ad_in_prev     (pci_ad_in_prev[0]),
  .pci_ad_out_next   (pci_ad_out_next[0]),  .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[0])
);
pci_registered_io_pad ad01 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[1]),  .pci_ad_in_prev     (pci_ad_in_prev[1]),
  .pci_ad_out_next   (pci_ad_out_next[1]),  .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[1])
);
pci_registered_io_pad ad02 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[2]),  .pci_ad_in_prev     (pci_ad_in_prev[2]),
  .pci_ad_out_next   (pci_ad_out_next[2]),  .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[2])
);
pci_registered_io_pad ad03 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[3]),  .pci_ad_in_prev     (pci_ad_in_prev[3]),
  .pci_ad_out_next   (pci_ad_out_next[3]),  .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[3])
);
pci_registered_io_pad ad04 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[4]),  .pci_ad_in_prev     (pci_ad_in_prev[4]),
  .pci_ad_out_next   (pci_ad_out_next[4]),  .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[4])
);
pci_registered_io_pad ad05 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[5]),  .pci_ad_in_prev     (pci_ad_in_prev[5]),
  .pci_ad_out_next   (pci_ad_out_next[5]),  .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[5])
);
pci_registered_io_pad ad06 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[6]),  .pci_ad_in_prev     (pci_ad_in_prev[6]),
  .pci_ad_out_next   (pci_ad_out_next[6]),  .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[6])
);
pci_registered_io_pad ad07 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[7]),  .pci_ad_in_prev     (pci_ad_in_prev[7]),
  .pci_ad_out_next   (pci_ad_out_next[7]),  .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[7])
);
pci_registered_io_pad cbe0 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (pci_cbe_l_in_comb[0]), .pci_ad_in_prev    (pci_cbe_l_in_prev[0]),
  .pci_ad_out_next (pci_cbe_l_out_next[0]), .pci_ad_out_en_next (pci_cbe_out_en_next),
  .pci_ad_out_oe_comb (pci_cbe_out_oe_comb), .pci_ad_ext        (pci_ext_cbe_l[0])
);
pci_registered_io_pad ad08 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[8]),  .pci_ad_in_prev     (pci_ad_in_prev[8]),
  .pci_ad_out_next   (pci_ad_out_next[8]),  .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[8])
);
pci_registered_io_pad ad09 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[9]),  .pci_ad_in_prev     (pci_ad_in_prev[9]),
  .pci_ad_out_next   (pci_ad_out_next[9]),  .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[9])
);
pci_registered_io_pad ad10 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[10]), .pci_ad_in_prev     (pci_ad_in_prev[10]),
  .pci_ad_out_next   (pci_ad_out_next[10]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb),  .pci_ad_ext         (pci_ext_ad[10])
);
pci_registered_io_pad ad11 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[11]), .pci_ad_in_prev     (pci_ad_in_prev[11]),
  .pci_ad_out_next   (pci_ad_out_next[11]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb),  .pci_ad_ext         (pci_ext_ad[11])
);
pci_registered_io_pad ad12 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[12]), .pci_ad_in_prev     (pci_ad_in_prev[12]),
  .pci_ad_out_next   (pci_ad_out_next[12]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[12])
);
pci_registered_io_pad ad13 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[13]), .pci_ad_in_prev     (pci_ad_in_prev[13]),
  .pci_ad_out_next   (pci_ad_out_next[13]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[13])
);
pci_registered_io_pad ad14 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[14]), .pci_ad_in_prev     (pci_ad_in_prev[14]),
  .pci_ad_out_next   (pci_ad_out_next[14]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext        (pci_ext_ad[14])
);
pci_registered_io_pad ad15 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[15]), .pci_ad_in_prev     (pci_ad_in_prev[15]),
  .pci_ad_out_next   (pci_ad_out_next[15]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[15])
);
pci_registered_io_pad cbe1 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (pci_cbe_l_in_comb[1]), .pci_ad_in_prev    (pci_cbe_l_in_prev[1]),
  .pci_ad_out_next (pci_cbe_l_out_next[1]), .pci_ad_out_en_next (pci_cbe_out_en_next),
  .pci_ad_out_oe_comb (pci_cbe_out_oe_comb), .pci_ad_ext        (pci_ext_cbe_l[1])
);
pci_registered_io_pad par (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_par_in),      .pci_ad_in_prev     (pci_par_in_prev),
  .pci_ad_out_next   (pci_par_out_next),    .pci_ad_out_en_next (1'b1),
  .pci_ad_out_oe_comb (pci_par_out_oe_comb), .pci_ad_ext        (pci_ext_par)
);
pci_registered_io_pad serr (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_serr_l_in),   .pci_ad_in_prev     (pci_serr_l_in_prev),
  .pci_ad_out_next   (1'b0),                .pci_ad_out_en_next (1'b0),
  .pci_ad_out_oe_comb (pci_serr_out_oe_comb), .pci_ad_ext       (pci_ext_serr_l)
);
pci_registered_io_pad perr (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_perr_l_in),   .pci_ad_in_prev     (pci_perr_l_in_prev),
  .pci_ad_out_next   (pci_perr_l_out_next), .pci_ad_out_en_next (1'b1), 
  .pci_ad_out_oe_comb (pci_perr_out_oe_comb), .pci_ad_ext       (pci_ext_perr_l)
);
pci_registered_io_pad stop (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (pci_stop_l_in_comb),  .pci_ad_in_prev     (pci_stop_l_in_prev),
  .pci_ad_out_next   (pci_stop_l_out_next), .pci_ad_out_en_next (1'b1),
  .pci_ad_out_oe_comb (pci_d_t_s_out_oe_comb), .pci_ad_ext      (pci_ext_stop_l)
);
pci_registered_io_pad devsel (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_devsel_l_in),  .pci_ad_in_prev   (pci_devsel_l_in_prev),
  .pci_ad_out_next   (pci_devsel_l_out_next), .pci_ad_out_en_next (1'b1),
  .pci_ad_out_oe_comb (pci_d_t_s_out_oe_comb), .pci_ad_ext      (pci_ext_devsel_l)
);
pci_registered_io_pad trdy (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (pci_trdy_l_in_comb),  .pci_ad_in_prev     (pci_trdy_l_in_prev),
  .pci_ad_out_next   (pci_trdy_l_out_next), .pci_ad_out_en_next (1'b1),
  .pci_ad_out_oe_comb (pci_d_t_s_out_oe_comb), .pci_ad_ext      (pci_ext_trdy_l)
);
pci_registered_io_pad irdy (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (pci_irdy_l_in_comb),  .pci_ad_in_prev     (pci_irdy_l_in_prev),
  .pci_ad_out_next   (pci_irdy_l_out_next), .pci_ad_out_en_next (1'b1),
  .pci_ad_out_oe_comb (pci_irdy_out_oe_comb), .pci_ad_ext       (pci_ext_irdy_l)
);
pci_registered_io_pad frame (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (pci_frame_l_in_comb), .pci_ad_in_prev     (pci_frame_l_in_prev),
  .pci_ad_out_next   (pci_frame_l_out_next), .pci_ad_out_en_next (1'b1),
  .pci_ad_out_oe_comb (pci_frame_out_oe_comb), .pci_ad_ext      (pci_ext_frame_l)
);
pci_registered_io_pad cbe2 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (pci_cbe_l_in_comb[2]), .pci_ad_in_prev    (pci_cbe_l_in_prev[2]),
  .pci_ad_out_next (pci_cbe_l_out_next[2]), .pci_ad_out_en_next (pci_cbe_out_en_next),
  .pci_ad_out_oe_comb (pci_cbe_out_oe_comb), .pci_ad_ext        (pci_ext_cbe_l[2])
);
pci_registered_io_pad ad16 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[16]), .pci_ad_in_prev     (pci_ad_in_prev[16]),
  .pci_ad_out_next   (pci_ad_out_next[16]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[16])
);
pci_registered_io_pad ad17 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[17]), .pci_ad_in_prev     (pci_ad_in_prev[17]),
  .pci_ad_out_next   (pci_ad_out_next[17]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[17])
);
pci_registered_io_pad ad18 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[18]), .pci_ad_in_prev     (pci_ad_in_prev[18]),
  .pci_ad_out_next   (pci_ad_out_next[18]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[18])
);
pci_registered_io_pad ad19 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[19]), .pci_ad_in_prev     (pci_ad_in_prev[19]),
  .pci_ad_out_next   (pci_ad_out_next[19]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[19])
);
pci_registered_io_pad ad20 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[20]), .pci_ad_in_prev     (pci_ad_in_prev[20]),
  .pci_ad_out_next   (pci_ad_out_next[20]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[20])
);
pci_registered_io_pad ad21 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[21]), .pci_ad_in_prev     (pci_ad_in_prev[21]),
  .pci_ad_out_next   (pci_ad_out_next[21]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[21])
);
pci_registered_io_pad ad22 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[22]), .pci_ad_in_prev     (pci_ad_in_prev[22]),
  .pci_ad_out_next   (pci_ad_out_next[22]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[22])
);
pci_registered_io_pad ad23 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[23]), .pci_ad_in_prev     (pci_ad_in_prev[23]),
  .pci_ad_out_next   (pci_ad_out_next[23]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[23])
);
`ifdef PCI_EXTERNAL_IDSEL
pci_registered_io_pad idsel (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_idsel_in),    .pci_ad_in_prev     (pci_idsel_in_prev),
  .pci_ad_out_next   (1'b0),                .pci_ad_out_en_next (1'b0),
  .pci_ad_out_oe_comb (1'b0),               .pci_ad_ext         (pci_ext_idsel)
);
`endif // PCI_EXTERNAL_IDSEL
pci_registered_io_pad cbe3 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (pci_cbe_l_in_comb[3]), .pci_ad_in_prev    (pci_cbe_l_in_prev[3]),
  .pci_ad_out_next (pci_cbe_l_out_next[3]), .pci_ad_out_en_next (pci_cbe_out_en_next),
  .pci_ad_out_oe_comb (pci_cbe_out_oe_comb), .pci_ad_ext        (pci_ext_cbe_l[3])
);
pci_registered_io_pad ad24 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[24]), .pci_ad_in_prev     (pci_ad_in_prev[24]),
  .pci_ad_out_next   (pci_ad_out_next[24]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[24])
);
pci_registered_io_pad ad25 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[25]), .pci_ad_in_prev     (pci_ad_in_prev[25]),
  .pci_ad_out_next   (pci_ad_out_next[25]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[25])
);
pci_registered_io_pad ad26 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[26]), .pci_ad_in_prev     (pci_ad_in_prev[26]),
  .pci_ad_out_next   (pci_ad_out_next[26]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[26])
);
pci_registered_io_pad ad27 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[27]), .pci_ad_in_prev     (pci_ad_in_prev[27]),
  .pci_ad_out_next   (pci_ad_out_next[27]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[27])
);
pci_registered_io_pad ad28 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[28]), .pci_ad_in_prev     (pci_ad_in_prev[28]),
  .pci_ad_out_next   (pci_ad_out_next[28]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[28])
);
pci_registered_io_pad ad29 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[29]), .pci_ad_in_prev     (pci_ad_in_prev[29]),
  .pci_ad_out_next   (pci_ad_out_next[29]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[29])
);
pci_registered_io_pad ad30 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[30]), .pci_ad_in_prev     (pci_ad_in_prev[30]),
  .pci_ad_out_next   (pci_ad_out_next[30]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[30])
);
pci_registered_io_pad ad31 (
  .pci_clk           (pci_clk),
  .pci_ad_in_comb    (discard_data_in[31]), .pci_ad_in_prev     (pci_ad_in_prev[31]),
  .pci_ad_out_next   (pci_ad_out_next[31]), .pci_ad_out_en_next (pci_ad_out_en_next),
  .pci_ad_out_oe_comb (pci_ad_out_oe_comb), .pci_ad_ext         (pci_ext_ad[31])
);
endmodule

