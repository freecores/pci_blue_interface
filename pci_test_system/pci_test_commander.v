//===========================================================================
// $Id: pci_test_commander.v,v 1.11 2001-09-26 09:48:59 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  Using sequential verilog code, issue PCI Commands to one
//           of the several Behaviorial or Synthesizable PCI Interfaces.
//           The interfaces will encode information to control the Target
//           in the middle 16 bits of PCI Address sent by the Master.
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
// NOTE:  This Test Chip instantiates one PCI interface and connects it
//        to its IO pads and to logic representing a real application.
//
// NOTE:  This Test Chip contains several local register variables which
//        are set by an external test framework to initiate PCI references.
//        Usually, a single external write will result in a single PCI
//        PCI reference.
//
//===========================================================================

`timescale 1ns/1ps

module pci_test_commander (
  pci_reset_comb, pci_ext_clk,
// signals used by the test bench instead of using "." notation
  test_sequence,
  test_master_number, test_address, test_command,
  test_data, test_byte_enables_l, test_size,
  test_make_addr_par_error, test_make_data_par_error,
  test_master_initial_wait_states, test_master_subsequent_wait_states,
  test_target_initial_wait_states, test_target_subsequent_wait_states,
  test_target_devsel_speed, test_fast_back_to_back,
  test_target_termination,
  test_expect_master_abort,
  test_start, test_accepted_l, test_result, test_error_event,
  present_test_name, total_errors_detected
);

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"

  input   pci_reset_comb, pci_ext_clk;
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
  output  test_start;
  input   test_accepted_l;
  input  [PCI_BUS_DATA_RANGE:0] test_result;
  input   test_error_event;
  output [79:0] present_test_name;
  input  [31:0] total_errors_detected;

  reg    [2:0] test_master_number;
  reg    [PCI_BUS_DATA_RANGE:0] test_address;
  reg    [3:0] test_command;
  reg    [PCI_BUS_DATA_RANGE:0] test_data;
  reg    [PCI_BUS_CBE_RANGE:0] test_byte_enables_l;
  reg    [3:0] test_size;
  reg     test_make_addr_par_error, test_make_data_par_error;
  reg    [3:0] test_master_initial_wait_states;
  reg    [3:0] test_master_subsequent_wait_states;
  reg    [3:0] test_target_initial_wait_states;
  reg    [3:0] test_target_subsequent_wait_states;
  reg    [1:0] test_target_devsel_speed;
  reg     test_fast_back_to_back;
  reg    [2:0] test_target_termination;
  reg     test_expect_master_abort;
  reg     test_start;
  reg    [79:0] present_test_name;
  reg     waiting;
  integer i;

task do_pause;
  input  [15:0] delay;
  reg    [15:0] cnt;
  begin
    test_start <= 1'b0;  // no device is allowed to take this
    for (cnt = 16'h0000; cnt[15:0] < delay[15:0]; cnt[15:0] = cnt[15:0] + 16'h0001)
    begin
      if (~pci_reset_comb)
      begin
           @ (negedge pci_ext_clk or posedge pci_reset_comb) ;
      end
      `NO_ELSE;
    end
  end
endtask

task DO_REF;
  input  [79:0] name;
  input  [2:0] master_number;
  input  [PCI_BUS_DATA_RANGE:0] address;
  input  [3:0] command;
  input  [PCI_BUS_DATA_RANGE:0] data;
  input  [PCI_BUS_CBE_RANGE:0] byte_enables_l;
  input  [3:0] size;
  input   make_addr_par_error, make_data_par_error;
  input  [7:0] master_wait_states;
  input  [7:0] target_wait_states;
  input  [1:0] target_devsel_speed;
  input   fast_back_to_back;
  input  [2:0] target_termination;
  input   expect_master_abort;
  reg     waiting;
  begin
