//===========================================================================
// $Id: pci_blue_pad_sharer.v,v 1.3 2001-02-26 11:50:11 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  Logic to let two on-chip PCI Interfaces share a single set of
//           external PCI IO Pads, while letting the two interfaces talk
//           to one-another.
//           This is mostly a 2-1 MUX on outgoing data signals and an or-gate
//           on outgoing OE signals.
//           The PCI Pads themselves are responsible for looping output data
//           back to the input wires without using the external signals
//           when one on-chip interface talks to the other.
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
// NOTE:  The signals DEVSEL, TRDY, and STOP share a single OE signal.
//        See the PCI Local Bus Specification revision 2.2, in
//        Appendix B, State Machines, target section.
//        FRAME and IRDY do NOT share an output signal, as documented
//        in the Master section.
//
// NOTE:  PCI SPec requires that when driving off-chip, device may NOT
//        receive driven signals for signal integrity reasons.  This
//        pad sharing logic must loop back from output to input in this
//        case, bypassing the external IO pads.  See the PCI Local Bus
//        Specification revision 2.2, section 3.10, paragraph 9.
//
// NOTE:  This code does not correctly implement the above requirement!  FIX
//
//===========================================================================
 

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/10ps

module pci_blue_pad_sharer (
  pci_ad_out_next_a, pci_ad_out_oe_next_a,
  pci_cbe_out_next_a, pci_cbe_out_oe_next_a,
  pci_par_out_next_a, pci_par_out_oe_next_a,
  pci_frame_out_next_a, pci_frame_out_oe_next_a,
  pci_irdy_out_next_a, pci_irdy_out_oe_next_a,
  pci_devsel_out_next_a, pci_dts_out_oe_next_a,
  pci_trdy_out_next_a, pci_stop_out_next_a,
  pci_perr_out_next_a, pci_perr_out_oe_next_a,
  pci_serr_out_oe_next_a,

  pci_ad_out_next_b, pci_ad_out_oe_next_b,
  pci_cbe_out_next_b, pci_cbe_out_oe_next_b,
  pci_par_out_next_b, pci_par_out_oe_next_b,
  pci_frame_out_next_b, pci_frame_out_oe_next_b,
  pci_irdy_out_next_b, pci_irdy_out_oe_next_b,
  pci_devsel_out_next_b, pci_dts_out_oe_next_b,
  pci_trdy_out_next_b, pci_stop_out_next_b,
  pci_perr_out_next_b, pci_perr_out_oe_next_b,
  pci_serr_out_oe_next_b,

  pci_ad_out_next, pci_ad_out_oe_next,
  pci_cbe_out_next, pci_cbe_out_oe_next,
  pci_par_out_next, pci_par_out_oe_next,
  pci_frame_out_next, pci_frame_out_oe_next,
  pci_irdy_out_next, pci_irdy_out_oe_next,
  pci_devsel_out_next, pci_dts_out_oe_next,
  pci_trdy_out_next, pci_stop_out_next,
  pci_perr_out_next, pci_perr_out_oe_next,
  pci_serr_out_oe_next
);

// wires which go to the first of N internal PCI interfaces
  input [31:0] pci_ad_out_next_a;
  input   pci_ad_out_oe_next_a;
  input [3:0] pci_cbe_out_next_a;
  input [3:0] pci_cbe_out_oe_next_a;
  input   pci_par_out_next_a, pci_par_out_oe_next_a;
  input   pci_frame_out_next_a, pci_frame_out_oe_next_a;
  input   pci_irdy_out_next_a, pci_irdy_out_oe_next_a;
  input   pci_devsel_out_next_a, pci_dts_out_oe_next_a;
  input   pci_trdy_out_next_a, pci_stop_out_next_a;
  input   pci_perr_out_next_a, pci_perr_out_oe_next_a;
  input   pci_serr_out_oe_next_a;

// wires which go to the first of N internal PCI interfaces
  input [31:0] pci_ad_out_next_b;
  input   pci_ad_out_oe_next_b;
  input [3:0] pci_cbe_out_next_b;
  input [3:0] pci_cbe_out_oe_next_b;
  input   pci_par_out_next_b, pci_par_out_oe_next_b;
  input   pci_frame_out_next_b, pci_frame_out_oe_next_b;
  input   pci_irdy_out_next_b, pci_irdy_out_oe_next_b;
  input   pci_devsel_out_next_b, pci_dts_out_oe_next_b;
  input   pci_trdy_out_next_b, pci_stop_out_next_b;
  input   pci_perr_out_next_b, pci_perr_out_oe_next_b;
  input   pci_serr_out_oe_next_b;

