//===========================================================================
// $Id: small_dual_port_sram_lib.v,v 1.1 2001-09-02 11:32:42 bbeaver Exp $
//
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// synchronizer_flop                                            ////
////                                                              ////
//// This file is part of the general opencores effort.           ////
//// <http://www.opencores.org/cores/misc/>                       ////
////                                                              ////
//// Module Description:                                          ////
////                                                              ////
//// This library provides a 16-bit dual-port-SRAM.               ////
////                                                              ////
//// If a target device library has a component which is          ////
////   especially well suited to perform this function, it should ////
////   be instantiated by name in this file.  Otherwise, the      ////
////   behaviorial version of this module will be used.           ////
////                                                              ////
//// To Do:                                                       ////
//// Nothing                                                      ////
////                                                              ////
//// Author(s):                                                   ////
//// - anynomous                                                  ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2001 Authors and OPENCORES.ORG                 ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE. See the GNU Lesser General Public License for more  ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from <http://www.opencores.org/lgpl.shtml>                   ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
// CVS Revision History
//
// $Log: not supported by cvs2svn $
// Revision 1.1  2001/09/02 11:32:02  Blue Beaver
// no message
//
//

`timescale 1ns/1ps

// A dual-port SRAM.  This SRAM must latch the address for both the read
//   port and the write port on the rising edge of the corresponding clock.
// Enables must also be latched on the rising edge.
// Write data is latched on the same rising edge as it's associated address
//   and chip enable.
// Data out comes some time after the rising clock edge in which Read_Enable
//   is asserted.
// If Read_Enable is NOT asserted, the SRAM returns garbage.
module dual_port_sync_sram_16x1_no_hold (
  write_clk, write_capture_data,
  write_address, write_data,
  read_clk, read_enable,
  read_address, read_data
);

  input   write_clk, write_capture_data;
  input  [3:0] write_address;
  input   write_data;
  input   read_clk, read_enable;
  input  [3:0] read_address;
  output  read_data;

`ifdef USE_VENDOR_SUPPLIED_DUAL_PORT_x16_SRAM_PRIMITIVE
`else  // USE_VENDOR_SUPPLIED_DUAL_PORT_x16_SRAM_PRIMITIVE

// store 16 bits of state
  reg     PCI_Fifo_Mem [0:15];  // address values, not bits in address

// write port
  always @(posedge write_clk)
  begin
    if (write_capture_data)
    begin
      PCI_Fifo_Mem[write_address[3:0]] <= write_data;
    end
    `NO_ELSE;  // can't do blah <= blah, because address may be unknown
  end

// Xilinx 4000 series and newer FPGAs contain a dual-port SRAM primitive with
//   synchronous write and asynchronous read.  Latch the read address to make
//   this primitive behave like a synchronous read SRAM
// read port
  reg    [3:0] latched_read_data;
  always @(posedge read_clk)
  begin
    latched_read_data <= read_enable
                       ? PCI_Fifo_Mem[read_address[3:0]]
                       : 1'bX;
  end

  assign  read_data = latched_read_data;
`endif  // USE_VENDOR_SUPPLIED_DUAL_PORT_x16_SRAM_PRIMITIVE
endmodule

// A dual-port SRAM.  This SRAM must latch the address for both the read
//   port and the write port on the rising edge of the corresponding clock.
// Enables must also be latched on the rising edge.
// Write data is latched on the same rising edge as it's associated address
//   and chip enable.
// Data out comes some time after the rising clock edge in which Read_Enable
//   is asserted.
// If Read_Enable is NOT asserted, the previous read data comes out.
module dual_port_sync_sram_16x1_no_hold (
  write_clk, write_capture_data,
  write_address, write_data,
  read_clk, read_enable,
  read_address, read_data
);

  input   write_clk, write_capture_data;
  input  [3:0] write_address;
  input   write_data;
  input   read_clk, read_enable;
  input  [3:0] read_address;
  output  read_data;

`ifdef FIFOS_ARE_MADE_FROM_FLOPS
`else  // FIFOS_ARE_MADE_FROM_FLOPS
`endif  // FIFOS_ARE_MADE_FROM_FLOPS

`ifdef USE_VENDOR_SUPPLIED_DUAL_PORT_x16_SRAM_PRIMITIVE
`else  // USE_VENDOR_SUPPLIED_DUAL_PORT_x16_SRAM_PRIMITIVE

// store 16 bits of state
  reg     PCI_Fifo_Mem [0:15];  // address values, not bits in address

// write port
  always @(posedge write_clk)
  begin
    if (write_capture_data)
    begin
      PCI_Fifo_Mem[write_address[3:0]] <= write_data;
    end
    `NO_ELSE;  // can't do blah <= blah, because address may be unknown
  end

// Xilinx 4000 series and newer FPGAs contain a dual-port SRAM primitive with
//   synchronous write and asynchronous read.  Latch the read address to make
//   this primitive behave like a synchronous read SRAM
// read port
  reg    [3:0] latched_read_data;
  always @(posedge read_clk)
  begin
    latched_read_data <= read_enable
                       ? PCI_Fifo_Mem[read_address[3:0]]
                       : latched_read_data;
  end

  assign  read_data = latched_read_data;
`endif  // USE_VENDOR_SUPPLIED_DUAL_PORT_x16_SRAM_PRIMITIVE
endmodule

