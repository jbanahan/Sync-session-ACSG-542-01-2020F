module OpenChain; class FiscalMonthAssigner
  def self.assign entry
    fiscal_reference = entry.importer.try(:fiscal_reference)
    return if fiscal_reference.blank?  
    entry_fiscal_ref_date = ModelField.find_by_uid(fiscal_reference).process_export(entry, nil)
    assign_entry(entry, entry_fiscal_ref_date)
    entry.broker_invoices.each { |bi| assign_brok_inv bi }
  end

  private

  def self.assign_entry entry, fiscal_ref_date
    fiscal_attribs = {fiscal_date: nil, fiscal_month: nil, fiscal_year: nil}
    if fiscal_ref_date.presence
      fiscal_month = get_entry_fiscal_month entry, fiscal_ref_date
      fiscal_attribs = {fiscal_date: fiscal_month.start_date, fiscal_month: fiscal_month.month_number, fiscal_year: fiscal_month.year}
    end
    entry.update_attributes! fiscal_attribs
  end

  def self.assign_brok_inv invoice
    fiscal_attribs = {fiscal_date: nil, fiscal_month: nil, fiscal_year: nil}
    if invoice.invoice_date.presence
      fiscal_month = get_invoice_fiscal_month(invoice)
      fiscal_attribs = {fiscal_date: fiscal_month.start_date, fiscal_month: fiscal_month.month_number, fiscal_year: fiscal_month.year}
    end
    invoice.update_attributes! fiscal_attribs
  end

  def self.get_entry_fiscal_month entry, fiscal_ref_date
    fms = FiscalMonth.where("company_id = #{entry.importer_id} AND start_date <= '#{fiscal_ref_date}' AND end_date >= '#{fiscal_ref_date}'").all
    raise "More than one fiscal month found for entry ##{entry.entry_number}" if fms.length > 1
    raise "No fiscal month found for entry ##{entry.entry_number}" if fms.length.zero?
    fms.first
  end

  def self.get_invoice_fiscal_month brok_inv
    fms = FiscalMonth.where("company_id = #{brok_inv.entry.importer_id} AND start_date <= '#{brok_inv.invoice_date}' AND end_date >= '#{brok_inv.invoice_date}'").all
    raise "More than one fiscal month found for broker invoice ##{brok_inv.invoice_number}" if fms.length > 1
    raise "No fiscal month found for broker invoice ##{brok_inv.invoice_number}" if fms.length.zero?
    fms.first
  end
end; end;