//===========================================================================
// $Id: pci_example_host_controller.v,v 1.2 2001-02-23 13:18:37 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  An example Host Controller.  This example code shows the correct
//           use of of the Request, Response, and Delayed Read Data FIFOs.
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
// NOTE TODO: Horrible.  Tasks can't depend on their Arguments being safe
//        if there are several instances ofthe task running at once.
//
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/1ps

module pci_example_host_controller (
// Wires used by the host controller to request action by the pci interface
  pci_host_request_data, pci_host_request_cbe, pci_host_request_type,
  pci_host_request_room_available_meta, pci_host_request_submit, pci_host_request_error,
// Wires used by the pci interface to request action by the host controller
  pci_host_response_data, pci_host_response_cbe, pci_host_response_type,
  pci_host_response_data_available_meta, pci_host_response_unload, pci_host_response_error,
// Wires used by the host controller to send delayed read data by the pci interface
  pci_host_delayed_read_data, pci_host_delayed_read_type,
  pci_host_delayed_read_room_available_meta, pci_host_delayed_read_data_submit,
  pci_host_delayed_read_data_error,
// Generic host interface wires
  pci_host_sees_pci_reset,
  host_reset, host_clk,
// Signals used by the test bench instead of using "." notation
// NOTE WORKING shouldn't this get commands based on the Host Clock?
  test_master_number, test_address, test_command,
  test_data, test_byte_enables, test_size,
  test_make_addr_par_error, test_make_data_par_error,
  test_master_initial_wait_states, test_master_subsequent_wait_states,
  test_target_initial_wait_states, test_target_subsequent_wait_states,
  test_target_devsel_speed, test_fast_back_to_back,
  test_target_termination,
  test_expect_master_abort,
  test_start, test_accepted_l, test_error_event,
  test_device_id
);
// Wires used by the host controller to request action by the pci interface
  output [31:0] pci_host_request_data;
  output [3:0] pci_host_request_cbe;
  output [2:0] pci_host_request_type;
  input   pci_host_request_room_available_meta;
  output  pci_host_request_submit;
  input   pci_host_request_error;
// Wires used by the pci interface to request action by the host controller
  input  [31:0] pci_host_response_data;
  input  [3:0] pci_host_response_cbe;
  input  [3:0] pci_host_response_type;
  input   pci_host_response_data_available_meta;
  output  pci_host_response_unload;
  input   pci_host_response_error;
// Wires used by the host controller to send delayed read data by the pci interface
  output [31:0] pci_host_delayed_read_data;
  output [2:0] pci_host_delayed_read_type;
  input   pci_host_delayed_read_room_available_meta;
  output  pci_host_delayed_read_data_submit;
  input   pci_host_delayed_read_data_error;
// Generic host interface wires
  output  pci_host_sees_pci_reset;
  input   host_reset;
  input   host_clk;

// Signals used by the test bench instead of using "." notation
  input  [2:0] test_master_number;
  input  [31:0] test_address;
  input  [3:0] test_command;
  input  [31:0] test_data;
  input  [3:0] test_byte_enables;
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
  reg    [3:0] hold_master_byte_enables;
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


