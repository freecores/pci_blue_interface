//===========================================================================
// $Id: pci_test_top.v,v 1.9 2001-08-05 06:35:43 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  Connect a Clock Generator, a PCI Bus Monitor, several debugging
//           Behaviorial PCI Interfaces, at least one Synthesizable PCI
//           Interface, and a Test Stimulus generator together.
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
// NOTE:  In order to get VeriLogger to automatically draw a diagram
//        with the PCI bus in it, make the PCI Bus Signals be ports
//        to the top-level module.
//
// NOTE:  VeriLogger Pro needs triand gates for open collector busses with
//        pullups.  The triand declaration must be only at the top module
//
// NOTE:  Extend the module interfaces to include ALL OE signals
//        FRAME, IRDY, D_T_S, PERR, AD, CBE, PAR, together as a bus
//        Make a top-level checker which looks for any 2 busses having
//        the same bit set at a rising edge.  That is a BUS FIGHT.
//        This could be placed in the monitor?  Unused vectors are all 0.
//
//===========================================================================

`timescale 1ns/1ps

// toplevel verilog to test PCI interface in a multi-device environment

module pci_test_top (
  test_sequence,
  test_master_number, test_address, test_command,
  test_data, test_byte_enables_l, test_size,
  test_make_addr_par_error, test_make_data_par_error,
  test_master_initial_wait_states, test_master_subsequent_wait_states,
  test_target_initial_wait_states, test_target_subsequent_wait_states,
  test_target_devsel_speed, test_fast_back_to_back,
  test_target_termination,
  test_expect_master_abort,
  test_result, test_start, test_accepted, test_error_event, test_idle_event,
  pci_test_observe_frame_oe, pci_test_observe_devsel_oe,
  pci_real_observe_frame_oe, pci_real_observe_devsel_oe,
  present_test_name,
  pci_ext_reset_l, pci_ext_clk,
  pci_test_req_l, pci_test_gnt_l,
  pci_real_req_l, pci_real_gnt_l,
  pci_ext_idsel_real,
  pci_ext_ad, pci_ext_cbe_l, pci_ext_par,
  pci_ext_frame_l, pci_ext_irdy_l,
  pci_ext_devsel_l, pci_ext_trdy_l, pci_ext_stop_l,
  pci_ext_perr_l, pci_ext_serr_l,
  pci_ext_inta_l
);

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"

// signals which are used by test modules to know what to do
  input  [3:0] test_sequence;
  output [2:0] test_master_number;
  output [PCI_BUS_DATA_RANGE:0] test_address;
  output [3:0] test_command;
  output [PCI_BUS_DATA_RANGE:0] test_data;
  output [PCI_BUS_CBE_RANGE:0] test_byte_enables_l;
  output [3:0] test_size;
  output  test_make_addr_par_error, test_make_data_par_error;
  output [3:0] test_master_initial_wait_states;
  output [3:0] test_master_subsequent_wait_states;
  output [3:0] test_target_initial_wait_states;
  output [3:0] test_target_subsequent_wait_states;
  output [1:0] test_target_devsel_speed;
  output  test_fast_back_to_back;
  output [2:0] test_target_termination;
  output  test_expect_master_abort;
  output [PCI_BUS_DATA_RANGE:0] test_result;
  output  test_start, test_accepted, test_error_event, test_idle_event;
  output [3:0] pci_test_observe_frame_oe;
  output [3:0] pci_test_observe_devsel_oe;
  output  pci_real_observe_frame_oe, pci_real_observe_devsel_oe;
  output [79:0] present_test_name;

// pins which will be displayed in the top-level waveform
  output  pci_ext_reset_l, pci_ext_clk;
  output [3:0] pci_test_req_l;
  output [3:0] pci_test_gnt_l;
  output  pci_real_req_l, pci_real_gnt_l;
  output  pci_ext_idsel_real;
  output [PCI_BUS_DATA_RANGE:0] pci_ext_ad;
  output [PCI_BUS_CBE_RANGE:0] pci_ext_cbe_l;
  output  pci_ext_par, pci_ext_frame_l,  pci_ext_irdy_l;
  output  pci_ext_devsel_l, pci_ext_trdy_l, pci_ext_stop_l;
  output  pci_ext_perr_l, pci_ext_serr_l, pci_ext_inta_l;

  reg pci_ext_clk, pci_ext_reset_l;

// signals which are used by test modules to know what to do
  triand  test_accepted_l_int, error_event_int;
  pullup  (test_accepted_l_int), (error_event_int);
  assign  test_accepted = ~test_accepted_l_int;
  wire   #1 pci_error_event_dly = error_event_int;
  assign  test_error_event = (pci_error_event_dly === 1'b1)
                          && (error_event_int === 1'b0);
  reg    [31:0] total_errors_detected;
  initial total_errors_detected = 32'h00000000;
  always @(negedge error_event_int)
  begin
    if (($time > 10) & pci_ext_reset_l)
    begin
      total_errors_detected = total_errors_detected + 32'h00000001;
    end
    `NO_ELSE;
  end