// wires which actually go to the IO pads
  output [31:0] pci_ad_out_next;
  output  pci_ad_out_oe_next;
  output [3:0] pci_cbe_out_next;
  output [3:0] pci_cbe_out_oe_next;
  output  pci_par_out_next, pci_par_out_oe_next;
  output  pci_frame_out_next, pci_frame_out_oe_next;
  output  pci_irdy_out_next, pci_irdy_out_oe_next;
  output  pci_devsel_out_next, pci_dts_out_oe_next;
  output  pci_trdy_out_next, pci_stop_out_next;
  output  pci_perr_out_next, pci_perr_out_oe_next;
  output                       pci_serr_out_oe_next;

  assign  pci_ad_out_next[7:0] =
                    ({8{pci_ad_out_oe_next_a}} & pci_ad_out_next_a[7:0])
                  | ({8{pci_ad_out_oe_next_b}} & pci_ad_out_next_b[7:0]);
  assign  pci_ad_out_next[15:8] =
                    ({8{pci_ad_out_oe_next_a}} & pci_ad_out_next_a[15:8])
                  | ({8{pci_ad_out_oe_next_b}} & pci_ad_out_next_b[15:8]);
  assign  pci_ad_out_next[23:16] =
                    ({8{pci_ad_out_oe_next_a}} & pci_ad_out_next_a[23:16])
                  | ({8{pci_ad_out_oe_next_b}} & pci_ad_out_next_b[23:16]);
  assign  pci_ad_out_next[31:24] =
                    ({8{pci_ad_out_oe_next_a}} & pci_ad_out_next_a[31:24])
                  | ({8{pci_ad_out_oe_next_b}} & pci_ad_out_next_b[31:24]);
  assign  pci_ad_out_oe_next =
                    pci_ad_out_oe_next_a | pci_ad_out_oe_next_a;

  assign  pci_cbe_out_next[3:0] =
                    (pci_cbe_out_oe_next_a[3:0] & pci_cbe_out_next_a[3:0])
                  | (pci_cbe_out_oe_next_b[3:0] & pci_cbe_out_next_b[3:0]);
  assign  pci_cbe_out_oe_next[3:0] =
                    pci_cbe_out_oe_next_a[3:0] | pci_cbe_out_oe_next_b[3:0];

  assign  pci_par_out_next =
                    (pci_par_out_oe_next_a & pci_par_out_next_a)
                  | (pci_par_out_oe_next_b & pci_par_out_next_b);
  assign  pci_par_out_oe_next = (pci_par_out_oe_next_a | pci_par_out_oe_next_b);

  assign  pci_frame_out_next =
                    (pci_frame_out_oe_next_a & pci_frame_out_next_a)
                  | (pci_frame_out_oe_next_b & pci_frame_out_next_b);
  assign  pci_frame_out_oe_next = pci_frame_out_oe_next_a | pci_frame_out_oe_next_b;

  assign  pci_irdy_out_next = 
                    (pci_irdy_out_oe_next_a & pci_irdy_out_next_a)
                  | (pci_irdy_out_oe_next_b & pci_irdy_out_next_b);
  assign  pci_irdy_out_oe_next = pci_irdy_out_oe_next_a | pci_irdy_out_oe_next_b;

  assign  pci_devsel_out_next =
                    (pci_dts_out_oe_next_a & pci_devsel_out_next_a)
                  | (pci_dts_out_oe_next_b & pci_devsel_out_next_b);
  assign  pci_dts_out_oe_next = pci_dts_out_oe_next_a | pci_dts_out_oe_next_b;

  assign  pci_trdy_out_next = 
                    (pci_dts_out_oe_next_a & pci_trdy_out_next_a)
                  | (pci_dts_out_oe_next_b & pci_trdy_out_next_b);

  assign  pci_stop_out_next =
                    (pci_dts_out_oe_next_a & pci_stop_out_next_a)
                  | (pci_dts_out_oe_next_b & pci_stop_out_next_b);

  assign  pci_perr_out_next =
                    (pci_perr_out_oe_next_a & pci_perr_out_next_a)
                  | (pci_perr_out_oe_next_b & pci_perr_out_next_b);
  assign  pci_perr_out_oe_next = pci_perr_out_oe_next_a | pci_perr_out_oe_next_b;

  assign  pci_serr_out_oe_next = pci_serr_out_oe_next_a | pci_serr_out_oe_next_b;

endmodule

