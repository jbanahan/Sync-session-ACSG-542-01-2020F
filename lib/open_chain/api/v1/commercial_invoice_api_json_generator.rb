require 'open_chain/api/v1/api_json_controller_adapter'

module OpenChain; module Api; module V1; class CommercialInvoiceApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    jsonizer = (jsonizer || OpenChain::Api::ApiEntityJsonizer.new(blank_if_nil:true))
    super(core_module: CoreModule::COMMERCIAL_INVOICE, jsonizer: jsonizer)
  end

  #needed for index
  def obj_to_json_hash ci
    headers_to_render = limit_fields([:ci_invoice_number,
      :ci_invoice_date,
      :ci_mfid,
      :ci_imp_syscode,
      :ci_currency,
      :ci_invoice_value_foreign,
      :ci_vendor_name,
      :ci_invoice_value,
      :ci_gross_weight,
      :ci_total_charges,
      :ci_exchange_rate,
      :ci_total_quantity,
      :ci_total_quantity_uom,
      :ci_docs_received_date,
      :ci_docs_ok_date,
      :ci_issue_codes,
      :ci_rater_comments,
      :ci_destination_code,
      :ci_updated_at
    ])
    line_fields_to_render = limit_fields([:cil_line_number,:cil_po_number,:cil_part_number,
      :cil_units,:cil_value,:ent_unit_price,:cil_uom,
      :cil_country_origin_code,:cil_country_export_code,
      :cil_value_foreign,:cil_currency
    ])
    tariff_fields_to_render = limit_fields([
      :cit_hts_code,
      :cit_entered_value,
      :cit_spi_primary,
      :cit_spi_secondary,
      :cit_classification_qty_1,
      :cit_classification_uom_1,
      :cit_classification_qty_2,
      :cit_classification_uom_2,
      :cit_classification_qty_3,
      :cit_classification_uom_3,
      :cit_gross_weight,
      :cit_tariff_description
    ])

    to_entity_hash(ci, headers_to_render + line_fields_to_render + tariff_fields_to_render)
  end

end; end; end; end;