// Make test name visible when the Master starts working on it
  reg    [79:0] present_test_name;
  wire   [79:0] next_test_name;
  always @(posedge test_accepted)
  begin
    present_test_name <= next_test_name;
  end

// Make visible the internal OE signals.  This makes it MUCH easier to
// see who is using the bus during simulation.
// OE Observation signals are
// {frame_oe, irdy_oe, devsel_t_s_oe, ad_oe, cbe_oe, perr_oe}
  wire   [5:0] test_observe_real_oe_sigs;
  wire   [5:0] test_observe_0_oe_sigs;
  wire   [5:0] test_observe_1_oe_sigs;
  wire   [5:0] test_observe_2_oe_sigs;
  wire   [5:0] test_observe_3_oe_sigs;

// make selected signals visible externally
  assign  pci_real_observe_frame_oe = test_observe_real_oe_sigs[5];
  assign  pci_real_observe_devsel_oe = test_observe_real_oe_sigs[3];
  assign  pci_test_observe_frame_oe =
                {test_observe_3_oe_sigs[5], test_observe_2_oe_sigs[5],
                 test_observe_1_oe_sigs[5], test_observe_0_oe_sigs[5]};
  assign  pci_test_observe_devsel_oe =
                {test_observe_3_oe_sigs[3], test_observe_2_oe_sigs[3],
                 test_observe_1_oe_sigs[3], test_observe_0_oe_sigs[3]};
// unused wires
  assign  test_observe_2_oe_sigs = 6'h00;
  assign  test_observe_3_oe_sigs = 6'h00;

