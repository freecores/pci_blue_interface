//===========================================================================
// $Id: test_pci_master.v,v 1.18 2001-08-11 15:01:35 bbeaver Exp $
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
  Master_Force_AD_to_Address_Data_Critical,
  Master_Exposes_Data_On_TRDY,
  pci_req_bus,
  pci_gnt_in_critical,
  pci_clk,
  pci_master_ad_bus,
  pci_ad_in_prev,
  pci_master_cbe_bus,
  pci_frame_in_critical,
  pci_frame_bus,
  pci_irdy_in_critical,
  pci_irdy_bus,
  pci_devsel_in_comb, pci_devsel_in_prev,
  pci_trdy_in_critical, pci_trdy_in_prev,
  pci_stop_in_critical, pci_stop_in_prev,
  pci_perr_in_prev, pci_serr_in_prev,
  pci_state,  // TEMPORARY
  pci_fifo_state,  // TEMPORARY
  pci_retry_type,
  pci_retry_address,  // TEMPORARY
  pci_retry_command,
  pci_retry_write_reg,
  Doing_Config_Reference,
  fifo_contains_address,
  pci_retry_data,  // TEMPORARY
  pci_retry_data_type,
  pci_target_full,  // TEMPORARY
  pci_bus_full,  // TEMPORARY
  one_word_avail,  // TEMPORARY
  two_words_avail,  // TEMPORARY
  addr_aval,  // TEMPORARY
  more,  // TEMPORARY
  two_more,  // TEMPORARY
  last,  // TEMPORARY
  working,
  new_addr_new_data,   // TEMPORARY
  old_addr_new_data,   // TEMPORARY
  old_addr_old_data,   // TEMPORARY
  new_data,
  inc,   // TEMPORARY
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
  output  Master_Force_AD_to_Address_Data_Critical;
  output  Master_Exposes_Data_On_TRDY;
  output  pci_req_bus;
  output  pci_gnt_in_critical;
  output  pci_clk;
  output [PCI_BUS_DATA_RANGE:0] pci_ad_in_prev;
  output [PCI_BUS_DATA_RANGE:0] pci_master_ad_bus;
  output [PCI_BUS_CBE_RANGE:0] pci_master_cbe_bus;
  output  pci_frame_in_critical;
  output  pci_frame_bus;
  output  pci_irdy_in_critical;
  output  pci_irdy_bus;
  output  pci_devsel_in_comb, pci_devsel_in_prev;
  output  pci_trdy_in_critical, pci_trdy_in_prev;
  output  pci_stop_in_critical, pci_stop_in_prev;
  output  pci_perr_in_prev, pci_serr_in_prev;
  output [4:0] pci_state;  // TEMPORARY
  output [1:0] pci_fifo_state;  // TEMPORARY
  output [2:0] pci_retry_type;  // TEMPORARY
  output [31:0] pci_retry_address;  // TEMPORARY
  output [3:0] pci_retry_command;  // TEMPORARY
  output  pci_retry_write_reg;
  output  Doing_Config_Reference;
  output  fifo_contains_address;
  output [31:0] pci_retry_data;  // TEMPORARY
  output [2:0] pci_retry_data_type;
  output  pci_target_full;  // TEMPORARY
  output  pci_bus_full;  // TEMPORARY
  output  one_word_avail;  // TEMPORARY
  output  two_words_avail;  // TEMPORARY
  output  addr_aval;  // TEMPORARY
  output  more, two_more, last;
  output  working;
  output  new_addr_new_data;     // TEMPORARY
  output  old_addr_new_data;     // TEMPORARY
  output  old_addr_old_data;     // TEMPORARY
  output  new_data;
  output  inc;     // TEMPORARY

  output  master_got_parity_error;
  output  master_caused_serr;
  output  master_caused_master_abort;
  output  master_got_target_abort;
  output  master_caused_parity_error;
  output  master_asked_to_retry;