// To make this interface interesting as a Target, it includes a small Memory.
// The Memory can be read and written by the external PCI Masters.
  reg     Host_Mem_Request, PCI_Bus_Mem_Request;
  reg    [31:0] Host_Mem_Write_Data;
  reg    [5:0] Host_Mem_Address;
  reg    [3:0] Host_Mem_Write_Byte_Enables;
  reg    [31:0] PCI_Bus_Mem_Write_Data;
  reg    [5:0] PCI_Bus_Mem_Address;
  reg    [3:0] PCI_Bus_Mem_Write_Byte_Enables;
  reg    [31:0] remembered_sram_read_data;

  wire   [31:0] mem_write_data = Host_Mem_Request
                         ? Host_Mem_Write_Data[31:0] : PCI_Bus_Mem_Write_Data[31:0];
  wire   [5:0] mem_address = Host_Mem_Request
                         ? Host_Mem_Address[5:0] : PCI_Bus_Mem_Address[5:0];
  wire   [3:0] mem_write_byte_enables = Host_Mem_Request
                         ? Host_Mem_Write_Byte_Enables[3:0]
                         : (PCI_Bus_Mem_Request
                            ? PCI_Bus_Mem_Write_Byte_Enables[3:0]
                            : 4'h0);
  wire    mem_read_enable = Host_Mem_Request
                         ? (Host_Mem_Write_Byte_Enables[3:0] == 4'h0)
                         : (PCI_Bus_Mem_Request
                              ? (PCI_Bus_Mem_Write_Byte_Enables[3:0] == 4'h0)
                              : 1'b0);
  wire    mem_write_enable = Host_Mem_Request
                         ? (Host_Mem_Write_Byte_Enables[3:0] != 4'h0)
                         : (PCI_Bus_Mem_Request
                              ? (PCI_Bus_Mem_Write_Byte_Enables[3:0] != 4'h0)
                              : 1'b0);
  reg    [31:0] mem_read_data;
  reg     PCI_Bus_Mem_Grant;

// storage accessed only through the following always block
  reg    [7:0] Example_Host_Mem_0 [0:63];  // address limits, not bits in address
  reg    [7:0] Example_Host_Mem_1 [0:63];  // address limits, not bits in address
  reg    [7:0] Example_Host_Mem_2 [0:63];  // address limits, not bits in address
  reg    [7:0] Example_Host_Mem_3 [0:63];  // address limits, not bits in address
`ifdef VERILOGGER_BUG
  always @(posedge host_clk)
  begin
    Example_Host_Mem_0[mem_address] <= (mem_write_enable & mem_write_byte_enables[0])
             ? mem_write_data[ 7: 0] : Example_Host_Mem_0[mem_address];
    Example_Host_Mem_1[mem_address] <= (mem_write_enable & mem_write_byte_enables[1])
             ? mem_write_data[15: 8] : Example_Host_Mem_1[mem_address];
    Example_Host_Mem_2[mem_address] <= (mem_write_enable & mem_write_byte_enables[2])
             ? mem_write_data[23:16] : Example_Host_Mem_2[mem_address];
    Example_Host_Mem_3[mem_address] <= (mem_write_enable & mem_write_byte_enables[3])
             ? mem_write_data[31:24] : Example_Host_Mem_3[mem_address];
    mem_read_data[31:0] <= mem_read_enable
             ? {Example_Host_Mem_3[mem_address], Example_Host_Mem_2[mem_address],
                Example_Host_Mem_1[mem_address], Example_Host_Mem_0[mem_address]}
             : 32'hXXXXXXXX;
    remembered_sram_read_data[31:0] <= hold_master_data[31:0];
    PCI_Bus_Mem_Grant <= ~Host_Mem_Request & PCI_Bus_Mem_Request;
    if (mem_read_enable)
    begin
      if ({Example_Host_Mem_3[mem_address], Example_Host_Mem_2[mem_address],
           Example_Host_Mem_1[mem_address], Example_Host_Mem_0[mem_address]}
          != remembered_sram_read_data[31:0])
      begin
        $display ("*** Example Host Controller %h - Local Memory Read Data invalid 'h%h, expected 'h%h, at %t",
                    test_device_id[2:0],
                    {Example_Host_Mem_3[mem_address], Example_Host_Mem_2[mem_address],
                     Example_Host_Mem_1[mem_address], Example_Host_Mem_0[mem_address]},
                     remembered_sram_read_data[31:0], $time);
        error_detected <= ~error_detected;
      end
    end
    `NO_ELSE;
`ifdef VERBOSE_TEST_DEVICE
    if (mem_read_enable)
    begin
      $display ("Example Host Controller %h - Local Memory read with Address %h, Data %h, at time %t",
                 test_device_id[2:0], mem_address[5:0],
                 {Example_Host_Mem_3[mem_address], Example_Host_Mem_2[mem_address],
                  Example_Host_Mem_1[mem_address], Example_Host_Mem_0[mem_address]}, $time);
    end
    `NO_ELSE;
    if (mem_write_enable)
    begin
      $display ("Example Host Controller %h - Local Memory written with Address %h, Data %h, Strobes %h, at time %t",
                 test_device_id[2:0], mem_address[5:0], mem_write_data[31:0], mem_write_byte_enables[3:0], $time);
    end
    `NO_ELSE;
`endif  // VERBOSE_TEST_DEVICE
  end
`endif  // VERILOGGER_BUG

// This models a CPU or other Master device.
// Capture Host Command from top-level Test Commander.
task Clear_Example_Host_Command;
  begin
    hold_master_address[31:0] <= `BUS_IMPOSSIBLE_VALUE;
    hold_master_command[3:0] <= `PCI_COMMAND_RESERVED_4;
    hold_master_data[31:0] <= `BUS_IMPOSSIBLE_VALUE;
    hold_master_byte_enables[3:0] <= 4'h0;
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

  wire    Expose_Next_Data_In_Burst;

// Display on negative edge so easy to see in the waveform.  Don't do so in real hardware!
  reg     host_command_finished, host_sram_ref_finished;
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
        $display (" Example Host Controller %h - Task Started, at %t", test_device_id[2:0], $time);
`endif // VERBOSE_TEST_DEVICE
        host_command_started <= 1'b1;
// Grab address and data in case it takes a while to get bus mastership
        hold_master_address[31:0] <= test_address[31:0];
        hold_master_command[3:0] <= test_command[3:0];
        hold_master_data[31:0] <= test_data[31:0];
        hold_master_byte_enables[3:0] <= test_byte_enables[3:0];
        hold_master_addr_par_err <= test_make_addr_par_error;
        hold_master_data_par_err <= test_make_data_par_error;
        hold_master_initial_waitstates[3:0] <= test_master_initial_wait_states[3:0];
        hold_master_subsequent_waitstates[3:0] <= test_master_subsequent_wait_states[3:0];
        hold_master_target_initial_waitstates[3:0] <= test_target_initial_wait_states[3:0];
        hold_master_target_subsequent_waitstates[3:0] <= test_target_subsequent_wait_states[3:0];
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
      else if (host_command_started & ~host_command_finished & ~host_sram_ref_finished)  // hold
      begin
        host_command_started <= host_command_started;
        hold_master_address[31:0] <= hold_master_address[31:0];
        hold_master_command[3:0] <= hold_master_command[3:0];
        hold_master_data[31:0] <= Expose_Next_Data_In_Burst
               ? (hold_master_data[31:0] + 32'h01010101) : hold_master_data[31:0];
// A real host might update the Byte Enables throughout a Burst.
        hold_master_byte_enables[3:0] <= hold_master_byte_enables[3:0];
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
      else  // drop
      begin
`ifdef VERBOSE_TEST_DEVICE
        $display (" Example Host Controller %h - Task Done, at %t", test_device_id[2:0], $time);
`endif // VERBOSE_TEST_DEVICE
        host_command_started <= 1'b0;
        Clear_Example_Host_Command;
      end
    end
  end


// This interface does a reference to it's 256-byte local SRAM whenever it sees
//   an address with the top byte the special value of 8'hDD.
// A real host adaptor would split off references to the on-chip SRAM at a
//   higher level, so this sort of reference would never get to this interface.
  always @(posedge host_clk)
  begin
    if (host_reset)
    begin
      host_sram_ref_finished <= 1'b0;
      Host_Mem_Request <= 1'b0;
      Host_Mem_Write_Data[31:0] <= 32'h00000000;
      Host_Mem_Address[5:0] <= 6'h00;
      Host_Mem_Write_Byte_Enables[3:0] <= 4'h0;
    end
    else if (host_command_started & (modified_master_address[31:24] == 8'hDD)
              & ~host_sram_ref_finished)
    begin  // Issue local Memory Reference
      host_sram_ref_finished <= 1'b1;  // assume Host SRAM Ref always finishes immediately
      Host_Mem_Request <= 1'b1;
      Host_Mem_Write_Data[31:0] <= hold_master_data[31:0];
      Host_Mem_Address[5:0] <= modified_master_address[5:0];
      Host_Mem_Write_Byte_Enables[3:0] <=
          ((hold_master_command[3:0] & `PCI_COMMAND_ANY_WRITE_COMMAND_MASK) != 4'h0)
          ? ~hold_master_byte_enables[3:0] : 4'h0;
    end
    else
    begin
      host_sram_ref_finished <= 1'b0;
      Host_Mem_Request <= 1'b0;
      Host_Mem_Write_Data[31:0] <= 32'h00000000;
      Host_Mem_Address[5:0] <= 6'h00;
      Host_Mem_Write_Byte_Enables[3:0] <= 4'h0;
    end
  end


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
// Host_Target_State_Machine asserts target_sees_write_fence_end.
// Host Interface can start writing again.
// If the request for a Write Fence comes in when the Host Interface is
//   waiting for the results of a Read, the first thing done after the
//   Read completes is to allow the Write Fence.  No writes are allowed
//   to occur after a read during which a Write Fence was requested.

  reg     target_requests_write_fence, master_issues_write_fence;
  reg     host_allows_write_fence;
  reg     target_sees_write_fence_end;

// top-level write fence state machine.
  always @(posedge host_clk)
  begin
    if (host_reset)
    begin
      host_allows_write_fence <= 1'b0;
    end
    else
    begin  // Could be delayed longer in a real Host Interface which must flush FIFOs.
      host_allows_write_fence <= target_requests_write_fence;
    end
  end

// There are two Host Controller State Machines.
// The Host_Master_State_Machine is responsible for executing requests from the
//   Host to the PCI Bus.
// The Host_Target_State_Machine is responsible for executing requests from the
//   PCI Bus to the local Memory.
// The Host_Target_State_Machine can ask the Host_Master_State_Machine to stick
//   a write fence into the Host Request FIFO in order to correctly implement
//   the PCI Ordering Rules.
// The Host_Target_State_Machine is also constantly sending info about the status
//   of Host-initiated PCI Activity back to the Host_Master_State_Machine.
// See the PCI Local Bus Spec Revision 2.2 section 3.3.3.3.

// The Host_Master_State_Machine either directly executes the read or write if
//   it is to the local Memory, or it makes a request to the PCI Interface.
// A real Host Interface might not have to bother with issuing a Memory Reference
//   here, because it will have it's own port to the Memory and will never inform
//   the Host PCI Interface that it is doing a Memory reference.
// Writes are indicated to be done immediately.  Reads wait until the
//   data gets back before indicating done.

  parameter Example_Host_Master_Idle          = 3'b001;
  parameter Example_Host_Master_Transfer_Data = 3'b010;
  parameter Example_Host_Master_Read_Linger   = 3'b100;

  reg    [2:0] Example_Host_Master_State;

  wire    present_command_is_read =
            ((hold_master_command[3:0] & `PCI_COMMAND_ANY_WRITE_COMMAND_MASK) == 4'h0);
  wire    present_command_is_write = ~present_command_is_read;

  reg    [3:0] pci_master_running_transfer_count;
  reg     target_sees_read_end;

// Host_Master_State_Machine.  Operates when Host talks to external PCI devices
  always @(posedge host_clk)
  begin
    if (host_reset)
    begin
      pci_master_running_transfer_count[3:0] <= 4'h0;
      host_command_finished <= 1'b0;
      master_issues_write_fence <= 1'b0;
      Example_Host_Master_State <= Example_Host_Master_Idle;
    end
    else
    begin
      case (Example_Host_Master_State[2:0])
      Example_Host_Master_Idle:
        begin
          pci_master_running_transfer_count[3:0] <= hold_master_size[3:0];  // grab size
          if (target_requests_write_fence & host_allows_write_fence
              & ~master_issues_write_fence & pci_host_request_room_available_meta)
          begin  // Issue Write Fence into FIFO, exclude other writes to FIFO
            host_command_finished <= 1'b0;
            master_issues_write_fence <= 1'b1;  // indicate that write fence inserted
            Example_Host_Master_State <= Example_Host_Master_Idle;
          end
          else if (host_command_started & ~host_command_finished
                    & pci_host_request_room_available_meta
                    & (modified_master_address[31:24] == 8'hCC) )
          begin  // Issue Local PCI Register command to PCI Controller
            if (present_command_is_write)
            begin
              host_command_finished <= 1'b1;
              master_issues_write_fence <= 1'b0;
              Example_Host_Master_State <= Example_Host_Master_Idle;
            end
            else
            begin
              host_command_finished <= 1'b0;
              master_issues_write_fence <= 1'b0;
              Example_Host_Master_State <= Example_Host_Master_Read_Linger;
            end
          end
          else if (host_command_started & ~host_command_finished
                    & pci_host_request_room_available_meta
                    & (modified_master_address[31:24] != 8'hDD))
          begin  // Issue Remote PCI Reference to PCI Controller
            host_command_finished <= 1'b0;
            master_issues_write_fence <= 1'b0;
            Example_Host_Master_State <= Example_Host_Master_Transfer_Data;
          end
          else
          begin  // No requests which can be acted on, so stay idle.
            host_command_finished <= 1'b0;
            master_issues_write_fence <= 1'b0;
            Example_Host_Master_State <= Example_Host_Master_Idle;
          end
        end
      Example_Host_Master_Transfer_Data:
        begin
          if (~pci_host_request_room_available_meta)
          begin
            pci_master_running_transfer_count[3:0] <=
                                  pci_master_running_transfer_count[3:0];
            host_command_finished <= 1'b0;
            Example_Host_Master_State <= Example_Host_Master_Transfer_Data;
          end
          else if ((pci_master_running_transfer_count[3:0] <= 4'h1)
                     & present_command_is_read)  // end of read
          begin
            pci_master_running_transfer_count[3:0] <=
                                  pci_master_running_transfer_count[3:0] - 4'h1;
            host_command_finished <= 1'b0;
            Example_Host_Master_State <= Example_Host_Master_Read_Linger;
          end
          else if ((pci_master_running_transfer_count[3:0] <= 4'h1)
                     & present_command_is_write)  // end of write
          begin
            pci_master_running_transfer_count[3:0] <=
                                  pci_master_running_transfer_count[3:0] - 4'h1;
            host_command_finished <= 1'b1;
            Example_Host_Master_State <= Example_Host_Master_Idle;
          end
          else  // more data to transfer
          begin
            pci_master_running_transfer_count[3:0] <=
                                  pci_master_running_transfer_count[3:0] - 4'h1;
            host_command_finished <= 1'b0;
            Example_Host_Master_State <= Example_Host_Master_Transfer_Data;
          end
          master_issues_write_fence <= 1'b0;  // not doing write fence, so never.
        end
      Example_Host_Master_Read_Linger:
        begin
          if (~target_sees_read_end)
          begin
            pci_master_running_transfer_count[3:0] <=
                                  pci_master_running_transfer_count[3:0];
            host_command_finished <= 1'b0;
            Example_Host_Master_State <= Example_Host_Master_Read_Linger;
          end
          else
          begin
            pci_master_running_transfer_count[3:0] <=
                                  pci_master_running_transfer_count[3:0];
            host_command_finished <= 1'b1;
            Example_Host_Master_State <= Example_Host_Master_Idle;
          end
        end
      default:
        begin
          pci_master_running_transfer_count[3:0] <=
                                  pci_master_running_transfer_count[3:0];
          host_command_finished <= 1'b0;
          master_issues_write_fence <= 1'b0;
          Example_Host_Master_State <= Example_Host_Master_Idle;
          $display ("*** Example Host Controller %h - Host_Master_State_Machine State invalid %b, at %t",
                      test_device_id[2:0], Example_Host_Master_State[2:0], $time);
          error_detected <= ~error_detected;
        end
      endcase
    end
  end

// Get the next Host Data during a Burst.  In this example Host Interface,
//   data always increments by 32'h01010101 during a burst.
// The Write side increments it during writes, and the Read side increments
// it during compares.
  wire    Offer_Next_Host_Data_During_Writes =
                (Example_Host_Master_State[2:0] == Example_Host_Master_Transfer_Data)
              & present_command_is_write & pci_host_request_room_available_meta;

// References to the local Config Registers can only be 1 byte at a time.
  wire   [7:0] config_ref_data =
                (hold_master_byte_enables[0] ? hold_master_data[ 7: 0] : 8'h00)
              | (hold_master_byte_enables[1] ? hold_master_data[15: 8] : 8'h00)
              | (hold_master_byte_enables[2] ? hold_master_data[23:16] : 8'h00)
              | (hold_master_byte_enables[3] ? hold_master_data[31:24] : 8'h00);
  wire   [1:0] config_ref_addr_lsb =
                (hold_master_byte_enables[0] ? 2'h0
              : (hold_master_byte_enables[1] ? 2'h1
              : (hold_master_byte_enables[2] ? 2'h2
              : 2'h3)));

// Data for either a Write Fence, a Config Reference, the PCI Address, or the PCI Data.
// This is actually an if-then-else, done in combinational logic.  Would it be clearer as a function?
// A slower Host Interface could do this as sequential logic in an always block.
  assign  pci_host_request_data[31:0] =
                (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & target_requests_write_fence & host_allows_write_fence
                   & ~master_issues_write_fence & pci_host_request_room_available_meta)
              ? {modified_master_address[31:18], 2'b00, config_ref_data[7:0],
                 modified_master_address[7:2], config_ref_addr_lsb[1:0]}
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & host_command_started & ~host_command_finished
                   & pci_host_request_room_available_meta
                   & (modified_master_address[31:24] == 8'hCC))
              ? {modified_master_address[31:18], present_command_is_read,
                 present_command_is_write, config_ref_data[7:0],
                 modified_master_address[7:2], config_ref_addr_lsb[1:0]}
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & host_command_started & ~host_command_finished
                   & pci_host_request_room_available_meta
                   & (modified_master_address[31:24] != 8'hDD))
              ? modified_master_address[31:0]
              : ((Example_Host_Master_State[2:0] == Example_Host_Master_Transfer_Data)
              ? hold_master_data[31:0]  // Data advanced by host interface during burst
              : modified_master_address[31:0]))));

// Either the Host PCI Command or the Host Byte Enables.
  assign  pci_host_request_cbe[3:0] =
             (Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
             ? hold_master_command[3:0]
             : hold_master_byte_enables[3:0];  // Byte Enables advanced by host interface during burst

// Either Write Fence, Read/Write Config Register, Read/Write Address, Read/Write Data, Spare.
// This is actually an if-then-else, done in combinational logic.  Would it be clearer as a function?
// A slower Host Interface could do this as sequential logic in an always block.
  assign  pci_host_request_type[2:0] =
                (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & target_requests_write_fence & host_allows_write_fence
                   & ~master_issues_write_fence & pci_host_request_room_available_meta)
              ? `PCI_HOST_REQUEST_INSERT_WRITE_FENCE
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & host_command_started & ~host_command_finished
                   & pci_host_request_room_available_meta
                   & (modified_master_address[31:24] == 8'hCC))
              ? `PCI_HOST_REQUEST_READ_WRITE_CONFIG_REGISTER
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & host_command_started & ~host_command_finished
                   & pci_host_request_room_available_meta
                   & (modified_master_address[31:24] != 8'hDD)
                   & ~hold_master_addr_par_err)
              ? `PCI_HOST_REQUEST_ADDRESS_COMMAND
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                   & host_command_started & ~host_command_finished
                   & pci_host_request_room_available_meta
                   & (modified_master_address[31:24] != 8'hDD)
                   & hold_master_addr_par_err)
              ? `PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Transfer_Data)
                   & (pci_master_running_transfer_count[3:0] > 4'h1)
                   & ~hold_master_data_par_err)
              ? `PCI_HOST_REQUEST_W_DATA_RW_MASK
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Transfer_Data)
                   & (pci_master_running_transfer_count[3:0] <= 4'h1)
                   & ~hold_master_data_par_err)
              ? `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Transfer_Data)
                   & (pci_master_running_transfer_count[3:0] > 4'h1)
                   & hold_master_data_par_err)
              ? `PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR
              : (((Example_Host_Master_State[2:0] == Example_Host_Master_Transfer_Data)
                   & (pci_master_running_transfer_count[3:0] <= 4'h1)
                   & hold_master_data_par_err)
              ? `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR
              : `PCI_HOST_REQUEST_SPARE))))))));

// Only write the FIFO when data is available and the FIFO has room for more data
// This is actually an if-then-else, done in combinational logic.  Would it be clearer as a function?
// A slower Host Interface could do this as sequential logic in an always block.
// NOTE WORKING that 1'b0 & ( has to go!
  assign  pci_host_request_submit = 1'b0 & (
                ((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                 & target_requests_write_fence & host_allows_write_fence
                 & ~master_issues_write_fence & pci_host_request_room_available_meta)
              | ((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                 & host_command_started & ~host_command_finished
                 & pci_host_request_room_available_meta
                 & (modified_master_address[31:24] == 8'hCC))
              | ((Example_Host_Master_State[2:0] == Example_Host_Master_Idle)
                 & host_command_started & ~host_command_finished
                 & pci_host_request_room_available_meta
                 & (modified_master_address[31:24] != 8'hDD))
              | ((Example_Host_Master_State[2:0] == Example_Host_Master_Transfer_Data)
                 & pci_host_request_room_available_meta) );

// Check for errors in the Host_Master_State_Machine
  always @(posedge host_clk)
  begin
    if (host_command_started & ~host_command_finished
         &  pci_host_request_room_available_meta
         & (modified_master_address[31:24] == 8'hCC) )
    begin
      if (hold_master_size[3:0] != 4'h1)
      begin
        $display ("*** Example Host Controller %h - Local Config Reg Refs must be exactly 1 word long %h, at %t",
                    test_device_id[2:0], hold_master_size[3:0], $time);
        error_detected <= ~error_detected;
      end
      `NO_ELSE;
      if (  (hold_master_byte_enables[3:0] != 4'h1)
          & (hold_master_byte_enables[3:0] != 4'h2)
          & (hold_master_byte_enables[3:0] != 4'h4)
          & (hold_master_byte_enables[3:0] != 4'h8) )
      begin
        $display ("*** Example Host Controller %h - Local Config Reg Refs must have exactly 1 Byte Enable %h, at %t",
                    test_device_id[2:0], hold_master_byte_enables[3:0], $time);
        error_detected <= ~error_detected;
      end
      `NO_ELSE;
    end
    `NO_ELSE;
    if (pci_host_request_error)
    begin
      $display ("*** Example Host Controller %h - Request FIFO reports Error, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
  end


// The Host_Target_State_Machine executes PCI Bus references to the local Memory.
// The Host_Target_State_Machine can ask the Host_Master_State_Machine to stick
//   a write fence into the Host Request FIFO in order to correctly implement
//   the PCI Ordering Rules for Delayed Reads.  See the PCI Local Bus Spec
//   Revision 2.2 section 3.3.3.3.
// This State Machine is responsible for restarting the Memory Read in the case
//   of a Delayed Read which is interrupted by a delayed write to the read region.
//
// This state machine seems to be stateless.
// The two bits of state it keeps are that it requested a Write Fence but the
//   fence has not been sent yet, and that it requested a restart on an SRAM
//   read but the restart has not happened yet.
//
// This example Host Interface also checks the results of Master Reference here.
// Reads and Writes are tagged, and the information is encoded into the
//   middle 16 bits of the PCI Address.  The information is used at the end
//   of a PCI transfer to see if the expected activity occurred.

// Forward references used to communicate with the Host_Master_State_Machine above:
// reg     target_requests_write_fence, master_issues_write_fence;
// reg     target_sees_write_fence_end;
// reg     target_sees_read_end;

// Communication with a Host Interface Status Register.  Not implemented here.
  reg     PERR_Detected, SERR_Detected, Master_Abort_Received, Target_Abort_Received;
  reg     Caused_Target_Abort, Caused_PERR, Discarded_Delayed_Read;
  reg     Target_Retry_Or_Disconnect, Illegal_Command_Detected_In_Request_FIFO;
  reg     Illegal_Command_Detected_In_Response_FIFO;

// Communication with the Host_Delayed_Read_State_Machine below:
  reg     delayed_read_start_requested, delayed_read_start_granted;
  reg     delayed_read_stop_seen;
  reg     delayed_read_flush_requested, delayed_read_flush_granted;

// Capture signals needed to do local SRAM references and to check Master reference results.
  reg    [31:0] Captured_Target_Address;
  reg    [3:0] Captured_Target_Type;
  reg     target_request_being_serviced;
  reg    [31:0] Captured_Master_Address_Check;
  reg    [3:0] Captured_Master_Type_Check;
  reg     master_results_being_returned;

task Hold_Master_And_Target_Memory_Activity;
  begin
    Captured_Target_Address[31:0] <= Captured_Target_Address[31:0];
    Captured_Target_Type[3:0] <= Captured_Target_Type[3:0];
    target_request_being_serviced <= target_request_being_serviced;
    Captured_Master_Address_Check[31:0] <= Captured_Master_Address_Check[31:0];
    Captured_Master_Type_Check[3:0] <= Captured_Master_Type_Check[3:0];
    master_results_being_returned <= master_results_being_returned;
  end
endtask

task Indicate_Possible_Response_Error;
  input   Response_Fifo_Command_Invalid;
  begin
    PERR_Detected <= 1'b0;
    SERR_Detected <= 1'b0;
    Master_Abort_Received <= 1'b0;
    Target_Abort_Received <= 1'b0;
    Caused_Target_Abort <= 1'b0;
    Caused_PERR <= 1'b0;
    Discarded_Delayed_Read <= 1'b0;
    Target_Retry_Or_Disconnect <= 1'b0;
    Illegal_Command_Detected_In_Request_FIFO <= 1'b0;
    Illegal_Command_Detected_In_Response_FIFO <= Response_Fifo_Command_Invalid;
  end
endtask

task Hold_Host_Write_Fence_Request;
  begin
    target_requests_write_fence <= target_requests_write_fence
                                 & ~master_issues_write_fence;
    target_sees_write_fence_end <= 1'b0;
    target_sees_read_end <= 1'b0;
  end
endtask

task Hold_Host_Delayed_Read_Flush_Request;
  begin
    delayed_read_start_requested <= delayed_read_start_requested
                                  & ~delayed_read_start_granted;
    delayed_read_stop_seen <= 1'b0;
    delayed_read_flush_requested <= delayed_read_flush_requested
                                  & ~delayed_read_flush_granted;
  end
endtask

// Host_Target_State_Machine
  always @(posedge host_clk)
  begin
    if (host_reset)
    begin
      Captured_Target_Address[31:0] <= 32'h00000000;
      Captured_Target_Type[3:0] <= 4'h0;
      target_request_being_serviced <= 1'b0;
      Captured_Master_Address_Check[31:0] <= 32'h00000000;
      Captured_Master_Type_Check[3:0] <= 4'h0;
      master_results_being_returned <= 1'b0;
      Indicate_Possible_Response_Error (1'b0);
      target_requests_write_fence <= 1'b0;
      target_sees_write_fence_end <= 1'b0;
      target_sees_read_end <= 1'b0;
      delayed_read_start_requested <= 1'b0;
      delayed_read_stop_seen <= 1'b0;
      delayed_read_flush_requested <= 1'b0;
    end
    else
    begin
// NOTE WORKING
//  input  [31:0] pci_host_response_data;
//  input  [3:0] pci_host_response_cbe;
      if (pci_host_response_data_available_meta)
      begin
        case (pci_host_response_type[3:0])
        `PCI_HOST_RESPONSE_SPARE:
          begin  // Unused, Illegal
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b1);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_EXECUTED_ADDRESS_COMMAND:
          begin  // Consumed a Master Reference Address
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_REPORT_SERR_PERR_M_T_ABORT:
          begin  // Indicated some sort of Error or Status event in the PCI Interface
            Hold_Master_And_Target_Memory_Activity;
            PERR_Detected <=              pci_host_response_data[31];
            SERR_Detected <=              pci_host_response_data[30];
            Master_Abort_Received <=      pci_host_response_data[29];
            Target_Abort_Received <=      pci_host_response_data[28];
            Caused_Target_Abort <=        pci_host_response_data[27];
            Caused_PERR <=                pci_host_response_data[24];
            Discarded_Delayed_Read <=     pci_host_response_data[18];
            Target_Retry_Or_Disconnect <= pci_host_response_data[17];
            Illegal_Command_Detected_In_Request_FIFO <= pci_host_response_data[16];
            Illegal_Command_Detected_In_Response_FIFO <= 1'b0;
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_UNLOADING_WRITE_FENCE:
          begin  // also `PCI_HOST_RESPONSE_READ_WRITE_CONFIG_REGISTER
// A write fence unload response will have Bits 16 and 17 both set to 1'b0.
// Config References can be identified by noticing that Bits 16 or 17 are non-zero.
// Data Bits [7:0] are the Byte Address of the Config Register being accessed.
// Data Bits [15:8] are the single-byte Read Data returned when writing the Config Register.
// Data Bit  [16] indicates that a Config Write has been done.
// Data Bit  [17] indicates that a Config Read has been done.
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_R_DATA_W_SENT:
          begin  // Master Data returned on Read, or Write Data consumed
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST:
          begin  // Master Data returned on Read, or Write Data consumed, end of burst
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_R_DATA_W_SENT_PERR:
          begin  // Master Data returned on Read, or Write Data consumed
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST_PERR:
          begin  // Master Data returned on Read, or Write Data consumed, end of burst
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_EXTERNAL_SPARE:
          begin  // Unused, Illegal
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b1);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_EXTERNAL_ADDRESS_COMMAND_READ_WRITE:
          begin  // External PCI Device has started a reference
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_EXT_DELAYED_READ_RESTART:
          begin  // A write occurred while servicing a Delayed Read.  Start the Read over
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_EXT_READ_UNSUSPENDING:
          begin  // A Delayed Read was suspended due to Write Traffic.  Continue the Read
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK:
          begin  // Target Data returned on Read, or Write Data consumed
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST:
          begin  // Target Data returned on Read, or Write Data consumed, end of burst
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_PERR:
          begin  // Target Data returned on Read, or Write Data consumed
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        `PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST_PERR:
          begin  // Target Data returned on Read, or Write Data consumed, end of burst
            Hold_Master_And_Target_Memory_Activity;
            Indicate_Possible_Response_Error (1'b0);
            Hold_Host_Write_Fence_Request;
            Hold_Host_Delayed_Read_Flush_Request;
          end
        default:
          begin
            Captured_Target_Address[31:0] <= 32'h00000000;
            Captured_Target_Type[3:0] <= 4'h0;
            target_request_being_serviced <= 1'b0;
            Captured_Master_Address_Check[31:0] <= 32'h00000000;
            Captured_Master_Type_Check[3:0] <= 4'h0;
            master_results_being_returned <= 1'b0;
            Indicate_Possible_Response_Error (1'b1);
            target_requests_write_fence <= 1'b0;
            target_sees_write_fence_end <= 1'b0;
            target_sees_read_end <= 1'b0;
            delayed_read_start_requested <= 1'b0;
            delayed_read_stop_seen <= 1'b0;
            delayed_read_flush_requested <= 1'b0;
            $display ("*** Example Host Controller %h - Host_Target_State_Machine FIFO Type invalid %b, at %t",
                        test_device_id[2:0], pci_host_response_type[3:0], $time);
            error_detected <= ~error_detected;
          end
        endcase
      end
      else
      begin  // Nothing in FIFO, so just sit in present state
        Hold_Master_And_Target_Memory_Activity;
        Indicate_Possible_Response_Error (1'b0);
        Hold_Host_Write_Fence_Request;
        Hold_Host_Delayed_Read_Flush_Request;
      end
    end
  end

// NOTE WORKING
// Unload Response FIFO when it is possible to pass its contents to all interested parties.
  assign  pci_host_response_unload = 1'b0;

// NOTE WORKING
// Get the next Host Data during a Burst.  In this example Host Interface,
//   data always increments by 32'h01010101 during a burst.
// The Write side increments it during writes, and the Read side increments
// it during compares.
  wire    Calculate_Next_Host_Data_During_Reads = 1'b0;


// Check for errors in the Host_Target_State_Machine
  always @(posedge host_clk)
  begin
    if (pci_host_response_error)
    begin
      $display ("*** Example Host Controller %h - Response FIFO reports Error, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (Illegal_Command_Detected_In_Request_FIFO)
    begin
      $display ("*** Example Host Controller %h - Illegal Command reported in Request FIFO, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (Illegal_Command_Detected_In_Response_FIFO)
    begin
      $display ("*** Example Host Controller %h - Illegal Command reported in Response FIFO, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
  end

// Get the next Host Data during a Burst.  In this example Host Interface,
//   data always increments by 32'h01010101 during a burst.
// Only master-initiated transfers are checked for correctness.  To check that
//   data is written correctly to a remote PCI device, read it back!
// The Write side increments it during writes, and the Read side increments
//   it during compares.
  assign  Expose_Next_Data_In_Burst = Offer_Next_Host_Data_During_Writes
                                    | Calculate_Next_Host_Data_During_Reads;

// Host_Delayed_Read_State_Machine
  always @(posedge host_clk)
  begin
    if (host_reset)
    begin
      PCI_Bus_Mem_Request <= 1'b0;
      PCI_Bus_Mem_Write_Data[31:0] <= 32'h00000000;
      PCI_Bus_Mem_Address[5:0] <= 6'h00;
      PCI_Bus_Mem_Write_Byte_Enables[3:0] <= 4'h0;
    end
    else
    begin
      if (pci_host_delayed_read_room_available_meta)
      begin
      end
    end
  end

// NOTE WORKING
// Things to tag the outgoing data stream with
//`define PCI_HOST_DELAYED_READ_DATA_SPARE               (3'b000)
//`define PCI_HOST_DELAYED_READ_DATA_VALID               (3'b001)
//`define PCI_HOST_DELAYED_READ_DATA_VALID_LAST          (3'b010)
//`define PCI_HOST_DELAYED_READ_DATA_VALID_PERR          (3'b101)
//`define PCI_HOST_DELAYED_READ_DATA_VALID_LAST_PERR     (3'b110)
//`define PCI_HOST_DELAYED_READ_DATA_TARGET_ABORT        (3'b011)

// NOTE WORKING
  assign  pci_host_delayed_read_data[31:0] = 32'h00000000;
  assign  pci_host_delayed_read_type[2:0] = `PCI_HOST_DELAYED_READ_DATA_SPARE;
  assign  pci_host_delayed_read_data_submit = 1'b0;

// Check for errors in the Host_Target_State_Machine
  always @(posedge host_clk)
  begin
    if (pci_host_delayed_read_data_error)
    begin
      $display ("*** Example Host Controller %h - Delayed Read FIFO reports Error, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
  end

// Print out various Interface Error reports.  Some of these printouts should
//   go away when the testing code above starts checking for intentional errors.
  always @(posedge host_clk)
  begin
    if (PERR_Detected)
    begin
      $display ("*** Example Host Controller %h - PERR_Detected, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (SERR_Detected)
    begin
      $display ("*** Example Host Controller %h - SERR_Detected, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (Master_Abort_Received)
    begin
      $display ("*** Example Host Controller %h - Master_Abort_Received, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (Target_Abort_Received)
    begin
      $display ("*** Example Host Controller %h - Target_Abort_Received, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (Caused_Target_Abort)
    begin
      $display ("*** Example Host Controller %h - Caused_Target_Abort, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (Caused_PERR)
    begin
      $display ("*** Example Host Controller %h - Caused_PERR, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (Discarded_Delayed_Read)
    begin
      $display ("*** Example Host Controller %h - Discarded_Delayed_Read, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (Target_Retry_Or_Disconnect)
    begin
      $display ("*** Example Host Controller %h - Target_Retry_Or_Disconnect, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (Illegal_Command_Detected_In_Request_FIFO)
    begin
      $display ("*** Example Host Controller %h - Illegal_Command_Detected_In_Request_FIFO, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
    if (Illegal_Command_Detected_In_Response_FIFO)
    begin
      $display ("*** Example Host Controller %h - Illegal_Command_Detected_In_Response_FIFO, at %t",
                  test_device_id[2:0], $time);
      error_detected <= ~error_detected;
    end
    `NO_ELSE;
  end

// Monitor the activity on the Host Interface of the PCI_Blue_Interface.
monitor_pci_interface_host_port monitor_pci_interface_host_port (
// Wires used by the host controller to request action by the pci interface
  .pci_host_request_data      (pci_host_request_data[31:0]),
  .pci_host_request_cbe       (pci_host_request_cbe[3:0]),
  .pci_host_request_type      (pci_host_request_type[2:0]),
  .pci_host_request_room_available_meta  (pci_host_request_room_available_meta),
  .pci_host_request_submit    (pci_host_request_submit),
  .pci_host_request_error     (pci_host_request_error),
// Wires used by the pci interface to request action by the host controller
  .pci_host_response_data     (pci_host_response_data[31:0]),
  .pci_host_response_cbe      (pci_host_response_cbe[3:0]),
  .pci_host_response_type     (pci_host_response_type[3:0]),
  .pci_host_response_data_available_meta  (pci_host_response_data_available_meta),
  .pci_host_response_unload   (pci_host_response_unload),
  .pci_host_response_error    (pci_host_response_error),
// Wires used by the host controller to send delayed read data by the pci interface
  .pci_host_delayed_read_data (pci_host_delayed_read_data[31:0]),
  .pci_host_delayed_read_type (pci_host_delayed_read_type[2:0]),
  .pci_host_delayed_read_room_available_meta  (pci_host_delayed_read_room_available_meta),
  .pci_host_delayed_read_data_submit          (pci_host_delayed_read_data_submit),
  .pci_host_delayed_read_data_error (pci_host_delayed_read_data_error),
  .host_clk                   (host_clk)
);
endmodule

