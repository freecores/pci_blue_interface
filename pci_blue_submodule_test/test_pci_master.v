//===========================================================================
// $Id: test_pci_master.v,v 1.8 2001-07-06 10:51:22 bbeaver Exp $
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

`timescale 1ns/1ps

module pci_test_master (
  host_reset_comb,
  pci_host_request_submit,
  pci_request_fifo_error,
  master_to_target_status_type,
  master_to_target_status_cbe,
  master_to_target_status_data,
  master_to_target_status_flush,
  master_to_target_status_available,
  master_to_target_status_unload,
  pci_req_out_next, pci_req_out_oe_comb,
  pci_gnt_in_comb,
  pci_clk,
  pci_master_ad_out_next,  pci_master_ad_out_oe_comb,
  pci_ad_in_prev,
  pci_cbe_l_out_next, pci_cbe_out_oe_comb,
  pci_frame_in_comb,
  pci_frame_out_next, pci_frame_out_oe_comb,
  pci_irdy_in_comb,
  pci_irdy_out_next, pci_irdy_out_oe_comb,
  pci_state,  // TEMPORARY
  pci_fifo_state,  // TEMPORARY
  pci_retry_address,  // TEMPORARY
  pci_retry_data,  // TEMPORARY
  pci_target_full,  // TEMPORARY
  pci_bus_full,  // TEMPORARY
  one_word_avail,  // TEMPORARY
  two_words_avail,  // TEMPORARY
  addr_aval,  // TEMPORARY
  working,  // TEMPORARY
  pci_devsel_in_comb, pci_devsel_in_prev,
  pci_trdy_in_comb, pci_trdy_in_prev,
  pci_stop_in_comb, pci_stop_in_prev,
  pci_perr_in_prev, pci_serr_in_prev,
  master_got_parity_error,
  master_caused_serr,
  master_caused_master_abort,
  master_got_target_abort,
  master_caused_parity_error,
  master_asked_to_retry
);

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"

  output  host_reset_comb;
  output  pci_host_request_submit;
  output  pci_request_fifo_error;
  output [2:0] master_to_target_status_type;
  output [PCI_BUS_CBE_RANGE:0] master_to_target_status_cbe;
  output [PCI_BUS_DATA_RANGE:0] master_to_target_status_data;
  output  master_to_target_status_flush;
  output  master_to_target_status_available;
  output  master_to_target_status_unload;
  output  pci_req_out_next;
  output  pci_req_out_oe_comb;
  output  pci_gnt_in_comb;
  output  pci_clk;
  output [PCI_BUS_DATA_RANGE:0] pci_ad_in_prev;
  output [PCI_BUS_DATA_RANGE:0] pci_master_ad_out_next;
  output  pci_master_ad_out_oe_comb;
  output [PCI_BUS_CBE_RANGE:0] pci_cbe_l_out_next;
  output  pci_cbe_out_oe_comb;
  output  pci_frame_in_comb;
  output  pci_frame_out_next, pci_frame_out_oe_comb;
  output  pci_irdy_in_comb;
  output  pci_irdy_out_next, pci_irdy_out_oe_comb;
  output [9:0] pci_state;  // TEMPORARY
  output [1:0] pci_fifo_state;  // TEMPORARY
  output [31:0] pci_retry_address;  // TEMPORARY
  output [31:0] pci_retry_data;  // TEMPORARY
  output  pci_target_full;  // TEMPORARY
  output  pci_bus_full;  // TEMPORARY
  output  one_word_avail;  // TEMPORARY
  output  two_words_avail;  // TEMPORARY
  output  addr_aval;  // TEMPORARY
  output  working;  // TEMPORARY
  output  pci_devsel_in_comb, pci_devsel_in_prev;
  output  pci_trdy_in_comb, pci_trdy_in_prev;
  output  pci_stop_in_comb, pci_stop_in_prev;
  output  pci_perr_in_prev, pci_serr_in_prev;
  output  master_got_parity_error;
  output  master_caused_serr;
  output  master_caused_master_abort;
  output  master_got_target_abort;
  output  master_caused_parity_error;
  output  master_asked_to_retry;

// GROSS debugging signal. Only here to put signal in waveform.
  assign  pci_state[9:0]        = pci_blue_master.PCI_Master_State[9:0];                 // TEMPORARY
  assign  pci_fifo_state[1:0]   = pci_blue_master.PCI_Master_Retry_State[1:0];           // TEMPORARY
  assign  pci_retry_address[31:0] = {pci_blue_master.Master_Retry_Address[31:2], 2'b0};  // TEMPORARY
  assign  pci_retry_data[31:0]  = pci_blue_master.Master_Retry_Data[31:0];               // TEMPORARY
  assign  pci_target_full       = pci_blue_master.master_to_target_status_full;          // TEMPORARY
  assign  pci_bus_full          = pci_blue_master.master_request_full;                    // TEMPORARY
  assign  two_words_avail       = pci_blue_master.request_fifo_two_words_available_meta;  // TEMPORARY
  assign  one_word_avail        = pci_blue_master.request_fifo_data_available_meta;      // TEMPORARY
  assign  addr_aval             = pci_blue_master.Request_FIFO_CONTAINS_ADDRESS;         // TEMPORARY
  assign  working               = pci_blue_master.Master_Abort_Detected;        // TEMPORARY

// PCI signals
  wire    pci_req_out_next, pci_req_out_oe_comb;
  reg     pci_gnt_in_prev, pci_gnt_in_comb;
  reg    [PCI_BUS_DATA_RANGE:0] pci_ad_in_prev;
  wire   [PCI_BUS_DATA_RANGE:0] pci_master_ad_out_next;
  wire    pci_master_ad_out_oe_comb;
  wire   [PCI_BUS_CBE_RANGE:0] pci_cbe_l_out_next;
  wire    pci_cbe_out_oe_comb;
  reg     pci_frame_in_comb;
  wire    pci_frame_out_next, pci_frame_out_oe_comb;
  reg     pci_irdy_in_comb;
  wire    pci_irdy_out_next, pci_irdy_out_oe_comb;
  reg     pci_devsel_in_prev, pci_devsel_in_comb;
  reg     pci_trdy_in_prev, pci_trdy_in_comb;
  reg     pci_stop_in_prev, pci_stop_in_comb;
  reg     pci_perr_in_prev, pci_serr_in_prev;
  wire    Master_Force_AD_to_Address_Data;
  wire    Master_Captures_Data_On_TRDY, Master_Exposes_Data_On_TRDY;
  wire    Master_Forces_PERR;
// Signal to control Request pin if on-chip PCI devices share it
  wire    Master_Forced_Off_Bus_By_Target_Abort;
  wire    PERR_Detected_While_Master_Read;

  wire   [2:0] master_to_target_status_type;
  wire   [PCI_BUS_CBE_RANGE:0] master_to_target_status_cbe;
  wire   [PCI_BUS_DATA_RANGE:0] master_to_target_status_data;
  wire    master_to_target_status_flush;
  wire    master_to_target_status_available;
  reg     master_to_target_status_unload;

// Signals from the Master to the Target to set bits in the Status Register
  wire    master_got_parity_error;
  wire    master_caused_serr;
  wire    master_caused_master_abort;
  wire    master_got_target_abort;
  wire    master_caused_parity_error;
// Signals used to document Master Behavior
  wire    master_asked_to_retry;
// Signals from the Config Regs to the Master to control it.
  reg     master_enable;
  reg     master_fast_b2b_en;
  reg     master_perr_enable;
  reg    [7:0] master_latency_value;

// Wires connecting the Host FIFOs to the PCI Interface
  reg    host_reset_comb;
  reg    pci_clk;

  wire    pci_host_request_room_available_meta;
  reg     pci_host_request_submit;
  reg    [2:0] pci_host_request_type;
  reg    [PCI_FIFO_CBE_RANGE:0] pci_host_request_cbe;
  reg    [PCI_FIFO_DATA_RANGE:0] pci_host_request_data;
  wire    pci_host_request_error;

  wire    pci_request_fifo_data_available_meta;
  wire    pci_request_fifo_two_words_available_meta;
  wire    pci_request_fifo_data_unload;
  wire   [2:0] pci_request_fifo_type;
  wire   [PCI_FIFO_CBE_RANGE:0] pci_request_fifo_cbe;
  wire   [PCI_FIFO_DATA_RANGE:0] pci_request_fifo_data;
  wire    pci_request_fifo_error;


task do_clocks;
  input [3:0] delay;
  reg [3:0] count;
  begin
    for (count[3:0] = delay[3:0]; count[3:0] != 4'h0; count[3:0] = count[3:0] - 4'h1)
    begin
      #3.0;
      pci_clk = 1'b1;
      #5.0;
      pci_clk = 1'b0;
      #2.0;
    end
  end
endtask

task do_reset;
  begin
    #3.0;
    pci_clk = 1'b0;
    pci_gnt_in_comb = 1'b0;
    host_reset_comb = 1'b1;
    master_to_target_status_unload = 1'b0;
    #5;
    host_reset_comb = 1'b0;
    #2.0;
  end
endtask

  reg    pci_perr_in_comb, pci_serr_in_comb;
  reg   [PCI_BUS_DATA_RANGE:0] pci_ad_in_comb;

task set_pci_idle;
  begin
    pci_gnt_in_comb = 1'b0;
    pci_ad_in_comb[PCI_BUS_DATA_RANGE:0] = `PCI_BUS_DATA_X;
    pci_frame_in_comb = 1'b0;
    pci_irdy_in_comb = 1'b0;
    pci_devsel_in_comb = 1'b0;
    pci_trdy_in_comb = 1'b0;
    pci_stop_in_comb = 1'b0;
    pci_perr_in_comb = 1'b0;
    pci_serr_in_comb = 1'b0;
    master_enable = 1'b0;
    master_fast_b2b_en = 1'b0;
    master_perr_enable = 1'b0;
    master_latency_value[7:0] = 8'h00;
  end
