require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; module LumberCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS = {
    cmp_sap_company: {label: 'SAP Company #', data_type: :string, module_type: 'Company'},
    cmp_merch_coc_review: {label: 'Merch COC Review', data_type: :string, module_type: 'Company'},
    cmp_pc_approved_date: {label: 'PC Approved Date', data_type: :date, module_type: 'Company'},
    cmp_pc_approved_by: {label: 'PC Approved By', data_type: :integer, module_type: 'Company'},
    cmp_dba_name: {label: 'DBA Name', data_type: :string, module_type: 'Company'},
    cmp_default_country_of_origin: {label: 'Default Country of Origin', data_type: :string, module_type: 'Company'},
    cmp_default_handover_port: {label: 'Default Handover Port', data_type: :string, module_type: 'Company'},
    cmp_default_inco_term: {label: 'Default INCO Term', data_type: :string, module_type: 'Company'},
    cmp_requested_payment_method: {label: 'Requested Payment Method', data_type: :string, module_type: 'Company'},
    cmp_approved_payment_method: {label: 'Approved Payment Method', data_type: :string, module_type: 'Company'},
    cmp_us_vendor: {label: 'US Vendor', data_type: :string, module_type: 'Company'},
    cmp_vendor_type: {label: 'Vendor Type', data_type: :string, module_type: 'Company'},
    cmp_industry: {label: 'Industry', data_type: :string, module_type: 'Company'},
    cmp_merch_approved_by: {label: 'Merch Approved By', data_type: :integer, module_type: 'Company'},
    cmp_merch_approved_date: {label: 'Merch Approved Date', data_type: :date, module_type: 'Company'},
    cmp_legal_approved_date: {label: 'Legal Approved Date', data_type: :date, module_type: 'Company'},
    cmp_legal_approved_by: {label: 'Legal Approved By', data_type: :integer, module_type: 'Company'},
    cmp_a_r_contact_name: {label: 'A/R Contact Name', data_type: :string, module_type: 'Company'},
    cmp_a_r_contact_email: {label: 'A/R Contact Email', data_type: :string, module_type: 'Company'},
    cmp_payment_terms: {label: 'Payment Terms', data_type: :string, module_type: 'Company'},
    cmp_purchasing_contact_name: {label: 'Purchasing Contact Name', data_type: :string, module_type: 'Company'},
    cmp_purchasing_contact_email: {label: 'Purchasing Contact Email', data_type: :string, module_type: 'Company'},
    cmp_payment_address: {label: 'Payment Address', data_type: :text, module_type: 'Company'},
    cmp_business_address: {label: 'Business Address', data_type: :text, module_type: 'Company'},
    cmp_primary_phone: {label: 'Primary Phone', data_type: :string, module_type: 'Company'},
    cmp_primary_fax: {label: 'Primary Fax', data_type: :string, module_type: 'Company'},
    cmp_pc_approved_by_executive: {label: 'PC Approved By - Executive', data_type: :integer, module_type: 'Company'},
    cmp_pc_approved_date_executive: {label: 'PC Approved Date - Executive', data_type: :date, module_type: 'Company'},
    cmp_po_blocked: {label: 'PO Blocked', data_type: :boolean, module_type: 'Company'},
    cmp_sap_blocked_status: {label: 'SAP Blocked Status', data_type: :boolean, module_type: 'Company'},
    cmp_vendor_agreement_review: {label: 'Vendor Agreement Review', data_type: :string, module_type: 'Company'},
    plnt_country_iso_code: {label: 'Country ISO Code', data_type: :string, module_type: 'Plant'},
    plnt_sap_coo_abbreviation: {label: 'SAP COO Abbreviation', data_type: :string, module_type: 'Plant'},
    plnt_address: {label: 'Address', data_type: :text, module_type: 'Plant'},
    plnt_region: {label: 'Region', data_type: :string, module_type: 'Plant'},
    plnt_mid_code: {label: 'MID Code', data_type: :string, module_type: 'Plant'},
    plnt_company_name_shipper: {label: 'Company Name - Shipper', data_type: :string, module_type: 'Plant'},
    plnt_company_name_manufacturer: {label: 'Company Name - Manufacturer', data_type: :string, module_type: 'Plant'},
    plnt_factory_contact_name: {label: 'Factory Contact Name', data_type: :string, module_type: 'Plant'},
    plnt_factory_contact_phone: {label: 'Factory Contact Phone', data_type: :string, module_type: 'Plant'},
    plnt_factory_contact_email: {label: 'Factory Contact Email', data_type: :string, module_type: 'Plant'},
    plnt_logistics_contact_name: {label: 'Logistics Contact Name', data_type: :string, module_type: 'Plant'},
    plnt_logistics_contact_phone: {label: 'Logistics Contact Phone', data_type: :string, module_type: 'Plant'},
    plnt_logistics_contact_email: {label: 'Logistics Contact Email', data_type: :string, module_type: 'Plant'},
    plnt_mill_code: {label: 'Mill Code', data_type: :string, module_type: 'Plant'},
    plnt_default_origin_port: {label: 'Default Origin Port', data_type: :string, module_type: 'Plant'},
    plnt_alternate_loading_port: {label: 'Alternate Loading Port', data_type: :string, module_type: 'Plant'},
    plnt_po_notify_email: {label: 'PO Notify Email', data_type: :string, module_type: 'Plant'},
    plnt_merch_approved_by: {label: 'Merch Approved By', data_type: :integer, module_type: 'Plant'},
    plnt_merch_approved_date: {label: 'Merch Approved Date', data_type: :date, module_type: 'Plant'},
    plnt_tc_approved_by: {label: 'TC Approved By', data_type: :integer, module_type: 'Plant'},
    plnt_tc_approved_date: {label: 'TC Approved Date', data_type: :date, module_type: 'Plant'},
    plnt_pc_approved_by: {label: 'PC Approved By', data_type: :integer, module_type: 'Plant'},
    plnt_pc_approved_date: {label: 'PC Approved Date', data_type: :date, module_type: 'Plant'},
    plnt_triage_document_review: {label: 'Triage Document Review', data_type: :string, module_type: 'Plant'},
    plnt_triage_exec_review: {label: 'Triage Document Exec Review', data_type: :string, module_type: 'Plant'},
    plnt_pc_approved_by_executive: {label: 'PC Approved By - Executive', data_type: :integer, module_type: 'Plant'},
    plnt_pc_approved_date_executive: {label: 'PC Approved Date - Executive', data_type: :date, module_type: 'Plant'},
    plnt_insurance_certificate_review: {label: 'Insurance Certificate Review', data_type: :string, module_type: 'Plant'},
    plnt_dc_ship_to: {label: 'DC Ship To', data_type: :string, module_type: 'Plant'},
    ppga_sample_coc_review: {label: 'Sample COC Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_triage_document_review: {label: 'Triage Document Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_carb_certificate_review: {label: 'CARB Certificate Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_ca_01350_addendum_review: {label: 'CA-01350 Addendum Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_scgen_010_review: {label: 'SCGEN-010 Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_ts_130_review: {label: 'TS-130 Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_ts_241_review: {label: 'TS-241 Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_ts_242_review: {label: 'TS-242 Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_ts_282_review: {label: 'TS-282 Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_ts_330_review: {label: 'TS-330 Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_ts_331_review: {label: 'TS-331 Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_ts_342_review: {label: 'TS-342 Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_ts_399_review: {label: 'TS-399 Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_ul_csa_etl_review: {label: 'UL/CSA/ETL Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_fda_certificate_accession_letter_review: {label: 'FDA Certificate & Accession Letter Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_ca_battery_charger_system_cert_review: {label: 'CA Battery Charger System Cert Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_formaldehyde_test_review: {label: 'Formaldehyde Test Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_phthalate_test_review: {label: 'Phthalate Test Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_heavy_metal_test_review: {label: 'Heavy Metal Test Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_lead_cadmium_test_review: {label: 'Lead & Cadmium Test Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_lead_paint_review: {label: 'Lead Paint Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_msds_review: {label: 'MSDS Review', data_type: :string, module_type: 'PlantProductGroupAssignment'},
    ppga_merch_approved_by: {label: 'Merch Approved By', data_type: :integer, module_type: 'PlantProductGroupAssignment'},
    ppga_merch_approved_date: {label: 'Merch Approved Date', data_type: :date, module_type: 'PlantProductGroupAssignment'},
    ppga_qa_approved_by: {label: 'QA Approved By', data_type: :integer, module_type: 'PlantProductGroupAssignment'},
    ppga_qa_approved_date: {label: 'QA Approved Date', data_type: :date, module_type: 'PlantProductGroupAssignment'},
    ppga_pc_approved_by: {label: 'PC Approved By', data_type: :integer, module_type: 'PlantProductGroupAssignment'},
    ppga_pc_approved_date: {label: 'PC Approved Date', data_type: :date, module_type: 'PlantProductGroupAssignment'},
    ppga_pc_approved_by_executive: {label: 'PC Approved By - Executive', data_type: :integer, module_type: 'PlantProductGroupAssignment'},
    ppga_pc_approved_date_executive: {label: 'PC Approved Date - Executive', data_type: :date, module_type: 'PlantProductGroupAssignment'},
    prod_old_article: {label: 'Old Article #', data_type: :string, module_type: 'Product'},
    prod_overall_thickness: {label: 'Overall Thickness', data_type: :string, module_type: 'Product', read_only: true},
    prod_merch_cat: {label: "Merch Category", data_type: :string, module_type: 'Product', read_only: true},
    prod_merch_cat_desc: {label: "Merch Category Description", data_type: :string, module_type: 'Product', read_only: true},
    prod_sap_extract: {label:'SAP Extract Date', data_type: :datetime, module_type: 'Product'},
    class_proposed_hts: {label: "Proposed HTS", data_type: :string, module_type: "Classification"},
    class_customs_description: {label: "Customs Description", data_type: :string, module_type: "Classification"},
    prodven_risk: {label:'Risk',data_type: :string, module_type:'ProductVendorAssignment'},
    pva_pc_approved_by: {label: 'PC Approved By', data_type: :integer, module_type: 'PlantVariantAssignment'},
    pva_pc_approved_date: {label: 'PC Approved Date', data_type: :datetime, module_type: 'PlantVariantAssignment'},
    ord_assigned_agent: {label: 'Assigned Agent', data_type: :string, module_type: 'Order', read_only: true},
    ord_avail_to_prom_date: {label: 'Availabe To Promise Date', data_type: :date, module_type: 'Order', read_only: true},
    ord_sap_extract: {label:'SAP Extract Date', data_type: :datetime, module_type: 'Order'},
    ord_type: {label: 'Order Type', data_type: :string, module_type: 'Order'},
    ord_buyer_name: {label: 'Buyer Name', data_type: :string, module_type: 'Order'},
    ord_buyer_phone: {label: 'Buyer Phone', data_type: :string, module_type: 'Order'},
    ord_country_of_origin: {label: 'Country of Origin', data_type: :string, module_type: 'Order'},
    ord_dhl_push_date: {label: "DHL PO Push Date", data_type: :date, module_type: "Order", read_only: true},
    ord_planned_expected_delivery_date: {label: "Planned Expected Delivery Date", data_type: :date, module_type: "Order", read_only:true},
    ord_planned_handover_date: {label: "Planned Handover Date", data_type: :date, module_type: "Order"},
    ord_qa_hold_by: {label: "QA Hold By", data_type: :integer, module_type:'Order', is_user:true, read_only: true},
    ord_qa_hold_date: {label: "QA Hold Date", data_type: :datetime, module_type:'Order', read_only:true},
    ord_sap_vendor_handover_date: {label: 'SAP Vendor Handover Date', data_type: :date, module_type: "Order", read_only: true},
    ord_ship_confirmation_date: {label: "Ship Confirmation Date", data_type: :date, module_type: "Order", read_only:true},
    ord_cancel_date: {label: "Cancelled Date", data_type: :date, module_type: "Order", read_only: true},
    ordln_pc_approved_by:  {label: 'PC Approved By', data_type: :integer, module_type: 'OrderLine'},
    ordln_pc_approved_date: {label: 'PC Approved Date', data_type: :datetime, module_type: 'OrderLine'},
    ordln_pc_approved_by_executive:  {label: 'PC Approved By - Executive', data_type: :integer, module_type: 'OrderLine'},
    ordln_pc_approved_date_executive: {label: 'PC Approved Date - Executive', data_type: :datetime, module_type: 'OrderLine'},
    ordln_qa_approved_by: {label: 'QA Approved By', data_type: :integer, module_type: 'OrderLine', read_only: true, is_user: true},
    ordln_qa_approved_date: {label: 'QA Approved DAte', data_type: :datetime, module_type: 'OrderLine', read_only: true},
    var_recipe: {label: 'Recipe', data_type: :text, module_type: 'Variant'}
  }

  def self.included(base)
    base.extend(::OpenChain::CustomHandler::CustomDefinitionSupport)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def prep_custom_definitions fields
      prep_custom_defs fields, CUSTOM_DEFINITION_INSTRUCTIONS
    end
  end
end; end; end; end