// Cautiously wait for previous command to be done
    for (waiting = test_accepted_l; waiting != 1'b0; waiting = waiting)
    begin
      if (~pci_reset_comb && (test_accepted_l == 1'b0))
      begin
        if (~pci_reset_comb)
        begin
             @ (negedge pci_ext_clk or posedge pci_reset_comb) ;
        end
        `NO_ELSE;
      end
      else
      begin
        waiting = 1'b0;  // ready to do next command
      end
    end
    present_test_name[79:0] <= name[79:0];
    test_master_number <= master_number[2:0];
    test_address[PCI_BUS_DATA_RANGE:0] <= address[PCI_BUS_DATA_RANGE:0];
    test_command[3:0] <= command[3:0] ;
    test_data[PCI_BUS_DATA_RANGE:0] <= data[PCI_BUS_DATA_RANGE:0];
    test_byte_enables_l[PCI_BUS_CBE_RANGE:0] <= byte_enables_l[PCI_BUS_CBE_RANGE:0];
    test_size <= size[3:0];
    test_make_addr_par_error <= make_addr_par_error;
    test_make_data_par_error <= make_data_par_error;
    test_master_initial_wait_states <= master_wait_states[7:4];
    test_master_subsequent_wait_states <= master_wait_states[3:0];
    test_target_initial_wait_states <= target_wait_states[7:4];
    test_target_subsequent_wait_states <= target_wait_states[3:0];
    test_target_devsel_speed <= target_devsel_speed[1:0];
    test_fast_back_to_back <= fast_back_to_back;
    test_target_termination <= target_termination[2:0];
    test_expect_master_abort <= expect_master_abort;
    test_start <= 1'b1;
    if (~pci_reset_comb)
    begin
      @ (negedge pci_ext_clk or posedge pci_reset_comb) ;
    end
    `NO_ELSE;
// wait for new command to start
    for (waiting = 1'b1; waiting != 1'b0; waiting = waiting)
    begin
      if (~pci_reset_comb && (test_accepted_l == 1'b1))
      begin
        if (~pci_reset_comb) @ (negedge pci_ext_clk or posedge pci_reset_comb) ;
      end
      else
      begin
        waiting = 1'b0;  // ready to do next command
      end
    end
  end
endtask

// Use Macros defined in pci_defines.vh as paramaters

// DO_REF (name[79:0], master_number[2:0],
//          address[PCI_FIFO_DATA_RANGE:0], command[3:0],
//          data[PCI_FIFO_DATA_RANGE:0], byte_enables_l[PCI_FIFO_CBE_RANGE:0], size[3:0],
//          make_addr_par_error, make_data_par_error,
//          master_wait_states[8:0], target_wait_states[8:0],
//          target_devsel_speed[1:0], fast_back_to_back,
//          target_termination[2:0],
//          expect_master_abort);

// Example:
//      DO_REF ("CFG_R_MA_0", `Test_Master_1, 32'h12345678, `Config_Read,
//                32'h76543210, `Test_All_Bytes, `Test_No_Data,
//                `Test_No_Addr_Perr, `Test_No_Data_Perr, `Test_No_Master_WS,
//                `Test_No_Target_WS, `Test_Devsel_Medium, `Test_Fast_B2B,
//                `Test_Target_Normal_Completion, `Test_Master_Abort);

// Do references which are guaranteed to cause a Master Abort

// Access a location with no high-order bits set, assuring that no device responds
task CONFIG_READ_MASTER_ABORT;
  input  [79:0] name;
  input  [2:0] master_number;
  input  [3:0] size;
  begin
    DO_REF (name[79:0], master_number[2:0], `NO_DEVICE_IDSEL_ADDR,
               PCI_COMMAND_CONFIG_READ, 32'h76543210, `Test_All_Bytes, size[3:0],
              `Test_Addr_Perr, `Test_Data_Perr, `Test_No_Master_WS,
              `Test_No_Target_WS, `Test_Devsel_Medium, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_Master_Abort);
  end
endtask

// Access a location with no high-order bits set, assuring that no device responds
task CONFIG_WRITE_MASTER_ABORT;
  input  [79:0] name;
  input  [2:0] master_number;
  input  [3:0] size;
  begin
    DO_REF (name[79:0], master_number[2:0], `NO_DEVICE_IDSEL_ADDR,
               PCI_COMMAND_CONFIG_WRITE, 32'h76543210, `Test_All_Bytes, size[3:0],
              `Test_Addr_Perr, `Test_Data_Perr, `Test_No_Master_WS,
              `Test_No_Target_WS, `Test_Devsel_Medium, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_Master_Abort);
  end
endtask

// Access a location with no high-order bits set, assuring that no device responds
task MEM_READ_MASTER_ABORT;
  input  [79:0] name;
  input  [2:0] master_number;
  input  [3:0] size;
  begin
    DO_REF (name[79:0], master_number[2:0], `NO_DEVICE_IDSEL_ADDR,
               PCI_COMMAND_MEMORY_READ, 32'h76543210, `Test_All_Bytes, size[3:0],
              `Test_Addr_Perr, `Test_Data_Perr, `Test_No_Master_WS,
              `Test_No_Target_WS, `Test_Devsel_Medium, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_Master_Abort);
  end
endtask

// Access a location with no high-order bits set, assuring that no device responds
task MEM_WRITE_MASTER_ABORT;
  input  [79:0] name;
  input  [2:0] master_number;
  input  [3:0] size;
  begin
    DO_REF (name[79:0], master_number[2:0], `NO_DEVICE_IDSEL_ADDR,
               PCI_COMMAND_MEMORY_WRITE, 32'h76543210, `Test_All_Bytes, size[3:0],
              `Test_Addr_Perr, `Test_Data_Perr, `Test_No_Master_WS,
              `Test_No_Target_WS, `Test_Devsel_Medium, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_Master_Abort);
  end
endtask

// Do variable length transfers with various paramaters
task CONFIG_READ;
  input  [79:0] name;
  input  [2:0] master_number;
  input  [PCI_BUS_DATA_RANGE:0] address;
  input  [PCI_BUS_DATA_RANGE:0] data;
  input  [3:0] size;
  input  [7:0] master_wait_states;
  input  [7:0] target_wait_states;
  input  [1:0] target_devsel_speed;
  input  [2:0] target_termination;
  begin
    DO_REF (name[79:0], master_number[2:0], address[PCI_BUS_DATA_RANGE:0],
              PCI_COMMAND_CONFIG_READ, data[PCI_BUS_DATA_RANGE:0], `Test_All_Bytes,
              size[3:0], `Test_No_Addr_Perr, `Test_No_Data_Perr,
              master_wait_states[7:0], target_wait_states[7:0],
              target_devsel_speed[1:0], `Test_Fast_B2B,
              target_termination[2:0], `Test_Expect_No_Master_Abort);
  end
endtask

task CONFIG_WRITE;
  input  [79:0] name;
  input  [2:0] master_number;
  input  [PCI_BUS_DATA_RANGE:0] address;
  input  [PCI_BUS_DATA_RANGE:0] data;
  input  [3:0] size;
  input  [7:0] master_wait_states;
  input  [7:0] target_wait_states;
  input  [1:0] target_devsel_speed;
  input  [2:0] target_termination;
  begin
    DO_REF (name[79:0], master_number[2:0], address[PCI_BUS_DATA_RANGE:0],
              PCI_COMMAND_CONFIG_WRITE, data[PCI_BUS_DATA_RANGE:0], `Test_All_Bytes,
              size[3:0], `Test_No_Addr_Perr, `Test_No_Data_Perr,
              master_wait_states[7:0], target_wait_states[7:0],
              target_devsel_speed[1:0], `Test_Fast_B2B,
              target_termination[2:0], `Test_Expect_No_Master_Abort);
  end
endtask

task MEM_READ;
  input  [79:0] name;
  input  [2:0] master_number;
  input  [PCI_BUS_DATA_RANGE:0] address;
  input  [PCI_BUS_DATA_RANGE:0] data;
  input  [3:0] size;
  input  [7:0] master_wait_states;
  input  [7:0] target_wait_states;
  input  [1:0] target_devsel_speed;
  input  [2:0] target_termination;
  begin
    DO_REF (name[79:0], master_number[2:0], address[PCI_BUS_DATA_RANGE:0],
              PCI_COMMAND_MEMORY_READ, data[PCI_BUS_DATA_RANGE:0], `Test_All_Bytes,
              size[3:0], `Test_No_Addr_Perr, `Test_No_Data_Perr,
              master_wait_states[7:0], target_wait_states[7:0],
              target_devsel_speed[1:0], `Test_Fast_B2B,
              target_termination[2:0], `Test_Expect_No_Master_Abort);
  end
endtask

task MEM_WRITE;
  input  [79:0] name;
  input  [2:0] master_number;
  input  [PCI_BUS_DATA_RANGE:0] address;
  input  [PCI_BUS_DATA_RANGE:0] data;
  input  [3:0] size;
  input  [7:0] master_wait_states;
  input  [7:0] target_wait_states;
  input  [1:0] target_devsel_speed;
  input  [2:0] target_termination;
  begin
    DO_REF (name[79:0], master_number[2:0], address[PCI_BUS_DATA_RANGE:0],
              PCI_COMMAND_MEMORY_WRITE, data[PCI_BUS_DATA_RANGE:0], `Test_All_Bytes,
              size[3:0], `Test_No_Addr_Perr, `Test_No_Data_Perr,
              master_wait_states[7:0], target_wait_states[7:0],
              target_devsel_speed[1:0], `Test_Fast_B2B,
              target_termination[2:0], `Test_Expect_No_Master_Abort);
  end
endtask

// Initialize the Config Registers of a behaviorial PCI Interface
task init_config_regs;
  input  [2:0] Master_ID;
  input  [PCI_BUS_DATA_RANGE:0] Target_Config_Addr;
  input  [PCI_BUS_DATA_RANGE:0] Target_Base_Addr_0;
  input  [PCI_BUS_DATA_RANGE:0] Target_Base_Addr_1;
  begin
// Turn on the device before doing memory references
    CONFIG_WRITE ("CFG_W_BAR0", Master_ID[2:0],
               Target_Config_Addr[PCI_BUS_DATA_RANGE:0] + 32'h10,
               Target_Base_Addr_0[PCI_BUS_DATA_RANGE:0],
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
    CONFIG_WRITE ("CFG_W_BAR1", Master_ID[2:0],
               Target_Config_Addr[PCI_BUS_DATA_RANGE:0] + 32'h14,
               Target_Base_Addr_1[PCI_BUS_DATA_RANGE:0],
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
    CONFIG_WRITE ("CFG_W_CMD ", Master_ID[2:0],
               Target_Config_Addr[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_SERR_EN | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
  end
endtask

// Do the several-step process needed to write data into our local Config Registers
task REG_WRITE_WORD_SELF;
  input  [79:0] name;
  input  [7:0] Address_MSB;
  input  [PCI_BUS_DATA_RANGE:0] address;
  input  [PCI_BUS_DATA_RANGE:0] data;
  begin
    DO_REF (name[79:0], 3'h7, {Address_MSB[7:0], 16'h0000, address[7:0]},
               PCI_COMMAND_CONFIG_WRITE, data[PCI_BUS_DATA_RANGE:0], `Test_Byte_0,
              `Test_One_Word, `Test_No_Addr_Perr, `Test_No_Data_Perr,
              `Test_No_Master_WS, `Test_No_Target_WS,
              `Test_Devsel_Medium, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
    DO_REF (name[79:0], 3'h7, {Address_MSB[7:0], 16'h0000, address[7:0]},
               PCI_COMMAND_CONFIG_WRITE, data[PCI_BUS_DATA_RANGE:0], `Test_Byte_1,
              `Test_One_Word, `Test_No_Addr_Perr, `Test_No_Data_Perr,
              `Test_No_Master_WS, `Test_No_Target_WS,
              `Test_Devsel_Medium, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
    DO_REF (name[79:0], 3'h7, {Address_MSB[7:0], 16'h0000, address[7:0]},
               PCI_COMMAND_CONFIG_WRITE, data[PCI_BUS_DATA_RANGE:0], `Test_Byte_2,
              `Test_One_Word, `Test_No_Addr_Perr, `Test_No_Data_Perr,
              `Test_No_Master_WS, `Test_No_Target_WS,
              `Test_Devsel_Medium, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
    DO_REF (name[79:0], 3'h7, {Address_MSB[7:0], 16'h0000, address[7:0]},
               PCI_COMMAND_CONFIG_WRITE, data[PCI_BUS_DATA_RANGE:0], `Test_Byte_3,
              `Test_One_Word, `Test_No_Addr_Perr, `Test_No_Data_Perr,
              `Test_No_Master_WS, `Test_No_Target_WS,
              `Test_Devsel_Medium, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
  end
endtask

// Initialize the Config Registers of the local Synthesized PCI Interface
task init_config_regs_self;
  input  [PCI_BUS_DATA_RANGE:0] Target_Base_Addr_0;
  input  [PCI_BUS_DATA_RANGE:0] Target_Base_Addr_1;
  begin
// Turn on the device before doing memory references
    REG_WRITE_WORD_SELF ("CFG_W_BAR0", 8'hCC, 32'h10,
                                Target_Base_Addr_0[PCI_BUS_DATA_RANGE:0]);
    REG_WRITE_WORD_SELF ("CFG_W_BAR1", 8'hCC, 32'h14,
                                Target_Base_Addr_1[PCI_BUS_DATA_RANGE:0]);
    REG_WRITE_WORD_SELF ("CFG_W_CMD ", 8'hCC, 32'h04,
                       CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_SERR_EN | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN);
  end
endtask

// Things to vary:
// Master/Target ID (01, 01, 10, 10, 01)  Do in 2 passes: same, alternating
// PCI command, especially read/write and address stepping
// Byte Masks
// Master Transfer Length (1,2)
// address parity error
// data parity error
// Master Wait States (0,1,2,3)
// Target Wait States (0,1,2,3)
// Target DEVSEL speed (0,1,2,3)
// fast back-to-back
// Target Termination scheme (0,1,2,3,4,5,6,7)
task vary_one_paramater_at_a_time;
  input  [2:0] Master_ID_A;
  input  [PCI_BUS_DATA_RANGE:0] Target_Config_Addr_A;
  input  [PCI_BUS_DATA_RANGE:0] Target_Base_Addr_A;
  input  [2:0] Master_ID_B;
  input  [PCI_BUS_DATA_RANGE:0] Target_Config_Addr_B;
  input  [PCI_BUS_DATA_RANGE:0] Target_Base_Addr_B;
  begin
// Disable PERR En register and SERR En register
    CONFIG_WRITE ("CFG_W_NOPS", Master_ID_A[2:0],
               Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h04,
                CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
    CONFIG_WRITE ("CFG_W_NOPS", Master_ID_B[2:0],
               Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Do address and data parity reference
    $display ("Expect Target to complain that DEVSEL Asserted when Address Parity Error during Read");
    $display ("Expect Undetected Address Parity Error during Read");
    DO_REF ("CFG_R_SERR", Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h20,
                PCI_COMMAND_CONFIG_READ, 32'h00000000, `Test_All_Bytes,  // expect error
               `Test_One_Word, `Test_Addr_Perr, `Test_No_Data_Perr,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Fast_B2B,
               `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
    $display ("Expect Undetected Read Data Parity Error");
    DO_REF ("CFG_R_PERR", Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h20,
                PCI_COMMAND_CONFIG_READ, 32'h00000000, `Test_All_Bytes,  // expect error
               `Test_One_Word, `Test_No_Addr_Perr, `Test_Data_Perr,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Fast_B2B,
               `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
    $display ("Expect Undetected Write Data Parity Error");
    DO_REF ("CFG_W_PERR", Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h20,
                PCI_COMMAND_CONFIG_WRITE, 32'h0F0F0F0F, `Test_All_Bytes,  // expect error
               `Test_One_Word, `Test_No_Addr_Perr, `Test_Data_Perr,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Fast_B2B,
               `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);

// Verify Master Abort, both got Parity Error, no signaled SERR
    CONFIG_READ ("CFG_R_NOPS", Master_ID_A[2:0],
               Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_DETECTED_PERR
                     | CONFIG_REG_CMD_STAT_CONSTANTS,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
    CONFIG_READ ("CFG_R_NOPS", Master_ID_B[2:0],
               Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_DETECTED_PERR
                     | CONFIG_REG_CMD_STAT_CONSTANTS,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Clear all error bits, and enable PERR En bit
    CONFIG_WRITE ("CFG_W_NOPS", Master_ID_A[2:0],
               Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_CLEAR_ALL,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
    CONFIG_WRITE ("CFG_W_NOPS", Master_ID_B[2:0],
               Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_CLEAR_ALL,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Do address and data parity reference
    $display ("Expect Undetected Address Parity Error during Read");
    DO_REF ("CFG_R_SERR", Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h20,
                PCI_COMMAND_CONFIG_READ, 32'hFFFFFFFF, `Test_All_Bytes,  // expect error
               `Test_One_Word, `Test_Addr_Perr, `Test_No_Data_Perr,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Fast_B2B,
               `Test_Target_Normal_Completion, `Test_Expect_Master_Abort);
    DO_REF ("CFG_R_PERR", Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h20,
                PCI_COMMAND_CONFIG_READ, 32'h00000000, `Test_All_Bytes,
               `Test_One_Word, `Test_No_Addr_Perr, `Test_Data_Perr,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Fast_B2B,
               `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
    DO_REF ("CFG_W_PERR", Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h20,
                PCI_COMMAND_CONFIG_WRITE, 32'h0F0F0F0F, `Test_All_Bytes,
               `Test_One_Word, `Test_No_Addr_Perr, `Test_Data_Perr,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Fast_B2B,
               `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);

// Verify Master Abort, both got Parity Error, no signaled SERR
    CONFIG_READ ("CFG_R_NOPS", Master_ID_A[2:0],
               Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_DETECTED_PERR
                     | CONFIG_REG_CMD_STAT_CONSTANTS,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
    CONFIG_READ ("CFG_R_NOPS", Master_ID_B[2:0],
               Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_DETECTED_PERR | CONFIG_STAT_CAUSED_PERR
                     | CONFIG_STAT_GOT_MABORT
                     | CONFIG_REG_CMD_STAT_CONSTANTS,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Clear all error bits, and enable PERR En bit and SERR En bit
    CONFIG_WRITE ("CFG_W_NOPS", Master_ID_A[2:0],
               Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_SERR_EN | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_CLEAR_ALL,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
    CONFIG_WRITE ("CFG_W_NOPS", Master_ID_B[2:0],
               Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_SERR_EN | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_CLEAR_ALL,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Do address and data parity reference
    DO_REF ("CFG_R_SERR", Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h20,
                PCI_COMMAND_CONFIG_READ, 32'h00000000, `Test_All_Bytes,
               `Test_One_Word, `Test_Addr_Perr, `Test_No_Data_Perr,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Fast_B2B,
               `Test_Target_Normal_Completion, `Test_Expect_Master_Abort);
    DO_REF ("CFG_R_PERR", Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h20,
                PCI_COMMAND_CONFIG_READ, 32'h00000000, `Test_All_Bytes,
               `Test_One_Word, `Test_No_Addr_Perr, `Test_Data_Perr,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Fast_B2B,
               `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
    DO_REF ("CFG_W_PERR", Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h20,
                PCI_COMMAND_CONFIG_WRITE, 32'h0F0F0F0F, `Test_All_Bytes,
               `Test_One_Word, `Test_No_Addr_Perr, `Test_Data_Perr,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Fast_B2B,
               `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);

// Verify Master Abort, both got Parity Error, target signaled SERR
    CONFIG_READ ("CFG_R_NOPS", Master_ID_A[2:0],
               Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_SERR_EN | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_DETECTED_PERR | CONFIG_STAT_DETECTED_SERR
                     | CONFIG_REG_CMD_STAT_CONSTANTS,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

    CONFIG_READ ("CFG_R_NOPS", Master_ID_B[2:0],
               Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_SERR_EN | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_DETECTED_PERR | CONFIG_STAT_CAUSED_PERR
                     | CONFIG_STAT_GOT_MABORT | CONFIG_STAT_DETECTED_SERR  // sees itself
                     | CONFIG_REG_CMD_STAT_CONSTANTS,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Do read causing Target Abort
    CONFIG_READ ("CFG_R_NOPS", Master_ID_A[2:0],
               Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h04, 32'h00000000,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Abort_Before_First);

// Verify Master Abort, both got Parity Error, target signaled SERR, target abort
    CONFIG_READ ("CFG_R_NOPS", Master_ID_A[2:0],
               Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_SERR_EN | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_DETECTED_PERR | CONFIG_STAT_DETECTED_SERR
                     | CONFIG_STAT_CAUSED_TABORT
                     | CONFIG_REG_CMD_STAT_CONSTANTS,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

    CONFIG_READ ("CFG_R_NOPS", Master_ID_B[2:0],
               Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_SERR_EN | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_DETECTED_PERR | CONFIG_STAT_CAUSED_PERR
                     | CONFIG_STAT_GOT_MABORT | CONFIG_STAT_DETECTED_SERR  // sees itself
                     | CONFIG_STAT_GOT_TABORT
                     | CONFIG_REG_CMD_STAT_CONSTANTS,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Clear all error bits, and enable PERR En bit and SERR En bit
    CONFIG_WRITE ("CFG_W_NOPS", Master_ID_A[2:0],
               Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_SERR_EN | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_CLEAR_ALL,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
    CONFIG_WRITE ("CFG_W_NOPS", Master_ID_B[2:0],
               Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_SERR_EN | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_STAT_CLEAR_ALL,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Verify that all error bits went away
    CONFIG_READ ("CFG_R_NOPS", Master_ID_A[2:0],
               Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_SERR_EN | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_REG_CMD_STAT_CONSTANTS,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
    CONFIG_READ ("CFG_R_NOPS", Master_ID_B[2:0],
               Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0] + 32'h04,
               CONFIG_CMD_FB2B_EN
                     | CONFIG_CMD_SERR_EN | CONFIG_CMD_PAR_ERR_EN
                     | CONFIG_CMD_MASTER_EN | CONFIG_CMD_TARGET_EN
                     | CONFIG_REG_CMD_STAT_CONSTANTS,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Write from Master 0 to Target 1, from Master 1 to Target 0, read back
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h12345678, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_B[2:0], Target_Base_Addr_B[PCI_BUS_DATA_RANGE:0],
               32'h87654321, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h12345678, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_READ  ("MMS_R_SCAN", Master_ID_B[2:0], Target_Base_Addr_B[PCI_BUS_DATA_RANGE:0],
               32'h87654321, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Byte Masks
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'hFFFFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        DO_REF ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               PCI_COMMAND_MEMORY_WRITE, 32'h00000000, `Test_Byte_0,
              `Test_One_Word, `Test_No_Addr_Perr, `Test_No_Data_Perr,
              `Test_No_Master_WS, `Test_No_Target_WS,
              `Test_Devsel_Medium, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'hFFFFFF00, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'hFFFFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        DO_REF ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               PCI_COMMAND_MEMORY_WRITE, 32'h00000000, `Test_Byte_1,
              `Test_One_Word, `Test_No_Addr_Perr, `Test_No_Data_Perr,
              `Test_No_Master_WS, `Test_No_Target_WS,
              `Test_Devsel_Medium, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'hFFFF00FF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'hFFFFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        DO_REF ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               PCI_COMMAND_MEMORY_WRITE, 32'h00000000, `Test_Byte_2,
              `Test_One_Word, `Test_No_Addr_Perr, `Test_No_Data_Perr,
              `Test_No_Master_WS, `Test_No_Target_WS,
              `Test_Devsel_Medium, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'hFF00FFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'hFFFFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        DO_REF ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               PCI_COMMAND_MEMORY_WRITE, 32'h00000000, `Test_Byte_3,
              `Test_One_Word, `Test_No_Addr_Perr, `Test_No_Data_Perr,
              `Test_No_Master_WS, `Test_No_Target_WS,
              `Test_Devsel_Medium, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h00FFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Master Transfer Length (1,2)
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'hFFFFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000004,
               32'hFFFFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000008,
               32'hFFFFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h01020304, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h01020304, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000004,
               32'h02030405, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000008,
               32'hFFFFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h01020304, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000004,
               32'hFFFFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        $display ("Expect Data comparison Error");
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],  // expect error
               32'h01020304, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Master Wait States (0,1)
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'hFFFFFFFF, `Test_One_Word,
               `Test_One_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000004,
               32'hFFFFFFFF, `Test_One_Word,
               `Test_One_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000008,
               32'hFFFFFFFF, `Test_One_Word,
               `Test_One_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h01020304, `Test_Two_Words,
               `Test_One_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h01020304, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000008,
               32'hFFFFFFFF, `Test_One_Word,
               `Test_One_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Target Wait States (0,1)
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h01020304, `Test_Two_Words,
               `Test_No_Master_WS, `Test_One_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h04050607, `Test_Two_Words,
               `Test_No_Master_WS, `Test_One_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h04050607, `Test_Two_Words,
               `Test_One_Master_WS, `Test_One_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_READ  ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000008,
               32'hFFFFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_One_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

// Target DEVSEL speed (0,1,2,3)
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h11111111, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Subtractive, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000004,
               32'h22222222, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Slow, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000008,
               32'h33333333, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h0000000C,
               32'h44444444, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h11111111, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Subtractive, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000004,
               32'h22222222, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Slow, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000008,
               32'h33333333, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h0000000C,
               32'h44444444, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);

// No fast back-to-back
        DO_REF ("MMS_W_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               PCI_COMMAND_MEMORY_WRITE, 32'h08090A0B, `Test_All_Bytes,
              `Test_One_Word, `Test_No_Addr_Perr, `Test_No_Data_Perr,
              `Test_No_Master_WS, `Test_No_Target_WS,
              `Test_Devsel_Fast, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
        DO_REF ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000004,
               PCI_COMMAND_MEMORY_WRITE, 32'h090A0B0C, `Test_All_Bytes,
              `Test_One_Word, `Test_No_Addr_Perr, `Test_No_Data_Perr,
              `Test_No_Master_WS, `Test_No_Target_WS,
              `Test_Devsel_Fast, `Test_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
        DO_REF ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000008,
               PCI_COMMAND_MEMORY_WRITE, 32'h0A0B0C0D, `Test_All_Bytes,
              `Test_One_Word, `Test_No_Addr_Perr, `Test_No_Data_Perr,
              `Test_No_Master_WS, `Test_No_Target_WS,
              `Test_Devsel_Fast, `Test_No_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
        DO_REF ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h0000000C,
               PCI_COMMAND_MEMORY_WRITE, 32'h0B0C0D0E, `Test_All_Bytes,
              `Test_One_Word, `Test_No_Addr_Perr, `Test_No_Data_Perr,
              `Test_No_Master_WS, `Test_No_Target_WS,
              `Test_Devsel_Fast, `Test_No_Fast_B2B,
              `Test_Target_Normal_Completion, `Test_Expect_No_Master_Abort);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0], Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0],
               32'h08090A0B, `Test_Four_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);

// Target Termination scheme (0,1,2,3,4,5,6,7)
// Normal, Retry 0.5, Stop 1, Retry 1.5, Stop 2, Delayed, Abort 0.5, Abort 1.5
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000000,
               32'h01010101, `Test_Eight_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000020,
               32'h09090909, `Test_Eight_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);

// Do Writes with various termination conditions
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000000,
               32'h99999999, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Retry_Before_First);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000004,
               32'hAAAAAAAA, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Disc_With_First);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h0000000C,
               32'hBBBBBBBB, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Retry_Before_Second);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000014,
               32'hDDDDDDDD, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Disc_With_Second);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000020,
               32'hFFFFFFFF, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Abort_Before_First);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000024,
               32'hA5A5A5A5, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Abort_Before_Second);

// Check that memory contains the right stuff
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000000,
               32'h01010101, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000004,
               32'hAAAAAAAA, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000008,
               32'h03030303, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h0000000C,
               32'hBBBBBBBB, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000010,
               32'h05050505, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000014,
               32'hDDDDDDDD, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000018,
               32'h1E1E1E1E, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h0000001C,
               32'h08080808, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000020,
               32'h09090909, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000024,
               32'hA5A5A5A5, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000028,
               32'h0B0B0B0B, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);

// Do Reads with various termination conditions
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000000,
               32'h99999999, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Retry_Before_First);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000004,
               32'hAAAAAAAA, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Disc_With_First);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h0000000C,
               32'hBBBBBBBB, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Retry_Before_Second);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000014,
               32'hDDDDDDDD, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Disc_With_Second);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000020,
               32'hFFFFFFFF, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Abort_Before_First);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000024,
               32'hA5A5A5A5, `Test_Two_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Abort_Before_Second);

// Test delayed read activity
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000000,
               32'h01010101, `Test_Eight_Words,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],  // Start the Delayed Read
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000000,
               32'hFFFFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Start_Delayed_Read);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],  // read is retried because it doesn't match
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000004,
               32'hFFFFFFFF, `Test_Expect_Delayed_Read_Retry,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A[2:0],  // Write Through even if Delayed Read
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000008,
               32'hA5A5A5A5, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],  // Dismiss the Delayed Read
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000000,
               32'h01010101, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        $display ("Expect Data comparison Error");
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],  // Verify that Read completes
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000004,  // Expect error
               32'hFFFFFFFF, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
        MEM_READ ("MMS_R_SCAN", Master_ID_A[2:0],  // Verify that Write completed
               Target_Base_Addr_A[PCI_BUS_DATA_RANGE:0] + 32'h00000008,
               32'hA5A5A5A5, `Test_One_Word,
               `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
  end
endtask

task exhaustive_config_refs_scan;
  input   alternate_sources;
  input  [2:0] Master_ID_A;
  input  [PCI_BUS_DATA_RANGE:0] Target_Config_Addr_A;
  input  [2:0] Master_ID_B;
  input  [PCI_BUS_DATA_RANGE:0] Target_Config_Addr_B;
  reg    [2:0] Master_ID_A_Now;
  reg    [PCI_BUS_DATA_RANGE:0] Target_Addr_A_Now;
  reg    [2:0] Master_ID_B_Now;
  reg    [PCI_BUS_DATA_RANGE:0] Target_Addr_B_Now;
  reg    [2:0] Master_ID_Temp;
  reg    [PCI_BUS_DATA_RANGE:0] Target_Addr_Temp;
  reg    [1:0] master_wait_states;
  reg    [1:0] devsel_type;
  reg    [1:0] target_wait_states;
  reg    [2:0] target_termination;
  reg     select_read;
  reg    [3:0] burst_size;
  reg    [11:0] j;
  begin
    Master_ID_A_Now[2:0] = Master_ID_A[2:0];
    Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0] = Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0];
    if (alternate_sources)
    begin
      Master_ID_B_Now[2:0] = Master_ID_B[2:0];
      Target_Addr_B_Now[PCI_BUS_DATA_RANGE:0] = Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0];
    end
    else
    begin
      Master_ID_B_Now[2:0] = Master_ID_A[2:0];
      Target_Addr_B_Now[PCI_BUS_DATA_RANGE:0] = Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0];
    end
    for (j = 12'h000; j != 12'h800; j = j + 12'h001)
    begin
      master_wait_states[1:0] = j[6:5];
      devsel_type[1:0] = j[4:3];
      target_wait_states[1:0] = j[8:7];
      target_termination[2:0] = j[2:0];
      select_read = ~j[9];
      burst_size[3:0] = j[10] ? `Test_Two_Words : `Test_One_Word;
      if (select_read)
      begin
        CONFIG_READ  ("CFA_R_SCAN", Master_ID_A_Now[2:0], Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0],
               32'hZZZZZZZZ, burst_size[3:0], // cant check config registers
               {2'h0, master_wait_states[1:0], 4'h0},
               {2'h0, target_wait_states[1:0], 4'h0},
               devsel_type[1:0], target_termination[2:0]);
        if (target_termination[2:0] == `Test_Target_Start_Delayed_Read)
        begin
          CONFIG_READ  ("CFA_R_SCAN", Master_ID_A_Now[2:0],  // complete delayed read
                 Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0], 32'hZZZZZZZZ, burst_size[3:0],
                 {2'h0, master_wait_states[1:0], 4'h0},
                 {2'h0, target_wait_states[1:0], 4'h0},
                 devsel_type[1:0], `Test_Target_Normal_Completion);
        end
        `NO_ELSE;
      end
      else
      begin
        CONFIG_WRITE ("CFA_W_SCAN", Master_ID_A_Now[2:0], Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0],
               32'h12341234, burst_size[3:0],
               {2'h0, master_wait_states[1:0], 4'h0},
               {2'h0, target_wait_states[1:0], 4'h0},
               devsel_type[1:0], target_termination[2:0]);
      end
// Swap source and destination
      Master_ID_Temp[2:0] = Master_ID_A_Now[2:0];
      Target_Addr_Temp[PCI_BUS_DATA_RANGE:0] = Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0];
      Master_ID_A_Now[2:0] = Master_ID_B_Now[2:0];
      Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0] = Target_Addr_B_Now[PCI_BUS_DATA_RANGE:0];
      Master_ID_B_Now[2:0] = Master_ID_Temp[2:0];
      Target_Addr_B_Now[PCI_BUS_DATA_RANGE:0] = Target_Addr_Temp[PCI_BUS_DATA_RANGE:0];
    end
  end
endtask

task exhaustive_mem_refs_scan;
  input   alternate_sources;
  input  [2:0] Master_ID_A;
  input  [PCI_BUS_DATA_RANGE:0] Target_Addr_A;
  input  [2:0] Master_ID_B;
  input  [PCI_BUS_DATA_RANGE:0] Target_Addr_B;
  reg    [2:0] Master_ID_A_Now;
  reg    [PCI_BUS_DATA_RANGE:0] Target_Addr_A_Now;
  reg    [2:0] Master_ID_B_Now;
  reg    [PCI_BUS_DATA_RANGE:0] Target_Addr_B_Now;
  reg    [2:0] Master_ID_Temp;
  reg    [PCI_BUS_DATA_RANGE:0] Target_Addr_Temp;
  reg    [1:0] master_wait_states;
  reg    [1:0] devsel_type;
  reg    [1:0] target_wait_states;
  reg    [2:0] target_termination;
  reg     select_read;
  reg    [3:0] burst_size;
  reg    [11:0] j;
  begin
    Master_ID_A_Now[2:0] = Master_ID_A[2:0];
    Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0] = Target_Addr_A[PCI_BUS_DATA_RANGE:0];
    for (j = 12'h000; j != 12'h800; j = j + 12'h001)
    begin
      MEM_WRITE ("MMS_W_INIT", Master_ID_A_Now[2:0],
               Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0] + {21'h000000, j[5:0], 2'h0},
               {2'b00, j[5:0] + 6'h03, 2'b00, j[5:0] + 6'h02,
                2'b00, j[5:0] + 6'h01, 2'b00, j[5:0] + 6'h00},
               `Test_One_Word, 8'h00, 8'h00,
               `Test_Devsel_Fast, `Test_Target_Normal_Completion);
    end
    if (alternate_sources)
    begin
      Master_ID_B_Now[2:0] = Master_ID_B[2:0];
      Target_Addr_B_Now[PCI_BUS_DATA_RANGE:0] = Target_Addr_B[PCI_BUS_DATA_RANGE:0];
      for (j = 12'h000; j != 12'h040; j = j + 12'h001)
      begin
        MEM_WRITE ("MMS_W_INIT", Master_ID_B_Now[2:0],
                 Target_Addr_B_Now[PCI_BUS_DATA_RANGE:0] + {21'h000000, j[5:0], 2'h0},
                 {2'b00, j[5:0] + 6'h03, 2'b00, j[5:0] + 6'h02,
                  2'b00, j[5:0] + 6'h01, 2'b00, j[5:0] + 6'h00},
                 `Test_One_Word, 8'h00, 8'h00,
                 `Test_Devsel_Fast, `Test_Target_Normal_Completion);
      end
    end
    else
    begin
      Master_ID_B_Now[2:0] = Master_ID_A[2:0];
      Target_Addr_B_Now[PCI_BUS_DATA_RANGE:0] = Target_Addr_A[PCI_BUS_DATA_RANGE:0];
    end

    for (j = 12'h000; j != 12'h800; j = j + 12'h001)
    begin
      master_wait_states[1:0] = j[6:5];
      devsel_type[1:0] = j[4:3];
      target_wait_states[1:0] = j[8:7];
      target_termination[2:0] = j[2:0];
      select_read = ~j[9];
      burst_size[3:0] = j[10] ? `Test_Two_Words : `Test_One_Word;
      if (select_read)
      begin
        MEM_READ  ("MMS_R_SCAN", Master_ID_A_Now[2:0],
               Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0] + {21'h000000, j[7:2], 2'h0},
               {2'b00, j[7:2] + 6'h03, 2'b00, j[7:2] + 6'h02,
                2'b00, j[7:2] + 6'h01, 2'b00, j[7:2] + 6'h00},
               burst_size[3:0],
               {2'h0, master_wait_states[1:0], 4'h0},
               {2'h0, target_wait_states[1:0], 4'h0},
               devsel_type[1:0], target_termination[2:0]);
        if (target_termination[2:0] == `Test_Target_Start_Delayed_Read)
        begin
          MEM_READ  ("MMS_R_SCAN", Master_ID_A_Now[2:0],  // complete delayed read
                 Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0] + {21'h000000, j[7:2], 2'h0},
                 {2'b00, j[7:2] + 6'h03, 2'b00, j[7:2] + 6'h02,
                  2'b00, j[7:2] + 6'h01, 2'b00, j[7:2] + 6'h00},
                 burst_size[3:0],
                 {2'h0, master_wait_states[1:0], 4'h0},
                 {2'h0, target_wait_states[1:0], 4'h0},
                 devsel_type[1:0], `Test_Target_Normal_Completion);
        end
        `NO_ELSE;
      end
      else
      begin
        MEM_WRITE ("MMS_W_SCAN", Master_ID_A_Now[2:0],
               Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0] + {21'h000000, j[7:2], 2'h0},
               {2'b00, j[7:2] + 6'h03, 2'b00, j[7:2] + 6'h02,
                2'b00, j[7:2] + 6'h01, 2'b00, j[7:2] + 6'h00},
               burst_size[3:0],
               {2'h0, master_wait_states[1:0], 4'h0},
               {2'h0, target_wait_states[1:0], 4'h0},
               devsel_type[1:0], target_termination[2:0]);
      end
// Swap source and destination
      Master_ID_Temp[2:0] = Master_ID_A_Now[2:0];
      Target_Addr_Temp[PCI_BUS_DATA_RANGE:0] = Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0];
      Master_ID_A_Now[2:0] = Master_ID_B_Now[2:0];
      Target_Addr_A_Now[PCI_BUS_DATA_RANGE:0] = Target_Addr_B_Now[PCI_BUS_DATA_RANGE:0];
      Master_ID_B_Now[2:0] = Master_ID_Temp[2:0];
      Target_Addr_B_Now[PCI_BUS_DATA_RANGE:0] = Target_Addr_Temp[PCI_BUS_DATA_RANGE:0];
    end
  end
endtask

// fire off tasks in response to top-level test bench
  reg    [2:0] Master_ID_A;
  reg    [PCI_BUS_DATA_RANGE:0] Target_Config_Addr_A;
  reg    [PCI_BUS_DATA_RANGE:0] Target_Base_Addr_A0;
  reg    [PCI_BUS_DATA_RANGE:0] Target_Base_Addr_A1;
  reg    [2:0] Master_ID_B;
  reg    [PCI_BUS_DATA_RANGE:0] Target_Config_Addr_B;
  reg    [PCI_BUS_DATA_RANGE:0] Target_Base_Addr_B0;
  reg    [PCI_BUS_DATA_RANGE:0] Target_Base_Addr_B1;

  initial
  begin
    Master_ID_A = `Test_Master_1;
    Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0] = `TEST_DEVICE_0_CONFIG_ADDR;
    Target_Base_Addr_A0[PCI_BUS_DATA_RANGE:0] = `PCI_BUS_DATA_ZERO;
    Target_Base_Addr_A1[PCI_BUS_DATA_RANGE:0] = `PCI_BUS_DATA_ZERO;
    Master_ID_B = `Test_Master_0;
    Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0] = `TEST_DEVICE_1_CONFIG_ADDR;
    Target_Base_Addr_B0[PCI_BUS_DATA_RANGE:0] = `PCI_BUS_DATA_ZERO;
    Target_Base_Addr_B1[PCI_BUS_DATA_RANGE:0] = `PCI_BUS_DATA_ZERO;

    present_test_name[79:0] <= "Nowhere___";
    test_master_number <= 3'h0;
    test_address[PCI_BUS_DATA_RANGE:0] <= `PCI_BUS_DATA_ZERO;
    test_command <= PCI_COMMAND_RESERVED_READ_4;
    test_data[PCI_BUS_DATA_RANGE:0] <= `PCI_BUS_DATA_ZERO;
    test_byte_enables_l[PCI_BUS_CBE_RANGE:0] <= `Test_All_Bytes;
    test_size <= `Test_One_Word;
    test_make_addr_par_error <= `Test_No_Addr_Perr;
    test_make_data_par_error <= `Test_No_Data_Perr;
    test_master_initial_wait_states <= 4'h0;
    test_master_subsequent_wait_states <= 4'h0;
    test_target_initial_wait_states <= 4'h0;
    test_target_subsequent_wait_states <= 4'h0;
    test_fast_back_to_back <=   `Test_No_Fast_B2B;
    test_target_termination <=  `Test_Target_Normal_Completion;
    test_expect_master_abort <= `Test_Expect_No_Master_Abort;
    test_start <= 1'b0;

    for (waiting = 1'b1; waiting != 1'b0; waiting = waiting)
    begin
      @ (negedge pci_ext_clk or posedge pci_reset_comb) ;
      if (pci_reset_comb)
      begin
        waiting = 1'b0;
        present_test_name[79:0] <= "Reset.....";
      end
      `NO_ELSE;
    end

    for (waiting = 1'b1; waiting != 1'b0; waiting = waiting)
    begin
      @ (negedge pci_ext_clk or negedge pci_reset_comb) ;
      if (~pci_reset_comb)
      begin
        waiting = 1'b0;
        present_test_name[79:0] <= "Initing...";
      end
    `NO_ELSE;
    end

    @ (negedge pci_ext_clk) ;
    @ (negedge pci_ext_clk) ;
    @ (negedge pci_ext_clk) ;

    if (test_sequence == 4'h0)
    begin
`ifdef REPORT_TEST_DEVICE
      $display (" test - Doing a sequence of Reads and Writes ending in Master Aborts");
`endif // REPORT_TEST_DEVICE
      init_config_regs (Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_A0[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_A1[PCI_BUS_DATA_RANGE:0]);
      init_config_regs (Master_ID_B[2:0], Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_B0[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_B1[PCI_BUS_DATA_RANGE:0]);
      do_pause( 16'h0008);

      CONFIG_READ_MASTER_ABORT ("CFG_R_MA_0", Master_ID_A[2:0], `Test_One_Word);
      CONFIG_READ_MASTER_ABORT ("CFG_R_MA_1", Master_ID_A[2:0], `Test_One_Word);
      CONFIG_READ_MASTER_ABORT ("CFG_R_MA_2", Master_ID_B[2:0], `Test_One_Word);
      CONFIG_READ_MASTER_ABORT ("CFG_R_MA_3", Master_ID_B[2:0], `Test_One_Word);
      CONFIG_READ_MASTER_ABORT ("CFG_R_MA_4", Master_ID_A[2:0], `Test_Two_Words);
      CONFIG_READ_MASTER_ABORT ("CFG_R_MA_5", Master_ID_A[2:0], `Test_Two_Words);

      MEM_READ_MASTER_ABORT ("MEM_R_MA_0", Master_ID_B[2:0], `Test_One_Word);
      MEM_READ_MASTER_ABORT ("MEM_R_MA_1", Master_ID_B[2:0], `Test_One_Word);
      MEM_READ_MASTER_ABORT ("MEM_R_MA_2", Master_ID_A[2:0], `Test_One_Word);
      MEM_READ_MASTER_ABORT ("MEM_R_MA_3", Master_ID_A[2:0], `Test_One_Word);
      MEM_READ_MASTER_ABORT ("MEM_R_MA_4", Master_ID_B[2:0], `Test_Two_Words);
      MEM_READ_MASTER_ABORT ("MEM_R_MA_5", Master_ID_B[2:0], `Test_Two_Words);

      do_pause( 16'h0008);

      CONFIG_WRITE_MASTER_ABORT ("CFG_W_MA_0", Master_ID_A[2:0], `Test_One_Word);
      CONFIG_WRITE_MASTER_ABORT ("CFG_W_MA_1", Master_ID_A[2:0], `Test_One_Word);
      CONFIG_WRITE_MASTER_ABORT ("CFG_W_MA_2", Master_ID_B[2:0], `Test_One_Word);
      CONFIG_WRITE_MASTER_ABORT ("CFG_W_MA_3", Master_ID_B[2:0], `Test_One_Word);
      CONFIG_WRITE_MASTER_ABORT ("CFG_W_MA_4", Master_ID_A[2:0], `Test_Two_Words);
      CONFIG_WRITE_MASTER_ABORT ("CFG_W_MA_5", Master_ID_A[2:0], `Test_Two_Words);

      MEM_WRITE_MASTER_ABORT ("MEM_W_MA_0", Master_ID_B[2:0], `Test_One_Word);
      MEM_WRITE_MASTER_ABORT ("MEM_W_MA_1", Master_ID_B[2:0], `Test_One_Word);
      MEM_WRITE_MASTER_ABORT ("MEM_W_MA_2", Master_ID_A[2:0], `Test_One_Word);
      MEM_WRITE_MASTER_ABORT ("MEM_W_MA_3", Master_ID_A[2:0], `Test_One_Word);
      MEM_WRITE_MASTER_ABORT ("MEM_W_MA_4", Master_ID_B[2:0], `Test_Two_Words);
      MEM_WRITE_MASTER_ABORT ("MEM_W_MA_5", Master_ID_B[2:0], `Test_Two_Words);
    end
    else if (test_sequence == 4'h1)
    begin
`ifdef REPORT_TEST_DEVICE
      $display (" test - Varying paramaters one paramater at a time");
`endif // REPORT_TEST_DEVICE
      init_config_regs (Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_A0[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_A1[PCI_BUS_DATA_RANGE:0]);
      init_config_regs (Master_ID_B[2:0], Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_B0[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_B1[PCI_BUS_DATA_RANGE:0]);
      do_pause( 16'h0008);
      vary_one_paramater_at_a_time (Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0],
                                    Target_Base_Addr_A0[PCI_BUS_DATA_RANGE:0],
                                    Master_ID_B[2:0], Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0],
                                    Target_Base_Addr_B0[PCI_BUS_DATA_RANGE:0]);
    end
    else if ( (test_sequence == 4'h2) | (test_sequence == 4'h3) )
    begin
`ifdef REPORT_TEST_DEVICE
      if (test_sequence == 4'h2)
        $display (" test - Doing a sequence of Config Reads and Writes from one master with various Wait States");
      else
        $display (" test - Doing a sequence of Config Reads and Writes from alternating masters with various Wait States");
`endif // REPORT_TEST_DEVICE
      init_config_regs (Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_A0[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_A1[PCI_BUS_DATA_RANGE:0]);
      init_config_regs (Master_ID_B[2:0], Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_B0[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_B1[PCI_BUS_DATA_RANGE:0]);
      do_pause( 16'h0008);
      if (test_sequence == 4'h2)
      begin
        exhaustive_config_refs_scan (1'b0, Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0],
                                           Master_ID_B[2:0], Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0]);
      end
      else
      begin
        exhaustive_config_refs_scan (1'b1, Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0],
                                           Master_ID_B[2:0], Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0]);
      end
    end
    else if ( (test_sequence == 4'h4) | (test_sequence == 4'h5) )
    begin
`ifdef REPORT_TEST_DEVICE
      if (test_sequence == 4'h4)
        $display (" test - Doing a sequence of Memory Reads and Writes from one master with various Wait States");
      else
        $display (" test - Doing a sequence of Memory Reads and Writes from alternating masters with various Wait States");
`endif // REPORT_TEST_DEVICE
      init_config_regs (Master_ID_A[2:0], Target_Config_Addr_A[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_A0[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_A1[PCI_BUS_DATA_RANGE:0]);
      init_config_regs (Master_ID_B[2:0], Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_B0[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_B1[PCI_BUS_DATA_RANGE:0]);
      do_pause( 16'h0008);
      if (test_sequence == 4'hF)
      begin
        exhaustive_mem_refs_scan (1'b0, Master_ID_A[2:0], Target_Base_Addr_A0[PCI_BUS_DATA_RANGE:0],
                                        Master_ID_B[2:0], Target_Base_Addr_B0[PCI_BUS_DATA_RANGE:0]);
      end
      else
      begin
        exhaustive_mem_refs_scan (1'b1, Master_ID_A[2:0], Target_Base_Addr_A0[PCI_BUS_DATA_RANGE:0],
                                        Master_ID_B[2:0], Target_Base_Addr_B0[PCI_BUS_DATA_RANGE:0]);
      end
    end
    else if ( (test_sequence == 4'hF) | (test_sequence == 4'hE ) )
    begin
`ifdef REPORT_TEST_DEVICE
      if (test_sequence == 4'hF)
        $display (" test - Synthesizable interface doing a sequence of Memory Reads and Writes from one master with various Wait States");
      else
        $display (" test - Synthesizable interface doing a sequence of Memory Reads and Writes from alternating masters with various Wait States");
`endif // REPORT_TEST_DEVICE

      MEM_WRITE ("WRITE_SRAM", 3'h7, 32'hDD000000, 32'h04030201,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
      MEM_WRITE ("WRITE_SRAM", 3'h7, 32'hDD000004, 32'h08070605,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
      MEM_WRITE ("WRITE_SRAM", 3'h7, 32'hDD000008, 32'h0C0B0A09,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
      MEM_WRITE ("WRITE_SRAM", 3'h7, 32'hDD00000C, 32'h100F0E0D,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);

      MEM_READ  ("READ_SRAM ", 3'h7, 32'hDD000000, 32'h04030201,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
      MEM_READ  ("READ_SRAM ", 3'h7, 32'hDD000004, 32'h08070605,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
      MEM_READ  ("READ_SRAM ", 3'h7, 32'hDD000008, 32'h0C0B0A09,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
      MEM_READ  ("READ_SRAM ", 3'h7, 32'hDD00000C, 32'h100F0E0D,
               `Test_One_Word, `Test_No_Master_WS, `Test_No_Target_WS,
               `Test_Devsel_Medium, `Test_Target_Normal_Completion);
      do_pause( 16'h0008);

      init_config_regs_self (Target_Base_Addr_A0[PCI_BUS_DATA_RANGE:0],
                             Target_Base_Addr_A1[PCI_BUS_DATA_RANGE:0]);
      do_pause( 16'h0008);
/*
      init_config_regs (Master_ID_B[2:0], Target_Config_Addr_B[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_B0[PCI_BUS_DATA_RANGE:0],
                        Target_Base_Addr_B1[PCI_BUS_DATA_RANGE:0]);
      do_pause( 16'h0008);
      if (test_sequence == 4'hF)
      begin
        exhaustive_mem_refs_scan (1'b0, Master_ID_A[2:0], Target_Base_Addr_A0[PCI_BUS_DATA_RANGE:0],
                                        Master_ID_B[2:0], Target_Base_Addr_B0[PCI_BUS_DATA_RANGE:0]);
      end
      else
      begin
        exhaustive_mem_refs_scan (1'b1, Master_ID_A[2:0], Target_Base_Addr_A0[PCI_BUS_DATA_RANGE:0,
                                        Master_ID_B[2:0], Target_Base_Addr_B0[PCI_BUS_DATA_RANGE:0]);
      end
*/
    end

    test_start <= 1'b0;
    for (i = 0; i < 20; i = i + 1)
    begin
      present_test_name[79:0] <= "Done......";
      @ (posedge pci_ext_clk) ;
    end
    $display ("Total number of errors detected 'h%h",
               total_errors_detected[31:0]);
    $finish;

  end
endmodule