endtask

task enable_pci_master;
  begin
    master_enable = 1'b1;
  end
endtask

task write_fifo;
  input [2:0] entry_type;
  input [PCI_FIFO_CBE_RANGE:0] entry_cbe;
  input [PCI_FIFO_DATA_RANGE:0] entry_data;
  begin
    pci_host_request_submit = 1'b1;
    pci_host_request_type[2:0] = entry_type[2:0];
    pci_host_request_cbe[PCI_FIFO_CBE_RANGE:0] = entry_cbe[PCI_FIFO_CBE_RANGE:0];
    pci_host_request_data[PCI_FIFO_DATA_RANGE:0] = entry_data[PCI_FIFO_DATA_RANGE:0];
  end
endtask

task unload_target_data;
  begin
    master_to_target_status_unload = 1'b1;
  end
endtask

task pci_grant;
  begin
    pci_gnt_in_comb = 1'b1;
  end
endtask

task pci_frame;
  begin
    pci_frame_in_comb = 1'b1;
  end
endtask

task pci_irdy;
  begin
    pci_irdy_in_comb = 1'b1;
  end
endtask

task pci_devsel;
  begin
    pci_devsel_in_comb = 1'b1;
  end
endtask

task pci_trdy;
  begin
    pci_trdy_in_comb = 1'b1;
  end
