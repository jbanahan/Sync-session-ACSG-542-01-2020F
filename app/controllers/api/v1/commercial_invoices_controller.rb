require 'api/v1/api_core_module_controller_base'
require 'open_chain/api/v1/commercial_invoice_api_json_generator'

module Api; module V1; class CommercialInvoicesController < Api::V1::ApiCoreModuleControllerBase

  def core_module
    CoreModule::COMMERCIAL_INVOICE
  end

  def json_generator
    OpenChain::Api::V1::CommercialInvoiceApiJsonGenerator.new
  end

  private
  def save_object h
    # Don't use this method as an example of how to write new API controller code for save_object implementations

    # With enough messing around, this should be able to use the more standardizable approach of updating / creating the invoice data
    # via an update_model_field_attributes call...for now, that's just a bit of a pain to backport into this controller method.
    ci = h['id'].blank? ? CommercialInvoice.new : CommercialInvoice.find(h['id'])
    raise StatusableError.new("Cannot update commercial invoice attached to customs entry.", :forbidden) if ci.entry_id
    h['ci_imp_syscode'] = current_user.company.system_code if h['ci_imp_syscode'].blank? && ci.importer.nil? && current_user.company.importer? && !current_user.company.system_code.blank?
    import_fields h, ci, CoreModule::COMMERCIAL_INVOICE
    load_lines ci, h
    ci.errors[:base] << (ci.importer ? "Cannot save invoice for importer #{ci.importer.system_code}." : "Cannot save invoice without importer.") unless ci.can_edit?(current_user)
    ci.save if ci.errors.full_messages.blank?
    ci
  end

  def load_lines ci, h
    if h['commercial_invoice_lines']
      h['commercial_invoice_lines'].each_with_index do |ln, i|
        c_line = ci.commercial_invoice_lines.find {|obj| obj.line_number == ln['cil_line_number'].to_i || obj.id == ln['id'].to_i}
        c_line = ci.commercial_invoice_lines.build(line_number:ln['cil_line_number']) if c_line.nil?
        import_fields ln, c_line, CoreModule::COMMERCIAL_INVOICE_LINE
        ci.errors[:base] << "Line #{i+1} is missing #{ModelField.find_by_uid(:cil_line_number).label}." if c_line.line_number.blank?
        unless ln['commercial_invoice_tariffs'].blank?
          ln['commercial_invoice_tariffs'].each_with_index do |tln, j|
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
