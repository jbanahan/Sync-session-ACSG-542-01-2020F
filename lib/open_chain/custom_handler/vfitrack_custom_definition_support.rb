require 'open_chain/custom_handler/custom_definition_support'

module OpenChain; module CustomHandler; module VfitrackCustomDefinitionSupport
  CUSTOM_DEFINITION_INSTRUCTIONS = {
    shp_revision: {label: "Revision", data_type: :integer, module_type: "Shipment", cdef_uid: "shp_revision"},
    shp_invoice_prepared: {label: "Invoice Prepared", data_type: :boolean, module_type: "Shipment", cdef_uid: "shp_invoice_prepared"},
    shpln_priority: {label: "Priority", data_type: :string, module_type: "ShipmentLine", cdef_uid: "shpln_priority"},
    shpln_po: {label:'PO Number',data_type: :string, module_type: 'ShipmentLine', cdef_uid: "shpln_po"},
    shpln_sku: {label:'SKU',data_type: :string, module_type: 'ShipmentLine', cdef_uid: "shpln_sku"},
    shpln_coo: {label:'Country of Origin ISO',data_type: :string, module_type: 'ShipmentLine', cdef_uid: "shpln_coo"},
    shpln_color: {label:'Color',data_type: :string, module_type: 'ShipmentLine', cdef_uid: "shpln_color"},
    shpln_desc: {label:'Description',data_type: :string, module_type: 'ShipmentLine', cdef_uid: "shpln_desc"},
    shpln_received_date: {label:'Received Date',data_type: :date, module_type: 'ShipmentLine', cdef_uid: "shpln_received_date"},
    shpln_uom: {label:'UOM',data_type: :string, module_type: 'ShipmentLine', cdef_uid: "shpln_uom"},
    shpln_size: {label:'Size',data_type: :string, module_type: 'ShipmentLine', cdef_uid: "shpln_size"},
    shpln_invoice_number: {label: "Invoice #", data_type: :string, module_type: "ShipmentLine", cdef_uid: "shpln_invoice_number"},
    prod_part_number: {label: 'Part Number', data_type: :string, module_type: 'Product', cdef_uid: "prod_part_number"},
    prod_country_of_origin: {label: "Country of Origin", data_type: :string, module_type: "Product", cdef_uid: "prod_country_of_origin"},
    prod_countries_of_origin: {label: "Countries of Origin", data_type: :text, module_type: "Product", cdef_uid: "prod_countries_of_origin"},
    prod_earliest_ship_date: {label: "Earliest Ship Date", data_type: :date, module_type: "Product", cdef_uid: "prod_earliest_ship_date"},
    prod_earliest_arrival_date: {label: "Earliest Arrival Date", data_type: :date, module_type: "Product", cdef_uid: "prod_earliest_arrival_date"},
    prod_fda_product: {label: "FDA Product?", data_type: :boolean, module_type: "Product", cdef_uid: "prod_fda_product"},
    prod_fda_product_code: {label: "FDA Product Code", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_product_code"},
    prod_fda_temperature: {label: "FDA Temperature", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_temperature"},
    prod_fda_uom: {label: "FDA Reporting UOM", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_uom"},
    prod_fda_country: {label: "FDA Product Country", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_country"},
    prod_fda_mid: {label: "FDA MID", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_mid"},
    prod_fda_shipper_id: {label: "FDA Shipper ID", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_shipper_id"},
    prod_fda_description: {label: "FDA Description", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_description"},
    prod_fda_establishment_no: {label: "FDA Establishment #", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_establishment_no"},
    prod_fda_container_length: {label: "FDA Container Length", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_container_length"},
    prod_fda_container_width: {label: "FDA Container Width", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_container_width"},
    prod_fda_container_height: {label: "FDA Container Height", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_container_height"},
    prod_fda_contact_name: {label: "FDA Contact Name", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_contact_name"},
    prod_fda_contact_phone: {label: "FDA Contact Phone", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_contact_phone"},
    prod_fda_affirmation_compliance: {label: "FDA Affirmation of Compliance", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_affirmation_compliance"},
    prod_fda_affirmation_compliance_value: {label: "FDA Affirmation of Compliance Value", data_type: :string, module_type: "Product", cdef_uid: "prod_fda_affirmation_compliance_value"},
    prod_import_restricted: {label: "US Import Restricted", data_type: :boolean, module_type: "Product", cdef_uid: "prod_import_restricted"},
    prod_po_numbers: {label: "PO Numbers", data_type: :text, module_type: "Product", cdef_uid: "prod_po_numbers"},
    prod_product_group: {label: "Product Group", data_type: :string, module_type: "Product", cdef_uid: "prod_product_group"},
    prod_season: {label: "Season", data_type: :string, module_type: "Product", cdef_uid: "prod_season"},
    prod_short_description: {label: "Short Description", data_type: :string, module_type: "Product", cdef_uid: "prod_short_description"},
    prod_sku_number: {label: "SKU Number", data_type: :string, module_type: "Product", cdef_uid: "prod_sku_number"},
    prod_suggested_tariff: {label: "Suggested Tariff", data_type: :string, module_type: "Product", cdef_uid: "prod_suggested_tariff"},
    prod_system_classified: {label: "System Classified", data_type: :boolean, module_type: "Product", cdef_uid: "prod_system_classified"},
    prod_units_per_set: {label: "Units Per Set", data_type: :integer, module_type: "Product", cdef_uid: "prod_units_per_set"},
    prod_value_order_number: {label: "Value Order Number", data_type: :string, module_type: "Product", cdef_uid: "prod_value_order_number"},
    prod_value: {label: "Product Value", data_type: :decimal, module_type: "Product", cdef_uid: "prod_value"},
    prod_set: {label: "Set?", data_type: :boolean, module_type: "Product", cdef_uid: "prod_set"},
    prod_vendor_style: {label: "Vendor Style", data_type: :string, module_type: "Product", cdef_uid: "prod_vendor_style"},
    prod_fabric_content: {label: "Fabric Content", data_type: :text, module_type: "Product", cdef_uid: "prod_fabric_content"},
    prod_classified_from_entry: {label: "Classified From Entry", data_type: :string, module_type: "Product", cdef_uid: "prod_classified_from_entry"},
    prod_brand: {label: "Brand", data_type: :string, module_type: "Product", cdef_uid: "prod_brand"},
    prod_department_code: {label: "Department Code", data_type: :string, module_type: "Product", cdef_uid: "prod_department_code"},
    prod_prepack: {label: "Prepack", data_type: :boolean, module_type: "Product", cdef_uid: "prod_prepack" },
    prod_reference_number: {label: "Reference Number", data_type: :string, module_type: "Product", cdef_uid: "prod_reference_number"},
    prod_fish_wildlife: {label:'Fish & Wildlife', data_type: :boolean, module_type: 'Product', cdef_uid: "prod_fish_wildlife"},
    prod_importer_style: {label:'Importer Style', data_type: :string, module_type: 'Product', cdef_uid: "prod_importer_style"},
    prod_suffix_indicator: {label: "Suffix Indicator", data_type: :string, module_type: 'Product', cdef_uid: "prod_suffix_indicator"},
    prod_exception_code: {label: "Exception Code", data_type: :string, module_type: 'Product', cdef_uid: "prod_exception_code"},
    prod_suffix: {label: "Suffix", data_type: :string, module_type: 'Product', cdef_uid: "prod_suffix"},
    prod_comments: {label: "Comments", data_type: :text, module_type: 'Product', cdef_uid: "prod_comments"},
    prod_department_name:{label:'Department Name',data_type: :string, module_type:'Product', cdef_uid: "prod_department_name"},
    prod_pattern: {label:'Pattern',data_type: :string, module_type:'Product', cdef_uid: "prod_pattern"},
    prod_buyer_name: {label:'Buyer Name',data_type: :string, module_type:'Product', cdef_uid: "prod_buyer_name"},
    class_customs_description: {label: "Customs Description", data_type: :string, module_type: "Classification", cdef_uid: "class_customs_description"},
    class_set_type: {label: "Set Type", data_type: :string, module_type: "Classification", cdef_uid: "class_set_type"},
    class_special_program_indicator: {label: "Special Program Indicator", data_type: :string, module_type: "Classification", cdef_uid: "class_special_program_indicator"},
    class_cfia_requirement_id: {label: "CFIA Requirement ID", data_type: :string, module_type: "Classification", cdef_uid: "class_cfia_requirement_id"},
    class_cfia_requirement_version: {label: "CFIA Requirement Version", data_type: :string, module_type: "Classification", cdef_uid: "class_cfia_requirement_version"},
    class_cfia_requirement_code: {label: "CFIA Code", data_type: :string, module_type: "Classification", cdef_uid: "class_cfia_requirement_code"},
    class_ogd_end_use: {label: "OGD End Use", data_type: :string, module_type: "Classification", cdef_uid: "class_ogd_end_use"},
    class_ogd_misc_id: {label: "OGD Misc ID", data_type: :string, module_type: "Classification", cdef_uid: "class_ogd_misc_id"},
    class_ogd_origin: {label: "OGD Origin", data_type: :string, module_type: "Classification", cdef_uid: "class_ogd_origin"},
    class_sima_code: {label: "SIMA Code", data_type: :string, module_type: "Classification", cdef_uid: "class_sima_code"},
    class_classification_notes: {label: "Classification Notes", data_type: :text, module_type: "Classification", cdef_uid: "class_classification_notes"},
    class_stale_classification: {label: "Stale Tariff", data_type: :boolean, module_type: "Classification", cdef_uid: "class_stale_classification"},
    ord_assigned_agent: {label: "Assigned Agent", data_type: :string, module_type: "Order", cdef_uid: "ord_assigned_agent"},
    ord_buyer: {label: "Buyer", data_type: :string, module_type: "Order", cdef_uid: "ord_buyer"},
    ord_buyer_order_number: {label: "Buyer Order Number", data_type: :string, module_type: "Order", cdef_uid: "ord_buyer_order_number"},
    ord_buyer_email: {label:'Buyer Email',data_type: :string, module_type:'Order', cdef_uid: "ord_buyer_email"},
    ord_invoicing_system: {label: "Invoicing System", data_type: :string, module_type: "Order", cdef_uid: "ord_invoicing_system"},
    ord_invoiced: {label: "Invoice Received?", data_type: :boolean, module_type: "Order", cdef_uid: "ord_invoiced"},
    ord_division: {label: "Division", data_type: :string, module_type: "Order", cdef_uid: "ord_division"},
    ord_department: {label: "Department", data_type: :string, module_type: "Order", cdef_uid: "ord_department"},
    ord_revision: {label: "Revision", data_type: :integer, module_type: "Order", cdef_uid: "ord_revision"},
    ord_revision_date: {label: "Revision Date", data_type: :date, module_type: "Order", cdef_uid: "ord_revision_date"},
    ord_selling_agent: {label: "Selling Agent", data_type: :string, module_type: "Order", cdef_uid: "ord_selling_agent"},
    ord_selling_channel: {label: "Selling Channel", data_type: :string, module_type: "Order", cdef_uid: "ord_selling_channel"},
    ord_planned_forwarder: {label: "Planned Forwarder", data_type: :string, module_type: "Order", cdef_uid: "ord_planned_forwarder"},
    ord_type: {label: "Type", data_type: :string, module_type: "Order", cdef_uid: "ord_type"},
    ord_country_of_origin: {label: "Country Of Origin", data_type: :string, module_type: "Order", cdef_uid: "ord_country_of_origin"},
    ord_entry_port_name: {label:'Entry Port Name', data_type: :string, module_type: 'Order', cdef_uid: "ord_entry_port_name"},
    ord_ship_type: {label:'Ship Mode Type', data_type: :string, module_type:'Order', cdef_uid: "ord_ship_type"},
    ord_original_gac_date: {label:'Original GAC Date', data_type: :date, module_type:'Order', cdef_uid: "ord_original_gac_date"},
    ord_destination_code: {label:'Final Destination',data_type: :string,module_type:'Order', cdef_uid: "ord_destination_code"},
    ord_factory_code: {label:'Factory Code', data_type: :string, module_type:'Order', cdef_uid: "ord_factory_code"},
    ord_line_ex_factory_date: {label: "Planned Ex-Factory", data_type: :date, module_type: "OrderLine", cdef_uid: "ord_line_ex_factory_date"},
    ord_line_color: {label: "Color", data_type: :string, module_type: "OrderLine", cdef_uid: "ord_line_color"},
    ord_line_color_description: {label: "Color Description", data_type: :text, module_type: "OrderLine", cdef_uid: "ord_line_color_description"},
    ord_line_department_code: {label: "Department Code", data_type: :string, module_type: "OrderLine", cdef_uid: "ord_line_department_code"},
    ord_line_destination_code: {label: "Destination Code", data_type: :string, module_type: "OrderLine", cdef_uid: "ord_line_destination_code"},
    ord_line_division: {label: "Division", data_type: :string, module_type: "OrderLine", cdef_uid: "ord_line_division"},
    ord_line_estimated_unit_landing_cost: {label: "Estimated Unit Landing Cost", data_type: :decimal, module_type: "OrderLine", cdef_uid: "ord_line_estimated_unit_landing_cost"},
    ord_line_season: {label: "Season", data_type: :string, module_type: "OrderLine", cdef_uid: "ord_line_season"},
    ord_line_size: {label: "Size", data_type: :string, module_type: "OrderLine", cdef_uid: "ord_line_size"},
    ord_line_size_description: {label: "Size Description", data_type: :string, module_type: "OrderLine", cdef_uid: "ord_line_size_description"},
    ord_line_wholesale_unit_price: {label: "Wholesale Unit Price", data_type: :decimal, module_type: "OrderLine", cdef_uid: "ord_line_wholesale_unit_price"},
    ord_line_prepacks_ordered: {label: "Prepacks Ordered", data_type: :decimal, module_type: "OrderLine", cdef_uid: "ord_line_prepacks_ordered"},
    ord_line_units_per_inner_pack: {label: "Units Per Inner Pack", data_type: :decimal, module_type: "OrderLine", cdef_uid: "ord_line_units_per_inner_pack"},
    ord_line_retail_unit_price: {label: "Retail Unit Price", data_type: :decimal, module_type: "OrderLine", cdef_uid: "ord_line_retail_unit_price"},
    ord_line_buyer_item_number: {label: "Buyer Item Number", data_type: :string, module_type: "OrderLine", cdef_uid: "ord_line_buyer_item_number"},
    ord_line_outer_pack_identifier: {label: "Outer Pack Identifier", data_type: :string, module_type: "OrderLine", cdef_uid: "ord_line_outer_pack_identifier"},
    ord_line_design_fee: {label: "Design Fee", data_type: :decimal, module_type: "OrderLine", cdef_uid: "ord_line_design_fee"},
    ord_line_planned_available_date: {label: "Planned Available Date", data_type: :date, module_type: "OrderLine", cdef_uid: "ord_line_planned_available_date"},
    ord_line_planned_dc_date: {label: "Planned Arrival DC Date", data_type: :date, module_type: "OrderLine", cdef_uid: "ord_line_planned_dc_date"},
    ord_line_note: {label:'Note',data_type: :string, module_type:'OrderLine', cdef_uid: "ord_line_note"},
    var_upc: {label: "UPC", data_type: "string", module_type: "Variant", cdef_uid: "var_upc"},
    var_article_number: {label: "Article Number", data_type: :string, module_type: "Variant", cdef_uid: "var_article_number"},
    var_description: {label: "Description", data_type: :string, module_type: "Variant", cdef_uid: "var_description"},
    var_hts_code: {label: "HTS Code", data_type: :string, module_type: "Variant", cdef_uid: "var_hts_code"},
    var_units_per_inner_pack: {label: "Units Per Inner Pack", data_type: :decimal, module_type: "Variant", cdef_uid: "var_units_per_inner_pack"},
    var_color: {label: "Color", data_type: :string, module_type: "Variant", cdef_uid: "var_color"},
    var_size: {label: "Size", data_type: :string, module_type: "Variant", cdef_uid: "var_size"}
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
end; end; end