// GROSS debugging signal. Only here to put signal in waveform.
  assign  pci_state[4:0]        = pci_blue_master.PCI_Master_State[4:0];                  // TEMPORARY
  assign  pci_retry_type[2:0]   = {pci_blue_master.Master_Retry_Address_Type[2:0]};       // TEMPORARY
  assign  pci_retry_address[31:0] = {pci_blue_master.Master_Retry_Address[31:2], 2'b0};   // TEMPORARY
  assign  pci_retry_command[3:0]  = pci_blue_master.Master_Retry_Command[3:0];            // TEMPORARY
  assign  pci_retry_write_reg   = pci_blue_master.Master_Retry_Write_Reg;                 // TEMPORARY
  assign  Doing_Config_Reference = pci_blue_master.Master_Doing_Config_Reference;         // TEMPORARY
  assign  pci_retry_data[31:0]  = pci_blue_master.Master_Retry_Data[31:0];                // TEMPORARY
  assign  pci_retry_data_type[2:0] = pci_blue_master.Master_Retry_Data_Type[2:0];         // TEMPORARY
  assign  fifo_contains_address = pci_blue_master.Request_FIFO_CONTAINS_ADDRESS;          // TEMPORARY
  assign  pci_target_full       = pci_blue_master.master_to_target_status_full;           // TEMPORARY
  assign  pci_bus_full          = pci_blue_master.master_request_full;                    // TEMPORARY
  assign  two_words_avail       = pci_blue_master.request_fifo_two_words_available_meta;  // TEMPORARY
  assign  one_word_avail        = pci_blue_master.request_fifo_data_available_meta;       // TEMPORARY
  assign  addr_aval             = pci_blue_master.Request_FIFO_CONTAINS_ADDRESS;          // TEMPORARY
  assign  more                  = pci_blue_master.Request_FIFO_CONTAINS_DATA_MORE;        // TEMPORARY
  assign  two_more              = pci_blue_master.Request_FIFO_CONTAINS_DATA_TWO_MORE;    // TEMPORARY
  assign  last                  = pci_blue_master.Request_FIFO_CONTAINS_DATA_LAST;        // TEMPORARY
  assign  working               = pci_blue_master.working;       // TEMPORARY
  assign  new_addr_new_data     = pci_blue_master.proceed_with_new_address_plus_new_data;        // TEMPORARY
  assign  old_addr_new_data     = pci_blue_master.proceed_with_stored_address_plus_new_data;     // TEMPORARY
  assign  old_addr_old_data     = pci_blue_master.proceed_with_stored_address_plus_stored_data;  // TEMPORARY
  assign  new_data              = pci_blue_master.proceed_with_new_data;                  // TEMPORARY
  assign  inc                   = pci_blue_master.Inc_Stored_Address;                     // TEMPORARY

// PCI signals
  wire    pci_req_out_next, pci_req_out_oe_comb;
  reg     pci_gnt_in_prev, pci_gnt_in_critical;
  reg    [PCI_BUS_DATA_RANGE:0] pci_ad_in_prev;
  wire   [PCI_BUS_DATA_RANGE:0] pci_master_ad_out_next;
  wire    pci_master_ad_out_oe_comb;
  wire   [PCI_BUS_CBE_RANGE:0] pci_cbe_l_out_next;
  wire    pci_cbe_out_oe_comb;
  reg     pci_frame_in_critical, pci_frame_in_prev;
  wire    pci_frame_out_next, pci_frame_out_oe_comb;
  reg     pci_irdy_in_critical, pci_irdy_in_prev;
  wire    pci_irdy_out_next, pci_irdy_out_oe_comb;
  reg     pci_devsel_in_prev, pci_devsel_in_comb;
  reg     pci_trdy_in_prev, pci_trdy_in_critical;
  reg     pci_stop_in_prev, pci_stop_in_critical;
  reg     pci_perr_in_prev, pci_serr_in_prev;
  wire    Master_Force_AD_to_Address_Data_Critical;
  wire    Master_Captures_Data_On_TRDY, Master_Exposes_Data_On_TRDY;
  wire    Master_Forces_PERR;
// Signal to control Request pin if on-chip PCI devices share it
  wire    Master_Forced_Off_Bus_By_Target_Termination;
  wire    PERR_Detected_While_Master_Read;
  wire    This_Chip_Driving_IRDY = 1'b0;  // NOTE: use GNT instead.

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
  reg    [PCI_BUS_CBE_RANGE:0] pci_host_request_cbe;
  reg    [PCI_BUS_DATA_RANGE:0] pci_host_request_data;
  wire    pci_host_request_error;
  reg    [PCI_BUS_DATA_RANGE:0] next_addr;
  reg    [PCI_BUS_DATA_RANGE:0] next_data;

  wire    pci_request_fifo_data_available_meta;
  wire    pci_request_fifo_two_words_available_meta;
  wire    pci_request_fifo_data_unload;
  wire   [2:0] pci_request_fifo_type;
  wire   [PCI_BUS_CBE_RANGE:0] pci_request_fifo_cbe;
  wire   [PCI_BUS_DATA_RANGE:0] pci_request_fifo_data;
  wire    pci_request_fifo_error;

task set_addr;
  input [PCI_BUS_DATA_RANGE:0] new_addr;
  begin
    next_addr[PCI_BUS_DATA_RANGE:0] = new_addr[PCI_BUS_DATA_RANGE:0];
  end
endtask

task inc_addr;
  begin
    next_addr[PCI_BUS_DATA_RANGE:0] =
       (next_addr[PCI_BUS_DATA_RANGE:0] + 32'h00100000) & 32'hFF7FFFFF;
  end
endtask

task set_data;
  input [PCI_BUS_DATA_RANGE:0] new_data;
  begin
    next_data[PCI_BUS_DATA_RANGE:0] = new_data[PCI_BUS_DATA_RANGE:0];
  end
endtask

task inc_data;
  begin
    next_data[PCI_BUS_DATA_RANGE:0] =
       (next_data[PCI_BUS_DATA_RANGE:0] + 32'h00100000) & 32'hFF7FFFFF;
  end
endtask

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
    if ($time > 0)
    begin
      if (   (pci_frame_bus === 1'b1)
           | (pci_frame_bus === 1'b0)
           | (pci_irdy_bus === 1'b1)
           | (pci_irdy_bus === 1'b0) )
        $display ("*** FRAME or IRDY still driven when Reset asserted at time %t", $time);

    end
    #3.0;
    pci_clk = 1'b0;
    pci_gnt_in_critical = 1'b0;
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
    pci_gnt_in_critical = 1'b0;
    pci_ad_in_comb[PCI_BUS_DATA_RANGE:0] = `PCI_BUS_DATA_X;
    pci_frame_in_critical = 1'b0;
    pci_irdy_in_critical = 1'b0;
    pci_devsel_in_comb = 1'b0;
    pci_trdy_in_critical = 1'b0;
    pci_stop_in_critical = 1'b0;
    pci_perr_in_comb = 1'b0;
    pci_serr_in_comb = 1'b0;
    master_enable = 1'b0;
    master_fast_b2b_en = 1'b0;
    master_perr_enable = 1'b0;
    master_latency_value[7:0] = 8'h0A;
  end
endtask

task enable_pci_master;
  begin
    master_enable = 1'b1;
  end
endtask

task write_fifo;
  input [2:0] entry_type;
  input [PCI_BUS_CBE_RANGE:0] entry_cbe;
  input [PCI_BUS_DATA_RANGE:0] entry_data;
  begin
    pci_host_request_submit = 1'b1;
    pci_host_request_type[2:0] = entry_type[2:0];
    pci_host_request_cbe[PCI_BUS_CBE_RANGE:0] = entry_cbe[PCI_BUS_CBE_RANGE:0];
    pci_host_request_data[PCI_BUS_DATA_RANGE:0] = entry_data[PCI_BUS_DATA_RANGE:0];
  end
endtask

task write_addr;
  input [2:0] entry_type;
  input [PCI_BUS_CBE_RANGE:0] entry_cbe;
  begin
    pci_host_request_submit = 1'b1;
    pci_host_request_type[2:0] = entry_type[2:0];
    pci_host_request_cbe[PCI_BUS_CBE_RANGE:0] = entry_cbe[PCI_BUS_CBE_RANGE:0];
    pci_host_request_data[PCI_BUS_DATA_RANGE:0] = next_addr[PCI_BUS_DATA_RANGE:0];
    inc_addr;
  end
endtask

task write_data;
  input [2:0] entry_type;
  input [PCI_BUS_CBE_RANGE:0] entry_cbe;
  begin
    pci_host_request_submit = 1'b1;
    pci_host_request_type[2:0] = entry_type[2:0];
    pci_host_request_cbe[PCI_BUS_CBE_RANGE:0] = entry_cbe[PCI_BUS_CBE_RANGE:0];
    pci_host_request_data[PCI_BUS_DATA_RANGE:0] = next_data[PCI_BUS_DATA_RANGE:0];
    inc_data;
  end
endtask

task unload_target_data;
  begin
    master_to_target_status_unload = 1'b1;
  end
endtask

task pci_grant;
  begin
    pci_gnt_in_critical = 1'b1;
  end
endtask

task pci_frame;
  begin
    pci_frame_in_critical = 1'b1;
  end
endtask

task pci_irdy;
  begin
    pci_irdy_in_critical = 1'b1;
  end
endtask

task pci_devsel;
  begin
    pci_devsel_in_comb = 1'b1;
  end
endtask

task pci_trdy;
  begin
    pci_trdy_in_critical = 1'b1;
  end
endtask

task pci_stop;
  begin
    pci_stop_in_critical = 1'b1;
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
    pci_gnt_in_prev <= pci_gnt_in_critical;
    pci_ad_in_prev[PCI_BUS_DATA_RANGE:0] <= pci_ad_in_comb[PCI_BUS_DATA_RANGE:0];
    pci_devsel_in_prev <= pci_devsel_in_comb;
    pci_frame_in_prev <= pci_frame_in_critical;
    pci_irdy_in_prev <= pci_irdy_in_critical;
    pci_trdy_in_prev <= pci_trdy_in_critical;
    pci_stop_in_prev <= pci_stop_in_critical;
    pci_perr_in_prev <= pci_perr_in_comb;
    pci_serr_in_prev <= pci_serr_in_comb;
  end

// Remove signals which are set for 1 clock by tasks to create activity
  initial
  begin
    pci_host_request_submit <= 1'b0;
    pci_host_request_type[2:0] <= 3'hX;
    pci_host_request_cbe[PCI_BUS_CBE_RANGE:0] <= 4'hX;
    pci_host_request_data[PCI_BUS_DATA_RANGE:0] <= `PCI_BUS_DATA_X;
    pci_gnt_in_critical <= 1'b0;
    pci_gnt_in_prev <= pci_gnt_in_critical;
    pci_frame_in_critical <= 1'b0;
    pci_frame_in_prev <= 1'b0;
    pci_irdy_in_critical <= 1'b0;
    pci_irdy_in_prev <= 1'b0;
    pci_devsel_in_comb <= 1'b0;
    pci_devsel_in_prev <= pci_devsel_in_comb;
    pci_trdy_in_critical <= 1'b0;
    pci_trdy_in_prev <= pci_trdy_in_critical;
    pci_stop_in_critical <= 1'b0;
    pci_stop_in_prev <= pci_stop_in_critical;
    pci_perr_in_prev <= 1'b0;
    pci_serr_in_prev <= 1'b0;
  end

  always @(posedge pci_clk)
  begin
    pci_host_request_submit <= 1'b0;
    pci_host_request_type[2:0] <= 3'hX;
    pci_host_request_cbe[PCI_BUS_CBE_RANGE:0] <= 4'hX;
    pci_host_request_data[PCI_BUS_DATA_RANGE:0] <= `PCI_BUS_DATA_X;
    pci_gnt_in_critical <= 1'b0;
    pci_gnt_in_prev <= pci_gnt_in_critical;
    pci_frame_in_critical <= 1'b0;
    pci_irdy_in_critical <= 1'b0;
    pci_devsel_in_comb <= 1'b0;
    pci_trdy_in_critical <= 1'b0;
    pci_stop_in_critical <= 1'b0;
    pci_perr_in_prev <= 1'b0;
    pci_serr_in_prev <= 1'b0;
  end

  initial
  begin
    host_reset_comb <= 1'b1;  // clobber reset right at the beginning
    $display ("Setting PCI bus to nominal, at time %t", $time);
    do_reset;
    set_pci_idle;
    set_addr (32'hAA012345);
    set_data (32'hDD06789A);
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

// WORKING
`define WORKING
`ifdef WORKING

    $display ("Doing Config Read, 1 word, no Wait States, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_CONFIG_READ);
      do_clocks (4'h2);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Config Read, 1 word, no Wait States, loose GNT, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_CONFIG_READ);
      do_clocks (4'h2);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_grant;
      do_clocks (4'h1);
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Config Write, 1 word, no Wait States, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_CONFIG_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Config Write, 1 word, no Wait States, loose GNT, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_CONFIG_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_grant;
      do_clocks (4'h1);
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Bus Park, at time %t", $time);
    do_reset;
    unload_target_data;
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 1 word, no Wait States, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h2);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 1 word, no Wait States, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h2);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 1 word, 1 Target Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h4);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 2 words, no Wait States, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 2 words, 1 Target Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h4);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 2 words, 1 Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h2);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 2 words, no Wait States, Target_Stop, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 2 words, 1 Wait State, Target_Stop, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h4);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 2 words, 1 Wait State, Target_Stop, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h2);
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 1 word, no Wait States, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 1 word, no Wait States, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_grant;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 1 word, 1 Target Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h4);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 2 words, no Wait States, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 2 words, 1 Target Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h4);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 2 words, 1 Target Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h2);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 2 words, no Wait States, Target_Stop, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 2 words, 1 Target Wait State, Target_Stop, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h4);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 2 words, 1 Target Wait State, Target_Stop, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h2);
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h8);


    $display ("Doing Memory Read, 3 words, 1 Master Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h2);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 3 words, 1 Master Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_1);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
      do_clocks (4'h2);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);


    $display ("Doing Memory Read, 3 words, 5 Master Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h4);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 3 words, 5 Master Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);


    $display ("Doing Memory Write, 3 words, 5 Master Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_1);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
      do_clocks (4'h4);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 3 words, 5 Master Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_1);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

// Concept:  test all exceptional cases:
// These include: Grant removed during Address Stepping,
// Retries due to Master Data Timeout,
// Retries due to Master Bus Timeout,
// Retries due to Target Retry, both with and without data
//
// ALL of the commands below this should result in a re-request (after a lull)

    $display ("Doing Memory Read, 3 words, 3 Master Wait State, Bus Latency Timeout, retry, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_3);  // too late?
      do_clocks (4'h4);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);  // Should re-arbitrate
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h2);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 3 words, 3 Master Wait State, Bus Latency Timeout, retry, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_3);
      do_clocks (4'h4);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);  // Should re-arbitrate
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 3 words, 3 Master Wait State, Bus Latency Timeout, d+stop, retry, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_3);  // too late?
      do_clocks (4'h4);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);  // Should re-arbitrate
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 3 words, 3 Master Wait State, Bus Latency Timeout, d+stop, retry, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_3);
      do_clocks (4'h4);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);  // Should re-arbitrate
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h2);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 3 words, 3 Master Wait State, Bus Latency Timeout, stop, retry, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_3);  // too late?
      do_clocks (4'h4);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);  // Should re-arbitrate
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_devsel;
    pci_stop;
      do_clocks (4'h2);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_stop;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 3 words, 3 Master Wait State, Bus Latency Timeout, stop, retry, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_3);
      do_clocks (4'h4);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);  // Should re-arbitrate
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_devsel;
    pci_stop;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_stop;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h8);


    $display ("Doing Memory Read, 3 words, 3 Master Wait State, Bus Latency Timeout, stop last, retry, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_3);  // too late?
      do_clocks (4'h4);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);  // Should re-arbitrate
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_devsel;
    pci_stop;
      do_clocks (4'h2);
    pci_grant;
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_stop;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 3 words, 3 Master Wait State, Bus Latency Timeout, stop last, retry, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_3);
      do_clocks (4'h4);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);  // Should re-arbitrate
    pci_devsel;
    pci_trdy;
      do_clocks (4'h1);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_devsel;
    pci_stop;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_stop;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
    pci_stop;
      do_clocks (4'h8);


    $display ("Doing Memory Read, 3 words, 6 Master Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h4);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h4);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h4);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 3 words, 6 Master Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h4);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h4);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h4);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 3 words, 7 Master Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h5);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h3);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h4);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 3 words, 7 Master Wait State, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h5);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h3);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h3);
    pci_grant;
      do_clocks (4'h4);
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

//  NOTE: need to test fast back-to-backs.  Do all exceptional conditions get handled?
`endif  // WORKING

`define DUMPING
`ifdef DUMPING

    $display ("Doing Memory Read, 1 word, Master Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_1);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h2);
    pci_grant;  // Clk 0, resulting in FRAME at first clock.
      do_clocks (4'h6);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h6);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 1 word, Master Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h2);
    pci_grant;
      do_clocks (4'h6);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h6);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);


    $display ("Doing Memory Read, 2 words, Master Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h6);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h7);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 2 words, Master Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h6);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h7);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 2 words, Master Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h3);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h1);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h7);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 2 words, Master Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h3);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h1);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h7);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 3 words, Master Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h3);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h8);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 3 words, Master Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h3);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h3);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h8);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

// Target abort before and after last data offered,

    $display ("Doing Memory Read, 1 word, Target Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_1);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h2);
    pci_grant;  // Clk 0, resulting in FRAME at first clock.
      do_clocks (4'h5);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h1);
    pci_stop;
      do_clocks (4'h6);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 1 word, Target Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h2);
    pci_grant;
      do_clocks (4'h5);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h1);
    pci_stop;
      do_clocks (4'h6);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);


    $display ("Doing Memory Read, 2 words, Target Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h5);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h1);
    pci_stop;
      do_clocks (4'h7);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 2 words, Target Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h1);
    pci_grant;
      do_clocks (4'h5);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h1);
    pci_stop;
      do_clocks (4'h7);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 2 words, Target Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h3);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_2);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
    pci_devsel;  // abort is 6 or greater
      do_clocks (4'h1);
    pci_stop;
      do_clocks (4'h7);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 2 words, Target Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Half_0);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h3);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Half_1);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
    pci_devsel;  // abort is 6 or greater
      do_clocks (4'h1);
    pci_stop;
      do_clocks (4'h7);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Read, 3 words, Target Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h3);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h2);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h1);
    pci_stop;
      do_clocks (4'h8);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
      do_clocks (4'h8);

    $display ("Doing Memory Write, 3 words, Target Abort, at time %t", $time);
    do_reset;
    unload_target_data;
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_WRITE);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_1);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h3);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK, `Test_Byte_2);
      do_clocks (4'h2);  // abort is 6 or greater
    pci_devsel;
      do_clocks (4'h1);
    pci_stop;
      do_clocks (4'h8);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_3);
      do_clocks (4'h1);
    write_addr (PCI_HOST_REQUEST_ADDRESS_COMMAND, PCI_COMMAND_MEMORY_READ);
      do_clocks (4'h1);
    write_data (PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST, `Test_Byte_0);
      do_clocks (4'h4);
    pci_grant;
      do_clocks (4'h3);  // 2 for fast decode, 3 for medium
    pci_devsel;
    pci_trdy;
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

`endif  // DUMPING

    pci_blue_master.report_missing_transitions;

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
                                pci_host_request_cbe[PCI_BUS_CBE_RANGE:0],
                                pci_host_request_data[PCI_BUS_DATA_RANGE:0]}),
  .write_error                (pci_host_request_error),
  .read_clk                   (pci_clk),
  .read_sync_clk              (pci_clk),
  .read_remove                (pci_request_fifo_data_unload),
  .read_data_available_meta   (pci_request_fifo_data_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .read_two_words_available_meta (pci_request_fifo_two_words_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .read_data                  ({pci_request_fifo_type[2:0],
                                pci_request_fifo_cbe[PCI_BUS_CBE_RANGE:0],
                                pci_request_fifo_data[PCI_BUS_DATA_RANGE:0]}),
  .read_error                 (pci_request_fifo_error)
);

// Instantiate the Master Interface
pci_blue_master pci_blue_master (
// Signals driven to control the external PCI interface
  .pci_req_out_next           (pci_req_out_next),
  .pci_req_out_oe_comb        (pci_req_out_oe_comb),
  .pci_gnt_in_prev            (pci_gnt_in_prev),
  .pci_gnt_in_critical        (pci_gnt_in_critical),
  .pci_master_ad_out_next     (pci_master_ad_out_next[PCI_BUS_DATA_RANGE:0]),
  .pci_master_ad_out_oe_comb  (pci_master_ad_out_oe_comb),
  .pci_cbe_l_out_next         (pci_cbe_l_out_next[PCI_BUS_CBE_RANGE:0]),
  .pci_cbe_out_oe_comb        (pci_cbe_out_oe_comb),
  .pci_frame_in_critical      (pci_frame_in_critical),
  .pci_frame_in_prev          (pci_frame_in_prev),
  .pci_frame_out_next         (pci_frame_out_next),
  .pci_frame_out_oe_comb      (pci_frame_out_oe_comb),
  .pci_irdy_in_critical       (pci_irdy_in_critical),
  .pci_irdy_in_prev           (pci_irdy_in_prev),
  .pci_irdy_out_next          (pci_irdy_out_next),
  .pci_irdy_out_oe_comb       (pci_irdy_out_oe_comb),
  .pci_devsel_in_prev         (pci_devsel_in_prev),
  .pci_trdy_in_prev           (pci_trdy_in_prev),
  .pci_trdy_in_critical       (pci_trdy_in_critical),
  .pci_stop_in_prev           (pci_stop_in_prev),
  .pci_stop_in_critical       (pci_stop_in_critical),
  .pci_perr_in_prev           (pci_perr_in_prev),
  .pci_serr_in_prev           (pci_serr_in_prev),
// Signals to control shared AD bus, Parity, and SERR signals
  .Master_Force_AD_to_Address_Data_Critical (Master_Force_AD_to_Address_Data_Critical),
  .Master_Captures_Data_On_TRDY (Master_Captures_Data_On_TRDY),
  .Master_Exposes_Data_On_TRDY (Master_Exposes_Data_On_TRDY),
  .Master_Forces_PERR         (Master_Forces_PERR),
  .PERR_Detected_While_Master_Read (PERR_Detected_While_Master_Read),
  .This_Chip_Driving_IRDY     (This_Chip_Driving_IRDY),
// Signal to control Request pin if on-chip PCI devices share it
  .Master_Forced_Off_Bus_By_Target_Termination (Master_Forced_Off_Bus_By_Target_Termination),
// Host Interface Request FIFO used to ask the PCI Interface to initiate
//   PCI References to an external PCI Target.
  .pci_request_fifo_type      (pci_request_fifo_type[2:0]),
  .pci_request_fifo_cbe       (pci_request_fifo_cbe[PCI_BUS_CBE_RANGE:0]),
  .pci_request_fifo_data      (pci_request_fifo_data[PCI_BUS_DATA_RANGE:0]),
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
  .master_to_target_status_two_words_free (master_to_target_status_unload),  // NOTE: WORKING
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

  reg     req_reg;
  reg    [PCI_BUS_DATA_RANGE:0] ad_reg;
  reg    [PCI_BUS_CBE_RANGE:0] cbe_reg;
  reg     frame_reg, irdy_reg;

  always @(posedge pci_clk or posedge host_reset_comb)
  begin
    if (host_reset_comb == 1'b1)
    begin
      req_reg <= 1'b0;
      ad_reg[PCI_BUS_DATA_RANGE:0] <= 32'hX;
      cbe_reg[PCI_BUS_CBE_RANGE:0] <= 4'hX;
      frame_reg <= 1'bX;
      irdy_reg <= 1'bX;
    end
    else
    begin
      req_reg <= pci_req_out_next;
      ad_reg[PCI_BUS_DATA_RANGE:0] <= (   Master_Force_AD_to_Address_Data_Critical
                                    | (Master_Exposes_Data_On_TRDY & pci_trdy_in_critical) )
                    ? pci_master_ad_out_next[PCI_BUS_DATA_RANGE:0]
                    : ad_reg[PCI_BUS_DATA_RANGE:0];
      cbe_reg[PCI_BUS_CBE_RANGE:0] <= (   Master_Force_AD_to_Address_Data_Critical
                                    | (Master_Exposes_Data_On_TRDY & pci_trdy_in_critical) )
                    ? pci_cbe_l_out_next[PCI_BUS_CBE_RANGE:0]
                    : cbe_reg[PCI_BUS_CBE_RANGE:0];
      frame_reg <= pci_frame_out_next;
      irdy_reg <= pci_irdy_out_next;
    end
  end

  assign pci_req_bus = pci_req_out_oe_comb ? ~req_reg : 1'bZ;
  assign pci_master_ad_bus[PCI_BUS_DATA_RANGE:0] = pci_master_ad_out_oe_comb
                                      ? ad_reg[PCI_BUS_DATA_RANGE:0]
                                      : 32'hZ;
  assign pci_master_cbe_bus[PCI_BUS_CBE_RANGE:0] = pci_cbe_out_oe_comb
                                      ? cbe_reg[PCI_BUS_CBE_RANGE:0]
                                      : 4'hZ;
  assign pci_frame_bus = pci_frame_out_oe_comb ? ~frame_reg : 1'bZ;
  assign pci_irdy_bus = pci_irdy_out_oe_comb ? ~irdy_reg : 1'bZ;
endmodule

