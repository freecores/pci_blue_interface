//===========================================================================
// $Id: pci_blue_interface.v,v 1.2 2001-02-23 13:18:35 bbeaver Exp $
//
// Copyright 2001 Blue Beaver.  All Rights Reserved.
//
// Summary:  The top level of the pci_blue_interface.  This module
//           instantiates the Request, Response, and Delayed Read Data FIFOs,
//           as well as the synthesizable PCI Master and PCI Target interfaces.
//           No logic here.
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
// NOTE:  not done yet
//
//===========================================================================

`include "pci_blue_options.vh"
`include "pci_blue_constants.vh"
`timescale 1ns/10ps

module pci_blue_interface (
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
  pci_config_reg_signals_some_error,
  pci_host_sees_pci_reset,
  host_reset_to_PCI_interface,
  host_clk, host_sync_clk,
// Wires used by the PCI State Machine and PCI Bus Combiner to drive the PCI bus
  pci_ad_in_prev,     pci_ad_out_next,     pci_ad_out_en_next,
                      pci_ad_out_oe_comb,
  pci_cbe_l_in_prev,  pci_cbe_l_out_next,  pci_cbe_out_en_next,
                      pci_cbe_out_oe_comb,
  pci_par_in_prev,    pci_par_in_comb,
                      pci_par_out_next,    pci_par_out_oe_comb,
  pci_frame_in_prev,  pci_frame_out_next,  pci_frame_out_oe_comb,
  pci_irdy_in_prev,   pci_irdy_in_comb,
                      pci_irdy_out_next,   pci_irdy_out_oe_comb,
  pci_devsel_in_prev, pci_devsel_out_next, pci_d_t_s_out_oe_comb,
  pci_trdy_in_prev,   pci_trdy_in_comb,
                      pci_trdy_out_next,
  pci_stop_in_prev,   pci_stop_out_next,
  pci_perr_in_prev,   pci_perr_out_next,   pci_perr_out_oe_comb,
  pci_serr_in_prev,                        pci_serr_out_oe_comb,
`ifdef PCI_EXTERNAL_IDSEL
  pci_idsel_in_prev,
`endif // PCI_EXTERNAL_IDSEL
  pci_reset_comb,
  pci_clk, pci_sync_clk
);
// Wires used by the host controller to request action by the pci interface
  input  [31:0] pci_host_request_data;
  input  [3:0] pci_host_request_cbe;
  input  [2:0] pci_host_request_type;
  output  pci_host_request_room_available_meta;
  input   pci_host_request_submit;
  output  pci_host_request_error;
// Wires used by the pci interface to request action by the host controller
  output [31:0] pci_host_response_data;
  output [3:0] pci_host_response_cbe;
  output [3:0] pci_host_response_type;
  output  pci_host_response_data_available_meta;
  input   pci_host_response_unload;
  output  pci_host_response_error;
// Wires used by the host controller to send delayed read data by the pci interface
  input  [31:0] pci_host_delayed_read_data;
  input  [2:0] pci_host_delayed_read_type;
  output  pci_host_delayed_read_room_available_meta;
  input   pci_host_delayed_read_data_submit;
  output  pci_host_delayed_read_data_error;
// Generic host interface wires
  output  pci_config_reg_signals_some_error;
  output  pci_host_sees_pci_reset;
  input   host_reset_to_PCI_interface;
  input   host_clk;
  input   host_sync_clk;  // used only by Synchronizers, and in Synthesis Constraints
// Wires used by the PCI State Machine and PCI Bus Combiner to drive the PCI bus
  input  [31:0] pci_ad_in_prev;
  output [31:0] pci_ad_out_next;
  output  pci_ad_out_en_next;
  output  pci_ad_out_oe_comb;
  input  [3:0] pci_cbe_l_in_prev;
  output [3:0] pci_cbe_l_out_next;
  output  pci_cbe_out_en_next;
  output  pci_cbe_out_oe_comb;
  input   pci_par_in_prev, pci_par_in_comb;
  output  pci_par_out_next, pci_par_out_oe_comb;
  input   pci_frame_in_prev;
  output  pci_frame_out_next, pci_frame_out_oe_comb;
  input   pci_irdy_in_prev, pci_irdy_in_comb;
  output  pci_irdy_out_next, pci_irdy_out_oe_comb;
  input   pci_devsel_in_prev;
  output  pci_devsel_out_next, pci_d_t_s_out_oe_comb;
  input   pci_trdy_in_prev, pci_trdy_in_comb;
  output  pci_trdy_out_next;
  input   pci_stop_in_prev;
  output  pci_stop_out_next;
  input   pci_perr_in_prev;
  output  pci_perr_out_next, pci_perr_out_oe_comb;
  input   pci_serr_in_prev;
  output                     pci_serr_out_oe_comb;
`ifdef PCI_EXTERNAL_IDSEL
  input   pci_idsel_in_prev;
