//===========================================================================
// $Id: pci_example_host_controller.v,v 1.5 2001-03-05 09:54:56 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  An example Host Controller.  This example code shows the correct
//           interaction with the pci_blue_interface.  The pci_blue_interface
//           does individual reads and writes when in target mode, and accepts
//           bursts when being used as a master by the host.
//           A real host controller will look quite similar!
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
// NOTE TODO: Horrible.  Tasks can't depend on their Arguments being safe
//        if there are several instances ofthe task running at once.
//
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/1ps

module pci_example_host_controller (
// Coordinate Write_Fence with CPU
  pci_target_requests_write_fence, host_allows_write_fence,
// Host uses these wires to request PCI activity.
  pci_master_ref_address, pci_master_ref_command, pci_master_ref_config,
  pci_master_byte_enables_l, pci_master_write_data, pci_master_read_data,
  pci_master_addr_valid, pci_master_data_valid,
  pci_master_requests_serr, pci_master_requests_perr, pci_master_requests_last,
  pci_master_data_consumed, pci_master_ref_error,
// PCI Interface uses these wires to request local memory activity.   
  pci_target_ref_address, pci_target_ref_command,
  pci_target_byte_enables_l, pci_target_write_data, pci_target_read_data,
  pci_target_busy, pci_target_ref_start,
  pci_target_requests_abort, pci_target_requests_perr,
  pci_target_requests_disconnect,
  pci_target_data_transferred,
// PCI_Error_Report.
  pci_interface_reports_errors, pci_config_reg_reports_errors,
// Generic host interface wires
  pci_host_sees_pci_reset,
  host_reset, host_clk,
// Signals used by the test bench instead of using "." notation
// NOTE WORKING shouldn't this get commands based on the Host Clock?
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
// Coordinate Write_Fence with CPU
  input   pci_target_requests_write_fence;
  output  host_allows_write_fence;
// Host uses these wires to request PCI activity.
  output [31:0] pci_master_ref_address;
  output [3:0] pci_master_ref_command;
  output  pci_master_ref_config;
  output [3:0] pci_master_byte_enables_l;
  output [31:0] pci_master_write_data;
  input  [31:0] pci_master_read_data;
  output  pci_master_addr_valid, pci_master_data_valid;
  output  pci_master_requests_serr, pci_master_requests_perr;
  output  pci_master_requests_last;
  input   pci_master_data_consumed;
  input   pci_master_ref_error;
// PCI Interface uses these wires to request local memory activity.   
  input  [31:0] pci_target_ref_address;
  input  [3:0] pci_target_ref_command;
  input  [3:0] pci_target_byte_enables_l;
  input  [31:0] pci_target_write_data;
  output [31:0] pci_target_read_data;
  output  pci_target_busy;
  input   pci_target_ref_start;
  output  pci_target_requests_abort, pci_target_requests_perr;
  output  pci_target_requests_disconnect;
  output  pci_target_data_transferred;
// PCI_Error_Report.
  input  [9:0] pci_interface_reports_errors;
  input   pci_config_reg_reports_errors;
// Generic host interface wires
  output  pci_host_sees_pci_reset;
  input   host_reset;
  input   host_clk;
// Signals used by the test bench instead of using "." notation
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

// Let test commander know when this PCI Master has accepted the command.
  reg     host_command_started;
  assign  test_accepted_l = host_command_started ? 1'b0 : 1'bZ;

// Make temporary Bip every time an error is detected
  reg     test_error_event;
  initial test_error_event <= 1'bZ;
  reg     error_detected;
  initial error_detected <= 1'b0;
  always @(error_detected)
  begin
    test_error_event <= 1'b0;
    #2;
    test_error_event <= 1'bZ;
  end

// This Host Adaptor acts like the Behaviorial PCI modules.  It receives commands
//   from a top-level testbench, and issues the commands to the PCI Interface.
// The Commands specify details about how the device should behave, for instance
//   whether to make an address with a parity error, and they also specify the
//   expected behavior of the Target.
//
// This Host Adaptor does one thing which the Behaviorial PCI Models can't do.
//   The Host Adaptor can read and write it's own Config Registers.  This Host
//   Adaptor issues a read or write to local Config Registers when the top-level
//   testbench issues a command with the top 8 bits of address are 8'hCC.

// Signals used by Master test code to apply correct info to the PCI bus
  reg    [31:0] hold_master_address;
  reg    [3:0] hold_master_command;
  reg    [31:0] hold_master_data;
  reg    [3:0] hold_master_byte_enables_l;
  reg    [3:0] hold_master_size;
  reg     hold_master_addr_par_err, hold_master_data_par_err;
  reg    [3:0] hold_master_initial_waitstates;
  reg    [3:0] hold_master_subsequent_waitstates;
  reg    [3:0] hold_master_target_initial_waitstates;
  reg    [3:0] hold_master_target_subsequent_waitstates;
  reg    [1:0] hold_master_target_devsel_speed;
  reg     hold_master_fast_b2b;
  reg    [2:0] hold_master_target_termination;
  reg     hold_master_expect_master_abort;
  reg    [31:0] modified_master_address;

// This models a CPU or other Master device.
// Capture Host Command from top-level Test Commander.
task Clear_Example_Host_Command;
  begin
    hold_master_address[31:0] <= `BUS_IMPOSSIBLE_VALUE;
    hold_master_command[3:0] <= `PCI_COMMAND_RESERVED_4;
    hold_master_data[31:0] <= `BUS_IMPOSSIBLE_VALUE;
    hold_master_byte_enables_l[3:0] <= 4'hF;
    hold_master_addr_par_err <= 1'b0;
    hold_master_data_par_err <= 1'b0;
    hold_master_initial_waitstates[3:0] <= 4'h0;
    hold_master_subsequent_waitstates[3:0] <= 4'h0;
    hold_master_target_initial_waitstates[3:0] <= 4'h0;
    hold_master_target_subsequent_waitstates[3:0] <= 4'h0;
    hold_master_target_devsel_speed[1:0] <= 2'h0;
    hold_master_fast_b2b <= 1'b0;
    hold_master_expect_master_abort <= 1'b0;
    hold_master_size[3:0] <= 4'h0;
    hold_master_target_termination[2:0] <= 3'h0;
    modified_master_address[31:0] <= 32'h00000000;
  end
endtask

// Update the captured Data during a Burst.  For Test Only.
// A real Host Interface might not have this.  It might offer size plus all data at once.
  wire    Update_Captured_Host_Data;

// Display on negative edge so easy to see in the waveform.  Don't do so in real hardware!
  reg     host_command_finished;
  always @(negedge host_clk)
  begin
    if (host_reset)
    begin
      host_command_started <= 1'b0;
      Clear_Example_Host_Command;
    end
    else
    begin
      if (test_start & (test_master_number[2:0] == test_device_id[2:0])
           & ~host_command_started)  // grab
      begin
`ifdef VERBOSE_TEST_DEVICE
        $display (" Example Host Controller %h - Task Started, at %t",
                    test_device_id[2:0], $time);
`endif // VERBOSE_TEST_DEVICE
        host_command_started <= 1'b1;
// Grab address and data in case it takes a while to get bus mastership
        hold_master_address[31:0] <= test_address[31:0];
        hold_master_command[3:0] <= test_command[3:0];
        hold_master_data[31:0] <= test_data[31:0];
        hold_master_byte_enables_l[3:0] <= test_byte_enables_l[3:0];
        hold_master_addr_par_err <= test_make_addr_par_error;
        hold_master_data_par_err <= test_make_data_par_error;
        hold_master_initial_waitstates[3:0] <= test_master_initial_wait_states[3:0];
        hold_master_subsequent_waitstates[3:0] <=
                                      test_master_subsequent_wait_states[3:0];
        hold_master_target_initial_waitstates[3:0] <=
                                      test_target_initial_wait_states[3:0];
        hold_master_target_subsequent_waitstates[3:0] <=
                                      test_target_subsequent_wait_states[3:0];
        hold_master_target_devsel_speed[1:0] <= test_target_devsel_speed[1:0];
        hold_master_fast_b2b <= test_fast_back_to_back;
        hold_master_expect_master_abort <= test_expect_master_abort;
        if (test_size[3:0] == 4'h0)  // This means read causing delayed read
        begin
          hold_master_size[3:0] <= 4'h1;
          hold_master_target_termination[2:0] <= `Test_Target_Retry_Before_First;
        end
        else
        begin
          hold_master_size[3:0] <= test_size[3:0];
          hold_master_target_termination[2:0] <= test_target_termination[2:0];
        end
        modified_master_address[31:24] <= test_address[31:24];
        modified_master_address[`TARGET_ENCODED_PARAMATERS_ENABLE] <= 1'b1;
        modified_master_address[`TARGET_ENCODED_INIT_WAITSTATES] <=
                                          test_target_initial_wait_states[3:0];
        modified_master_address[`TARGET_ENCODED_SUBS_WAITSTATES] <=
                                          test_target_subsequent_wait_states[3:0];
        modified_master_address[`TARGET_ENCODED_TERMINATION]  <=
                                          test_target_termination[2:0];
        modified_master_address[`TARGET_ENCODED_DEVSEL_SPEED] <=
                                          test_target_devsel_speed[1:0];
        modified_master_address[`TARGET_ENCODED_DATA_PAR_ERR] <=
                                          test_make_data_par_error;
        modified_master_address[`TARGET_ENCODED_ADDR_PAR_ERR] <=
                                          test_make_addr_par_error;
        modified_master_address[7:0] <= test_address[7:0];
      end
      else if (host_command_started & ~host_command_finished)  // hold
      begin
        host_command_started <= host_command_started;
        hold_master_address[31:0] <= hold_master_address[31:0];
        hold_master_command[3:0] <= hold_master_command[3:0];
        hold_master_data[31:0] <= Update_Captured_Host_Data
               ? (hold_master_data[31:0] + 32'h01010101) : hold_master_data[31:0];
// NOTE:  A real Master might change byte enables throughout a Burst.
        hold_master_byte_enables_l[3:0] <= Update_Captured_Host_Data
               ? hold_master_byte_enables_l[3:0] : hold_master_byte_enables_l[3:0];
        hold_master_addr_par_err <= hold_master_addr_par_err;
        hold_master_data_par_err <= hold_master_data_par_err;
        hold_master_initial_waitstates[3:0] <= hold_master_initial_waitstates[3:0];
        hold_master_subsequent_waitstates[3:0] <=
                                    hold_master_subsequent_waitstates[3:0];
        hold_master_target_initial_waitstates[3:0] <=
                                    hold_master_target_initial_waitstates[3:0];
        hold_master_target_subsequent_waitstates[3:0] <=
                                    hold_master_target_subsequent_waitstates[3:0];
        hold_master_target_devsel_speed[1:0] <= hold_master_target_devsel_speed[1:0];
        hold_master_fast_b2b <= hold_master_fast_b2b;
        hold_master_expect_master_abort <= hold_master_expect_master_abort;
        hold_master_size[3:0] <= hold_master_size[3:0];
        hold_master_target_termination[2:0] <= hold_master_target_termination[2:0];
        modified_master_address[31:0] <= modified_master_address[31:0];
      end
      else if (host_command_started & host_command_finished)  // drop
      begin
`ifdef VERBOSE_TEST_DEVICE
        $display (" Example Host Controller %h - Task Done, at %t",
                     test_device_id[2:0], $time);
`endif // VERBOSE_TEST_DEVICE
        host_command_started <= 1'b0;
        Clear_Example_Host_Command;
      end
      else  // do nothing
      begin
        host_command_started <= 1'b0;
        Clear_Example_Host_Command;
      end
    end
  end

// Host Interface Status Register.  This Host Adaptor makes an Interface Status
//   Register which is read whenever the MSB of the Read Address is 0xDD and the LSB
//   of the Read Address is 0xFC.  The register is cleared whenever it is written to.
  reg    [9:0] Host_Interface_Status_Register;
  reg     Reset_Host_Status_Register;
  reg    [9:0] PCI_Interface_Reporting_Errors;

  always @(posedge host_clk)
  begin
    if (host_reset)
    begin
      Host_Interface_Status_Register[9:0] <= 10'h000;
    end
    else
    begin
      Host_Interface_Status_Register[9:0] <= ~Reset_Host_Status_Register
                  & (   Host_Interface_Status_Register[9:0]
                      | PCI_Interface_Reporting_Errors[9:0]);
// contains:    {PERR_Detected,          SERR_Detected,
//               Master_Abort_Received,  Target_Abort_Received,
//               Caused_Target_Abort,    Caused_PERR,
//               Discarded_Delayed_Read, Target_Retry_Or_Disconnect,
//               Illegal_Command_Detected_In_Request_FIFO,
//               Illegal_Command_Detected_In_Response_FIFO}
    end
  end

// Print out various Interface Error reports.  Some of these printouts should
//   go away when the testing code above starts checking for intentional errors.
  always @(posedge host_clk)
  begin
    if (PCI_Interface_Reporting_Errors[9])
    begin
      $display ("*** Example Host Controller %h - PERR_Detected, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (PCI_Interface_Reporting_Errors[8])
    begin
      $display ("*** Example Host Controller %h - SERR_Detected, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (PCI_Interface_Reporting_Errors[7])
    begin
      $display ("*** Example Host Controller %h - Master_Abort_Received, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (PCI_Interface_Reporting_Errors[6])
    begin
      $display ("*** Example Host Controller %h - Target_Abort_Received, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (PCI_Interface_Reporting_Errors[5])
    begin
      $display ("*** Example Host Controller %h - Caused_Target_Abort, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (PCI_Interface_Reporting_Errors[4])
    begin
      $display ("*** Example Host Controller %h - Caused_PERR, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (PCI_Interface_Reporting_Errors[3])
    begin
      $display ("*** Example Host Controller %h - Discarded_Delayed_Read, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (PCI_Interface_Reporting_Errors[2])
    begin
      $display ("*** Example Host Controller %h - Target_Retry_Or_Disconnect, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (PCI_Interface_Reporting_Errors[1])
    begin
      $display ("*** Example Host Controller %h - Illegal_Command_Detected_In_Request_FIFO, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (PCI_Interface_Reporting_Errors[0])
    begin
      $display ("*** Example Host Controller %h - Illegal_Command_Detected_In_Response_FIFO, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
  end

// To make this Example Host Interface interesting as a Target, it includes a
//   small Memory.  The Memory can be read and written by the external PCI Masters.
//   Any reference with the high address byte being 8'hDD addresses the SRAM.

// These variables come from a ficticious processor or DMA device
  wire    Host_Mem_Read_Request, Host_Mem_Write_Request;
  wire   [7:2] Host_Mem_Address = modified_master_address[7:2];
  wire   [31:0] Host_Mem_Write_Data = hold_master_data[31:0];
  wire   [3:0] Host_Mem_Write_Byte_Enables_l = hold_master_byte_enables_l[3:0];

// These following variables come from the PCI Delayed Read State Machine below.
  wire    PCI_Bus_Mem_Read_Request, PCI_Bus_Mem_Write_Request;
  wire   [7:2] PCI_Bus_Mem_Address;
  wire   [31:0] PCI_Bus_Mem_Write_Data;
  wire   [3:0] PCI_Bus_Mem_Write_Byte_Enables_l;
  reg     PCI_Bus_Mem_Grant;

  wire   [31:0] mem_write_data = Host_Mem_Write_Request
                         ? Host_Mem_Write_Data[31:0] : PCI_Bus_Mem_Write_Data[31:0];
  wire   [7:2] mem_address = (Host_Mem_Read_Request | Host_Mem_Write_Request)
                         ? Host_Mem_Address[7:2] : PCI_Bus_Mem_Address[7:2];
  wire   [3:0] mem_write_byte_enables_l = Host_Mem_Write_Request
                         ? Host_Mem_Write_Byte_Enables_l[3:0]
                         : PCI_Bus_Mem_Write_Byte_Enables_l[3:0];
  wire    mem_read_enable = Host_Mem_Read_Request
                          | ( (~Host_Mem_Read_Request & ~Host_Mem_Write_Request)
                              & PCI_Bus_Mem_Read_Request);
  wire    mem_write_enable = Host_Mem_Write_Request
                          | ( (~Host_Mem_Read_Request & ~Host_Mem_Write_Request)
                              & PCI_Bus_Mem_Write_Request);
  reg    [31:0] mem_read_data;

// storage accessed only through the following always block
`ifdef VERILOGGER_BUG
  reg    [7:0] Example_Host_Mem_0 [0:63];  // address limits, not bits in address
  reg    [7:0] Example_Host_Mem_1 [0:63];  // address limits, not bits in address
  reg    [7:0] Example_Host_Mem_2 [0:63];  // address limits, not bits in address
  reg    [7:0] Example_Host_Mem_3 [0:63];  // address limits, not bits in address
`else  // VERILOGGER_BUG
  reg    [7:0] Example_Host_Mem_0;  // used until synapticad fixes their mem bug.
  reg    [7:0] Example_Host_Mem_1;  // used until synapticad fixes their mem bug.
  reg    [7:0] Example_Host_Mem_2;  // used until synapticad fixes their mem bug.
  reg    [7:0] Example_Host_Mem_3;  // used until synapticad fixes their mem bug.
`endif  // VERILOGGER_BUG

  always @(posedge host_clk)
  begin
`ifdef VERILOGGER_BUG
    Example_Host_Mem_0[mem_address[7:2]] <=
              (mem_write_enable & ~mem_write_byte_enables_l[0])
             ? mem_write_data[ 7: 0] : Example_Host_Mem_0[mem_address[7:2]];
    Example_Host_Mem_1[mem_address[7:2]] <=
              (mem_write_enable & ~mem_write_byte_enables_l[1])
             ? mem_write_data[15: 8] : Example_Host_Mem_1[mem_address[7:2]];
    Example_Host_Mem_2[mem_address[7:2]] <=
              (mem_write_enable & ~mem_write_byte_enables_l[2])
             ? mem_write_data[23:16] : Example_Host_Mem_2[mem_address[7:2]];
    Example_Host_Mem_3[mem_address[7:2]] <=
              (mem_write_enable & ~mem_write_byte_enables_l[3])
             ? mem_write_data[31:24] : Example_Host_Mem_3[mem_address[7:2]];

    mem_read_data[31:0] <= mem_read_enable
             ? (  (mem_address[7:2] == 6'h3F)
                  ? {22'h000000, Host_Interface_Status_Register[9:0]}  // read status register
                  : {Example_Host_Mem_3[mem_address],
                     Example_Host_Mem_2[mem_address],
                     Example_Host_Mem_1[mem_address],
                     Example_Host_Mem_0[mem_address]})
             : 32'hXXXXXXXX;
`else  // VERILOGGER_BUG
    Example_Host_Mem_0[7:0] <=
              ((mem_write_enable & ~mem_write_byte_enables_l[0]) != 1'b0)
             ? mem_write_data[ 7: 0] : Example_Host_Mem_0[7:0];
    Example_Host_Mem_1[7:0] <=
              ((mem_write_enable & ~mem_write_byte_enables_l[1]) != 1'b0)
             ? mem_write_data[15: 8] : Example_Host_Mem_1[7:0];
    Example_Host_Mem_2[7:0] <=
              ((mem_write_enable & ~mem_write_byte_enables_l[2]) != 1'b0)
             ? mem_write_data[23:16] : Example_Host_Mem_2[7:0];
    Example_Host_Mem_3[7:0] <=
              ((mem_write_enable & ~mem_write_byte_enables_l[3]) != 1'b0)
             ? mem_write_data[31:24] : Example_Host_Mem_3[7:0];
    mem_read_data[31:0] <= mem_read_enable
             ? (  (mem_address[7:2] == 6'h3F)
                  ? {22'h000000, Host_Interface_Status_Register[9:0]}  // read status register
                  : {Example_Host_Mem_3[7:0], Example_Host_Mem_2[7:0],
                     Example_Host_Mem_1[7:0], Example_Host_Mem_0[7:0]})
             : 32'hXXXXXXXX;
`endif  // VERILOGGER_BUG

    Reset_Host_Status_Register <= mem_write_enable & (mem_address[7:2] == 6'h3F);
    PCI_Bus_Mem_Grant <= (~Host_Mem_Read_Request & ~Host_Mem_Write_Request)
                       & (PCI_Bus_Mem_Read_Request | PCI_Bus_Mem_Write_Request);  // Tell PCI interface that data is valid

`ifdef VERILOGGER_BUG
    if (mem_read_enable)
    begin
      if ({Example_Host_Mem_3[mem_address[7:2]],
           Example_Host_Mem_2[mem_address[7:2]],
           Example_Host_Mem_1[mem_address[7:2]],
           Example_Host_Mem_0[mem_address[7:2]]}
          !== hold_master_data[31:0])
      begin
        $display ("*** Example Host Controller %h - Local Memory Read Data invalid 'h%h, expected 'h%h, at %t",
                    test_device_id[2:0],
                    {Example_Host_Mem_3[mem_address[7:2]],
                     Example_Host_Mem_2[mem_address[7:2]],
                     Example_Host_Mem_1[mem_address[7:2]],
                     Example_Host_Mem_0[mem_address[7:2]]},
                     hold_master_data[31:0], $time);
        error_detected <= ~error_detected;
      end
    end
    `NO_ELSE;
`ifdef VERBOSE_TEST_DEVICE
    if (mem_read_enable)
    begin
      $display ("Example Host Controller %h - Local Memory read with Address %h, Data %h, at time %t",
                 test_device_id[2:0], {mem_address[7:2], 2'b00},
                 Example_Host_Mem_Zero[31:0], $time);
    end
    `NO_ELSE;
    if (mem_write_enable)
    begin
      $display ("Example Host Controller %h - Local Memory written with Address %h, Data %h, Strobes %h, at time %t",
                 test_device_id[2:0], {mem_address[7:2], 2'b00},
                 mem_write_data[31:0], mem_write_byte_enables_l[3:0], $time);
    end
    `NO_ELSE;
`endif  // VERBOSE_TEST_DEVICE
`else  // VERILOGGER_BUG
    if (mem_read_enable)
    begin
      if ({Example_Host_Mem_3[7:0], Example_Host_Mem_2[7:0],
           Example_Host_Mem_1[7:0], Example_Host_Mem_0[7:0]}
             !== hold_master_data[31:0])
      begin
        $display ("*** Example Host Controller %h - Local Memory Read Data invalid 'h%h, expected 'h%h, at %t",
                    test_device_id[2:0],
                    {Example_Host_Mem_3[7:0], Example_Host_Mem_2[7:0],
                     Example_Host_Mem_1[7:0], Example_Host_Mem_0[7:0]},
                     hold_master_data[31:0], $time);
        error_detected <= ~error_detected;
      end
    end
    `NO_ELSE;
`ifdef VERBOSE_TEST_DEVICE
    if (mem_read_enable)
    begin
      $display ("Example Host Controller %h - Local Memory read with Address %h, Data %h, at time %t",
                 test_device_id[2:0], {mem_address[7:2], 2'b00},
                 {Example_Host_Mem_3[7:0], Example_Host_Mem_2[7:0],
                  Example_Host_Mem_1[7:0], Example_Host_Mem_0[7:0]}, $time);
    end
    `NO_ELSE;
    if (mem_write_enable)
    begin
      $display ("Example Host Controller %h - Local Memory written with Address %h, Data %h, Strobes %h, at time %t",
                 test_device_id[2:0], {mem_address[7:2], 2'b00},
                 mem_write_data[31:0], mem_write_byte_enables_l[3:0], $time);
    end
    `NO_ELSE;
`endif  // VERILOGGER_BUG
  end

// At last, interact with the pci_blue_interface here.

// Write Fences are used so that Delayed Read data comes out after all posted
//   writes are complete, and before writes done after the read are committed.
// The protocol is this:
// Host_Target_State_Machine asserts target_requests_write_fence;
// Host Interface does as many writes as it wants.
//   The Delayed Read cannot complete during this period.
// Host Interface asserts host_allows_write_fence.
//   Host Interface holds off further writes while the Fence is in the pipe.
// Host_Master_State_Machine puts a Write Fence in the FIFO.
// Host_Master_State_Machine asserts master_issues_write_fence.
// Delayed Read state machine fetches and delivers data to external PCI Master.
// Host_Target_State_Machine deasserts target_requests_write_fence.
// Host Interface can start writing again.
// If the request for a Write Fence comes in when the Host Interface is
//   waiting for the results of a Read, the first thing done after the
//   Read completes is to allow the Write Fence.  No writes are allowed
//   to occur after a read during which a Write Fence was requested.

// Top-level write fence state machine.
  reg     host_allows_write_fence;

// This interface is simple.  Immediately allow Write Fence.
// In a real application, once host_allows_write_fence is asserted,
//   the PCI interface will stop serving Reads and Writes until
//   pci_target_requests_write_fence is deasserted.
  always @(posedge host_clk)
  begin
    if (host_reset)
    begin
      host_allows_write_fence <= 1'b0;
    end
    else
    begin  // Could be delayed longer in a real Host Interface which must flush FIFOs.
      host_allows_write_fence <= pci_target_requests_write_fence;
    end
  end

// Implement Master Reads and Writes here.  When the Host asks for data to be
//   transferred, and the PCI Interface is ready to accept a new command,
//   start sending in the Address and Data info.
// The Host or DMA Controller interface in this test setup asserts Address,
//   data, and the valid signal on the falling edge of the clock.
// It can be acted upon at the next rising edge of the clock.
// This interface wants to have the addrss written into the FIFO that next
//   clock, to start the PCI activity as soon as possible.
// This interface must update the write data during a write burst, so that
//   different data goes over the bus.  This update is achieved by using
//   a combinational MUX on the write data bus.

  wire    host_doing_write_now = (hold_master_command[3:0]
                               & `PCI_COMMAND_ANY_WRITE_MASK) != 4'h0;
  reg     host_working_on_pci_reference, host_doing_write;
  reg    [31:0] pci_master_updated_data;
  reg    [3:0] pci_master_updated_burst_size;

// When host_command_started is asserted, the following signals are valid:
//    modified_master_address[31:0], hold_master_command[3:0];
//    hold_master_data[31:0], hold_master_byte_enables_l[3:0];
//    hold_master_addr_par_err, hold_master_data_par_err;
//    hold_master_size[3:0];
//    hold_master_expect_master_abort, hold_master_target_termination[2:0];
// Once the Host is told to continue, these might change again.
// NOTE that Config Writes (writes with modified_master_address[31:24] == 8'hCC)
//   can be marked finished immediately, by a combinational path.

  always @(posedge host_clk)
  begin
    if (host_reset)
    begin
      host_command_finished <= 1'b0;
      host_working_on_pci_reference <= 1'b0;  // pci interface stuff
      host_doing_write <= host_doing_write;  // don't care
      pci_master_updated_data[31:0] <= hold_master_data[31:0];  // don't care
      pci_master_updated_burst_size[3:0] <= pci_master_updated_burst_size[3:0];  // don't care
    end
    else if (host_command_started & ~host_command_finished  // second term prevents accidental back-to-back references
              & (modified_master_address[31:24] == 8'hDD))  // access local SRAM
    begin  // Issue local Memory Reference
      host_command_finished <= 1'b1;  // assume Host SRAM Ref always finishes immediately
      host_working_on_pci_reference <= 1'b0;
      host_doing_write <= host_doing_write;  // don't care
      pci_master_updated_data[31:0] <= pci_master_updated_data[31:0];  // don't care
      pci_master_updated_burst_size[3:0] <= pci_master_updated_burst_size[3:0];  // don't care
    end
    else if (host_command_started & ~host_working_on_pci_reference  // second term prevents accidental back-to-back references
              & (modified_master_address[31:24] != 8'hDD)
              & pci_master_data_consumed)
    begin  // must be an instantaneous Config Write ack
      host_command_finished <= 1'b1;
      host_working_on_pci_reference <= 1'b0;
      host_doing_write <= host_doing_write_now;  // grab to allow writes to be dismissed early
      pci_master_updated_data[31:0] <= hold_master_data[31:0];
      pci_master_updated_burst_size[3:0] <= hold_master_size[3:0];
    end

    else if (host_command_started & ~host_working_on_pci_reference  // second term prevents accidental back-to-back references
              & (modified_master_address[31:24] != 8'hDD)
              & pci_master_data_consumed)
    begin  // a delayed Config Write, or any normal read or write
      host_command_finished <= 1'b0;
      host_working_on_pci_reference <= 1'b1;
      host_doing_write <= host_doing_write_now;  // grab to allow writes to be dismissed early
      pci_master_updated_data[31:0] <= hold_master_data[31:0];
      pci_master_updated_burst_size[3:0] <= hold_master_size[3:0];
    end
    else if (host_working_on_pci_reference)  // only get here for PCI references.
    begin
      if (pci_master_ref_error)
      begin
        host_command_finished <= 1'b1;
        host_working_on_pci_reference <= 1'b0;
        host_doing_write <= host_doing_write;
        pci_master_updated_data[31:0] <= pci_master_updated_data[31:0];
        pci_master_updated_burst_size[3:0] <= pci_master_updated_burst_size[3:0];
        if (~hold_master_expect_master_abort)
        begin
          $display ("*** Example Host Controller %h - Got Master Abort when not expected, at %t",
                      test_device_id[2:0], $time);
          error_detected <= ~error_detected;
        end
      end
      else if (pci_master_data_consumed)
      begin
        if (pci_master_updated_burst_size[3:0] <= 1'b1)
        begin
          host_command_finished <= 1'b1;
          host_working_on_pci_reference <= 1'b0;
          if (hold_master_expect_master_abort)
          begin
            $display ("*** Example Host Controller %h - Didn't get Master Abort when expected, at %t",
                        test_device_id[2:0], $time);
            error_detected <= ~error_detected;
          end
        end
        else
        begin
          host_command_finished <= 1'b0;
          host_working_on_pci_reference <= 1'b1;
          if (pci_master_read_data[31:0] !== pci_master_updated_data[31:0])
          begin
            $display ("*** Example Host Controller %h - Read Data %h not expected %h, at %t",
                        test_device_id[2:0], pci_master_read_data[31:0],
                        pci_master_updated_data[31:0], $time);
            error_detected <= ~error_detected;
          end
        end
        host_doing_write <= host_doing_write;
        pci_master_updated_data[31:0] <= pci_master_updated_data[31:0]
                                             + 32'h01010101;
        pci_master_updated_burst_size[3:0] <= pci_master_updated_burst_size[3:0] - 4'h1;
      end
      else
      begin
        host_command_finished <= 1'b0;
        host_working_on_pci_reference <= 1'b1;
        host_doing_write <= host_doing_write;
        pci_master_updated_data[31:0] <= pci_master_updated_data[31:0];
        pci_master_updated_burst_size[3:0] <= pci_master_updated_burst_size[3:0];
      end
    end
    else  // idle
    begin
      host_command_finished <= 1'b0;
      host_working_on_pci_reference <= 1'b0;
      host_doing_write <= host_doing_write;  // don't care
      pci_master_updated_data[31:0] <= pci_master_updated_data[31:0];  // don't care
      pci_master_updated_burst_size[3:0] <= pci_master_updated_burst_size[3:0];  // don't care
    end
  end

// Start SRAM activity, which immediately services the request.
// Last term prevents accidental back-to-back references
  assign  Host_Mem_Read_Request = host_command_started & ~host_doing_write_now
                                 & (modified_master_address[31:24] == 8'hDD)
                                 & ~host_command_finished;
  assign  Host_Mem_Write_Request = host_command_started &  host_doing_write_now
                                 & (modified_master_address[31:24] == 8'hDD)
                                 & ~host_command_finished ;

// Start PCI Activity.
  assign  pci_master_addr_valid = host_command_started  // combinational for speed
                                 & (modified_master_address[31:24] != 8'hDD)
                                 & ~host_command_finished;
  assign  pci_master_data_valid = host_command_started  // combinational for speed
                                 & (modified_master_address[31:24] != 8'hDD)
                                 & ~host_command_finished;
// This low-performance Host Controller makes the Host wait till the data is consumed.
// This would be fine of the Host had a write buffer.
  assign  pci_master_ref_address[31:0] = modified_master_address[31:0];
  assign  pci_master_ref_command[3:0] = hold_master_command[3:0];
  assign  pci_master_ref_config = (modified_master_address[31:24] == 8'hCC);
  assign  pci_master_byte_enables_l[3:0] = hold_master_byte_enables_l[3:0];
  assign  pci_master_write_data[31:0] = ~host_working_on_pci_reference
                                 ? hold_master_data[31:0]
                                 : pci_master_updated_data[31:0];
  assign  pci_master_requests_serr = hold_master_addr_par_err;
  assign  pci_master_requests_perr = hold_master_data_par_err;
  assign  pci_master_requests_last = pci_master_ref_config
                                  | (host_working_on_pci_reference
                                      ? (pci_master_updated_burst_size[3:0] <= 4'h1)
                                      : (hold_master_size[3:0] <= 4'h1) );

// Implement Target Reads and Writes here.  When the PCI Interface asks for data
//   to be transferred, grab the address and request data.  Watch the target
//   request signals to keep aware of when to stop transferring data.
// NOTE that a Read might come in which causes the Master side of the interface
//   to dump a write cache.  In this case, the Read cannot be allowed to complete
//   until the Write activity has finished, and the Write Fence has been
//   written to the internal request FIFO.  The Host Interface knows this has
//   happened when it asserts host_allows_write_fence.
// NOTE that Writes must ALWAYS be serviced.
// NOTE that a new request might come in while waiting for a memory reference
//   to complete.  Make sure not to change critical signals until the present
//   reference is finished.

  reg     mem_ref_in_progress;
  reg     mem_read_in_progress;
  reg     mem_last_word_in_progress;
// NOTE a different Host Controller might simply not unload write data, instead
//   of unloading it into holding registers to support a later write.
// If the different Host Controller knew one or two cycles early that a write
//   was about to be completed, it could unload at the correct time, and suffer
//   no performance loss.
  wire    target_doing_write = (pci_target_ref_command[3:0]
                                 & `PCI_COMMAND_ANY_WRITE_MASK) != 4'h0;

  reg    [7:0] pci_target_hold_address;
  reg    [31:0] pci_target_hold_write_data;
  reg    [3:0] pci_target_hold_byte_enables_l;
  reg     pci_target_hold_write_reference;
  reg     pci_target_perr_requested;
  reg     pci_target_disconnect_with_first;
  reg     pci_target_disconnect_with_second;
  reg     pci_target_abort_before_first;
  reg     pci_target_abort_before_second;

// NOTE WORKING put in access to SRAM here
  always @(posedge host_clk)
  begin
    if (host_reset)
    begin
      mem_ref_in_progress <= 1'b0;
      mem_read_in_progress <= mem_read_in_progress;
      mem_last_word_in_progress <= mem_last_word_in_progress;
      pci_target_hold_address[7:0] <= pci_target_hold_address[7:0];
      pci_target_hold_write_data[31:0] <= pci_target_hold_write_data[31:0]; 
      pci_target_hold_byte_enables_l[3:0] <= pci_target_hold_byte_enables_l[3:0];
      pci_target_hold_write_reference <= pci_target_hold_write_reference;
      pci_target_perr_requested <= pci_target_perr_requested;
      pci_target_disconnect_with_first <= pci_target_disconnect_with_first;
      pci_target_disconnect_with_second <= pci_target_disconnect_with_second;
      pci_target_abort_before_first <= pci_target_abort_before_first;
      pci_target_abort_before_second <= pci_target_abort_before_second;
    end
    else
    begin
      if (mem_ref_in_progress)
      begin
        mem_ref_in_progress <= mem_ref_in_progress;
        mem_read_in_progress <= mem_read_in_progress;
        mem_last_word_in_progress <= mem_last_word_in_progress;
        pci_target_hold_address[7:0] <= pci_target_ref_address[7:0];
        pci_target_hold_write_data[31:0] <= pci_target_write_data[31:0]; 
        pci_target_hold_byte_enables_l[3:0] <= pci_target_byte_enables_l[3:0];
        pci_target_hold_write_reference <= target_doing_write;
        pci_target_perr_requested <= pci_target_ref_address[23]
               & pci_target_ref_address[9];
        pci_target_disconnect_with_first <= pci_target_ref_address[23]
               & (pci_target_ref_address[14:12] == `Test_Target_Disc_With_First);
        pci_target_disconnect_with_second <= pci_target_ref_address[23]
               & (pci_target_ref_address[14:12] == `Test_Target_Disc_With_Second);
        pci_target_abort_before_first <= pci_target_ref_address[23]
               & (pci_target_ref_address[14:12] == `Test_Target_Abort_Before_First);
        pci_target_abort_before_second <= pci_target_ref_address[23]
               & (pci_target_ref_address[14:12] == `Test_Target_Abort_Before_Second);
      end
      else
      begin
        mem_ref_in_progress <= pci_target_ref_start;
        mem_read_in_progress <= mem_read_in_progress;
        mem_last_word_in_progress <= mem_last_word_in_progress;
        pci_target_hold_address[7:0] <= pci_target_hold_address[7:0];
        pci_target_hold_write_data[31:0] <= pci_target_hold_write_data[31:0];
        pci_target_hold_byte_enables_l[3:0] <= pci_target_hold_byte_enables_l[3:0];
        pci_target_hold_write_reference <= pci_target_hold_write_reference;
        pci_target_perr_requested <= pci_target_perr_requested;
        pci_target_disconnect_with_first <= pci_target_disconnect_with_first;
        pci_target_disconnect_with_second <= pci_target_disconnect_with_second;
        pci_target_abort_before_first <= pci_target_abort_before_first;
        pci_target_abort_before_second <= pci_target_abort_before_second;
      end
    end
  end

  assign  PCI_Bus_Mem_Address[7:2] = ~mem_ref_in_progress
                                   ? pci_target_ref_address[7:2]
                                   : pci_target_hold_address[7:2];
  assign  PCI_Bus_Mem_Write_Data[31:0] = ~mem_ref_in_progress
                                   ? pci_target_write_data[31:0]
                                   : pci_target_hold_write_data[31:0];
  assign  PCI_Bus_Mem_Write_Byte_Enables_l[3:0] = ~mem_ref_in_progress
                                   ? pci_target_byte_enables_l[3:0]
                                   : pci_target_hold_byte_enables_l[3:0];
  assign  PCI_Bus_Mem_Read_Request = 1'b0 & (~mem_ref_in_progress  // NOTE WORKING
                                   ? (mem_ref_in_progress & ~PCI_Bus_Mem_Grant)
                                   : pci_target_ref_start);
  assign  PCI_Bus_Mem_Write_Request = 1'b0 & (~mem_ref_in_progress  // NOTE WORKING
                                   ? target_doing_write
                                   : pci_target_hold_write_reference);

  assign  pci_target_read_data[31:0] = mem_read_data[31:0];
  assign  pci_target_requests_abort = pci_target_abort_before_first;
  assign  pci_target_requests_perr = pci_target_perr_requested;
  assign  pci_target_requests_disconnect = pci_target_disconnect_with_first;
  assign  pci_target_data_transferred = PCI_Bus_Mem_Grant;

  assign  pci_target_busy = mem_ref_in_progress;
endmodule