endtask

task pci_stop;
  begin
    pci_stop_in_comb = 1'b1;
  end
endtask

task pci_perr;
  begin
    pci_perr_in_prev = 1'b1;
  end
endtask

task pci_serr;
  begin
    pci_serr_in_prev = 1'b1;
  end
endtask

// delay signals like the Pads delay them
  always @(posedge pci_clk)
  begin
    pci_gnt_in_prev <= pci_gnt_in_comb;
    pci_ad_in_prev[PCI_BUS_DATA_RANGE:0] <= pci_ad_in_comb[PCI_BUS_DATA_RANGE:0];
    pci_devsel_in_prev <= pci_devsel_in_comb;
    pci_trdy_in_prev <= pci_trdy_in_comb;
    pci_stop_in_prev <= pci_stop_in_comb;
    pci_perr_in_prev <= pci_perr_in_comb;
    pci_serr_in_prev <= pci_serr_in_comb;
  end

// Remove signals which are set for 1 clock by tasks to create activity
  initial
  begin
    pci_host_request_submit <= 1'b0;
    pci_host_request_type[2:0] <= 3'hX;
    pci_host_request_cbe[PCI_FIFO_CBE_RANGE:0] <= 4'hX;
    pci_host_request_data[PCI_FIFO_DATA_RANGE:0] <= `PCI_FIFO_DATA_X;
    pci_gnt_in_comb <= 1'b0;
    pci_gnt_in_prev <= pci_gnt_in_comb;
    pci_frame_in_comb <= 1'b0;
    pci_irdy_in_comb <= 1'b0;
    pci_devsel_in_comb <= 1'b0;
    pci_devsel_in_prev <= pci_devsel_in_comb;
    pci_trdy_in_comb <= 1'b0;
    pci_trdy_in_prev <= pci_trdy_in_comb;
    pci_stop_in_comb <= 1'b0;
    pci_stop_in_prev <= pci_stop_in_comb;
    pci_perr_in_prev <= 1'b0;
    pci_serr_in_prev <= 1'b0;
  end

  always @(posedge pci_clk)
  begin
    pci_host_request_submit <= 1'b0;
    pci_host_request_type[2:0] <= 3'hX;
    pci_host_request_cbe[PCI_FIFO_CBE_RANGE:0] <= 4'hX;
    pci_host_request_data[PCI_FIFO_DATA_RANGE:0] <= `PCI_FIFO_DATA_X;
    pci_gnt_in_comb <= 1'b0;
    pci_gnt_in_prev <= pci_gnt_in_comb;
    pci_frame_in_comb <= 1'b0;
    pci_irdy_in_comb <= 1'b0;
    pci_devsel_in_comb <= 1'b0;
    pci_devsel_in_prev <= pci_devsel_in_comb;
    pci_trdy_in_comb <= 1'b0;
    pci_trdy_in_prev <= pci_trdy_in_comb;
    pci_stop_in_comb <= 1'b0;
    pci_stop_in_prev <= pci_stop_in_comb;
    pci_perr_in_prev <= 1'b0;
    pci_serr_in_prev <= 1'b0;
  end

  initial
  begin
    $display ("Setting PCI bus to nominal, at time %t", $time);
    do_reset;
    set_pci_idle;
    unload_target_data;
      do_clocks (4'h1);
    enable_pci_master;
      do_clocks (4'h1);

    $display ("Doing Read Reg, at time %t", $time);
    do_reset;
    write_fifo (PCI_HOST_REQUEST_INSERT_WRITE_FENCE, 4'h0, 32'h00020000);
      do_clocks (4'h4);
    unload_target_data;
      do_clocks (4'h4);

    $display ("Doing Write Reg, at time %t", $time);
    do_reset;
    write_fifo (PCI_HOST_REQUEST_INSERT_WRITE_FENCE, 4'h0, 32'h00010000);
      do_clocks (4'h4);
    unload_target_data;
      do_clocks (4'h4);

    $display ("Doing Write Fence, at time %t", $time);
    do_reset;
    write_fifo (PCI_HOST_REQUEST_INSERT_WRITE_FENCE, 4'h0, 32'h00000000);
      do_clocks (4'h4);
    unload_target_data;
      do_clocks (4'h4);

    $display ("Doing Write Fence, no room in Target, at time %t", $time);
    do_reset;
    write_fifo (PCI_HOST_REQUEST_INSERT_WRITE_FENCE, 4'h0, 32'h00011111);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_INSERT_WRITE_FENCE, 4'h0, 32'h00001111);
      do_clocks (4'h6);
    unload_target_data;
      do_clocks (4'h4);

    $display ("Doing Config Read, 1 word, Loose Arb, Master Abort, at time %t", $time);
    do_reset;
    write_fifo (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_CONFIG_READ, 32'h11223344);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_All_Bytes, 32'h15667788);
      do_clocks (4'h1);
    unload_target_data;
    pci_grant;           // park
      do_clocks (4'h1);
    pci_grant;           // park
      do_clocks (4'h1);
    pci_grant;           // drive
      do_clocks (4'h1);
                         // loose arbitration
      do_clocks (4'h1);
    pci_grant;           // drive
      do_clocks (4'h1);
    pci_grant;           // drive
      do_clocks (4'h8);

    $display ("Doing Config Read, 2 words, Loose Arb, Master Abort, at time %t", $time);
    do_reset;
    write_fifo (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_CONFIG_READ, 32'h21223344);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_All_Bytes, 32'h25667788);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_All_Bytes, 32'h29AABBCC);
      do_clocks (4'h1);
    unload_target_data;
    pci_grant;           // park
      do_clocks (4'h1);
    pci_grant;           // drive
      do_clocks (4'h1);
                         // loose arbitration
      do_clocks (4'h1);
    pci_grant;           // drive
      do_clocks (4'h1);
    pci_grant;           // drive
      do_clocks (4'h8);

    $display ("Doing Config Write, 1 word, Loose Arb, Master Abort, at time %t", $time);
    do_reset;
    write_fifo (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_CONFIG_WRITE, 32'h31223344);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_All_Bytes, 32'h35667788);
      do_clocks (4'h1);
    unload_target_data;
    pci_grant;           // park
      do_clocks (4'h1);
    pci_grant;           // park
      do_clocks (4'h1);
    pci_grant;           // drive
      do_clocks (4'h1);
                         // loose arbitration
      do_clocks (4'h1);
    pci_grant;           // drive
      do_clocks (4'h1);
    pci_grant;           // drive
      do_clocks (4'h8);

    $display ("Doing Config Write, 2 words, Loose Arb, Master Abort, at time %t", $time);
    do_reset;
    write_fifo (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_CONFIG_WRITE, 32'h41223344);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_All_Bytes, 32'h45667788);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_All_Bytes, 32'h49AABBCC);
      do_clocks (4'h1);
    unload_target_data;
    pci_grant;           // park
      do_clocks (4'h1);
    pci_grant;           // drive
      do_clocks (4'h1);
                         // loose arbitration
      do_clocks (4'h1);
    pci_grant;           // drive
      do_clocks (4'h1);
    pci_grant;           // drive
      do_clocks (4'h8);

`ifdef LATER
    $display ("Doing Memory Read, 1 word, Master Abort, at time %t", $time);
    do_reset;
    write_fifo (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ, 32'h51223344);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0, 32'h55667788);
      do_clocks (4'h8);

    $display ("Doing Memory Read, 2 words, Master Abort, at time %t", $time);
    do_reset;
    write_fifo (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ, 32'h61223344);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1, 32'h65667788);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2, 32'h69AABBCC);
      do_clocks (4'h8);

    $display ("Doing Memory Write, 1 word, Master Abort, at time %t", $time);
    do_reset;
    write_fifo (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE, 32'h71223344);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3, 32'h75667788);
      do_clocks (4'h8);

    $display ("Doing Memory Write, 2 words, Master Abort, at time %t", $time);
    do_reset;
    write_fifo (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE, 32'h81223344);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0, 32'h85667788);
      do_clocks (4'h1);
    write_fifo (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1, 32'h89AABBCC);
      do_clocks (4'h8);

    $display ("Doing Memory Read, 1 word, Target Abort, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 2 words, Target Abort, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 1 word, Target Abort, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 2 words, Target Abort, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 1 word, Target Retry with no data, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 2 words, Target Retry with no data, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 1 word, Target Retry with no data, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 2 words, Target Retry with no data, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 1 word, Target Retry with data, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 2 words, Target Retry with data, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 1 word, Target Retry with data, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 2 words, Target Retry with data, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 1 word, normal transfer, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 2 words, normal transfer, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 1 word, normal transfer, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 2 words, normal transfer, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 1 word, target wait states, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 2 words, target wait states, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 1 word, target wait states, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 2 words, target wait states, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 1 word, master wait states, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 2 words, master wait states, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 1 word, master wait states, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 2 words, master wait states, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 1 word, master data latency timer expires, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 2 words, master data latency timer expires, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 1 word, master data latency timer expires, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 2 words, master data latency timer expires, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 2 words, master bus latency timer expires, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 2 words, master bus latency timer expires, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 1 word, address parity error, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 2 words, address parity error, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 1 word, address parity error, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 2 words, address parity error, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 1 word, data parity error, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, 2 words, data parity error, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 1 word, data parity error, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, 2 words, data parity error, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, then Read, 1 word, fast back-to-back, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, then Write, 1 word, fast back-to-back, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read, then Config, 1 word, fast back-to-back, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, then Read, 1 word, fast back-to-back, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, then Write, 1 word, fast back-to-back, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write, then Config, 1 word, fast back-to-back, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read Master Abort, then Read, 1 word, fast back-to-back, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read Master Abort then Write, 1 word, fast back-to-back, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Read Master Abort, then Config, 1 word, fast back-to-back, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write Master Abort, then Read, 1 word, fast back-to-back, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write Master Abort, then Write, 1 word, fast back-to-back, at time %t", $time);
    do_reset;
      do_clocks (4'h1);

    $display ("Doing Memory Write Master Abort, then Config, 1 word, fast back-to-back, at time %t", $time);
    do_reset;
      do_clocks (4'h1);
`endif  // LATER

    do_reset;
      do_clocks (4'h4);
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
                                pci_host_request_cbe[PCI_FIFO_CBE_RANGE:0],
                                pci_host_request_data[PCI_FIFO_DATA_RANGE:0]}),
  .write_error                (pci_host_request_error),
  .read_clk                   (pci_clk),
  .read_sync_clk              (pci_clk),
  .read_remove                (pci_request_fifo_data_unload),
  .read_data_available_meta   (pci_request_fifo_data_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .read_two_words_available_meta (pci_request_fifo_two_words_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .read_data                  ({pci_request_fifo_type[2:0],
                                pci_request_fifo_cbe[PCI_FIFO_CBE_RANGE:0],
                                pci_request_fifo_data[PCI_FIFO_DATA_RANGE:0]}),
  .read_error                 (pci_request_fifo_error)
);

// Instantiate the Master Interface
pci_blue_master pci_blue_master (
// Signals driven to control the external PCI interface
  .pci_req_out_next           (pci_req_out_next),
  .pci_req_out_oe_comb        (pci_req_out_oe_comb),
  .pci_gnt_in_prev            (pci_gnt_in_prev),
  .pci_gnt_in_comb            (pci_gnt_in_comb),
  .pci_master_ad_out_next     (pci_master_ad_out_next[PCI_BUS_DATA_RANGE:0]),
  .pci_master_ad_out_oe_comb  (pci_master_ad_out_oe_comb),
  .pci_cbe_l_out_next         (pci_cbe_l_out_next[PCI_BUS_CBE_RANGE:0]),
  .pci_cbe_out_oe_comb        (pci_cbe_out_oe_comb),
  .pci_frame_in_comb          (pci_frame_in_comb),
  .pci_frame_out_next         (pci_frame_out_next),
  .pci_frame_out_oe_comb      (pci_frame_out_oe_comb),
  .pci_irdy_in_comb           (pci_irdy_in_comb),
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
  .Master_Force_AD_to_Address_Data (Master_Force_AD_to_Address_Data),
  .Master_Captures_Data_On_TRDY (Master_Captures_Data_On_TRDY),
  .Master_Exposes_Data_On_TRDY (Master_Exposes_Data_On_TRDY),
  .Master_Forces_PERR         (Master_Forces_PERR),
  .PERR_Detected_While_Master_Read (PERR_Detected_While_Master_Read),
// Signal to control Request pin if on-chip PCI devices share it
  .Master_Forced_Off_Bus_By_Target_Abort (Master_Forced_Off_Bus_By_Target_Abort),
// Host Interface Request FIFO used to ask the PCI Interface to initiate
//   PCI References to an external PCI Target.
  .pci_request_fifo_type      (pci_request_fifo_type[2:0]),
  .pci_request_fifo_cbe       (pci_request_fifo_cbe[PCI_FIFO_CBE_RANGE:0]),
  .pci_request_fifo_data      (pci_request_fifo_data[PCI_FIFO_DATA_RANGE:0]),
  .pci_request_fifo_data_available_meta (pci_request_fifo_data_available_meta),
  .pci_request_fifo_two_words_available_meta (pci_request_fifo_two_words_available_meta),
  .pci_request_fifo_data_unload (pci_request_fifo_data_unload),
  .pci_request_fifo_error     (pci_request_fifo_error),
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  .master_to_target_status_type   (master_to_target_status_type[2:0]),
  .master_to_target_status_cbe    (master_to_target_status_cbe[PCI_BUS_CBE_RANGE:0]),
  .master_to_target_status_data   (master_to_target_status_data[PCI_BUS_DATA_RANGE:0]),
  .master_to_target_status_flush  (master_to_target_status_flush),
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
  .master_latency_value       (master_latency_value[7:0]),
  .pci_clk                    (pci_clk),
  .pci_reset_comb             (host_reset_comb)
);
endmodule



