//===========================================================================
// $Id: monitor_pci_interface_host_port.v,v 1.6 2001-06-20 11:25:40 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  Watch and report activity on the Host side of the PCI Request,
//           Response, and Delayed Read Data FIFOs.  Purely a debugging aid.
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
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/1ps

module monitor_pci_interface_host_port (
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
  host_clk
);
// Wires used by the host controller to request action by the pci interface
  input  [31:0] pci_host_request_data;
  input  [3:0] pci_host_request_cbe;
  input  [2:0] pci_host_request_type;
  input   pci_host_request_room_available_meta;
  input   pci_host_request_submit;
  input   pci_host_request_error;
// Wires used by the pci interface to request action by the host controller
  input  [31:0] pci_host_response_data;
  input  [3:0] pci_host_response_cbe;
  input  [3:0] pci_host_response_type;
  input   pci_host_response_data_available_meta;
  input   pci_host_response_unload;
  input   pci_host_response_error;
// Wires used by the host controller to send delayed read data by the pci interface
  input  [31:0] pci_host_delayed_read_data;
  input  [2:0] pci_host_delayed_read_type;
  input   pci_host_delayed_read_room_available_meta;
  input   pci_host_delayed_read_data_submit;
  input   pci_host_delayed_read_data_error;
// Generic host interface wires
  input   host_clk;

  always @(posedge host_clk)
  begin
    if ($time > 0)
    begin
      if (pci_host_request_submit)
      begin
        case (pci_host_request_type[2:0])
        `PCI_HOST_REQUEST_SPARE:
          $display ("Putting Spare Data into Host Request FIFO, at time %t", $time);
        `PCI_HOST_REQUEST_ADDRESS_COMMAND:
          $display ("Putting Command %h and Address 'h%h into Host Request FIFO, at time %t",
                     pci_host_request_cbe[3:0], pci_host_request_data[31:0], $time);
        `PCI_HOST_REQUEST_ADDRESS_COMMAND_SERR:
          $display ("Putting Command %h and Address 'h%h with Parity Error into Host Request FIFO, at time %t",
                     pci_host_request_cbe[3:0], pci_host_request_data[31:0], $time);
        `PCI_HOST_REQUEST_INSERT_WRITE_FENCE:
