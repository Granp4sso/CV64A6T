// Author: Valerio Di Domenico, University of Naples Federico II
// Date: 28.05.2025

// Description: This module contains PMP, MPT for data requests and a memory protocol converter
//              from MEM protocol to DCACHE

`include "uninasoc_mem.svh" 
import mpt_pkg::*;

module mpu_data_if
    import ariane_pkg::*;
    # (
        parameter config_pkg::cva6_cfg_t CVA6Cfg  = config_pkg::cva6_cfg_empty,
        parameter type icache_areq_t              = logic,
        parameter type exception_t                = logic,
        parameter type dcache_req_i_t             = logic,
        parameter type dcache_req_o_t             = logic    
    )
    (
        input logic clk_i,
        input logic rst_ni,

        // pmp_data_if signals
        input icache_areq_t icache_areq_i,
        output icache_areq_t icache_areq_o,
        input [CVA6Cfg.VLEN-1:0] icache_fetch_vaddr_i, 
        input logic lsu_valid_i, 
        input logic [CVA6Cfg.PLEN-1:0] lsu_paddr_i,  
        input logic [CVA6Cfg.VLEN-1:0] lsu_vaddr_i, 
        input exception_t lsu_exception_i,  
        input logic lsu_is_store_i, 
        output logic lsu_valid_o,  
        output logic [CVA6Cfg.PLEN-1:0] lsu_paddr_o,  
        output exception_t lsu_exception_o,  
        input riscv::priv_lvl_t priv_lvl_i,
        input logic v_i,
        input riscv::priv_lvl_t ld_st_priv_lvl_i,
        input logic ld_st_v_i,
        input riscv::pmpcfg_t [avoid_neg(CVA6Cfg.NrPMPEntries-1):0] pmpcfg_i,
        input logic [avoid_neg(CVA6Cfg.NrPMPEntries-1):0][CVA6Cfg.PLEN-3:0] pmpaddr_i,

        // MPTW of the Store Unit
        input logic flush_i,
        input logic ptw_store_enable_i,                  
        input spa_t_u spa_i,                       
        input logic addr_store_valid_i,                  
        input mmpt_reg_t mmpt_store_reg_i,               
        output logic store_access_page_fault_o,           
        output page_format_fault_e store_format_error_o, 
        output logic ptw_store_busy_o,                   
        output logic ptw_store_valid_o,                  
        output plb_entry_t plb_entry_store_o,            
        output logic allow_store_o,

        // MPTW of the Load Unit
        input logic ptw_load_enable_i, 
        input logic addr_load_valid_i,      
        input mmpt_reg_t mmpt_load_reg_i,
        output logic load_access_page_fault_o,
        output page_format_fault_e load_format_error_o,
        output logic ptw_load_busy_o,                   
        output logic ptw_load_valid_o,                  
        output plb_entry_t plb_entry_load_o,            
        output logic allow_load_o,

        // Data cache request out - CACHES from MPTW LOAD UNIT
        input dcache_req_o_t req_port_i_mptw_load,
        // Data cache request in - CACHES MPTW LOAD UNIT
        output dcache_req_i_t req_port_o_mptw_load,
        // Data cache request out - CACHES from MPTW STORE UNIT
        input dcache_req_o_t req_port_i_mptw_store,
        // Data cache request in - CACHES MPTW STORE UNIT
        output dcache_req_i_t req_port_o_mptw_store   
    );

    `DECLARE_MEM_BUS(m_load,CVA6Cfg.CVA6ConfigXlen);
    `DECLARE_MEM_BUS(m_store, CVA6Cfg.CVA6ConfigXlen);

generate
  if (CVA6Cfg.SMMPT) begin : gen_mptw_load
    // ------------------
    // MPT used by LOAD unit
    // ------------------ 
    mpt_top #(
    ) i_mptw_load (
        .clk_i,
        .rst_ni,
        .flush_i,
        .ptw_enable_i           (ptw_load_enable_i),
        .spa_i,
        .addr_valid_i           (addr_load_valid_i),
        .mmpt_reg_i             (mmpt_load_reg_i),
        .access_type_i          (riscv::ACCESS_READ),
        .m_mem_req              (m_load_mem_req),
        .m_mem_gnt              (m_load_mem_gnt),            
        .m_mem_valid            (m_load_mem_valid),
        .m_mem_addr             (m_load_mem_addr),
        .m_mem_rdata            (m_load_mem_rdata),
        .m_mem_wdata            (m_load_mem_wdata),
        .m_mem_we               (m_load_mem_we),
        .m_mem_be               (m_load_mem_be),
        .m_mem_error            (m_load_mem_error),
        .access_page_fault_o    (load_access_page_fault_o),
        .format_error_o         (load_format_error_o),
        .ptw_busy_o             (ptw_load_busy_o),
        .ptw_valid_o            (ptw_load_valid_o),
        .plb_entry_o            (plb_entry_load_o),
        .allow_o                (allow_load_o)
    );


    // ------------------
    // MEM to DCACHE protocol converter for MPTW of the Load Unit
    // ------------------    
    mem_to_dcache_converter #(
        .CVA6Cfg                (CVA6Cfg),
        .dcache_req_i_t         (dcache_req_i_t),
        .dcache_req_o_t         (dcache_req_o_t)
    ) i_mem_dcache_adp_load(
        .clk_i,
        .rst_ni,
        .s_mem_req              (m_load_mem_req),
        .s_mem_gnt              (m_load_mem_gnt),            
        .s_mem_valid            (m_load_mem_valid),
        .s_mem_addr             (m_load_mem_addr),
        .s_mem_rdata            (m_load_mem_rdata),
        .s_mem_wdata            (m_load_mem_wdata),
        .s_mem_we               (m_load_mem_we),
        .s_mem_be               (m_load_mem_be),
        .s_mem_error            (m_load_mem_error),
        .req_port_i             (req_port_i_mptw_load),
        .req_port_o             (req_port_o_mptw_load)
    );
  end else begin
    assign load_access_page_fault_o = 1'b0;
    assign load_format_error_o = NO_ERROR;
    assign ptw_load_busy_o = 1'b0;
    assign ptw_load_valid_o = 1'b0;
    assign plb_entry_load_o = 72'b0;
    assign allow_load_o = 1'b0;
  end
endgenerate

generate
    if(CVA6Cfg.SMMPT) begin : gen_mptw_store
        // ------------------
        // MPT used by STORE unit
        // ------------------
        mpt_top # (
        ) i_mptw_store (
            .clk_i,
            .rst_ni,
            .flush_i,
            .ptw_enable_i           (ptw_store_enable_i),
            .spa_i,    
            .addr_valid_i           (addr_store_valid_i),
            .mmpt_reg_i             (mmpt_store_reg_i),
            .access_type_i          (riscv::ACCESS_WRITE),
            .m_mem_req              (m_store_mem_req),
            .m_mem_gnt              (m_store_mem_gnt),
            .m_mem_valid            (m_store_mem_valid),
            .m_mem_addr             (m_store_mem_addr),
            .m_mem_rdata            (m_store_mem_rdata),
            .m_mem_wdata            (m_store_mem_wdata),
            .m_mem_we               (m_store_mem_we),
            .m_mem_be               (m_store_mem_be),
            .m_mem_error            (m_store_mem_error),
            .access_page_fault_o    (store_access_page_fault_o),          
            .format_error_o         (store_format_error_o),          
            .ptw_busy_o             (ptw_store_busy_o),
            .ptw_valid_o            (ptw_store_valid_o),
            .plb_entry_o            (plb_entry_store_o),          
            .allow_o                (allow_store_o)
        );

    // ------------------
    // MEM to DCACHE protocol converter for MPTW of the Store Unit
    // ------------------
    mem_to_dcache_converter #(
        .CVA6Cfg                (CVA6Cfg),
        .dcache_req_i_t         (dcache_req_i_t),
        .dcache_req_o_t         (dcache_req_o_t)
    ) i_mem_dcache_adp_store(
        .clk_i,
        .rst_ni,
        .s_mem_req              (m_store_mem_req),
        .s_mem_gnt              (m_store_mem_gnt),
        .s_mem_valid            (m_store_mem_valid),
        .s_mem_addr             (m_store_mem_addr),
        .s_mem_rdata            (m_store_mem_rdata),
        .s_mem_wdata            (m_store_mem_wdata),
        .s_mem_we               (m_store_mem_we),
        .s_mem_be               (m_store_mem_be),
        .s_mem_error            (m_store_mem_error),
        .req_port_i             (req_port_i_mptw_store),
        .req_port_o             (req_port_o_mptw_store)
    );
    end else begin
    assign store_access_page_fault_o = 1'b0;
    assign store_format_error_o = NO_ERROR;
    assign ptw_store_busy_o = 1'b0;
    assign ptw_store_valid_o = 1'b0;
    assign plb_entry_store_o = 72'b0;
    assign allow_store_o = 1'b0;
  end
endgenerate
    // ------------------
    // PMP
    // ------------------
    pmp_data_if #(
      .CVA6Cfg                  (CVA6Cfg),
      .icache_areq_t            (icache_areq_t),
      .exception_t              (exception_t)
    ) i_pmp_data_if (
        .clk_i,
        .rst_ni,
        .icache_areq_i,
        .icache_areq_o,
        .icache_fetch_vaddr_i,
        .lsu_valid_i,
        .lsu_paddr_i,
        .lsu_vaddr_i,
        .lsu_exception_i,
        .lsu_is_store_i,
        .lsu_valid_o,
        .lsu_paddr_o,
        .lsu_exception_o,
        .priv_lvl_i,
        .v_i,
        .ld_st_priv_lvl_i,
        .ld_st_v_i,
        .pmpcfg_i,
        .pmpaddr_i            
    );

endmodule