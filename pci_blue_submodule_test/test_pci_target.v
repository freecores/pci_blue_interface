//===========================================================================
// $Id: test_pci_target.v,v 1.5 2001-09-04 04:51:56 bbeaver Exp $
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
// NOTE: NOT WORKED ON YET.  A copy of TEST_PCI_MASTER!
//
//===========================================================================

`timescale 1ns/1ps

module pci_test_target (
  host_reset_comb,
  pci_response_fifo_error,
  Target_Force_AD_to_Address_Data_Critical,
  Target_Exposes_Data_On_IRDY,
  pci_clk,
  pci_target_ad_bus,
  pci_ad_in_prev,
  pci_cbe_l_in_prev,
  pci_frame_in_critical, pci_frame_in_prev,
  pci_irdy_in_critical, pci_irdy_in_prev,
  pci_devsel_in_critical,
  pci_devsel_bus,
  pci_trdy_in_critical,
  pci_trdy_bus,
  pci_stop_in_critical,
  pci_stop_bus,
  pci_perr_in_prev,
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
  inc   // TEMPORAR
);

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"

  output  host_reset_comb;
  output  pci_response_fifo_error;
  output  Target_Force_AD_to_Address_Data_Critical;
  output  Target_Exposes_Data_On_IRDY;
  output  pci_clk;
  output [PCI_BUS_DATA_RANGE:0] pci_ad_in_prev;
  output [PCI_BUS_CBE_RANGE:0] pci_cbe_l_in_prev;
  output [PCI_BUS_DATA_RANGE:0] pci_target_ad_bus;
  output  pci_frame_in_critical, pci_frame_in_prev;
  output  pci_irdy_in_critical, pci_irdy_in_prev;
  output  pci_devsel_in_critical;
  output  pci_devsel_bus;
  output  pci_trdy_in_critical;
  output  pci_trdy_bus;
  output  pci_stop_in_critical;
  output  pci_stop_bus;
  output  pci_perr_in_prev;
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

`ifdef TARGET_INCLUDED
// GROSS debugging signal. Only here to put signal in waveform.
  assign  pci_state[4:0]        = pci_blue_target.PCI_Master_State[4:0];                  // TEMPORARY
  assign  pci_retry_type[2:0]   = {pci_blue_target.Master_Retry_Address_Type[2:0]};       // TEMPORARY
  assign  pci_retry_address[31:0] = {pci_blue_target.Master_Retry_Address[31:2], 2'b0};   // TEMPORARY
  assign  pci_retry_command[3:0]  = pci_blue_target.Master_Retry_Command[3:0];            // TEMPORARY
  assign  pci_retry_write_reg   = pci_blue_target.Master_Retry_Write_Reg;                 // TEMPORARY
  assign  Doing_Config_Reference = pci_blue_target.Master_Doing_Config_Reference;         // TEMPORARY
  assign  pci_retry_data[31:0]  = pci_blue_target.Master_Retry_Data[31:0];                // TEMPORARY
  assign  pci_retry_data_type[2:0] = pci_blue_target.Master_Retry_Data_Type[2:0];         // TEMPORARY
  assign  fifo_contains_address = pci_blue_target.Request_FIFO_CONTAINS_ADDRESS;          // TEMPORARY
  assign  pci_target_full       = pci_blue_target.master_to_target_status_full;           // TEMPORARY
  assign  pci_bus_full          = pci_blue_target.master_request_full;                    // TEMPORARY
  assign  two_words_avail       = pci_blue_target.request_fifo_two_words_available_meta;  // TEMPORARY
  assign  one_word_avail        = pci_blue_target.request_fifo_data_available_meta;       // TEMPORARY
  assign  addr_aval             = pci_blue_target.Request_FIFO_CONTAINS_ADDRESS;          // TEMPORARY
  assign  more                  = pci_blue_target.Request_FIFO_CONTAINS_DATA_MORE;        // TEMPORARY
  assign  two_more              = pci_blue_target.Request_FIFO_CONTAINS_DATA_TWO_MORE;    // TEMPORARY
  assign  last                  = pci_blue_target.Request_FIFO_CONTAINS_DATA_LAST;        // TEMPORARY
  assign  working               = pci_blue_target.working;       // TEMPORARY
  assign  new_addr_new_data     = pci_blue_target.proceed_with_new_address_plus_new_data;        // TEMPORARY
  assign  old_addr_new_data     = pci_blue_target.proceed_with_stored_address_plus_new_data;     // TEMPORARY
  assign  old_addr_old_data     = pci_blue_target.proceed_with_stored_address_plus_stored_data;  // TEMPORARY
  assign  new_data              = pci_blue_target.proceed_with_new_data;                  // TEMPORARY
  assign  inc                   = pci_blue_target.Inc_Stored_Address;                     // TEMPORARY
`endif  // TARGET_INCLUDED

// PCI signals
  reg    [PCI_BUS_DATA_RANGE:0] pci_ad_in_prev;
  reg    [PCI_BUS_CBE_RANGE:0] pci_cbe_l_in_prev;
  wire   [PCI_BUS_DATA_RANGE:0] pci_target_ad_out_next;
  wire    pci_target_ad_out_oe_comb;
  reg     pci_frame_in_critical, pci_frame_in_prev;
  wire    pci_frame_out_next, pci_frame_out_oe_comb;
  reg     pci_irdy_in_critical, pci_irdy_in_prev;
  wire    pci_irdy_out_next, pci_irdy_out_oe_comb;
  reg     pci_devsel_in_prev, pci_devsel_in_critical;
  reg     pci_trdy_in_prev, pci_trdy_in_critical;
  reg     pci_stop_in_prev, pci_stop_in_critical;
  reg     pci_perr_in_prev;
  wire    Target_Force_AD_to_Address_Data_Critical;
  wire    Target_Captures_Data_On_IRDY, Target_Exposes_Data_On_IRDY;
  wire    Target_Forces_PERR;
// Signal to control Request pin if on-chip PCI devices share it
  wire    This_Chip_Driving_TRDY = 1'b0;  // NOTE: use GNT instead.

// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  wire   [2:0] master_to_target_status_type = 3'h0;
  wire   [PCI_BUS_CBE_RANGE:0] master_to_target_status_cbe = 4'h0;
  wire   [PCI_BUS_DATA_RANGE:0] master_to_target_status_data = 32'h00000000;
  wire    master_to_target_status_flush = 1'b0;
  wire    master_to_target_status_available = 1'b0;
  reg     master_to_target_status_two_words_free;
  reg     master_to_target_status_unload;

// Signals from the Config Regs to the Master to control it.
  wire    master_enable;
  wire    master_fast_b2b_en;
  wire    master_perr_enable;
  wire   [7:0] master_latency_value;

// Wires connecting the Host FIFOs to the PCI Interface
  reg    host_reset_comb;
  reg    pci_clk;

  reg    [PCI_BUS_DATA_RANGE:0] next_addr;
  reg    [PCI_BUS_DATA_RANGE:0] next_data;

// Wires used by the pci interface to request action by the host controller
  wire   [PCI_BUS_DATA_RANGE:0] pci_host_response_data;
  wire   [PCI_BUS_CBE_RANGE:0] pci_host_response_cbe;
  wire   [3:0] pci_host_response_type;
  wire    pci_host_response_data_available_meta;
  reg     pci_host_response_unload;
  wire    pci_host_response_error;

// Wires used by the host controller to send delayed read data by the pci interface
  reg    [PCI_BUS_DATA_RANGE:0] pci_host_delayed_read_data;
  reg    [2:0] pci_host_delayed_read_type;
  wire    pci_host_delayed_read_room_available_meta;
  wire    pci_host_delayed_read_two_words_available_meta;
  reg     pci_host_delayed_read_data_submit;
  wire    pci_host_delayed_read_data_error;

// Wires connecting the Host FIFOs to the PCI Interface
  wire   [3:0] pci_response_fifo_type;
  wire   [PCI_BUS_CBE_RANGE:0] pci_response_fifo_cbe;
  wire   [PCI_BUS_DATA_RANGE:0] pci_response_fifo_data;
  wire    pci_response_fifo_room_available_meta;
  wire    pci_response_fifo_two_words_available_meta;
  wire    pci_response_fifo_data_load, pci_response_fifo_error;
  wire   [2:0] pci_delayed_read_fifo_type;
  wire   [PCI_BUS_DATA_RANGE:0] pci_delayed_read_fifo_data;
  wire    pci_delayed_read_fifo_data_available_meta;
  wire    pci_delayed_read_fifo_data_unload, pci_delayed_read_fifo_error;

task set_ext_addr;
  input [PCI_BUS_DATA_RANGE:0] new_addr;
  begin
    next_addr[PCI_BUS_DATA_RANGE:0] <= new_addr[PCI_BUS_DATA_RANGE:0];
  end
endtask

task inc_ext_addr;
  begin
    next_addr[PCI_BUS_DATA_RANGE:0] <=
       (next_addr[PCI_BUS_DATA_RANGE:0] + 32'h00100000) & 32'hFF7FFFFF;
  end
endtask

task set_ext_data;
  input [PCI_BUS_DATA_RANGE:0] new_data;
  begin
    next_data[PCI_BUS_DATA_RANGE:0] <= new_data[PCI_BUS_DATA_RANGE:0];
  end
endtask

task inc_ext_data;
  begin
    next_data[PCI_BUS_DATA_RANGE:0] <=
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
      if (   (pci_devsel_bus === 1'b1)
           | (pci_devsel_bus === 1'b0)
           | (pci_trdy_bus === 1'b1)
           | (pci_trdy_bus === 1'b0)
           | (pci_stop_bus === 1'b1)
           | (pci_stop_bus === 1'b0) )
        $display ("*** DEVSEL, TRDY, or STOP still driven when Reset asserted at time %t", $time);
    end
    #3.0;
    pci_clk = 1'b0;
    host_reset_comb = 1'b1;
    #5;
    host_reset_comb = 1'b0;
    #2.0;
  end
endtask

  reg    pci_perr_in_comb, pci_serr_in_comb;
  reg   [PCI_BUS_DATA_RANGE:0] pci_ad_in_comb;
  reg   [PCI_BUS_CBE_RANGE:0] pci_cbe_l_in_comb;

task set_pci_idle;
  begin
    pci_ad_in_comb[PCI_BUS_DATA_RANGE:0] = `PCI_BUS_DATA_X;
    pci_cbe_l_in_comb[PCI_BUS_CBE_RANGE:0] = `PCI_BUS_CBE_X;
    pci_devsel_in_critical = 1'b0;
    pci_trdy_in_critical = 1'b0;
    pci_stop_in_critical = 1'b0;
    pci_perr_in_comb = 1'b0;
    pci_serr_in_comb = 1'b0;
  end
endtask

task write_delayed_read_fifo;
  input [2:0] entry_type;
  input [PCI_BUS_CBE_RANGE:0] entry_cbe;
  begin
    pci_host_delayed_read_data_submit <= 1'b1;
    pci_host_delayed_read_type[2:0] <= entry_type[2:0];
    pci_host_delayed_read_data[PCI_BUS_DATA_RANGE:0] <= next_data[PCI_BUS_DATA_RANGE:0];
  end
endtask

task pci_frame;
  begin
    pci_frame_in_critical <= 1'b1;
  end
endtask

task pci_irdy;
  begin
    pci_irdy_in_critical <= 1'b1;
  end
endtask

task pci_perr;
  begin
    pci_perr_in_prev <= 1'b1;
  end
endtask

task write_reg;
  input  [PCI_BUS_CBE_RANGE:0] ref_type;
  begin
  end
endtask

task write_addr;
  input  [PCI_BUS_CBE_RANGE:0] ref_type;
  input   serr_requested;
  begin
  end
endtask

task read_be;
  input  [PCI_BUS_CBE_RANGE:0] byte_enables;
  input   last_requested;
  begin
  end
endtask

task write_data;
  input  [PCI_BUS_CBE_RANGE:0] byte_enables;
  input   last_requested;
  input   perr_requested;
  begin
  end
endtask

// Make shorthand command task so that it is easier to set things up.
// CRITICAL WRITE must always be READ + 1.  Used in _pair task below.
  parameter noop =                  0;
  parameter REG_READ  =             1;
  parameter REG_WRITE =             2;
  parameter MEM_READ =              3;
  parameter MEM_WRITE =             4;
  parameter MEM_READ_SERR =         5;
  parameter MEM_WRITE_SERR =        6;

  parameter READ_DATA =             7;
  parameter READ_DATA_LAST =        8;

  parameter WRITE_DATA =            9;
  parameter WRITE_DATA_PERR =      10;
  parameter WRITE_DATA_LAST =      11;
  parameter WRITE_DATA_LAST_PERR = 12;

  parameter DLY_noop =              0;
  parameter DLY_DATA =              1;
  parameter DLY_DATA_PERR =         2;
  parameter DLY_DATA_LAST =         3;
  parameter DLY_DATA_LAST_PERR =    4;
  parameter DLY_DISCONNECT =        5;
  parameter DLY_ABORT =             6;

// Lets think about this.
//   Need to have external device do a Reference.
//   Need to have Response FIFO have appropriate stuff in it.
//   Need to have Delayed Read FIFO have appropriate stuff in it.

task do_target_test;
  input  [7:0] total_time;

  input  [3:0] command_1;      input  [3:0] data_type_1;

  input  [7:0] data_time_2;    input  [3:0] data_type_2;
  input  [7:0] data_time_3;    input  [3:0] data_type_3;
  input  [7:0] data_time_4;    input  [3:0] data_type_4;

  input  [7:0] addr_time_5;    input  [3:0] command_5;

  input  [7:0] data_time_6;    input  [3:0] data_type_6;
  input  [7:0] data_time_7;    input  [3:0] data_type_7;


  input  [7:0] delayed_read_fifo_time_1;  input  [2:0] delayed_read_type_1;
  input  [7:0] delayed_read_fifo_time_2;  input  [2:0] delayed_read_type_2;
  input  [7:0] delayed_read_fifo_time_3;  input  [2:0] delayed_read_type_3;
  input  [7:0] delayed_read_fifo_time_4;  input  [2:0] delayed_read_type_4;
  input  [7:0] delayed_read_fifo_time_5;  input  [2:0] delayed_read_type_5;
  input  [7:0] delayed_read_fifo_time_6;  input  [2:0] delayed_read_type_6;
  input  [7:0] delayed_read_fifo_time_7;  input  [2:0] delayed_read_type_7;

  integer t1, d2, d3, d4, d5, d6, d7;
  integer g1, g2, g3, g4, g5, g6, g7;
  integer dlyrd1, dlyrd2, dlyrd3, dlyrd4, dlyrd5, dlyrd6, dlyrd7;

  begin
    fork
      begin  // clock gen
        do_reset;
        for (t1 = 8'h00; t1 < total_time[7:0]; t1 = t1 + 8'h01) do_clocks (4'h1);
      end  // clock gen

// Cause external bus activity, including FRAME and IRDY activity
      begin  // first Address, data
        @(negedge pci_clk);
        if (command_1 == REG_READ)
          write_reg (PCI_COMMAND_CONFIG_READ);
        else if (command_1 == REG_WRITE)
          write_reg (PCI_COMMAND_CONFIG_WRITE);
        else if (command_1 == MEM_READ)
          write_addr (PCI_COMMAND_MEMORY_READ, 1'b0);
        else if (command_1 == MEM_READ_SERR)
          write_addr (PCI_COMMAND_MEMORY_READ, 1'b1);
        else if (command_1 == MEM_WRITE)
          write_addr (PCI_COMMAND_MEMORY_WRITE, 1'b0);
        else if (command_1 == MEM_WRITE_SERR)
          write_addr (PCI_COMMAND_MEMORY_WRITE, 1'b1);

        else $display ("*** bad first command");
        @(negedge pci_clk);
        if (data_type_1 == READ_DATA)
          read_be (`Test_Byte_0, 1'b0);
        else if (data_type_1 == READ_DATA_LAST)
          read_be (`Test_Byte_0, 1'b1);
        else if (data_type_1 == WRITE_DATA)
          write_data (`Test_Byte_0, 1'b0, 1'b0);
        else if (data_type_1 == WRITE_DATA_PERR)
          write_data (`Test_Byte_0, 1'b0, 1'b1);
        else if (data_type_1 == WRITE_DATA_LAST)
          write_data (`Test_Byte_0, 1'b1, 1'b0);
        else if (data_type_1 == WRITE_DATA_LAST_PERR)
          write_data (`Test_Byte_0, 1'b1, 1'b1);
      end  // first Address, data

      begin  // second data
        if (data_time_2[7:0] != 8'h00)
        begin
          for (d2 = 8'h00; d2 <= data_time_2[7:0]; d2 = d2 + 8'h01) @(negedge pci_clk);
          if (data_type_2 == READ_DATA)
            read_be (`Test_Byte_0, 1'b0);
          else if (data_type_2 == READ_DATA_LAST)
            read_be (`Test_Byte_0, 1'b1);
          else if (data_type_2 == WRITE_DATA)
            write_data (`Test_Byte_0, 1'b0, 1'b0);
          else if (data_type_2 == WRITE_DATA_PERR)
            write_data (`Test_Byte_0, 1'b0, 1'b1);
          else if (data_type_2 == WRITE_DATA_LAST)
            write_data (`Test_Byte_0, 1'b1, 1'b0);
          else if (data_type_2 == WRITE_DATA_LAST_PERR)
            write_data (`Test_Byte_0, 1'b1, 1'b1);
        end
      end  // second data

      begin  // third data
        if (data_time_3[7:0] != 8'h00)
        begin
          for (d3 = 8'h00; d3 <= data_time_3[7:0]; d3 = d3 + 8'h01) @(negedge pci_clk);
          if (data_type_3 == READ_DATA)
            read_be (`Test_Byte_0, 1'b0);
          else if (data_type_3 == READ_DATA_LAST)
            read_be (`Test_Byte_0, 1'b1);
          else if (data_type_3 == WRITE_DATA)
            write_data (`Test_Byte_0, 1'b0, 1'b0);
          else if (data_type_3 == WRITE_DATA_PERR)
            write_data (`Test_Byte_0, 1'b0, 1'b1);
          else if (data_type_3 == WRITE_DATA_LAST)
            write_data (`Test_Byte_0, 1'b1, 1'b0);
          else if (data_type_3 == WRITE_DATA_LAST_PERR)
            write_data (`Test_Byte_0, 1'b1, 1'b1);
        end
      end  // third data

      begin  // fourth data
        if (data_time_4[7:0] != 8'h00)
        begin
          for (d4 = 8'h00; d4 <= data_time_4[7:0]; d4 = d4 + 8'h01) @(negedge pci_clk);
          if (data_type_4 == READ_DATA)
            read_be (`Test_Byte_0, 1'b0);
          else if (data_type_4 == READ_DATA_LAST)
            read_be (`Test_Byte_0, 1'b1);
          else if (data_type_4 == WRITE_DATA)
            write_data (`Test_Byte_0, 1'b0, 1'b0);
          else if (data_type_4 == WRITE_DATA_PERR)
            write_data (`Test_Byte_0, 1'b0, 1'b1);
          else if (data_type_4 == WRITE_DATA_LAST)
            write_data (`Test_Byte_0, 1'b1, 1'b0);
          else if (data_type_4 == WRITE_DATA_LAST_PERR)
            write_data (`Test_Byte_0, 1'b1, 1'b1);
        end
      end  // fourth data

      begin  // fifth Address
        if (addr_time_5[7:0] != 8'h00)
        begin
          for (d5 = 8'h00; d5 <= addr_time_5[7:0]; d5 = d5 + 8'h01) @(negedge pci_clk);
        if (command_5 == REG_READ)
          write_reg (PCI_COMMAND_CONFIG_READ);
        else if (command_5 == REG_WRITE)
          write_reg (PCI_COMMAND_CONFIG_WRITE);
          else if (command_5 == MEM_READ)
            write_data (`Test_Byte_0, 1'b0, 1'b0);
          else if (command_5 == MEM_READ_SERR)
            write_data (`Test_Byte_0, 1'b0, 1'b1);
          else if (command_5 == MEM_WRITE)
            write_data (`Test_Byte_0, 1'b1, 1'b0);
          else if (command_5 == MEM_WRITE_SERR)
            write_data (`Test_Byte_0, 1'b1, 1'b1);
        end
      end  // fifth Address

      begin  // sixth data
        if (data_time_6[7:0] != 8'h00)
        begin
          for (d6 = 8'h00; d6 <= data_time_6[7:0]; d6 = d6 + 8'h01) @(negedge pci_clk);
          if (data_type_6 == READ_DATA)
            read_be (`Test_Byte_0, 1'b0);
          else if (data_type_6 == READ_DATA_LAST)
            read_be (`Test_Byte_0, 1'b1);
          else if (data_type_6 == WRITE_DATA)
            write_data (`Test_Byte_0, 1'b0, 1'b0);
          else if (data_type_6 == WRITE_DATA_PERR)
            write_data (`Test_Byte_0, 1'b0, 1'b1);
          else if (data_type_6 == WRITE_DATA_LAST)
            write_data (`Test_Byte_0, 1'b1, 1'b0);
          else if (data_type_6 == WRITE_DATA_LAST_PERR)
            write_data (`Test_Byte_0, 1'b1, 1'b1);
        end
      end  // sixth data

      begin  // seventh data
        if (data_time_7[7:0] != 8'h00)
        begin
          for (d7 = 8'h00; d7 <= data_time_7[7:0]; d7 = d7 + 8'h01) @(negedge pci_clk);
          if (data_type_7 == READ_DATA)
            read_be (`Test_Byte_0, 1'b0);
          else if (data_type_7 == READ_DATA_LAST)
            read_be (`Test_Byte_0, 1'b1);
          else if (data_type_7 == WRITE_DATA)
            write_data (`Test_Byte_0, 1'b0, 1'b0);
          else if (data_type_7 == WRITE_DATA_PERR)
            write_data (`Test_Byte_0, 1'b0, 1'b1);
          else if (data_type_7 == WRITE_DATA_LAST)
            write_data (`Test_Byte_0, 1'b1, 1'b0);
          else if (data_type_7 == WRITE_DATA_LAST_PERR)
            write_data (`Test_Byte_0, 1'b1, 1'b1);
        end
      end  // seventh data

// Insert data into the Delayed Read FIFO
      begin  // delayed_read 1
        if (delayed_read_fifo_time_1[7:0] != 8'h00)
        begin
          for (dlyrd1 = 8'h00; dlyrd1 <= delayed_read_fifo_time_1[7:0]; dlyrd1 = dlyrd1 + 8'h01) @(negedge pci_clk);
          if (delayed_read_type_1[2:0] == DLY_DATA)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID, `Test_Byte_0);
          else if (delayed_read_type_1[2:0] == DLY_DATA_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_PERR, `Test_Byte_0);
          else if (delayed_read_type_1[2:0] == DLY_DATA_LAST)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST, `Test_Byte_0);
          else if (delayed_read_type_1[2:0] == DLY_DATA_LAST_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST_PERR, `Test_Byte_0);
          else if (delayed_read_type_1[2:0] == DLY_DISCONNECT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_FAST_RETRY, `Test_Byte_0);
          else if (delayed_read_type_1[2:0] == DLY_ABORT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_TARGET_ABORT, `Test_Byte_0);
        end
      end  // delayed_read 1

      begin  // delayed_read 2
        if (delayed_read_fifo_time_2[7:0] != 8'h00)
        begin
          for (dlyrd2 = 8'h00; dlyrd2 <= delayed_read_fifo_time_2[7:0]; dlyrd2 = dlyrd2 + 8'h01) @(negedge pci_clk);
          if (delayed_read_type_2[2:0] == DLY_DATA)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID, `Test_Byte_0);
          else if (delayed_read_type_2[2:0] == DLY_DATA_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_PERR, `Test_Byte_0);
          else if (delayed_read_type_2[2:0] == DLY_DATA_LAST)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST, `Test_Byte_0);
          else if (delayed_read_type_2[2:0] == DLY_DATA_LAST_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST_PERR, `Test_Byte_0);
          else if (delayed_read_type_2[2:0] == DLY_DISCONNECT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_FAST_RETRY, `Test_Byte_0);
          else if (delayed_read_type_2[2:0] == DLY_ABORT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_TARGET_ABORT, `Test_Byte_0);
        end
      end  // delayed_read 2

      begin  // delayed_read 3
        if (delayed_read_fifo_time_3[7:0] != 8'h00)
        begin
          for (dlyrd3 = 8'h00; dlyrd3 <= delayed_read_fifo_time_3[7:0]; dlyrd3 = dlyrd3 + 8'h01) @(negedge pci_clk);
          if (delayed_read_type_3[2:0] == DLY_DATA)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID, `Test_Byte_0);
          else if (delayed_read_type_3[2:0] == DLY_DATA_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_PERR, `Test_Byte_0);
          else if (delayed_read_type_3[2:0] == DLY_DATA_LAST)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST, `Test_Byte_0);
          else if (delayed_read_type_3[2:0] == DLY_DATA_LAST_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST_PERR, `Test_Byte_0);
          else if (delayed_read_type_3[2:0] == DLY_DISCONNECT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_FAST_RETRY, `Test_Byte_0);
          else if (delayed_read_type_3[2:0] == DLY_ABORT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_TARGET_ABORT, `Test_Byte_0);
        end
      end  // delayed_read 3

      begin  // delayed_read 4
        if (delayed_read_fifo_time_4[7:0] != 8'h00)
        begin
          for (dlyrd4 = 8'h00; dlyrd4 <= delayed_read_fifo_time_4[7:0]; dlyrd4 = dlyrd4 + 8'h01) @(negedge pci_clk);
          if (delayed_read_type_4[2:0] == DLY_DATA)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID, `Test_Byte_0);
          else if (delayed_read_type_4[2:0] == DLY_DATA_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_PERR, `Test_Byte_0);
          else if (delayed_read_type_4[2:0] == DLY_DATA_LAST)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST, `Test_Byte_0);
          else if (delayed_read_type_4[2:0] == DLY_DATA_LAST_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST_PERR, `Test_Byte_0);
          else if (delayed_read_type_4[2:0] == DLY_DISCONNECT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_FAST_RETRY, `Test_Byte_0);
          else if (delayed_read_type_4[2:0] == DLY_ABORT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_TARGET_ABORT, `Test_Byte_0);
        end
      end  // delayed_read 4

      begin  // delayed_read 5
        if (delayed_read_fifo_time_5[7:0] != 8'h00)
        begin
          for (dlyrd5 = 8'h00; dlyrd5 <= delayed_read_fifo_time_5[7:0]; dlyrd5 = dlyrd5 + 8'h01) @(negedge pci_clk);
          if (delayed_read_type_5[2:0] == DLY_DATA)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID, `Test_Byte_0);
          else if (delayed_read_type_5[2:0] == DLY_DATA_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_PERR, `Test_Byte_0);
          else if (delayed_read_type_5[2:0] == DLY_DATA_LAST)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST, `Test_Byte_0);
          else if (delayed_read_type_5[2:0] == DLY_DATA_LAST_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST_PERR, `Test_Byte_0);
          else if (delayed_read_type_5[2:0] == DLY_DISCONNECT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_FAST_RETRY, `Test_Byte_0);
          else if (delayed_read_type_5[2:0] == DLY_ABORT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_TARGET_ABORT, `Test_Byte_0);
        end
      end  // delayed_read 5

      begin  // delayed_read 6
        if (delayed_read_fifo_time_6[7:0] != 8'h00)
        begin
          for (dlyrd6 = 8'h00; dlyrd6 <= delayed_read_fifo_time_6[7:0]; dlyrd6 = dlyrd6 + 8'h01) @(negedge pci_clk);
          if (delayed_read_type_6[2:0] == DLY_DATA)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID, `Test_Byte_0);
          else if (delayed_read_type_6[2:0] == DLY_DATA_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_PERR, `Test_Byte_0);
          else if (delayed_read_type_6[2:0] == DLY_DATA_LAST)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST, `Test_Byte_0);
          else if (delayed_read_type_6[2:0] == DLY_DATA_LAST_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST_PERR, `Test_Byte_0);
          else if (delayed_read_type_6[2:0] == DLY_DISCONNECT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_FAST_RETRY, `Test_Byte_0);
          else if (delayed_read_type_6[2:0] == DLY_ABORT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_TARGET_ABORT, `Test_Byte_0);
        end
      end  // delayed_read 6

      begin  // delayed_read 7
        if (delayed_read_fifo_time_7[7:0] != 8'h00)
        begin
          for (dlyrd7 = 8'h00; dlyrd7 <= delayed_read_fifo_time_7[7:0]; dlyrd7 = dlyrd7 + 8'h01) @(negedge pci_clk);
          if (delayed_read_type_7[2:0] == DLY_DATA)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID, `Test_Byte_0);
          else if (delayed_read_type_7[2:0] == DLY_DATA_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_PERR, `Test_Byte_0);
          else if (delayed_read_type_7[2:0] == DLY_DATA_LAST)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST, `Test_Byte_0);
          else if (delayed_read_type_7[2:0] == DLY_DATA_LAST_PERR)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_VALID_LAST_PERR, `Test_Byte_0);
          else if (delayed_read_type_7[2:0] == DLY_DISCONNECT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_FAST_RETRY, `Test_Byte_0);
          else if (delayed_read_type_7[2:0] == DLY_ABORT)
            write_delayed_read_fifo (PCI_HOST_DELAYED_READ_DATA_TARGET_ABORT, `Test_Byte_0);
        end
      end  // delayed_read 7
    join
  end
endtask

// This task REQUIRES that a write command is constructed by adding 1 to a read command
task do_test_target_read_write_pair;
  input  [7:0] total_time;

  input  [3:0] command_1;      input  [3:0] data_type_1;

  input  [7:0] data_time_2;    input  [3:0] data_type_2;
  input  [7:0] data_time_3;    input  [3:0] data_type_3;
  input  [7:0] data_time_4;    input  [3:0] data_type_4;

  input  [7:0] addr_time_5;    input  [3:0] command_5;

  input  [7:0] data_time_6;    input  [3:0] data_type_6;
  input  [7:0] data_time_7;    input  [3:0] data_type_7;

  input  [7:0] target_time_1;  input  [2:0] target_dts_1;
  input  [7:0] target_time_2;  input  [2:0] target_dts_2;
  input  [7:0] target_time_3;  input  [2:0] target_dts_3;
  input  [7:0] target_time_4;  input  [2:0] target_dts_4;
  input  [7:0] target_time_5;  input  [2:0] target_dts_5;
  input  [7:0] target_time_6;  input  [2:0] target_dts_6;
  input  [7:0] target_time_7;  input  [2:0] target_dts_7;

  begin
    $display ("Reading at %t", $time);
    do_target_test (total_time[7:0],  // the Read command
         command_1[3:0], data_type_1[3:0],  // First Reference
         data_time_2[7:0], data_type_2[3:0],  // Optional Data
         data_time_3[7:0], data_type_3[3:0],
         data_time_4[7:0], data_type_4[3:0],
         addr_time_5[7:0], command_5[3:0],  // Second reference
         data_time_6[7:0], data_type_6[3:0],
         data_time_7[7:0], data_type_7[3:0],
         target_time_1[7:0], target_dts_1[2:0], target_time_2[7:0], target_dts_2[2:0],  // Target
         target_time_3[7:0], target_dts_3[2:0], target_time_4[7:0], target_dts_4[2:0],
         target_time_5[7:0], target_dts_5[2:0], target_time_6[7:0], target_dts_6[2:0], 
         target_time_7[7:0], target_dts_7[2:0]);

    $display ("Writing at %t", $time);
    do_target_test (total_time[7:0],  // the Write command
         command_1[3:0] + 4'h1, data_type_1[3:0],  // First Reference
         data_time_2[7:0], data_type_2[3:0],  // Optional Data
         data_time_3[7:0], data_type_3[3:0],
         data_time_4[7:0], data_type_4[3:0],
         addr_time_5[7:0], command_5[3:0],  // Second reference
         data_time_6[7:0], data_type_6[3:0],
         data_time_7[7:0], data_type_7[3:0],
         target_time_1[7:0], target_dts_1[2:0], target_time_2[7:0], target_dts_2[2:0],  // Target
         target_time_3[7:0], target_dts_3[2:0], target_time_4[7:0], target_dts_4[2:0],
         target_time_5[7:0], target_dts_5[2:0], target_time_6[7:0], target_dts_6[2:0], 
         target_time_7[7:0], target_dts_7[2:0]);
  end
endtask

// delay signals like the Pads delay them
  always @(posedge pci_clk)
  begin
    pci_ad_in_prev[PCI_BUS_DATA_RANGE:0] <= pci_ad_in_comb[PCI_BUS_DATA_RANGE:0];
    pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0] <= pci_cbe_l_in_comb[PCI_BUS_CBE_RANGE:0];
    pci_frame_in_prev  <= pci_frame_in_critical;
    pci_irdy_in_prev   <= pci_irdy_in_critical;
    pci_devsel_in_prev <= pci_devsel_in_critical;
    pci_trdy_in_prev   <= pci_trdy_in_critical;
    pci_stop_in_prev   <= pci_stop_in_critical;
    pci_perr_in_prev   <= pci_perr_in_comb;
  end

// Initialize signals which are set for 1 clock by tasks to create activity
  initial
  begin
    pci_host_delayed_read_data_submit <= 1'b0;
    pci_host_delayed_read_type[2:0] <= 3'hX;
    pci_host_delayed_read_data[PCI_BUS_DATA_RANGE:0] <= `PCI_BUS_DATA_X;
    pci_frame_in_critical  <= 1'b0;
    pci_frame_in_prev      <= 1'b0;
    pci_irdy_in_critical   <= 1'b0;
    pci_irdy_in_prev       <= 1'b0;
    pci_devsel_in_critical <= 1'b0;
    pci_devsel_in_prev     <= 1'b0;
    pci_trdy_in_critical   <= 1'b0;
    pci_trdy_in_prev       <= 1'b0;
    pci_stop_in_critical   <= 1'b0;
    pci_stop_in_prev       <= 1'b0;
    pci_perr_in_prev       <= 1'b0;
  end

// Remove signals which are set for 1 clock by tasks to create activity
  always @(posedge pci_clk)
  begin
    pci_host_delayed_read_data_submit <= 1'b0;
    pci_host_delayed_read_type[2:0] <= 3'hX;
    pci_host_delayed_read_data[PCI_BUS_DATA_RANGE:0] <= `PCI_BUS_DATA_X;
    pci_frame_in_critical  <= 1'b0;
    pci_irdy_in_critical   <= 1'b0;
    pci_devsel_in_critical <= 1'b0;
    pci_trdy_in_critical   <= 1'b0;
    pci_stop_in_critical   <= 1'b0;
    pci_perr_in_prev       <= 1'b0;
  end

// `define BEGINNING_OPS
// `define NORMAL_OPS
// `define RETRY_OPS
// `define TIMEOUT_OPS
// `define ERROR_OPS

  initial
  begin
    host_reset_comb <= 1'b1;  // clobber reset right at the beginning
    $display ("Setting PCI bus to nominal, at time %t", $time);
    do_reset;
    set_pci_idle;
    set_ext_addr (32'hAA012345);
    set_ext_data (32'hDD06789A);
      do_clocks (4'h2);

`ifdef BEGINNING_OPS

    $display ("Doing Read Reg, at time %t", $time);
    do_target_test (8'h10,
         REG_READ, noop,
         8'h00, noop, 8'h00, noop, 8'h00, noop,
         8'h00, noop, 8'h00, noop, 8'h00, noop,
         8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
         8'h09, DEV_TRANSFER_DATA, 8'h00, noop, 8'h00, noop, 8'h00, noop,
         8'h00, noop, 8'h00, noop, 8'h00, noop);

    $display ("Doing Write Reg, at time %t", $time);
    do_target_test (8'h10,
         REG_WRITE, noop,  // First Reference
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Optional Data
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Second reference
         8'h09, DEV_TRANSFER_DATA, 8'h00, noop, 8'h00, noop, 8'h00, noop,  // Target
         8'h00, noop, 8'h00, noop, 8'h00, noop);

`endif  // BEGINNING_OPS

// Simple memory references, just exploring things like STOP and wait-states

// noop, REG_READ, REG_WRITE, FENCE, CONFIG_READ, CONFIG_WRITE
// MEM_READ, MEM_READ_SER, MEM_WRITE, MEM_WRITE_SERR
// DATA, DATA_PERR, DATA_LAST, DATA_LAST_PERR
// DEV, DEV_TRANSFER_DATA, DEV_RETRY_WITH_OLD_DATA, DEV_RETRY_WITH_NEW_DATA, TARGET_ABORT

`ifdef NORMAL_OPS

    $display ("Doing Memory refs, 1 word, no Wait States, at time %t", $time);
    do_test_target_read_write_pair (8'h0C,
         MEM_READ, DATA_LAST,  // First Reference
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Optional Data
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Second reference
         8'h07, DEV_TRANSFER_DATA, 8'h00, noop, 8'h00, noop, 8'h00, noop,  // Target
         8'h00, noop, 8'h00, noop, 8'h00, noop);

    $display ("Doing Memory refs, 1 word, no Wait States, STOP, at time %t", $time);
    do_test_target_read_write_pair (8'h0C,
         MEM_READ, DATA_LAST,  // First Reference
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Optional Data
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Second reference
         8'h07, DEV_RETRY_WITH_NEW_DATA, 8'h00, noop, 8'h00, noop, 8'h00, noop,  // Target
         8'h00, noop, 8'h00, noop, 8'h00, noop);

    $display ("Doing Memory refs, 2 words, no Wait States, at time %t", $time);
    do_test_target_read_write_pair (8'h0C,
         MEM_READ, DATA,  // First Reference
         8'h02, DATA_LAST, 8'h00, noop, 8'h00, noop,  // Optional Data
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Second reference
         8'h07, DEV_TRANSFER_DATA, 8'h08, DEV_TRANSFER_DATA, 8'h00, noop, 8'h00, noop,  // Target
         8'h00, noop, 8'h00, noop, 8'h00, noop);

    $display ("Doing Memory refs, 2 words, no Wait States, STOP, at time %t", $time);
    do_test_target_read_write_pair (8'h0C,
         MEM_READ, DATA,  // First Reference
         8'h02, DATA_LAST, 8'h00, noop, 8'h00, noop,  // Optional Data
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Second reference
         8'h07, DEV_TRANSFER_DATA, 8'h08, DEV_RETRY_WITH_NEW_DATA, 8'h00, noop, 8'h00, noop,  // Target
         8'h00, noop, 8'h00, noop, 8'h00, noop);

    $display ("Doing Memory refs, 2 words, 1 Target Wait States, at time %t", $time);
    do_test_target_read_write_pair (8'h0C,
         MEM_READ, DATA,  // First Reference
         8'h02, DATA_LAST, 8'h00, noop, 8'h00, noop,  // Optional Data
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Second reference
         8'h08, DEV_TRANSFER_DATA, 8'h09, DEV_TRANSFER_DATA, 8'h00, noop, 8'h00, noop,  // Target
         8'h00, noop, 8'h00, noop, 8'h00, noop);

    $display ("Doing Memory refs, 3 words, no Wait States, at time %t", $time);  // 43
    do_test_target_read_write_pair (8'h10,
         MEM_READ, DATA,  // First Reference
         8'h02, DATA, 8'h03, DATA_LAST, 8'h00, noop,  // Optional Data
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Second reference
         8'h07, DEV_TRANSFER_DATA, 8'h09, DEV_TRANSFER_DATA, 8'h0A, DEV_TRANSFER_DATA, 8'h00, noop,  // Target
         8'h00, noop, 8'h00, noop, 8'h00, noop);

    $display ("Doing Memory refs, 3 words, no Wait States, STOP, at time %t", $time);
    do_test_target_read_write_pair (8'h10,
         MEM_READ, DATA,  // First Reference
         8'h02, DATA, 8'h03, DATA_LAST, 8'h00, noop,  // Optional Data
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Second reference
         8'h07, DEV_TRANSFER_DATA, 8'h08, DEV_TRANSFER_DATA, 8'h09, DEV_RETRY_WITH_NEW_DATA, 8'h00, noop,  // Target
         8'h00, noop, 8'h00, noop, 8'h00, noop);

    $display ("Doing Memory refs, 3 words, Master Wait States, at time %t", $time);  // 29?
    do_test_target_read_write_pair (8'h18,
         MEM_READ, DATA,  // First Reference
         8'h03, DATA, 8'h07, DATA_LAST, 8'h00, noop,  // Optional Data
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Second reference
         8'h08, DEV_TRANSFER_DATA, 8'h0B, DEV_TRANSFER_DATA, 8'h0C, DEV_TRANSFER_DATA, 8'h00, noop,  // Target
         8'h00, noop, 8'h00, noop, 8'h00, noop);

    $display ("Doing Memory refs, 3 words, no Wait States, Early STOP, at time %t", $time);
    do_test_target_read_write_pair (8'h18,
         MEM_READ, DATA,  // First Reference
         8'h02, DATA, 8'h03, DATA_LAST, 8'h00, noop,  // Optional Data
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Second reference
         8'h07, DEV_RETRY_WITH_NEW_DATA, 8'h0E, DEV_TRANSFER_DATA, 8'h0F, DEV_RETRY_WITH_NEW_DATA, 8'h00, noop,  // Target
         8'h00, noop, 8'h00, noop, 8'h00, noop);

    $display ("Doing Memory refs, 3 words, no Wait States, Early STOP, at time %t", $time);
    do_test_target_read_write_pair (8'h18,
         MEM_READ, DATA,  // First Reference
         8'h02, DATA, 8'h03, DATA_LAST, 8'h00, noop,  // Optional Data
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Second reference
         8'h07, DEV_TRANSFER_DATA, 8'h08, DEV_RETRY_WITH_NEW_DATA, 8'h10, DEV_RETRY_WITH_NEW_DATA, 8'h00, noop,  // Target
         8'h00, noop, 8'h00, noop, 8'h00, noop);

    $display ("Doing Memory refs, 3 words, no Wait States, Early STOP, at time %t", $time);
    do_test_target_read_write_pair (8'h20,
         MEM_READ, DATA,  // First Reference
         8'h02, DATA, 8'h08, DATA_LAST, 8'h00, noop,  // Optional Data
         8'h00, noop, 8'h00, noop, 8'h00, noop,  // Second reference
         8'h07, DEV_TRANSFER_DATA, 8'h09, DEV_RETRY_WITH_NEW_DATA, 8'h0A, DEV_RETRY_WITH_NEW_DATA, 8'h17, DEV_RETRY_WITH_NEW_DATA,  // Target
         8'h00, noop, 8'h00, noop, 8'h00, noop);

`endif  // NORMAL_OPS

    pci_blue_target.report_missing_transitions;

    do_reset;
      do_clocks (4'h4);
    $finish;
  end
 
// Instantiate the Host_Response_FIFO, from the PCI Interface to the Host
pci_fifo_storage_response pci_fifo_storage_response (
  .reset_flags_async          (host_reset_to_PCI_interface),
// Mode 2`b10 means write together, read flag, then read data
  .fifo_mode                  (2'b10),
  .write_clk                  (pci_clk),
  .write_sync_clk             (pci_sync_clk),
  .write_submit               (pci_response_fifo_data_load),
// NOTE Needs extra settling time to avoid metastability
  .write_room_available_meta  (pci_response_fifo_room_available_meta),
// NOTE Needs extra settling time to avoid metastability
  .write_two_words_available_meta  (pci_response_fifo_two_words_available_meta),
  .write_data                 ({pci_response_fifo_type[3:0],
                                pci_response_fifo_cbe[PCI_BUS_CBE_RANGE:0],
                                pci_response_fifo_data[PCI_BUS_DATA_RANGE:0]}),
  .write_error                (pci_response_fifo_error),
  .read_clk                   (host_clk),
  .read_sync_clk              (host_sync_clk),
  .read_remove                (pci_host_response_unload),
// NOTE Needs extra settling time to avoid metastability
  .read_data_available_meta   (pci_host_response_data_available_meta),
// NOTE Needs extra settling time to avoid metastability
  .read_two_words_available_meta (),  // NOTE: WORKING
  .read_data                  ({pci_host_response_type[3:0],
                                pci_host_response_cbe[PCI_BUS_CBE_RANGE:0],
                                pci_host_response_data[PCI_BUS_DATA_RANGE:0]}),
  .read_error                 (pci_host_response_error)
);

// Instantiate the Host_Delayed_Read_Data_FIFO, from the Host to the PCI Interface
pci_fifo_storage_delayed_read pci_fifo_storage_delayed_read (
  .reset_flags_async          (host_reset_to_PCI_interface),
// Mode 2`b01 means write data, then update flag, read together
  .fifo_mode                  (2'b01),
  .write_clk                  (host_clk),
  .write_sync_clk             (host_sync_clk),
  .write_submit               (pci_host_delayed_read_data_submit),
// NOTE Needs extra settling time to avoid metastability
  .write_room_available_meta  (pci_host_delayed_read_room_available_meta),
  .write_data                 ({pci_host_delayed_read_type[2:0],
                                pci_host_delayed_read_data[PCI_BUS_DATA_RANGE:0]}), 
  .write_error                (pci_host_delayed_read_data_error),
  .read_clk                   (pci_clk),
  .read_sync_clk              (pci_sync_clk),
  .read_remove                (pci_delayed_read_fifo_data_unload),
// NOTE Needs extra settling time to avoid metastability
  .read_data_available_meta   (pci_delayed_read_fifo_data_available_meta),
// NOTE Needs extra settling time to avoid metastability
  .read_two_words_available_meta (),  // NOTE: WORKING
  .read_data                  ({pci_delayed_read_fifo_type[2:0],
                                pci_delayed_read_fifo_data[PCI_BUS_DATA_RANGE:0]}), 
  .read_error                 (pci_delayed_read_fifo_error)
);

  wire    pci_devsel_out_next, pci_trdy_out_next, pci_stop_out_next;
  wire    pci_d_t_s_out_oe_comb;

`ifdef TARGET_INCLUDED
// Instantiate the Target Interface
pci_blue_target pci_blue_target (
// Signals driven to control the external PCI interface
  .pci_ad_in_prev             (pci_ad_in_prev[PCI_BUS_DATA_RANGE:0]),
  .pci_target_ad_out_next     (pci_target_ad_out_next[PCI_BUS_DATA_RANGE:0]),
  .pci_target_ad_en_next      (pci_target_ad_en_next),
  .pci_target_ad_out_oe_comb  (pci_target_ad_out_oe_comb),
  .pci_idsel_in_prev          (pci_idsel_in_prev),
  .pci_cbe_l_in_prev          (pci_cbe_l_in_prev[PCI_BUS_CBE_RANGE:0]),
  .pci_par_in_critical        (pci_par_in_critical),
  .pci_par_in_prev            (pci_par_in_prev),
  .pci_target_par_out_next    (pci_target_par_out_next),
  .pci_target_par_out_oe_comb (pci_target_par_out_oe_comb),
  .pci_frame_in_critical      (pci_frame_in_critical),
  .pci_frame_in_prev          (pci_frame_in_prev),
  .pci_irdy_in_critical       (pci_irdy_in_critical),
  .pci_irdy_in_prev           (pci_irdy_in_prev),
  .pci_devsel_out_next        (pci_devsel_out_next),
  .pci_trdy_out_next          (pci_trdy_out_next),
  .pci_stop_out_next          (pci_stop_out_next),
  .pci_d_t_s_out_oe_comb      (pci_d_t_s_out_oe_comb),
  .pci_perr_in_prev           (pci_perr_in_prev),
  .pci_target_perr_out_next   (pci_target_perr_out_next),
  .pci_target_perr_out_oe_comb (pci_target_perr_out_oe_comb),
  .pci_serr_in_prev           (pci_serr_in_prev),
  .pci_target_serr_out_oe_comb (pci_target_serr_out_oe_comb),
// Signals to control shared AD bus, Parity, and SERR signals
  .Target_Force_AD_to_Data    (Target_Force_AD_to_Data),
  .Target_Exposes_Data_On_IRDY (Target_Exposes_Data_On_IRDY),
  .Target_Forces_PERR         (Target_Forces_PERR),
// Signal from Master to say that DMA data should be captured into Response FIFO
  .Master_Captures_Data_On_TRDY (Master_Captures_Data_On_TRDY),
// Host Interface Response FIFO used to ask the Host Interface to service
//   PCI References initiated by an external PCI Master.
// This FIFO also sends status info back from the master about PCI
//   References this interface acts as the PCI Master for.
  .pci_response_fifo_type     (pci_response_fifo_type[3:0]),
  .pci_response_fifo_cbe      (pci_response_fifo_cbe[PCI_BUS_CBE_RANGE:0]),
  .pci_response_fifo_data     (pci_response_fifo_data[PCI_BUS_DATA_RANGE:0]),
  .pci_response_fifo_room_available_meta (pci_response_fifo_room_available_meta),
  .pci_response_fifo_two_words_available_meta (pci_response_fifo_two_words_available_meta),
  .pci_response_fifo_data_load (pci_response_fifo_data_load),
  .pci_response_fifo_error    (pci_response_fifo_error),
// Host Interface Delayed Read Data FIFO used to pass the results of a
//   Delayed Read on to the external PCI Master which started it.
  .pci_delayed_read_fifo_type (pci_delayed_read_fifo_type[2:0]),
  .pci_delayed_read_fifo_data (pci_delayed_read_fifo_data[PCI_BUS_DATA_RANGE:0]),
  .pci_delayed_read_fifo_data_available_meta (pci_delayed_read_fifo_data_available_meta),
  .pci_delayed_read_fifo_data_unload (pci_delayed_read_fifo_data_unload),
  .pci_delayed_read_fifo_error (pci_delayed_read_fifo_error),
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  .master_to_target_status_type   (master_to_target_status_type[2:0]),
  .master_to_target_status_cbe    (master_to_target_status_cbe[PCI_BUS_CBE_RANGE:0]),
  .master_to_target_status_data   (master_to_target_status_data[PCI_BUS_DATA_RANGE:0]),
  .master_to_target_status_flush  (master_to_target_status_flush),
  .master_to_target_status_available (master_to_target_status_available),
  .master_to_target_status_two_words_free (master_to_target_status_two_words_free),
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
// Courtesy indication that PCI Interface Config Register contains an error indication
  .target_config_reg_signals_some_error (target_config_reg_signals_some_error),
  .pci_clk                    (pci_clk),
  .pci_reset_comb             (host_reset_comb)
);
`endif  // TARGET_INCLUDED

// Convert seperate signals and OE controls into composite signal
  reg    [PCI_BUS_DATA_RANGE:0] ad_reg;
  reg     devsel_reg, trdy_reg, stop_reg;

  always @(posedge pci_clk or posedge host_reset_comb)
  begin
    if (host_reset_comb == 1'b1)
    begin
      ad_reg[PCI_BUS_DATA_RANGE:0] <= 32'hX;
      devsel_reg <= 1'bX;
      trdy_reg <= 1'bX;
      stop_reg <= 1'bX;
    end
    else
    begin
      ad_reg[PCI_BUS_DATA_RANGE:0] <= (   Target_Force_AD_to_Address_Data_Critical
                                    | (Target_Exposes_Data_On_IRDY & pci_irdy_in_critical) )
                    ? pci_target_ad_out_next[PCI_BUS_DATA_RANGE:0]
                    : ad_reg[PCI_BUS_DATA_RANGE:0];
      devsel_reg <= pci_devsel_out_next;
      trdy_reg   <= pci_trdy_out_next;
      stop_reg   <= pci_stop_out_next;
    end
  end

  assign pci_target_ad_bus[PCI_BUS_DATA_RANGE:0] = pci_target_ad_out_oe_comb
                                      ? ad_reg[PCI_BUS_DATA_RANGE:0]
                                      : 32'hZ;
  assign pci_devsel_bus = pci_d_t_s_out_oe_comb ? ~devsel_reg : 1'bZ;
  assign pci_trdy_bus =   pci_d_t_s_out_oe_comb ? ~trdy_reg   : 1'bZ;
  assign pci_stop_bus =   pci_d_t_s_out_oe_comb ? ~stop_reg   : 1'bZ;
endmodule