`endif // PCI_EXTERNAL_IDSEL
  input   pci_reset_comb;
  input   pci_clk;
  input   pci_sync_clk;  // used only by Synchronizers, and in Synthesis Constraints

// Double-synchronize the PCI Reset signal into the Host Clock Domain.  The PCI Reset
//   signal must be visible for at least two complete Host interface clocks.
  reg     pci_host_sees_pci_reset;
  wire    pci_reset_sync;
  always @(posedge host_clk)
  begin
    if (host_reset_to_PCI_interface)
    begin
      pci_host_sees_pci_reset <= 1'b0;
    end
    else
    begin
      pci_host_sees_pci_reset <= pci_reset_sync;  // double-synchronize
    end
  end

pci_synchronizer_flop sync_reset_flop (
  .data_in                    (pci_reset_comb),
  .clk_out                    (host_sync_clk),
  .sync_data_out              (pci_reset_sync),
  .async_reset                (host_reset_to_PCI_interface)
);

  wire    target_config_reg_signals_some_error;
pci_synchronizer_flop sync_error_flop (
  .data_in                    (target_config_reg_signals_some_error),
  .clk_out                    (host_sync_clk),
  .sync_data_out              (pci_config_reg_signals_some_error),
  .async_reset                (host_reset_to_PCI_interface)
);

// Wires connecting the Host FIFOs to the PCI Interface
  wire   [2:0] pci_iface_request_type;
  wire   [3:0] pci_iface_request_cbe;
  wire   [31:0] pci_iface_request_data;
  wire    pci_iface_request_data_available_meta;
  wire    pci_iface_request_data_unload, pci_iface_request_error;
  wire   [3:0] pci_iface_response_type;
  wire   [3:0] pci_iface_response_cbe;
  wire   [31:0] pci_iface_response_data;
  wire    pci_iface_response_room_available_meta;
  wire    pci_iface_response_data_load, pci_iface_response_error;
  wire   [2:0] pci_iface_delayed_read_type;
  wire   [31:0] pci_iface_delayed_read_data;
  wire    pci_iface_delayed_read_data_available_meta;
  wire    pci_iface_delayed_read_data_unload, pci_iface_delayed_read_error;
 
// Instantiate the Host_Request_FIFO, from the Host to the PCI Interface
pci_fifo_storage_Nx39 pci_host_request_fifo (
  .reset_flags_async          (host_reset_to_PCI_interface),
  .fifo_mode                  (2'b01),  // NOTE WORKING need to take into consideration `DOUBLE_SYNC_PCI_HOST_SYNCHRONIZERS
  .write_clk                  (host_clk),
  .write_sync_clk             (host_sync_clk),
  .write_submit               (pci_host_request_submit),
  .write_room_available_meta  (pci_host_request_room_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .write_data                 ({pci_host_request_type[2:0],
                                pci_host_request_cbe[3:0],
                                pci_host_request_data[31:0]}),
  .write_error                (pci_host_request_error),
  .read_clk                   (pci_clk),
  .read_sync_clk              (pci_sync_clk),
  .read_remove                (pci_iface_request_data_unload),
  .read_data_available_meta   (pci_iface_request_data_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .read_data                  ({pci_iface_request_type[2:0],
                                pci_iface_request_cbe[3:0],
                                pci_iface_request_data[31:0]}),
  .read_error                 (pci_iface_request_error)
);

// Instantiate the Host_Response_FIFO, from the PCI Interface to the Host
pci_fifo_storage_Nx40 pci_host_response_fifo (
  .reset_flags_async          (host_reset_to_PCI_interface),
  .fifo_mode                  (2'b10),  // NOTE WORKING need to take into consideration `DOUBLE_SYNC_PCI_HOST_SYNCHRONIZERS
  .write_clk                  (pci_clk),
  .write_sync_clk             (pci_sync_clk),
  .write_submit               (pci_iface_response_data_load),
  .write_room_available_meta  (pci_iface_response_room_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .write_data                 ({pci_iface_response_type[3:0],
                                pci_iface_response_cbe[3:0],
                                pci_iface_response_data[31:0]}),
  .write_error                (pci_iface_response_error),
  .read_clk                   (host_clk),
  .read_sync_clk              (host_sync_clk),
  .read_remove                (pci_host_response_unload),
  .read_data_available_meta   (pci_host_response_data_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .read_data                  ({pci_host_response_type[3:0],
                                pci_host_response_cbe[3:0],
                                pci_host_response_data[31:0]}),
  .read_error                 (pci_host_response_error)
);

// Instantiate the Host_Delayed_Read_Data_FIFO, from the Host to the PCI Interface
pci_fifo_storage_Nx35 pci_delayed_read_data_fifo (
  .reset_flags_async          (host_reset_to_PCI_interface),
  .fifo_mode                  (2'b01),  // NOTE WORKING need to take into consideration `DOUBLE_SYNC_PCI_HOST_SYNCHRONIZERS
  .write_clk                  (host_clk),
  .write_sync_clk             (host_sync_clk),
  .write_submit               (pci_host_delayed_read_data_submit),
  .write_room_available_meta  (pci_host_delayed_read_room_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .write_data                 ({pci_host_delayed_read_type[2:0],
                                pci_host_delayed_read_data[31:0]}), 
  .write_error                (pci_host_delayed_read_data_error),
  .read_clk                   (pci_clk),
  .read_sync_clk              (pci_sync_clk),
  .read_remove                (pci_iface_delayed_read_data_unload),
  .read_data_available_meta   (pci_iface_delayed_read_data_available_meta),  // NOTE Needs extra settling time to avoid metastability
  .read_data                  ({pci_iface_delayed_read_type[2:0],
                                pci_iface_delayed_read_data[31:0]}), 
  .read_error                 (pci_iface_delayed_read_error)
);

// Target signals to be combined with Master signals on the way to the PCI IO Pads.
  wire   [31:0] pci_target_ad_out_next;
  wire    pcu_target_ad_en_next,    pci_target_ad_out_oe_comb;
  wire    pci_target_par_out_next,  pci_target_par_out_oe_comb;
  wire    pci_target_perr_out_next, pci_target_perr_out_oe_comb;
  wire    pci_target_serr_out_oe_comb;

// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  wire   [2:0] pci_master_to_target_request_type;
  wire   [3:0] pci_master_to_target_request_cbe;
  wire   [31:0] pci_master_to_target_request_data;
  wire    pci_master_to_target_request_room_available_meta;
  wire    pci_master_to_target_request_data_load;
  wire    pci_master_to_target_request_error;

// Signals from the Master to the Target to set bits in the Status Register.
  wire    master_got_parity_error, master_caused_serr;
  wire    master_got_master_abort, master_got_target_abort;
  wire    master_caused_parity_error;
  wire    master_enable, master_fast_b2b_en, master_perr_enable, master_serr_enable;
  wire   [7:0] master_latency_value;

// Instantiate the Target Interface, which contains the Config Registers
pci_blue_target pci_blue_target (
// Signals driven to control the external PCI interface
  .pci_ad_in_prev             (pci_ad_in_prev[31:0]),
  .pci_target_ad_out_next     (pci_target_ad_out_next[31:0]),
  .pci_target_ad_en_next      (pci_target_ad_en_next),
  .pci_target_ad_out_oe_comb  (pci_target_ad_out_oe_comb),
  .pci_idsel_in_prev          (pci_idsel_in_prev),
  .pci_cbe_l_in_prev          (pci_cbe_l_in_prev[3:0]),
  .pci_par_in_prev            (pci_par_in_prev),
  .pci_par_in_comb            (pci_par_in_comb),
  .pci_target_par_out_next    (pci_target_par_out_next),
  .pci_target_par_out_oe_comb (pci_target_par_out_oe_comb),
  .pci_frame_in_prev          (pci_frame_in_prev),
  .pci_irdy_in_prev           (pci_irdy_in_prev),
  .pci_irdy_in_comb           (pci_irdy_in_comb),
  .pci_devsel_out_next        (pci_devsel_out_next),
  .pci_d_t_s_out_oe_comb      (pci_d_t_s_out_oe_comb),
  .pci_trdy_out_next          (pci_trdy_out_next),
  .pci_stop_out_next          (pci_stop_out_next),
  .pci_perr_in_prev           (pci_perr_in_prev),
  .pci_target_perr_out_next    (pci_target_perr_out_next),
  .pci_target_perr_out_oe_comb (pci_target_perr_out_oe_comb),
  .pci_serr_in_prev            (pci_serr_in_prev),
  .pci_target_serr_out_oe_comb (pci_target_serr_out_oe_comb),
// Host Interface Response FIFO used to ask the Host Interface to service
//   PCI References initiated by an external PCI Master.
// This FIFO also sends status info back from the master about PCI
//   References this interface acts as the PCI Master for.
  .pci_iface_response_type    (pci_iface_response_type[3:0]),
  .pci_iface_response_cbe     (pci_iface_response_cbe[3:0]),
  .pci_iface_response_data    (pci_iface_response_data[31:0]),
  .pci_iface_response_room_available_meta (pci_iface_response_room_available_meta),
  .pci_iface_response_data_load (pci_iface_response_data_load),
  .pci_iface_response_error   (pci_iface_response_error),
// Host Interface Delayed Read Data FIFO used to pass the results of a
//   Delayed Read on to the external PCI Master which started it.
  .pci_iface_delayed_read_type (pci_iface_delayed_read_type[2:0]),
  .pci_iface_delayed_read_data (pci_iface_delayed_read_data[31:0]),
  .pci_iface_delayed_read_data_available_meta (pci_iface_delayed_read_data_available_meta),
  .pci_iface_delayed_read_data_unload (pci_iface_delayed_read_data_unload),
  .pci_iface_delayed_read_error (pci_iface_delayed_read_error),
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  .pci_master_to_target_request_type (pci_master_to_target_request_type[2:0]),
  .pci_master_to_target_request_cbe  (pci_master_to_target_request_cbe[3:0]),
  .pci_master_to_target_request_data (pci_master_to_target_request_data[31:0]),
  .pci_master_to_target_request_room_available_meta
                                (pci_master_to_target_request_room_available_meta),
  .pci_master_to_target_request_data_load (pci_master_to_target_request_data_load),
  .pci_master_to_target_request_error (pci_master_to_target_request_error),
// Signals from the Master to the Target to set bits in the Status Register
  .master_got_parity_error    (master_got_parity_error),
  .master_caused_serr         (master_caused_serr),
  .master_got_master_abort    (master_got_master_abort),
  .master_got_target_abort    (master_got_target_abort),
  .master_caused_parity_error (master_caused_parity_error),
  .master_enable              (master_enable),
  .master_fast_b2b_en         (master_fast_b2b_en),
  .master_perr_enable         (master_perr_enable),
  .master_serr_enable         (master_serr_enable),
  .master_latency_value       (master_latency_value[7:0]),
// Courtesy indication that PCI Interface Config Register contains an error indication
  .target_config_reg_signals_some_error (target_config_reg_signals_some_error),
  .pci_clk                    (pci_clk),
  .pci_reset_comb             (pci_reset_comb)
);

// Master signals to be combined with Target signals on the way to the PCI IO Pads.
  wire   [31:0] pci_master_ad_out_next;
  wire    pcu_master_ad_en_next,    pci_master_ad_out_oe_comb;
  wire    pci_master_par_out_next,  pci_master_par_out_oe_comb;
  wire    pci_master_perr_out_next, pci_master_perr_out_oe_comb;
  wire    pci_master_serr_out_oe_comb;

// Instantiate the Master Interface
pci_blue_master pci_blue_master (
// Signals driven to control the external PCI interface
  .master_req_out             (master_req_out),
  .master_gnt_now             (master_gnt_now),
  .pci_ad_in_prev             (pci_ad_in_prev[31:0]),
  .pci_master_ad_out_next     (pci_master_ad_out_next[31:0]),
  .pci_master_ad_en_next      (pci_master_ad_en_next),
  .pci_master_ad_out_oe_comb  (pci_master_ad_out_oe_comb),
  .pci_cbe_l_out_next         (pci_cbe_l_out_next[3:0]),
  .pci_cbe_out_en_next        (pci_cbe_out_en_next),
  .pci_cbe_out_oe_comb        (pci_cbe_out_oe_comb),
  .pci_par_in_prev            (pci_par_in_prev),
  .pci_par_in_comb            (pci_par_in_comb),
  .pci_master_par_out_next    (pci_master_par_out_next),
  .pci_master_par_out_oe_comb (pci_master_par_out_oe_comb),
  .pci_frame_out_next         (pci_frame_out_next),
  .pci_frame_out_oe_comb      (pci_frame_out_oe_comb),
  .pci_frame_in_prev          (pci_frame_in_prev),
  .pci_irdy_out_next          (pci_irdy_out_next),
  .pci_irdy_out_oe_comb       (pci_irdy_out_oe_comb),
  .pci_devsel_in_prev         (pci_devsel_in_prev),
  .pci_devsel_in_comb         (pci_devsel_in_comb),
  .pci_trdy_in_prev           (pci_trdy_in_prev),
  .pci_trdy_in_comb           (pci_trdy_in_comb),
  .pci_stop_in_prev           (pci_stop_in_prev),
  .pci_stop_in_comb           (pci_stop_in_comb),
  .pci_perr_in_prev           (pci_perr_in_prev),
  .pci_master_perr_out_next    (pci_master_perr_out_next),
  .pci_master_perr_out_oe_comb (pci_master_perr_out_oe_comb),
  .pci_serr_in_prev            (pci_serr_in_prev),
  .pci_master_serr_out_oe_comb (pci_master_serr_out_oe_comb),
// Host Interface Request FIFO used to ask the PCI Interface to initiate
//   PCI References to an external PCI Target.
  .pci_iface_request_type     (pci_iface_request_type[2:0]),
  .pci_iface_request_cbe      (pci_iface_request_cbe[3:0]),
  .pci_iface_request_data     (pci_iface_request_data[31:0]),
  .pci_iface_request_data_available_meta (pci_iface_request_data_available_meta),
  .pci_iface_request_data_unload (pci_iface_request_data_unload),
  .pci_iface_request_error    (pci_iface_request_error),
// Signals from the Master to the Target to insert Status Info into the Response FIFO.
  .pci_master_to_target_request_type (pci_master_to_target_request_type[2:0]),
  .pci_master_to_target_request_cbe  (pci_master_to_target_request_cbe[3:0]),
  .pci_master_to_target_request_data (pci_master_to_target_request_data[31:0]),
  .pci_master_to_target_request_room_available_meta
                                (pci_master_to_target_request_room_available_meta),
  .pci_master_to_target_request_data_load (pci_master_to_target_request_data_load),
  .pci_master_to_target_request_error (pci_master_to_target_request_error),
// Signals from the Master to the Target to set bits in the Status Register
  .master_got_parity_error    (master_got_parity_error),
  .master_caused_serr         (master_caused_serr),
  .master_got_master_abort    (master_got_master_abort),
  .master_got_target_abort    (master_got_target_abort),
  .master_caused_parity_error (master_caused_parity_error),
  .master_enable              (master_enable),
  .master_fast_b2b_en         (master_fast_b2b_en),
  .master_perr_enable         (master_perr_enable),
  .master_serr_enable         (master_serr_enable),
  .master_latency_value       (master_latency_value[7:0]),
  .pci_clk                    (pci_clk),
  .pci_reset_comb             (pci_reset_comb)
);

// Combine signals which are driven by both the Master and the Target
  assign  pci_ad_out_oe_comb =  pci_master_ad_out_oe_comb
                              | pci_target_ad_out_oe_comb;
  assign  pci_par_out_oe_comb = pci_master_par_out_oe_comb
                              | pci_target_par_out_oe_comb;
  assign  pci_frame_out_oe_comb = 1'b0;  // controlled by Master
  assign  pci_irdy_out_oe_comb =  1'b0;  // controlled by Master
// Devsel already controlled by Target
  assign  pci_perr_out_oe_comb = pci_master_perr_out_oe_comb
                               | pci_target_perr_out_oe_comb;
  assign  pci_serr_out_oe_comb = pci_master_serr_out_oe_comb
                               | pci_target_serr_out_oe_comb;
endmodule

