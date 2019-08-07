module OpenChain; class FiscalMonthAssigner
  def self.assign entry
    fiscal_reference = entry.importer.try(:fiscal_reference)
    return if fiscal_reference.blank?

    fiscal_model_field = ModelField.find_by_uid(fiscal_reference)
    entry_fiscal_ref_date = fiscal_model_field.process_export(entry, nil)

    assign_entry(entry, fiscal_model_field, entry_fiscal_ref_date)

    # We should skip any broker invoice marked for deletion
    # This is kinda wonky, but I prefer it here rather than having the entry parsers deal with it
    entry.broker_invoices.each do |bi|
      next if bi.marked_for_destruction? || bi.destroyed?
      assign_brok_inv bi
    end
  end

  private

  def self.assign_entry entry, fiscal_model_field, fiscal_ref_date
    fiscal_attribs = {fiscal_date: nil, fiscal_month: nil, fiscal_year: nil}
    if fiscal_ref_date
      fiscal_month = get_entry_fiscal_month entry, fiscal_model_field, fiscal_ref_date
      entry.fiscal_date = fiscal_month.start_date
      entry.fiscal_month = fiscal_month.month_number
      entry.fiscal_year = fiscal_month.year
    else
      entry.fiscal_date = nil
      entry.fiscal_month = nil
      entry.fiscal_year = nil
    end
  end

  def self.assign_brok_inv invoice
    fiscal_attribs = {fiscal_date: nil, fiscal_month: nil, fiscal_year: nil}
    if invoice.invoice_date
      fiscal_month = get_invoice_fiscal_month(invoice)
      invoice.fiscal_date = fiscal_month.start_date
      invoice.fiscal_month = fiscal_month.month_number
      invoice.fiscal_year = fiscal_month.year
    else
      invoice.fiscal_date = nil
      invoice.fiscal_month = nil
      invoice.fiscal_year = nil
    end
  end

  def self.get_entry_fiscal_month entry, fiscal_model_field, fiscal_ref_date
    # We need to handle date and date time fields differently, for date time fields we need to adjust them to the current date they
    # represent in US East timezone so that they align correctly with the fiscal date's date fields.
    # If we just did a straight compare, the time component of the fiscal date (.ie release date) makes the any straight date comparison
    # fail if the date occurs on the end_date of the fiscal month.
    fiscal_date = fiscal_model_field.data_type == :date ? fiscal_ref_date : fiscal_ref_date.in_time_zone("America/New_York").to_date
    fms = FiscalMonth.where("company_id = ? AND start_date <= ? AND end_date >= ?", entry.importer_id, fiscal_date, fiscal_date).all

    raise "More than one fiscal month found for Entry ##{entry.entry_number} with #{fiscal_model_field.label} #{fiscal_date}." if fms.length > 1
    raise "No fiscal month found for Entry ##{entry.entry_number} with #{fiscal_model_field.label} #{fiscal_date}." if fms.length.zero?
    fms.first
  end

  def self.get_invoice_fiscal_month brok_inv
    fms = FiscalMonth.where("company_id = ? #{} AND start_date <= ? AND end_date >= ?", brok_inv.entry.importer_id, brok_inv.invoice_date, brok_inv.invoice_date).all
    raise "More than one fiscal month found for Broker Invoice ##{brok_inv.invoice_number} with Invoice Date #{brok_inv.invoice_date}." if fms.length > 1
    raise "No fiscal month found for Broker Invoice ##{brok_inv.invoice_number} with Invoice Date #{brok_inv.invoice_date}." if fms.length.zero?
    fms.first
  end
end; end;