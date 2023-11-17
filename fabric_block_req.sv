// -----------------------------------------------------------------------------
// ---
// ---                  (C) COPYRIGHT 2019-2020 Fresco Logic, Inc.
// ---                            ALL RIGHTS RESERVED
// ---
// ---  This software and the associated documentation are confidential and
// ---  proprietary to Fresco Logic, Inc.  Your use or disclosure of this
// ---  software is subject to the terms and conditions of a written
// ---  license agreement between you, or your company, and Fresco Logic, Inc.
// ---
// ---  The entire notice above must be reproduced on all authorized copies.
// ---
// ---  RCS information:
// ---    Author: Fresco Logic, Inc.
// ---    $LastChangedDate: 2017-12-19 11:15:51 -0800 (Tue, 19 Dec 2017) $
// ---    $Revision: 6814 $
// ---
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module description:
// -----------------------------------------------------------------------------
// --- Fresco Logic, Inc. block-level fabric assembly - Adds redundancy
// -----------------------------------------------------------------------------
// ---
module fabric_block_req
import cm_env::*, cm_cfg::*, mbus_pkg::*, fabric_pkg::*, global_pkg::*;
#(  parameter NBL = 4, NCLS=4, NSLC=4, LATENCY=2,
    parameter PW=Clog2(NBL)               )
(   input                           clk,
    input                           rst_n,
    input   rfab_redund_sel_t       rsel,
    input   [PW-1:0]                sel,
    input   rfab_packet_blk_t       pkt_in_blk,
    output  rfab_packet_blk_t       pkt_out_blk
);

typedef struct packed {rfab_payload_t payload1, payload2; pkt_hdr_t hdr1, hdr2; } rfab_redund_packet_t; // Redundant payload and hdr
typedef rfab_redund_packet_t      [NSLC-1:0] rfab_redund_packet_cls_t;
typedef rfab_redund_packet_cls_t  [NCLS-1:0] rfab_redund_packet_blk_t;
rfab_redund_packet_blk_t pkt_in_redund, pkt_out_redund;

//rfab_redund_sel_t rsel_d;
//delay #(.WD($bits(rfab_redund_sel_t)))  u_rsel(.clk(clk),.rst_n(rst_n),.din(rsel),.dout(rsel_d));


// For requests, we just replicate the entire request, hdr and payload separately
genvar cls, slc;
generate
    for (cls=0; cls<NCLS; cls++) begin : EXPAND_CLS
        for (slc=0; slc<NSLC; slc++) begin : EXPAND_SLC
            assign pkt_in_redund[cls][slc].hdr1    = pkt_in_blk[cls][slc].hdr;     // Replicate header
            assign pkt_in_redund[cls][slc].hdr2    = pkt_in_blk[cls][slc].hdr;     // Replicate header
            assign pkt_in_redund[cls][slc].payload1= pkt_in_blk[cls][slc].payload; // Replicate Payload
            assign pkt_in_redund[cls][slc].payload2= pkt_in_blk[cls][slc].payload; // Replicate Payload
        end // EXPAND_SLC
    end
endgenerate

// Switch the redundand fabric
fabric_mux #(.WD($bits(rfab_redund_packet_cls_t)),.NO_RESET(TRUE), .LATENCY(LATENCY)) u_fabric_mux_req (
    .clk                (clk),
    .rst_n              (TRUE), // Don't reset the fabric
    .sel                (sel),
    .pkt_in_blk         (pkt_in_redund),
    .pkt_out_blk        (pkt_out_redund)
);

// Compress the redundant fabric (remove redundancies)
generate
    for (cls=0; cls<NCLS; cls++) begin : COMPRESS_CLS
        for (slc=0; slc<NSLC; slc++) begin : COMPRESS_SLC
            assign pkt_out_blk[cls][slc].payload   = rsel.faulty_payload   ? pkt_out_redund[cls][slc].payload2 : pkt_out_redund[cls][slc].payload1;
            assign pkt_out_blk[cls][slc].hdr       = rsel.faulty_hdr       ? pkt_out_redund[cls][slc].hdr2     : pkt_out_redund[cls][slc].hdr1;
        end // EXPAND_SLC
    end
endgenerate

endmodule