// Generate the external PCI Clock
// Right now, the Async Reset is generated inthe external test bench.

  initial
  begin
    pci_ext_clk <= 1'b0;
    pci_ext_reset_l <= 1'b1;
    #10;
    pci_ext_reset_l <= 1'b0;
    #20;
    pci_ext_reset_l <= 1'b1;
    #10;
    while (1'b1)
    begin
      pci_ext_clk <= ~pci_ext_clk;
      #(`PCI_CLK_PERIOD/2);
    end
  end

// Motherboard PCI bus
  triand  pci_real_req_l;
  wire    pci_real_gnt_l;   // no PC board pullup
  wire   [PCI_BUS_DATA_RANGE:0] pci_ext_ad;   // no PC board pullup
  wire   [PCI_BUS_CBE_RANGE:0] pci_ext_cbe_l; // no PC board pullup
  wire    pci_ext_par;      // no PC board pullup
  triand  pci_ext_frame_l, pci_ext_irdy_l;  // shared, with pullup
  triand  pci_ext_devsel_l, pci_ext_trdy_l, pci_ext_stop_l;  // shared, with pullup
  triand  pci_ext_perr_l, pci_ext_serr_l;  // shared, with pullup

// signals from the test device to the external arbiter or the internal one
  triand  pci_test_req_int0_l;
  triand  pci_test_req_int1_l;
  triand  pci_test_req_int2_l;
  triand  pci_test_req_int3_l;
  wire   [3:0] pci_test_req_l = {pci_test_req_int3_l, pci_test_req_int2_l,
                                 pci_test_req_int1_l, pci_test_req_int0_l};
  wire   [3:0] pci_test_gnt_l;   // no PC board pullup

// motherboard pullups.
  pullup  (pci_real_req_l);
  pullup  (pci_test_req_int0_l), (pci_test_req_int1_l);
  pullup  (pci_test_req_int2_l), (pci_test_req_int3_l);
  pullup  (pci_ext_frame_l), (pci_ext_irdy_l);
  pullup  (pci_ext_devsel_l), (pci_ext_trdy_l), (pci_ext_stop_l);
  pullup  (pci_ext_perr_l), (pci_ext_serr_l);

// assign IDSEL to AD24 and above, to keep the lower 24 bits available for paramaters
  wire    pci_idsel_real =   pci_ext_ad[`REAL_DEVICE_IDSEL_INDEX];    // typically 24
  wire    pci_idsel_test_0 = pci_ext_ad[`TEST_DEVICE_0_IDSEL_INDEX];  // typically 25
  wire    pci_idsel_test_1 = pci_ext_ad[`TEST_DEVICE_1_IDSEL_INDEX];  // typically 26
  assign  pci_ext_idsel_real = pci_idsel_real;

// signal used to make it easy to see that the PCI bus is High-Z or Parked
  reg     test_idle_event_int;
  initial test_idle_event_int <= 1'b0;
  wire   #2 test_idle_event_dly = test_idle_event_int;
  assign  test_idle_event = test_idle_event_dly;
  wire    bus_idle_right_now = pci_ext_frame_l & pci_ext_irdy_l
                             & (   (pci_ext_ad[PCI_BUS_DATA_RANGE:0] === `BUS_PARK_VALUE)
                                 | (pci_ext_ad[PCI_BUS_DATA_RANGE:0] === `PCI_BUS_DATA_Z) );
  reg bus_idle_prev;
  always @(posedge pci_ext_clk)
  begin
    bus_idle_prev <= pci_ext_reset_l & bus_idle_right_now;
    if (bus_idle_right_now & bus_idle_prev)
    begin
      test_idle_event_int <= ~test_idle_event_int;
    end
    `NO_ELSE;
  end

`ifdef PCI_EXTERNAL_MASTER
  triand  pci_ext_inta_l;
  pullup  (pci_ext_inta_l);

  wire   [3:0] pci_ext_req_l = pci_test_req_l[3:0];
  wire   [3:0] pci_ext_gnt_l;
  assign pci_test_gnt_l = pci_ext_gnt_l[3:0];

// external arbiter here.
  wire    arbitration_enable = 1'b1;

// model input pads in real chip
  reg     pci_frame_prev, pci_irdy_prev;
  reg     pci_real_req_prev;
  reg    [3:0] pci_ext_req_prev;
  always @(posedge pci_ext_clk)
  begin
    pci_frame_prev <= ~pci_ext_frame_l;
    pci_irdy_prev <= ~pci_ext_irdy_l;
    pci_real_req_prev <= ~pci_real_req_l;
    pci_ext_req_prev <= ~pci_ext_req_l[3:0];
  end

// model output pads in real chip
  wire    pci_real_gnt_direct_out;
  wire   [3:0] pci_ext_gnt_direct_out;

  wire   [4:0] gnt_out_dly1;
  wire   [4:0] gnt_out_dly2;
  assign  #`PAD_MIN_DATA_DLY gnt_out_dly1 =
                   {pci_ext_gnt_direct_out[3:0], pci_real_gnt_direct_out};
  assign  #`PAD_MAX_DATA_DLY gnt_out_dly2 =
                   {pci_ext_gnt_direct_out[3:0], pci_real_gnt_direct_out};

  assign  pci_real_gnt_l = (gnt_out_dly1[0] !== gnt_out_dly2[0])
                        ? 1'bX : ~gnt_out_dly2[0];
  assign  pci_ext_gnt_l[0] = (gnt_out_dly1[1] !== gnt_out_dly2[1])
                        ? 1'bX : ~gnt_out_dly2[1];
  assign  pci_ext_gnt_l[1] = (gnt_out_dly1[2] !== gnt_out_dly2[2])
                        ? 1'bX : ~gnt_out_dly2[2];
  assign  pci_ext_gnt_l[2] = (gnt_out_dly1[3] !== gnt_out_dly2[3])
                        ? 1'bX : ~gnt_out_dly2[3];
  assign  pci_ext_gnt_l[3] = (gnt_out_dly1[4] !== gnt_out_dly2[4])
                        ? 1'bX : ~gnt_out_dly2[4];

pci_blue_arbiter arbiter (
  .pci_int_req_direct         (pci_real_req_prev),
  .pci_ext_req_prev           (pci_ext_req_prev[3:0]),
  .pci_int_gnt_direct_out     (pci_real_gnt_direct_out),
  .pci_ext_gnt_direct_out     (pci_ext_gnt_direct_out[3:0]),
  .pci_frame_prev             (pci_frame_prev),
  .pci_irdy_prev              (pci_irdy_prev),
  .pci_irdy_now               (~pci_ext_irdy_l),
  .arbitration_enable         (arbitration_enable),
  .pci_reset_comb             (~pci_ext_reset_l),
  .pci_clk                    (pci_ext_clk)
);
`else // PCI_EXTERNAL_MASTER
// NOT WRITTEN OR TESTED YET
  triand  pci_ext_inta_l, pci_ext_intb_l, pci_ext_intc_l, pci_ext_intd_l;
  pullup  (pci_ext_inta_l), (pci_ext_intb_l), (pci_ext_intc_l), (pci_ext_intd_l);

  wire [3:0] pci_ext_req_l = pci_test_req_l[3:0];
  wire [3:0] pci_ext_gnt_l;
  assign pci_test_gnt_l = pci_ext_gnt_l[3:0];
`endif // PCI_EXTERNAL_MASTER

// The module representing a real use of this IP
pci_example_chip pci_example_chip (
  .pci_ext_ad                 (pci_ext_ad[PCI_BUS_DATA_RANGE:0]),
  .pci_ext_cbe_l              (pci_ext_cbe_l[PCI_BUS_CBE_RANGE:0]),
  .pci_ext_par                (pci_ext_par),
  .pci_ext_frame_l            (pci_ext_frame_l),
  .pci_ext_irdy_l             (pci_ext_irdy_l),
  .pci_ext_devsel_l           (pci_ext_devsel_l),
  .pci_ext_trdy_l             (pci_ext_trdy_l),
  .pci_ext_stop_l             (pci_ext_stop_l),
  .pci_ext_perr_l             (pci_ext_perr_l),
  .pci_ext_serr_l             (pci_ext_serr_l),
`ifdef PCI_EXTERNAL_IDSEL
  .pci_ext_idsel              (pci_idsel_real),
`endif  // PCI_EXTERNAL_IDSEL
`ifdef PCI_EXTERNAL_MASTER
  .pci_ext_inta_l             (pci_ext_inta_l),
  .pci_ext_req_l              (pci_real_req_l),  // output
  .pci_ext_gnt_l              (pci_real_gnt_l),  // input
`else // PCI_EXTERNAL_MASTER
  .pci_ext_inta_l             (pci_ext_inta_l),
  .pci_ext_intb_l             (pci_ext_intb_l),
  .pci_ext_intc_l             (pci_ext_intc_l),
  .pci_ext_intd_l             (pci_ext_intd_l),
  .pci_int_req_l              (pci_real_req_l),  // monitor output
  .pci_int_gnt_l              (pci_real_gnt_l),  // monitor output
  .pci_ext_req_l              (pci_ext_req_l[3:0]),  // input
  .pci_ext_gnt_l              (pci_ext_gnt_l[3:0]),  // output
`endif // PCI_EXTERNAL_MASTER
  .pci_ext_reset_l            (pci_ext_reset_l),
  .pci_ext_clk                (pci_ext_clk),
// Signals used by the test bench, instead of using "." notation.
// Everything below this would be gone in a real use of the interface.
  .test_observe_oe_sigs       (test_observe_real_oe_sigs[5:0]),
  .test_master_number         (test_master_number[2:0]),
  .test_address               (test_address[PCI_BUS_DATA_RANGE:0]),
  .test_command               (test_command[3:0]),
  .test_data                  (test_data[PCI_BUS_DATA_RANGE:0]),
  .test_byte_enables_l        (test_byte_enables_l[PCI_BUS_CBE_RANGE:0]),
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
  .test_accepted_l            (test_accepted_l_int),
  .test_error_event           (error_event_int),
  .test_device_id             (`Test_Master_Real)
);

// The module representing a test PCI device on the motherboard
pci_behaviorial_device pci_behaviorial_device_0 (
  .pci_ext_ad                 (pci_ext_ad[PCI_BUS_DATA_RANGE:0]),
  .pci_ext_cbe_l              (pci_ext_cbe_l[PCI_BUS_CBE_RANGE:0]),
  .pci_ext_par                (pci_ext_par),
  .pci_ext_frame_l            (pci_ext_frame_l),
  .pci_ext_irdy_l             (pci_ext_irdy_l),
  .pci_ext_devsel_l           (pci_ext_devsel_l),
  .pci_ext_trdy_l             (pci_ext_trdy_l),
  .pci_ext_stop_l             (pci_ext_stop_l),
  .pci_ext_perr_l             (pci_ext_perr_l),
  .pci_ext_serr_l             (pci_ext_serr_l),
  .pci_ext_idsel              (pci_idsel_test_0),
  .pci_ext_inta_l             (pci_ext_inta_l),
  .pci_ext_req_l              (pci_test_req_int0_l),
  .pci_ext_gnt_l              (pci_test_gnt_l[0]),
  .pci_ext_reset_l            (pci_ext_reset_l),
  .pci_ext_clk                (pci_ext_clk),
// signals used by the test bench, instead of using "." notation
// Everything below this would be gone in a real use of the interface.
  .test_observe_oe_sigs       (test_observe_0_oe_sigs[5:0]),
  .test_master_number         (test_master_number[2:0]),
  .test_address               (test_address[PCI_BUS_DATA_RANGE:0]),
  .test_command               (test_command[3:0]),
  .test_data                  (test_data[PCI_BUS_DATA_RANGE:0]),
  .test_byte_enables_l        (test_byte_enables_l[PCI_BUS_CBE_RANGE:0]),
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
  .test_accepted_l            (test_accepted_l_int),
  .test_error_event           (error_event_int),
  .test_device_id             (`Test_Master_0)
);

// The module representing a test PCI device on the motherboard
pci_behaviorial_device pci_behaviorial_device_1 (
  .pci_ext_ad                 (pci_ext_ad[PCI_BUS_DATA_RANGE:0]),
  .pci_ext_cbe_l              (pci_ext_cbe_l[PCI_BUS_CBE_RANGE:0]),
  .pci_ext_par                (pci_ext_par),
  .pci_ext_frame_l            (pci_ext_frame_l),
  .pci_ext_irdy_l             (pci_ext_irdy_l),
  .pci_ext_devsel_l           (pci_ext_devsel_l),
  .pci_ext_trdy_l             (pci_ext_trdy_l),
  .pci_ext_stop_l             (pci_ext_stop_l),
  .pci_ext_perr_l             (pci_ext_perr_l),
  .pci_ext_serr_l             (pci_ext_serr_l),
  .pci_ext_idsel              (pci_idsel_test_1),
  .pci_ext_inta_l             (pci_ext_inta_l),
  .pci_ext_req_l              (pci_test_req_int1_l),
  .pci_ext_gnt_l              (pci_test_gnt_l[1]),
  .pci_ext_reset_l            (pci_ext_reset_l),
  .pci_ext_clk                (pci_ext_clk),
// signals used by the test bench, instead of using "." notation
// Everything below this would be gone in a real use of the interface.
  .test_observe_oe_sigs       (test_observe_1_oe_sigs[5:0]),
  .test_master_number         (test_master_number[2:0]),
  .test_address               (test_address[PCI_BUS_DATA_RANGE:0]),
  .test_command               (test_command[3:0]),
  .test_data                  (test_data[PCI_BUS_DATA_RANGE:0]),
  .test_byte_enables_l        (test_byte_enables_l[PCI_BUS_CBE_RANGE:0]),
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
  .test_accepted_l            (test_accepted_l_int),
  .test_error_event           (error_event_int),
  .test_device_id             (`Test_Master_1)
);

// module which hopefully watches for bus protocol problems
pci_bus_monitor pci_bus_monitor (
  .pci_ext_ad                 (pci_ext_ad[PCI_BUS_DATA_RANGE:0]),
  .pci_ext_cbe_l              (pci_ext_cbe_l[PCI_BUS_CBE_RANGE:0]),
  .pci_ext_par                (pci_ext_par),
  .pci_ext_frame_l            (pci_ext_frame_l),
  .pci_ext_irdy_l             (pci_ext_irdy_l),
  .pci_ext_devsel_l           (pci_ext_devsel_l),
  .pci_ext_trdy_l             (pci_ext_trdy_l),
  .pci_ext_stop_l             (pci_ext_stop_l),
  .pci_ext_perr_l             (pci_ext_perr_l),
  .pci_ext_serr_l             (pci_ext_serr_l),
  .pci_real_req_l             (pci_real_req_l),
  .pci_real_gnt_l             (pci_real_gnt_l),
  .pci_ext_req_l              (pci_ext_req_l[3:0]),
  .pci_ext_gnt_l              (pci_ext_gnt_l[3:0]),
  .test_error_event           (error_event_int),
  .test_observe_r_oe_sigs     (test_observe_real_oe_sigs[5:0]),
  .test_observe_0_oe_sigs     (test_observe_0_oe_sigs[5:0]),
  .test_observe_1_oe_sigs     (test_observe_1_oe_sigs[5:0]),
  .test_observe_2_oe_sigs     (test_observe_2_oe_sigs[5:0]),
  .test_observe_3_oe_sigs     (test_observe_3_oe_sigs[5:0]),
  .pci_ext_reset_l            (pci_ext_reset_l),
  .pci_ext_clk                (pci_ext_clk)
);

// Module which either reads scripts, executes instructions, or runs
// canned behavior included as program source.
  wire   [3:0] test_sequence_non_X =
                  ((^test_sequence[3:0]) === 1'bX) ? 4'h0 : test_sequence;
  initial
  begin
    if ((^test_sequence[3:0]) === 1'bX)
    begin
      #500000 $finish;
    end
    `NO_ELSE;
  end

pci_test_commander pci_test_commander (
  .test_sequence              (test_sequence_non_X[3:0]),
  .pci_reset_comb             (~pci_ext_reset_l),
  .pci_ext_clk                (pci_ext_clk),
  .test_master_number         (test_master_number[2:0]),
  .test_address               (test_address[PCI_BUS_DATA_RANGE:0]),
  .test_command               (test_command[3:0]),
  .test_data                  (test_data[PCI_BUS_DATA_RANGE:0]),
  .test_byte_enables_l        (test_byte_enables_l[PCI_BUS_CBE_RANGE:0]),
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
  .test_accepted_l            (test_accepted_l_int),
  .test_result                (test_result[PCI_BUS_DATA_RANGE:0]),
  .test_error_event           (error_event_int),
  .present_test_name          (next_test_name[79:0]),
  .total_errors_detected      (total_errors_detected[31:0])
);

endmodule

