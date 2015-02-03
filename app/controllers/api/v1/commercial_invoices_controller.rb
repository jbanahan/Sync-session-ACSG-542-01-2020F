require 'api/v1/api_core_module_controller_base'

module Api; module V1; class CommercialInvoicesController < Api::V1::ApiCoreModuleControllerBase

  def initialize
    super(OpenChain::Api::ApiEntityJsonizer.new( blank_if_nil:true))
  end

  def core_module
    CoreModule::COMMERCIAL_INVOICE
  end

  def index
    render_search CoreModule::COMMERCIAL_INVOICE
  end
  def create
    do_create CoreModule::COMMERCIAL_INVOICE
  end
  def update
    do_update CoreModule::COMMERCIAL_INVOICE
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

  private
  def save_object h
    # Don't use this method as an example of how to write new API controller code for save_object implementations

    # With enough messing around, this should be able to use the more standardizable approach of updating / creating the invoice data 
    # via an update_model_field_attributes call...for now, that's just a bit of a pain to backport into this controller method.
    ci = h['id'].blank? ? CommercialInvoice.new : CommercialInvoice.find(h['id'])
    raise StatusableError.new("Cannot update commercial invoice attached to customs entry.",:forbidden) if ci.entry_id
    h['ci_imp_syscode'] = current_user.company.system_code if h['ci_imp_syscode'].blank? && ci.importer.nil? && current_user.company.importer? && !current_user.company.system_code.blank?
    import_fields h, ci, CoreModule::COMMERCIAL_INVOICE
    load_lines ci, h
    ci.errors[:base] << (ci.importer ? "Cannot save invoice for importer #{ci.importer.system_code}." : "Cannot save invoice without importer.") unless ci.can_edit?(current_user)
    ci.save if ci.errors.full_messages.blank?
    ci
  end

  def load_lines ci, h
    if h['commercial_invoice_lines']
      h['commercial_invoice_lines'].each_with_index do |ln,i|
        c_line = ci.commercial_invoice_lines.find {|obj| obj.line_number == ln['cil_line_number'].to_i || obj.id == ln['id'].to_i}
        c_line = ci.commercial_invoice_lines.build(line_number:ln['cil_line_number']) if c_line.nil?
        import_fields ln, c_line, CoreModule::COMMERCIAL_INVOICE_LINE
        ci.errors[:base] << "Line #{i+1} is missing #{ModelField.find_by_uid(:cil_line_number).label}." if c_line.line_number.blank?
        unless ln['commercial_invoice_tariffs'].blank?
          ln['commercial_invoice_tariffs'].each_with_index do |tln,j|
            hts = tln['cit_hts_code']
            ct = c_line.commercial_invoice_tariffs.find {|t| t.hts_code == hts}
            ct = c_line.commercial_invoice_tariffs.build(hts_code:hts) if ct.nil?
            import_fields tln, ct, CoreModule::COMMERCIAL_INVOICE_TARIFF
          end
        end
      end
    end
  end

  
end; end; end