//===========================================================================
// $Id: pci_example_chip.v,v 1.4 2001-03-05 09:54:56 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  Example of a use of the pci_blue_interface.  This file
//           instantiates one synthesizable pci_blue_interface, a set
//           of PCI Pads, and one example_host_interface.
//           An optional PCI Arbiter is also included.
//           The Host Interface gets commands from the top-level stimulus
//           generator, and feeds them to the pci interface.
//           This file also contains logic to allow two independent on-chip
//           PCI interfaces to share a single set of external IO pads,
//           allowing the two interfaces to talk to one-another.
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
// NOTE:  This interface can be configureg to be one of several subsets
//        of the full PCI interface.  The paramaters which determine
//        the configuration of this verilog are contained in pci_params.vh.
//        I have no idea what to do if there are 2 PCI interfaces with
//        different parameter settings.  It might turn out to be best to
//        set the paramaters for this module at the instantiation site.
//
// NOTE:  The PCI bus has many asserted-LOW signals.  However, to make
//        this interface simple, ALL SIGNALS ARE ASSERTED HIGH.  The
//        conversion to their external levels are done in the Pads.
//        One possible exception to this rule is the C_BE bus.
//
// NOTE WORKING:  Think I should double-synchronize on Host side of the
//          FIFOs, instead of single-synchronizing then waiting.
//          This will still allow the writer to write both data and
//          flag at once.  It will remove any metastability issues
//          on the read side of the FIFO, too.
// NOTE WORKING:  Have to make sure FIFOs don't over-write next word
//          in the case of a full FIFO, and when data is written before Flag.
//          Host should still write data, then flag.
//
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/1ps

