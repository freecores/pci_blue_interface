//===========================================================================
// $Id: test_pci_master.v,v 1.1 2001-06-27 08:41:22 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  A top-level module to exercise the PCI Master.  This will
//           exercise the various Target Aborts and PCI Writes.  PCI
//           reads will be exercised using the complete test framework.
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
// NOTE:  This module is used to test the PCI Master.
//        It will not instantiate IO pads or the Target.
//
// NOTE:  This module is for development purposes only.
//        The waveforms will be examined to determine pass
//        or fail.
//
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/1ps

module pci_test_master (
  pci_clk,
  host_reset_comb,
  pci_req_out_next, pci_req_out_oe_comb,
  pci_gnt_in_comb,
  pci_ad_in_prev,
  pci_master_ad_out_next,
  pci_master_ad_en_next, pci_master_ad_out_oe_comb
);
  output  pci_clk;
  output  host_reset_comb;
  output  pci_req_out_next;
  output  pci_req_out_oe_comb;
  output  pci_gnt_in_comb;
  output [31:0] pci_ad_in_prev;
  output [31:0] pci_master_ad_out_next;
  output  pci_master_ad_en_next;
  output  pci_master_ad_out_oe_comb;

// Wires connecting the Host FIFOs to the PCI Interface
  reg    host_reset_comb;
  reg    pci_clk;

  wire    pci_host_request_room_available_meta, pci_host_request_submit;
  wire   [2:0] pci_host_request_type;
  wire   [3:0] pci_host_request_cbe;
  wire   [31:0] pci_host_request_data;
  wire    pci_host_request_error;

  wire    pci_request_fifo_data_available_meta;
  wire    pci_request_fifo_two_words_available_meta;
  wire    pci_request_fifo_data_unload;
  wire   [2:0] pci_request_fifo_type;
  wire   [3:0] pci_request_fifo_cbe;
  wire   [31:0] pci_request_fifo_data;
  wire    pci_request_fifo_error;

// PCI signals
  wire    pci_req_out_next, pci_req_out_oe_comb;
  reg     pci_gnt_in_prev, pci_gnt_in_comb;
  reg    [31:0] pci_ad_in_prev;
  wire   [31:0] pci_master_ad_out_next;
  wire    pci_master_ad_en_next, pci_master_ad_out_oe_comb;
  wire   [3:0] pci_cbe_l_out_next;
  wire    pci_cbe_out_en_next, pci_cbe_out_oe_comb;
  wire    pci_frame_out_next, pci_frame_out_oe_comb;
  wire    pci_irdy_out_next, pci_irdy_out_oe_comb;
  reg     pci_devsel_in_prev, pci_devsel_in_comb;
  reg     pci_trdy_in_prev, pci_trdy_in_comb;
  reg     pci_stop_in_prev, pci_stop_in_comb;
  reg     pci_perr_in_prev, pci_serr_in_prev;
  wire    Master_Force_Address_Data, Master_Expects_TRDY, Master_Requests_PERR;

  wire   [2:0] master_to_target_status_type;
  wire   [3:0] master_to_target_status_cbe;
  wire   [31:0] master_to_target_status_data;
  wire    master_to_target_status_available;
  reg     master_to_target_status_unload;
// Signals from the Master to the Target to set bits in the Status Register
  wire   master_got_parity_error;
  wire   master_caused_serr;
  wire   master_caused_master_abort;
  wire   master_got_target_abort;
  wire   master_caused_parity_error;
// Signals used to document Master Behavior
  wire   master_asked_to_retry;
// Signals from the Config Regs to the Master to control it.
  reg    master_enable;
  reg    master_fast_b2b_en;
  reg    master_perr_enable;
  reg    master_serr_enable;
  reg   [7:0] master_latency_value;

task do_both_clocks;
  begin
    #2.5;
    pci_clk = 1'b1;
    #5.0;
    pci_clk = 1'b0;
    #2.5;
  end
endtask

  initial
  begin
    $display ("Checking that Async Reset sets FIFOs to known state, at time %t", $time);
    #5;
    host_reset_comb <= 1'b1;
    #5;
    host_reset_comb <= 1'b1;
    #5;

    $display ("Checking that FIFOs stay empty when nothing is going on, at time %t", $time);

    do_both_clocks;
    $finish;
  end
 