//      `PCI_HOST_REQUEST_READ_WRITE_CONFIG_REGISTER:
          if (pci_host_request_data[17:16] == 2'b00)
          begin
            $display ("Putting Write Fence into Host Request FIFO, at time %t", $time);
          end
          else
          begin
            $display ("Putting Config Register Ref Read %h, Write %h, Data %h, Address %h into Host Request FIFO, at time %t",
                       pci_host_request_data[17], pci_host_request_data[16],
                       pci_host_request_data[15:8], pci_host_request_data[7:0], $time);
          end
        `PCI_HOST_REQUEST_W_DATA_RW_MASK:
          $display ("Putting Data 'h%h and Mask %h into Host Request FIFO, at time %t",
                     pci_host_request_data[31:0], pci_host_request_cbe[3:0], $time);
        `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST:
          $display ("Putting Data 'h%h and Mask %h Last into Host Request FIFO, at time %t",
                     pci_host_request_data[31:0], pci_host_request_cbe[3:0], $time);
        `PCI_HOST_REQUEST_W_DATA_RW_MASK_PERR:
          $display ("Putting Data 'h%h and Mask %h with Parity Error into Host Request FIFO, at time %t",
                     pci_host_request_data[31:0], pci_host_request_cbe[3:0], $time);
        `PCI_HOST_REQUEST_W_DATA_RW_MASK_LAST_PERR:
          $display ("Putting Data 'h%h and Mask %h Last with Parity Error into Host Request FIFO, at time %t",
                     pci_host_request_data[31:0], pci_host_request_cbe[3:0], $time);
        default:
          $display ("Putting Illegal Type %h into Host Request FIFO, at time %t",
                     pci_host_request_type[2:0], $time);
        endcase
      end
      `NO_ELSE;

      if (pci_host_response_unload)
      begin
        case (pci_host_response_type[3:0])
        `PCI_HOST_RESPONSE_SPARE:
          $display ("Reading Spare Data from Host Response FIFO, at time %t", $time);
        `PCI_HOST_RESPONSE_EXECUTED_ADDRESS_COMMAND:
          $display ("Reading that Command %h and Address 'h%h are complete from Host Response FIFO, at time %t",
                     pci_host_response_cbe[3:0], pci_host_response_data[31:0], $time);
        `PCI_HOST_RESPONSE_REPORT_SERR_PERR_M_T_ABORT:
          begin
            if (pci_host_response_data[31])
            begin
              $display ("Reading PERR Detected from Host Response FIFO, at time %t", $time);
            end
            `NO_ELSE;
            if (pci_host_response_data[30])
            begin
              $display ("Reading SERR Detected from Host Response FIFO, at time %t", $time);
            end
            `NO_ELSE;
            if (pci_host_response_data[29])
            begin
              $display ("Reading Master Abort Detected from Host Response FIFO, at time %t", $time);
            end
            `NO_ELSE;
            if (pci_host_response_data[28])
            begin
              $display ("Reading Target Abort Detected from Host Response FIFO, at time %t", $time);
            end
            `NO_ELSE;
            if (pci_host_response_data[27])
            begin
              $display ("Reading Caused Target Abort from Host Response FIFO, at time %t", $time);
            end
            `NO_ELSE;
            if (pci_host_response_data[24])
            begin
              $display ("Reading Caused PERR from Host Response FIFO, at time %t", $time);
            end
            `NO_ELSE;
            if (pci_host_response_data[18])
            begin
              $display ("Reading Delayed Read Discarded from Host Response FIFO, at time %t", $time);
            end
            `NO_ELSE;
            if (pci_host_response_data[17])
            begin
              $display ("Reading Target Retry or Dsconnect from Host Response FIFO, at time %t", $time);
            end
            `NO_ELSE;
            if (pci_host_response_data[16])
            begin
              $display ("Reading Illegal Command Sequence from Host Response FIFO, at time %t", $time);
            end
            `NO_ELSE;
          end
        `PCI_HOST_RESPONSE_UNLOADING_WRITE_FENCE:
//      `PCI_HOST_RESPONSE_READ_WRITE_CONFIG_REGISTER:
          begin
            if (pci_host_response_data[17:16] == 2'b00)
            begin
              $display ("Reading Write Fence Complete from Host Response FIFO, at time %t", $time);
            end
            else
            begin
              $display ("Reading Config Register Ref Read %h, Write %h, Data %h, Address %h from Host Response FIFO, at time %t",
                         pci_host_response_data[17], pci_host_response_data[16],
                         pci_host_response_data[15:8], pci_host_response_data[7:0], $time);
            end
          end
        `PCI_HOST_RESPONSE_R_DATA_W_SENT:
          $display ("Reading that Data 'h%h and Mask %h is complete from Host Response FIFO, at time %t",
                     pci_host_response_data[31:0], pci_host_response_cbe[3:0], $time);
        `PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST:
          $display ("Reading that Data 'h%h and Mask %h Last is complete from Host Response FIFO, at time %t",
                     pci_host_response_data[31:0], pci_host_response_cbe[3:0], $time);
        `PCI_HOST_RESPONSE_R_DATA_W_SENT_FLUSH:
          $display ("Reading that Data 'h%h and Mask %h PERR is being FLUSHED from Host Response FIFO, at time %t",
                     pci_host_response_data[31:0], pci_host_response_cbe[3:0], $time);
        `PCI_HOST_RESPONSE_R_DATA_W_SENT_LAST_FLUSH:
          $display ("Reading that Data 'h%h and Mask %h Last PERR is being FLUSHED from Host Response FIFO, at time %t",
                     pci_host_response_data[31:0], pci_host_response_cbe[3:0], $time);
        `PCI_HOST_RESPONSE_EXTERNAL_SPARE:
          $display ("Reading that External Master queued a Spare 'h%h, %h, from Host Response FIFO, at time %t",
                     pci_host_response_data[31:0], pci_host_response_cbe[3:0], $time);
        `PCI_HOST_RESPONSE_EXTERNAL_ADDRESS_COMMAND_READ_WRITE:
          $display ("Reading that External Master queued Command %h, Address 'h%h, from Host Response FIFO, at time %t",
                     pci_host_response_cbe[3:0], pci_host_response_data[31:0], $time);
        `PCI_HOST_RESPONSE_EXT_DELAYED_READ_RESTART:
          $display ("Reading that External Master queued Delayed Read Restart, Command %h, Address 'h%h, from Host Response FIFO, at time %t",
                     pci_host_response_cbe[3:0], pci_host_response_data[31:0], $time);
        `PCI_HOST_RESPONSE_EXT_READ_UNSUSPENDING:
          $display ("Reading that External Master Read unsuspending with Mask %h from Host Response FIFO, at time %t",
                     pci_host_response_cbe[3:0], $time);
        `PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK:
          $display ("Reading that External Master queued Write Data 'h%h, Mask %h, from Host Response FIFO, at time %t",
                     pci_host_response_data[31:0], pci_host_response_cbe[3:0], $time);
        `PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST:
          $display ("Reading that External Master queued Write Data 'h%h, Mask %h, Last, from Host Response FIFO, at time %t",
                     pci_host_response_data[31:0], pci_host_response_cbe[3:0], $time);
        `PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_PERR:
          $display ("Reading that External Master queued Write Data 'h%h, Mask %h, Previous PERR, from Host Response FIFO, at time %t",
                     pci_host_response_data[31:0], pci_host_response_cbe[3:0], $time);
        `PCI_HOST_RESPONSE_EXT_W_DATA_RW_MASK_LAST_PERR:
          $display ("Reading that External Master queued Write Data 'h%h, Mask %h, Last, Previous PERR, from Host Response FIFO, at time %t",
                     pci_host_response_data[31:0], pci_host_response_cbe[3:0], $time);
        default:
          $display ("Reading Illegal Type %h from Host Response FIFO, at time %t",
                     pci_host_response_type[3:0], $time);
        endcase
      end
      `NO_ELSE;

      if (pci_host_delayed_read_data_submit)
      begin
        case (pci_host_delayed_read_type[2:0])
        `PCI_HOST_DELAYED_READ_DATA_SPARE:
          $display ("Putting Spare Data into Delayed Read FIFO, at time %t", $time);
        `PCI_HOST_DELAYED_READ_DATA_VALID:
          $display ("Putting Valid Data into Delayed Read FIFO, at time %t",
                     pci_host_delayed_read_data[31:0], $time);
        `PCI_HOST_DELAYED_READ_DATA_VALID_LAST:
          $display ("Putting Valid Last Data into Delayed Read FIFO, at time %t",
                     pci_host_delayed_read_data[31:0], $time);
        `PCI_HOST_DELAYED_READ_DATA_VALID_PERR:
          $display ("Putting Valid PERR Data into Delayed Read FIFO, at time %t",
                     pci_host_delayed_read_data[31:0], $time);
        `PCI_HOST_DELAYED_READ_DATA_VALID_LAST_PERR:
          $display ("Putting Valid Last PERR Data into Delayed Read FIFO, at time %t",
                     pci_host_delayed_read_data[31:0], $time);
        `PCI_HOST_DELAYED_READ_DATA_TARGET_ABORT:
          $display ("Putting Target Abort into Delayed Read FIFO, at time %t", $time);
        default:
          $display ("Putting Illegal Type %h into Delayed Read FIFO, at time %t",
                     pci_host_delayed_read_type[2:0], $time);
        endcase
      end
      `NO_ELSE;

      if (pci_host_request_error)
      begin
        $display ("*** Host Request FIFO reports Error, at time %t", $time);
      end
      `NO_ELSE;
      if (pci_host_response_error)
      begin
        $display ("*** Host Response FIFO reports Error, at time %t", $time);
      end
      `NO_ELSE;
      if (pci_host_delayed_read_data_error)
      begin
        $display ("*** Delayed Read FIFO reports Error, at time %t", $time);
      end
      `NO_ELSE;
    end
  end
endmodule