module pci_example_chip (
  pci_ext_ad, pci_ext_cbe_l, pci_ext_par,
  pci_ext_frame_l, pci_ext_irdy_l,
  pci_ext_devsel_l, pci_ext_trdy_l, pci_ext_stop_l,
  pci_ext_perr_l, pci_ext_serr_l,
`ifdef PCI_EXTERNAL_IDSEL
  pci_ext_idsel,
`endif // PCI_EXTERNAL_IDSEL
`ifdef PCI_EXTERNAL_MASTER
  pci_ext_inta_l,
  pci_ext_req_l, pci_ext_gnt_l,
`else // PCI_EXTERNAL_MASTER
  pci_ext_inta_l, pci_ext_intb_l, pci_ext_intc_l, pci_ext_intd_l,
  pci_int_req_l, pci_int_gnt_l,
  pci_ext_req_l, pci_ext_gnt_l,
`endif // PCI_EXTERNAL_MASTER
  pci_ext_reset_l, pci_ext_clk,
// signals used by the test bench instead of using "." notation
  test_observe_oe_sigs,
  test_master_number, test_address, test_command,
  test_data, test_byte_enables_l, test_size,
  test_make_addr_par_error, test_make_data_par_error,
  test_master_initial_wait_states, test_master_subsequent_wait_states,
  test_target_initial_wait_states, test_target_subsequent_wait_states,
  test_target_devsel_speed, test_fast_back_to_back,
  test_target_termination,
  test_expect_master_abort,
  test_start, test_accepted_l, test_error_event,
  test_device_id
);
  inout  [31:0] pci_ext_ad;
  inout  [3:0] pci_ext_cbe_l;
  inout   pci_ext_par;
  inout   pci_ext_frame_l, pci_ext_irdy_l;
  inout   pci_ext_devsel_l, pci_ext_trdy_l, pci_ext_stop_l;
  inout   pci_ext_perr_l, pci_ext_serr_l;
`ifdef PCI_EXTERNAL_IDSEL
  input   pci_ext_idsel;
`endif // PCI_EXTERNAL_IDSEL
`ifdef PCI_EXTERNAL_MASTER
  output  pci_ext_inta_l;
  output  pci_ext_req_l;
  input   pci_ext_gnt_l;
`else // PCI_EXTERNAL_MASTER
  inout   pci_ext_inta_l, pci_ext_intb_l, pci_ext_intc_l, pci_ext_intd_l;
  output  pci_int_req_l, pci_int_gnt_l;
  input  [3:0] pci_ext_req_l;
  output [3:0] pci_ext_gnt_l;
`endif // PCI_EXTERNAL_MASTER
  input   pci_ext_reset_l, pci_ext_clk;

// signals used by the test bench instead of using "." notation
  output [5:0] test_observe_oe_sigs;
  input  [2:0] test_master_number;
  input  [31:0] test_address;
  input  [3:0] test_command;
  input  [31:0] test_data;
  input  [3:0] test_byte_enables_l;
  input  [3:0] test_size;
  input   test_make_addr_par_error, test_make_data_par_error;
  input  [3:0] test_master_initial_wait_states;
  input  [3:0] test_master_subsequent_wait_states;
  input  [3:0] test_target_initial_wait_states;
  input  [3:0] test_target_subsequent_wait_states;
  input  [1:0] test_target_devsel_speed;
  input   test_fast_back_to_back;
  input  [2:0] test_target_termination;
  input   test_expect_master_abort;
  input   test_start;
  output  test_accepted_l;
  output  test_error_event;
  input  [2:0] test_device_id;

// assemble the verilog signals and modules needed to make a functional PCI device.
// reset and clock related wires
  wire    pci_pll_bypass = 1'b0;
  wire    pci_reset_out_oe_comb = 1'b0;
  wire    pci_clk, pci_reset_raw;

// input wires reporting the value of the external PCI bus
  wire   [31:0] pci_ad_in_prev;
  wire   [3:0] pci_cbe_l_in_prev;
  wire    pci_par_in_prev;
  wire    pci_frame_in_prev, pci_irdy_in_prev;
  wire    pci_devsel_in_prev, pci_trdy_in_prev, pci_stop_in_prev;
  wire    pci_perr_in_prev, pci_serr_in_prev;
  wire    pci_irdy_in_comb, pci_trdy_in_comb;  // critical high-speed wires

// wires to drive the external PCI bus
  wire   [31:0] pci_ad_out_next;
  wire    pci_ad_out_en_next, pci_ad_out_oe_comb;
  wire   [3:0] pci_cbe_l_out_next;
  wire    pci_cbe_out_en_next;
  wire    pci_cbe_out_oe_comb;
  wire    pci_par_out_next, pci_par_out_oe_comb;
  wire    pci_frame_out_next, pci_frame_out_oe_comb;
  wire    pci_irdy_out_next, pci_irdy_out_oe_comb;  // delayed 1 clock from Frame OE
  wire    pci_devsel_out_next, pci_d_t_s_out_oe_comb;
  wire    pci_trdy_out_next, pci_stop_out_next;  // shares OE with above
  wire    pci_perr_out_next, pci_perr_out_oe_comb;
  wire    pci_serr_out_oe_comb;
  wire    pci_idsel_in_prev;

// Make the async-assert, sync-deassert reset needed by all PCI modules
  reg     pci_reset_comb, pci_reset_d1, pci_reset_d2, pci_reset_d3;
  always @(posedge pci_clk or posedge pci_reset_raw)
  begin
        if (pci_reset_raw)
        begin
            pci_reset_d1 <= 1'b1;
            pci_reset_d2 <= 1'b1;
            pci_reset_d3 <= 1'b1;
            pci_reset_comb <= 1'b1;
        end
        else
        begin
            pci_reset_d1 <= 1'b0;
            pci_reset_d2 <= pci_reset_d1;
            pci_reset_d3 <= pci_reset_d2;
            pci_reset_comb <= pci_reset_d3;  // asserts quickly, deasserts slowly
        end
  end

// Make the async-assert, sync-deassert reset needed by all Host modules

// NOTE WORKING need to create host clock which is different than the PCI Clock
  wire    host_clk = pci_clk;

  reg     host_reset, host_reset_d1, host_reset_d2, host_reset_d3;
  always @(posedge host_clk or posedge pci_reset_raw)
  begin
        if (pci_reset_raw)
        begin
            host_reset_d1 <= 1'b1;
            host_reset_d2 <= 1'b1;
            host_reset_d3 <= 1'b1;
            host_reset <= 1'b1;
        end
        else
        begin
            host_reset_d1 <= 1'b0;
            host_reset_d2 <= host_reset_d1;
            host_reset_d3 <= host_reset_d2;
            host_reset <= host_reset_d3;  // asserts quickly, deasserts slowly
        end
  end

// Connect to the external PCI pads
pci_clk_reset_pads pci_clk_reset_pads (
  .pci_ext_clk                (pci_ext_clk),  // external signal
  .pci_ext_reset_l            (pci_ext_reset_l),  // external signal
  .pci_pll_bypass             (pci_pll_bypass),
  .pci_reset_out_oe_comb      (pci_reset_out_oe_comb),
  .pci_clk                    (pci_clk),
  .pci_reset_raw              (pci_reset_raw)
);

// Connect to the external PCI pads
pci_target_pads pci_target_pads (
  .pci_ext_ad                 (pci_ext_ad[31:0]),
  .pci_ext_cbe_l              (pci_ext_cbe_l[3:0]),
  .pci_ext_par                (pci_ext_par),
  .pci_ext_frame_l            (pci_ext_frame_l),
  .pci_ext_irdy_l             (pci_ext_irdy_l),
  .pci_ext_devsel_l           (pci_ext_devsel_l),
  .pci_ext_trdy_l             (pci_ext_trdy_l),
  .pci_ext_stop_l             (pci_ext_stop_l),
  .pci_ext_perr_l             (pci_ext_perr_l),
  .pci_ext_serr_l             (pci_ext_serr_l),
`ifdef PCI_EXTERNAL_IDSEL
  .pci_ext_idsel              (pci_ext_idsel),
`endif // PCI_EXTERNAL_IDSEL
// wires used by the PCI State Machine and buffers to drive the PCI bus
  .pci_ad_in_prev             (pci_ad_in_prev[31:0]),
  .pci_ad_out_next            (pci_ad_out_next[31:0]),
  .pci_ad_out_en_next         (pci_ad_out_en_next),
  .pci_ad_out_oe_comb         (pci_ad_out_oe_comb),
  .pci_cbe_l_in_prev          (pci_cbe_l_in_prev[3:0]),
  .pci_cbe_l_out_next         (pci_cbe_l_out_next[3:0]),
  .pci_cbe_out_en_next        (pci_cbe_out_en_next),
  .pci_cbe_out_oe_comb        (pci_cbe_out_oe_comb),
  .pci_par_in_prev            (pci_par_in_prev),
  .pci_par_out_next           (pci_par_out_next),
  .pci_par_out_oe_comb        (pci_par_out_oe_comb),
  .pci_frame_in_prev          (pci_frame_in_prev),
  .pci_frame_out_next         (pci_frame_out_next),
  .pci_frame_out_oe_comb      (pci_frame_out_oe_comb),
  .pci_irdy_in_prev           (pci_irdy_in_prev),
  .pci_irdy_in_comb           (pci_irdy_in_comb),
  .pci_irdy_out_next          (pci_irdy_out_next),
  .pci_irdy_out_oe_comb       (pci_irdy_out_oe_comb),
  .pci_devsel_in_prev         (pci_devsel_in_prev),
  .pci_devsel_out_next        (pci_devsel_out_next),
  .pci_d_t_s_out_oe_comb      (pci_d_t_s_out_oe_comb),
  .pci_trdy_in_prev           (pci_trdy_in_prev),
  .pci_trdy_in_comb           (pci_trdy_in_comb),
  .pci_trdy_out_next          (pci_trdy_out_next),
  .pci_stop_in_prev           (pci_stop_in_prev),
  .pci_stop_out_next          (pci_stop_out_next),
  .pci_perr_in_prev           (pci_perr_in_prev),
  .pci_perr_out_next          (pci_perr_out_next),
  .pci_perr_out_oe_comb       (pci_perr_out_oe_comb),
  .pci_serr_in_prev           (pci_serr_in_prev),
  .pci_serr_out_oe_comb       (pci_serr_out_oe_comb),
`ifdef PCI_EXTERNAL_IDSEL
  .pci_idsel_in_prev          (pci_idsel_in_prev),
`endif // PCI_EXTERNAL_IDSEL
  .pci_clk                    (pci_clk)
);

// Make visible the internal OE signals.  This makes it MUCH easier to
//   see who is using the bus during simulation.
// OE Observation signals are
//   {frame_oe, irdy_oe, devsel_t_s_oe, ad_oe, cbe_oe, perr_oe}
  assign  test_observe_oe_sigs[5:0] =
               {pci_frame_out_oe_comb, pci_irdy_out_oe_comb, pci_d_t_s_out_oe_comb,
                pci_ad_out_oe_comb, pci_cbe_out_oe_comb, pci_par_out_oe_comb};

// Need to consider the case of multiple devices on-chip sharing the IO pads.
// The problem is that one on-chip device cannot talk to another on-chip
//   device using the external wires.
// See the PCI Local Bus Spec Revision 2.2 section 3.10, item 9.
// This difficult requirement means that the devices must exchange data
//   using internal datapaths when there are several independent devices
//   on the same chip.
// Of course, this is not a problem if there is only one device on chip.
//
// Note that there is a second problem, too.  The several on-chip devices might
//   share a single DMA request wire.  If one device is told to do a retry,
//   the external DMA Request wire must be deasserted for 2 clocks, independent
//   of the activity of the other device, before the retry is done.  See the
//   PCI Local Bus Spec Revision 2.2 section 3.3.3.2.2 for a reminder of this.

// wires to connect to the first, or only, pci controller on chip
  wire    [31:0] pci_ad_out_next_a;
  wire     pci_ad_out_en_next_a, pci_ad_out_oe_comb_a;
  wire    [3:0] pci_cbe_l_out_next_a;
  wire     pci_cbe_out_en_next_a, pci_cbe_out_oe_comb_a;
  wire     pci_par_out_next_a, pci_par_out_oe_comb_a;
  wire     pci_frame_out_next_a, pci_frame_out_oe_comb_a;
  wire     pci_irdy_out_next_a, pci_irdy_out_oe_comb_a;
  wire     pci_devsel_out_next_a, pci_d_t_s_out_oe_comb_a;
  wire     pci_trdy_out_next_a, pci_stop_out_next_a;
  wire     pci_perr_out_next_a, pci_perr_out_oe_comb_a;
  wire     pci_serr_out_oe_comb_a;

`ifdef SUPPORT_MULTIPLE_ONCHIP_INTERFACES

`ifdef SIMULTANEOUS_MASTER_TARGET
// Everything is OK if this other necessary option is selected.
`else // SIMULTANEOUS_MASTER_TARGET
XXXX  Intentional Syntax Error.  Need to define SIMULTANEOUS_MASTER_TARGET
XXXX  whenever the SUPPORT_MULTIPLE_ONCHIP_INTERFACES option is selected.
`endif // SIMULTANEOUS_MASTER_TARGET

// wires from the second interface to drive the external PCI bus
  wire    [31:0] pci_ad_out_next_b;
  wire     pci_ad_out_en_next_b, pci_ad_out_oe_comb_b;
  wire    [3:0] pci_cbe_l_out_next_b;
  wire     pci_cbe_out_en_next_b, pci_cbe_out_oe_comb_b;
  wire     pci_par_out_next_b, pci_par_out_oe_comb_b;
  wire     pci_frame_out_next_b, pci_frame_out_oe_comb_b;
  wire     pci_irdy_out_next_b, pci_irdy_out_oe_comb_b;
  wire     pci_devsel_out_next_b, pci_d_t_s_out_oe_comb_b;
  wire     pci_trdy_out_next_b, pci_stop_out_next_b;
  wire     pci_perr_out_next_b, pci_perr_out_oe_comb_b;
  wire     pci_serr_out_oe_comb_b;

`ifdef PCI_EXTERNAL_IDSEL
  wire    pci_idsel_b_in_reg;
`endif // PCI_EXTERNAL_IDSEL
`ifdef PCI_EXTERNAL_INT
  wire    pci_int_b_out;
`endif // PCI_EXTERNAL_INT
`ifdef PCI_MASTER
  wire    pci_req_b_out_next, pci_gnt_b_in_reg;
`endif // PCI_MASTER

// If there are more than 1 PCI interface on-chip, they will share IO pads.
// This module lets one of the interfaces drive the external PCI bus at
// a time, and the other interface is don't care at that time.

pci_pad_sharer pci_pad_sharer (
  .pci_ad_out_next_a          (pci_ad_out_next_a[31:0]),
  .pci_ad_out_en_next_a       (pci_ad_out_en_next_a),
  .pci_ad_out_oe_comb_a       (pci_ad_out_oe_comb_a),
  .pci_cbe_l_out_next_a       (pci_cbe_l_out_next_a[3:0]),
  .pci_cbe_out_en_next_a      (pci_cbe_out_en_next_a),
  .pci_cbe_out_oe_comb_a      (pci_cbe_out_oe_comb_a),
  .pci_par_out_next_a         (pci_par_out_next_a),
  .pci_par_out_oe_comb_a      (pci_par_out_oe_comb_a),
  .pci_frame_out_next_a       (pci_frame_out_next_a),
  .pci_frame_out_oe_comb_a    (pci_frame_out_oe_comb_a),
  .pci_irdy_out_next_a        (pci_irdy_out_next_a),
  .pci_irdy_out_oe_comb_a     (pci_irdy_out_oe_comb_a),
  .pci_devsel_out_next_a      (pci_devsel_out_next_a),
  .pci_d_t_s_out_oe_comb_a    (pci_d_t_s_out_oe_comb_a),
  .pci_trdy_out_next_a        (pci_trdy_out_next_a),
  .pci_stop_out_next_a        (pci_stop_out_next_a),
  .pci_perr_out_next_a        (pci_perr_out_next_a),
  .pci_perr_out_oe_comb_a     (pci_perr_out_oe_comb_a),
  .pci_serr_out_oe_comb_a     (pci_serr_out_oe_comb_a),

  .pci_ad_out_next_b          (pci_ad_out_next_b[31:0]),
  .pci_ad_out_en_next_b       (pci_ad_out_en_next_b),
  .pci_ad_out_oe_comb_b       (pci_ad_out_oe_comb_b),
  .pci_cbe_l_out_next_b       (pci_cbe_l_out_next_b[3:0]),
  .pci_cbe_out_en_next_b      (pci_cbe_out_en_next_b),
  .pci_cbe_out_oe_comb_b      (pci_cbe_out_oe_comb_b),
  .pci_par_out_next_b         (pci_par_out_next_b),
  .pci_par_out_oe_comb_b      (pci_par_out_oe_comb_b),
  .pci_frame_out_next_b       (pci_frame_out_next_b),
  .pci_frame_out_oe_comb_b    (pci_frame_out_oe_comb_b),
  .pci_irdy_out_next_b        (pci_irdy_out_next_b),
  .pci_irdy_out_oe_comb_b     (pci_irdy_out_oe_comb_b),
  .pci_devsel_out_next_b      (pci_devsel_out_next_b),
  .pci_d_t_s_out_oe_comb_b    (pci_d_t_s_out_oe_comb_b),
  .pci_trdy_out_next_b        (pci_trdy_out_next_b),
  .pci_stop_out_next_b        (pci_stop_out_next_b),
  .pci_perr_out_next_b        (pci_perr_out_next_b),
  .pci_perr_out_oe_comb_b     (pci_perr_out_oe_comb_b),
  .pci_serr_out_oe_comb_b     (pci_serr_out_oe_comb_b),

  .pci_ad_out_next            (pci_ad_out_next[31:0]),
  .pci_ad_out_en_next         (pci_ad_out_en_next),
  .pci_ad_out_oe_comb         (pci_ad_out_oe_comb),
  .pci_cbe_l_out_next         (pci_cbe_l_out_next[3:0]),
  .pci_cbe_out_en_next        (pci_cbe_out_en_next),
  .pci_cbe_out_oe_comb        (pci_cbe_out_oe_comb),
  .pci_par_out_next           (pci_par_out_next),
  .pci_par_out_oe_comb        (pci_par_out_oe_comb),
  .pci_frame_out_next         (pci_frame_out_next),
  .pci_frame_out_oe_comb      (pci_frame_out_oe_comb),
  .pci_irdy_out_next          (pci_irdy_out_next),
  .pci_irdy_out_oe_comb       (pci_irdy_out_oe_comb),
  .pci_devsel_out_next        (pci_devsel_out_next),
  .pci_d_t_s_out_oe_comb      (pci_d_t_s_out_oe_comb),
  .pci_trdy_out_next          (pci_trdy_out_next),
  .pci_stop_out_next          (pci_stop_out_next),
  .pci_perr_out_next          (pci_perr_out_next),
  .pci_perr_out_oe_comb       (pci_perr_out_oe_comb),
  .pci_serr_out_oe_comb       (pci_serr_out_oe_comb)
);

// If more than 1 internal PCI controllers are needed, they will share
// IO pads.  This module asserts constants to act like an idle interface.
pci_null_interface pci_null_interface (
  .pci_ad_out_next            (pci_ad_out_next_b[31:0]),
  .pci_ad_out_en_next         (pci_ad_out_en_next_b),
  .pci_ad_out_oe_comb         (pci_ad_out_oe_comb_b),
  .pci_cbe_l_out_next         (pci_cbe_l_out_next_b[3:0]),
  .pci_cbe_out_en_next        (pci_cbe_out_en_next_b),
  .pci_cbe_out_oe_comb        (pci_cbe_out_oe_comb_b),
  .pci_par_out_next           (pci_par_out_next_b),
  .pci_par_out_oe_comb        (pci_par_out_oe_comb_b),
  .pci_frame_out_next         (pci_frame_out_next_b),
  .pci_frame_out_oe_comb      (pci_frame_out_oe_comb_b),
  .pci_irdy_out_next          (pci_irdy_out_next_b),
  .pci_irdy_out_oe_comb       (pci_irdy_out_oe_comb_b),
  .pci_devsel_out_next        (pci_devsel_out_next_b),
  .pci_d_t_s_out_oe_comb      (pci_d_t_s_out_oe_comb_b),
  .pci_trdy_out_next          (pci_trdy_out_next_b),
  .pci_stop_out_next          (pci_stop_out_next_b),
  .pci_perr_out_next          (pci_perr_out_next_b),
  .pci_perr_out_oe_comb       (pci_perr_out_oe_comb_b),
  .pci_serr_out_oe_comb       (pci_serr_out_oe_comb_b),

  .pci_ad_in_prev             (pci_ad_in_prev[31:0]),
  .pci_cbe_l_in_prev          (pci_cbe_l_in_prev[3:0]),
  .pci_par_in_prev            (pci_par_in_prev),
  .pci_frame_in_prev          (pci_frame_in_prev),
  .pci_irdy_in_prev           (pci_irdy_in_prev),
  .pci_irdy_in_comb           (pci_irdy_in_comb),
  .pci_devsel_in_prev         (pci_devsel_in_prev),
  .pci_trdy_in_prev           (pci_trdy_in_prev),
  .pci_trdy_in_comb           (pci_trdy_in_comb),
  .pci_stop_in_prev           (pci_stop_in_prev),
  .pci_perr_in_prev           (pci_perr_in_prev),
  .pci_serr_in_prev           (pci_serr_in_prev),
`ifdef PCI_EXTERNAL_IDSEL
  .pci_idsel_in_prev          (pci_idsel_in_prev),
`endif // PCI_EXTERNAL_IDSEL
`ifdef PCI_EXTERNAL_INT
  .pci_int_out                (pci_int_b_out),
`endif // PCI_EXTERNAL_INT
`ifdef PCI_MASTER
  .pci_req_out_next           (pci_req_b_out_next),
  .pci_gnt_in_reg             (pci_gnt_b_in_reg),
`endif // PCI_MASTER
  .pci_reset_comb             (pci_reset_comb),
  .pci_clk                    (pci_clk)
);

`else // SUPPORT_MULTIPLE_ONCHIP_INTERFACES
  assign  pci_ad_out_next       = pci_ad_out_next_a[31:0];
  assign  pci_ad_out_en_next    = pci_ad_out_en_next_a;
  assign  pci_ad_out_oe_comb    = pci_ad_out_oe_comb_a;
  assign  pci_cbe_l_out_next    = pci_cbe_l_out_next_a[3:0];
  assign  pci_cbe_out_en_next   = pci_cbe_out_en_next_a;
  assign  pci_cbe_out_oe_comb   = pci_cbe_out_oe_comb_a;
  assign  pci_par_out_next      = pci_par_out_next_a;
  assign  pci_par_out_oe_comb   = pci_par_out_oe_comb_a;
  assign  pci_frame_out_next    = pci_frame_out_next_a;
  assign  pci_frame_out_oe_comb = pci_frame_out_oe_comb_a;
  assign  pci_irdy_out_next     = pci_irdy_out_next_a;
  assign  pci_irdy_out_oe_comb  = pci_irdy_out_oe_comb_a;
  assign  pci_devsel_out_next   = pci_devsel_out_next_a;
  assign  pci_d_t_s_out_oe_comb = pci_d_t_s_out_oe_comb_a;
  assign  pci_trdy_out_next     = pci_trdy_out_next_a;
  assign  pci_stop_out_next     = pci_stop_out_next_a;
  assign  pci_perr_out_next     = pci_perr_out_next_a;
  assign  pci_perr_out_oe_comb  = pci_perr_out_oe_comb_a;
  assign  pci_serr_out_oe_comb  = pci_serr_out_oe_comb_a;
`endif // SUPPORT_MULTIPLE_ONCHIP_INTERFACES

// Instantiate one operational copy of the PCI interface

// Coordinate Write_Fence with CPU
  wire    pci_target_requests_write_fence, host_allows_write_fence;
// Host uses these wires to request PCI activity.
  wire   [31:0] pci_master_ref_address;
  wire   [3:0] pci_master_ref_command;
  wire    pci_master_ref_config;
  wire   [3:0] pci_master_byte_enables_l;
  wire   [31:0] pci_master_write_data;
  wire   [31:0] pci_master_read_data;
  wire    pci_master_addr_valid, pci_master_data_valid;
  wire    pci_master_requests_serr, pci_master_requests_perr;
  wire    pci_master_requests_last;
  wire    pci_master_data_consumed;
  wire    pci_master_ref_error;
// PCI Interface uses these wires to request local memory activity.   
  wire   [31:0] pci_target_ref_address;
  wire   [3:0] pci_target_ref_command;
  wire   [3:0] pci_target_byte_enables_l;
  wire   [31:0] pci_target_write_data;
  wire   [31:0] pci_target_read_data;
  wire    pci_target_busy;
  wire    pci_target_ref_start;
  wire    pci_target_requests_abort, pci_target_requests_perr;
  wire    pci_target_requests_disconnect;
  wire    pci_target_data_transferred;
// PCI_Error_Report.
  wire   [9:0] pci_interface_reports_errors;
  wire    pci_config_reg_reports_errors;
  wire    pci_host_sees_pci_reset;

pci_blue_interface pci_blue_interface (
// Coordinate Write_Fence with CPU
  .pci_target_requests_write_fence (pci_target_requests_write_fence),
  .host_allows_write_fence    (host_allows_write_fence),
// Host uses these wires to request PCI activity.
  .pci_master_ref_address     (pci_master_ref_address[31:0]),
  .pci_master_ref_command     (pci_master_ref_command[3:0]),
  .pci_master_ref_config      (pci_master_ref_config),
  .pci_master_byte_enables_l  (pci_master_byte_enables_l[3:0]),
  .pci_master_write_data      (pci_master_write_data[31:0]),
  .pci_master_read_data       (pci_master_read_data[31:0]),
  .pci_master_addr_valid      (pci_master_addr_valid),
  .pci_master_data_valid      (pci_master_data_valid),
  .pci_master_requests_serr   (pci_master_requests_serr),
  .pci_master_requests_perr   (pci_master_requests_perr),
  .pci_master_requests_last   (pci_master_requests_last),
  .pci_master_data_consumed   (pci_master_data_consumed),
  .pci_master_ref_error       (pci_master_ref_error),
// PCI Interface uses these wires to request local memory activity.   
  .pci_target_ref_address     (pci_target_ref_address[31:0]),
  .pci_target_ref_command     (pci_target_ref_command[3:0]),
  .pci_target_byte_enables_l  (pci_target_byte_enables_l[3:0]),
  .pci_target_write_data      (pci_target_write_data[31:0]),
  .pci_target_read_data       (pci_target_read_data[31:0]),
  .pci_target_busy            (pci_target_busy),
  .pci_target_ref_start       (pci_target_ref_start),
  .pci_target_requests_abort  (pci_target_requests_abort),
  .pci_target_requests_perr   (pci_target_requests_perr),
  .pci_target_requests_disconnect (pci_target_requests_disconnect),
  .pci_target_data_transferred (pci_target_data_transferred),
// PCI_Error_Report.
  .pci_interface_reports_errors (pci_interface_reports_errors[9:0]),
  .pci_config_reg_reports_errors (pci_config_reg_reports_errors),
  .pci_host_sees_pci_reset    (pci_host_sees_pci_reset),
// Generic host interface wires
  .host_reset_to_PCI_interface (host_reset),
  .host_clk                   (host_clk),
  .host_sync_clk              (host_clk),
// Wires used by the PCI State Machine and PCI Bus Combiner to drive the PCI bus
  .pci_ad_in_prev             (pci_ad_in_prev[31:0]),
  .pci_ad_out_next            (pci_ad_out_next_a[31:0]),
  .pci_ad_out_en_next         (pci_ad_out_en_next_a),
  .pci_ad_out_oe_comb         (pci_ad_out_oe_comb_a),
  .pci_cbe_l_in_prev          (pci_cbe_l_in_prev[3:0]),
  .pci_cbe_l_out_next         (pci_cbe_l_out_next_a[3:0]),
  .pci_cbe_out_en_next        (pci_cbe_out_en_next_a),
  .pci_cbe_out_oe_comb        (pci_cbe_out_oe_comb_a),
  .pci_par_in_prev            (pci_par_in_prev),
  .pci_par_in_comb            (pci_par_in_comb),
  .pci_par_out_next           (pci_par_out_next_a),
  .pci_par_out_oe_comb        (pci_par_out_oe_comb_a),
  .pci_frame_in_prev          (pci_frame_in_prev),
  .pci_frame_out_next         (pci_frame_out_next_a),
  .pci_frame_out_oe_comb      (pci_frame_out_oe_comb_a),
  .pci_irdy_in_prev           (pci_irdy_in_prev),
  .pci_irdy_in_comb           (pci_irdy_in_comb),
  .pci_irdy_out_next          (pci_irdy_out_next_a),
  .pci_irdy_out_oe_comb       (pci_irdy_out_oe_comb_a),
  .pci_devsel_in_prev         (pci_devsel_in_prev),
  .pci_devsel_out_next        (pci_devsel_out_next_a),
  .pci_d_t_s_out_oe_comb      (pci_d_t_s_out_oe_comb_a),
  .pci_trdy_in_prev           (pci_trdy_in_prev),
  .pci_trdy_in_comb           (pci_trdy_in_comb),
  .pci_trdy_out_next          (pci_trdy_out_next_a),
  .pci_stop_in_prev           (pci_stop_in_prev),
  .pci_stop_out_next          (pci_stop_out_next_a),
  .pci_perr_in_prev           (pci_perr_in_prev),
  .pci_perr_out_next          (pci_perr_out_next_a),
  .pci_perr_out_oe_comb       (pci_perr_out_oe_comb_a),
  .pci_serr_in_prev           (pci_serr_in_prev),
  .pci_serr_out_oe_comb       (pci_serr_out_oe_comb_a),
`ifdef PCI_EXTERNAL_IDSEL
  .pci_idsel_in_prev          (pci_idsel_in_prev),
`endif  // PCI_EXTERNAL_IDSEL
  .test_device_id             (test_device_id[2:0]),
  .interface_error_event      (test_error_event),
  .pci_reset_comb             (pci_reset_comb),
  .pci_clk                    (pci_clk),
  .pci_sync_clk               (pci_clk)
);

// Instantiate a fake host adaptor to exercise the PCI interface
pci_example_host_controller pci_example_host_controller (
// Coordinate Write_Fence with CPU
  .pci_target_requests_write_fence (pci_target_requests_write_fence),
  .host_allows_write_fence    (host_allows_write_fence),
// Host uses these wires to request PCI activity.
  .pci_master_ref_address     (pci_master_ref_address[31:0]),
  .pci_master_ref_command     (pci_master_ref_command[3:0]),
  .pci_master_ref_config      (pci_master_ref_config),
  .pci_master_byte_enables_l  (pci_master_byte_enables_l[3:0]),
  .pci_master_write_data      (pci_master_write_data[31:0]),
  .pci_master_read_data       (pci_master_read_data[31:0]),
  .pci_master_addr_valid      (pci_master_addr_valid),
  .pci_master_data_valid      (pci_master_data_valid),
  .pci_master_requests_serr   (pci_master_requests_serr),
  .pci_master_requests_perr   (pci_master_requests_perr),
  .pci_master_requests_last   (pci_master_requests_last),
  .pci_master_data_consumed   (pci_master_data_consumed),
  .pci_master_ref_error       (pci_master_ref_error),
// PCI Interface uses these wires to request local memory activity.   
  .pci_target_ref_address     (pci_target_ref_address[31:0]),
  .pci_target_ref_command     (pci_target_ref_command[3:0]),
  .pci_target_byte_enables_l  (pci_target_byte_enables_l[3:0]),
  .pci_target_write_data      (pci_target_write_data[31:0]),
  .pci_target_read_data       (pci_target_read_data[31:0]),
  .pci_target_busy            (pci_target_busy),
  .pci_target_ref_start       (pci_target_ref_start),
  .pci_target_requests_abort  (pci_target_requests_abort),
  .pci_target_requests_perr   (pci_target_requests_perr),
  .pci_target_requests_disconnect (pci_target_requests_disconnect),
  .pci_target_data_transferred (pci_target_data_transferred),
//  PCI_Error_Report.
  .pci_interface_reports_errors (pci_interface_reports_errors[9:0]),
  .pci_config_reg_reports_errors (pci_config_reg_reports_errors),
  .pci_host_sees_pci_reset    (pci_host_sees_pci_reset),
// generic host interface wires
  .host_reset                 (host_reset),
  .host_clk                   (host_clk),
// signals used by the test bench instead of using "." notation
  .test_master_number         (test_master_number[2:0]),
  .test_address               (test_address[31:0]),
  .test_command               (test_command[3:0]),
  .test_data                  (test_data[31:0]),
  .test_byte_enables_l        (test_byte_enables_l[3:0]),
  .test_size                  (test_size[3:0]),
  .test_make_addr_par_error   (test_make_addr_par_error),
  .test_make_data_par_error   (test_make_data_par_error),
  .test_master_initial_wait_states     (test_master_initial_wait_states[3:0]),
  .test_master_subsequent_wait_states  (test_master_subsequent_wait_states[3:0]),
  .test_target_initial_wait_states     (test_target_initial_wait_states[3:0]),
  .test_target_subsequent_wait_states  (test_target_subsequent_wait_states[3:0]),
  .test_target_devsel_speed   (test_target_devsel_speed[1:0]),
  .test_fast_back_to_back     (test_fast_back_to_back),
  .test_target_termination    (test_target_termination[2:0]),
  .test_expect_master_abort   (test_expect_master_abort),
  .test_start                 (test_start),
  .test_accepted_l            (test_accepted_l),
  .test_device_id             (test_device_id[2:0]),
  .test_error_event           (test_error_event)
);
endmodule