// Instantiate the Host_Request_FIFO, from the Host to the PCI Interface
pci_fifo_storage_request pci_fifo_storage_request (
  .reset_flags_async          (host_reset_comb),
  .fifo_mode                  (2'b01),  // Mode 2`b01 means write data, then update flag, read together
// NOTE WORKING need to take into consideration `DOUBLE_SYNC_PCI_HOST_SYNCHRONIZERS
  .write_clk                  (pci_clk),  // use only 1 clock
  .write_sync_clk             (pci_clk),
  .write_submit               (pci_host_request_submit),
  .write_room_available_meta  (pci_host_request_room_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .write_data                 ({pci_host_request_type[2:0],
                                pci_host_request_cbe[3:0],
                                pci_host_request_data[31:0]}),
  .write_error                (pci_host_request_error),
  .read_clk                   (pci_clk),
  .read_sync_clk              (pci_clk),
  .read_remove                (pci_request_fifo_data_unload),
  .read_data_available_meta   (pci_request_fifo_data_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .read_two_words_available_meta (pci_request_fifo_two_words_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .read_data                  ({pci_request_fifo_type[2:0],
                                pci_request_fifo_cbe[3:0],
                                pci_request_fifo_data[31:0]}),
  .read_error                 (pci_request_fifo_error)
);

// Instantiate the Master Interface
pci_blue_master pci_blue_master (
// Signals driven to control the external PCI interface
  .pci_req_out_next           (pci_req_out_next),
  .pci_req_out_oe_comb        (pci_req_out_oe_comb),
  .pci_gnt_in_prev            (pci_gnt_in_prev),
  .pci_gnt_in_comb            (pci_gnt_in_comb),
  .pci_ad_in_prev             (pci_ad_in_prev[31:0]),
  .pci_master_ad_out_next     (pci_master_ad_out_next[31:0]),
  .pci_master_ad_en_next      (pci_master_ad_en_next),
  .pci_master_ad_out_oe_comb  (pci_master_ad_out_oe_comb),
  .pci_cbe_l_out_next         (pci_cbe_l_out_next[3:0]),
  .pci_cbe_out_en_next        (pci_cbe_out_en_next),
  .pci_cbe_out_oe_comb        (pci_cbe_out_oe_comb),
  .pci_frame_out_next         (pci_frame_out_next),
  .pci_frame_out_oe_comb      (pci_frame_out_oe_comb),
  .pci_irdy_out_next          (pci_irdy_out_next),
  .pci_irdy_out_oe_comb       (pci_irdy_out_oe_comb),
  .pci_devsel_in_prev         (pci_devsel_in_prev),
  .pci_devsel_in_comb         (pci_devsel_in_comb),
  .pci_trdy_in_prev           (pci_trdy_in_prev),
  .pci_trdy_in_comb           (pci_trdy_in_comb),
  .pci_stop_in_prev           (pci_stop_in_prev),
  .pci_stop_in_comb           (pci_stop_in_comb),
  .pci_perr_in_prev           (pci_perr_in_prev),
  .pci_serr_in_prev           (pci_serr_in_prev),
// Signals to control shared AD bus, Parity, and SERR signals
  .Master_Force_Address_Data  (Master_Force_Address_Data),
  .Master_Expects_TRDY        (Master_Expects_TRDY),
  .Master_Requests_PERR       (Master_Requests_PERR),
// Host Interface Request FIFO used to ask the PCI Interface to initiate
//   PCI References to an external PCI Target.
  .pci_request_fifo_type      (pci_request_fifo_type[2:0]),
  .pci_request_fifo_cbe       (pci_request_fifo_cbe[3:0]),
  .pci_request_fifo_data      (pci_request_fifo_data[31:0]),
  .pci_request_fifo_data_available_meta (pci_request_fifo_data_available_meta),
  .pci_request_fifo_two_words_available_meta (pci_request_fifo_two_words_available_meta),
  .pci_request_fifo_data_unload (pci_request_fifo_data_unload),
  .pci_request_fifo_error     (pci_request_fifo_error),
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  .master_to_target_status_type (master_to_target_status_type[2:0]),
  .master_to_target_status_cbe  (master_to_target_status_cbe[3:0]),
  .master_to_target_status_data (master_to_target_status_data[31:0]),
  .master_to_target_status_available (master_to_target_status_available),
  .master_to_target_status_unload (master_to_target_status_unload),
// Signals from the Master to the Target to set bits in the Status Register
  .master_got_parity_error    (master_got_parity_error),
  .master_caused_serr         (master_caused_serr),
  .master_caused_master_abort (master_caused_master_abort),
  .master_got_target_abort    (master_got_target_abort),
  .master_caused_parity_error (master_caused_parity_error),
// Signals used to document Master Behavior
  .master_asked_to_retry      (master_asked_to_retry),
// Signals from the Config Regs to the Master to control it.
  .master_enable              (master_enable),
  .master_fast_b2b_en         (master_fast_b2b_en),
  .master_perr_enable         (master_perr_enable),
  .master_serr_enable         (master_serr_enable),
  .master_latency_value       (master_latency_value[7:0]),
  .pci_clk                    (pci_clk),
  .pci_reset_comb             (pci_reset_comb)
);
endmodule



