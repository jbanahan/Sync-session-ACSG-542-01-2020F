module OpenChain; module CustomHandler; module Hm; class HmPoLineParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  def initialize custom_file
    @custom_file = custom_file
  end

  # Required for custom file processing
  def process user
    errors = process_excel @custom_file
    body = "H&M PO File '#{@custom_file.attached_file_name}' has finished processing."
    subject = "H&M PO File Processing Completed"
    if !errors.empty?
      subject += " With Errors"
      if errors[:unexpected].presence
        body += "\n\n#{errors[:unexpected].join("\n")}"
        user.messages.create(:subject=>subject, :body=>body)
      else
        body += "\n\n#{errors[:fixable].join("\n")}"
      end
    end
    user.messages.create(:subject=>subject, :body=>body)
    nil
  end

  def can_view?(user)
    user.company.master? && MasterSetup.get.custom_feature?('H&M')
  end

  def process_excel custom_file
    errors = Hash.new{ |h, k| h[k] = [] }
    if  [".xls", ".xlsx"].include? File.extname(custom_file.path).downcase
      begin
        imp_id = Company.where(system_code: "HENNE").first.id
        foreach(custom_file, skip_headers: true) { |row, i| parse_row!(row, i, imp_id, errors)}
      rescue => e
        errors[:unexpected] << "Unrecoverable errors were encountered while processing this file. These errors have been forwarded to the IT department and will be resolved."
        errors[:unexpected] << e.message
        e.log_me
      end
    else
      errors[:fixable] << "No CI Upload processor exists for #{File.extname(custom_file.path).downcase} file types."
    end
    errors
  end

  private

  def parse_row! row, row_num, imp_id, errors
    po_number = text_value(row[0])
    tariff_number = text_value(row[3])
    
    unless po_number =~ /^\d{6}$/
      errors[:fixable] << "PO number has wrong format at row #{row_num + 1}!"
      return
    end

    unless tariff_number =~ /^\d{10}$/
      errors[:fixable] << "Tariff number has wrong format at row #{row_num + 1}!"
      return
    end

    inv_hsh, line_hsh, tariff_hsh = unpack_row(row)
    write_record po_number, imp_id, inv_hsh, line_hsh, tariff_hsh
  end

  def unpack_row row
    inv_hsh = {destination_code: text_value(row[2]), mfid: text_value(row[4]), total_quantity: decimal_value(row[11]), 
               invoice_value_foreign: decimal_value(row[14], decimal_places: 2), docs_received_date: date_value(row[16]), docs_ok_date: date_value(row[17]), 
               issue_codes: text_value(row[18]), rater_comments: text_value(row[19]), total_quantity_uom: 'CTNS'}

    line_hsh = {part_number: text_value(row[1]), country_origin_code: text_value(row[5]), quantity: decimal_value(row[6]), 
                unit_price: decimal_value(row[12], decimal_places: 2), currency: text_value(row[13]), value_foreign: decimal_value(row[15], decimal_places: 2), 
                line_number: 1}
    
    tariff_hsh = {hts_code: text_value(row[3]), classification_qty_1: decimal_value(row[7]), classification_uom_1: text_value(row[8]), 
                  gross_weight: decimal_value(row[10])}

    if row[9].presence && row[9].to_f > 0
      tariff_hsh[:classification_qty_2] = decimal_value(row[9])
      tariff_hsh[:classification_uom_2] = 'KGS'
    end
    [inv_hsh, line_hsh, tariff_hsh]
  end

  def write_record po_number, imp_id, inv_hsh, line_hsh, tariff_hsh
    ActiveRecord::Base.transaction do
      inv = CommercialInvoice.where(importer_id: imp_id)
                             .where(invoice_number: po_number)
                             .order("updated_at DESC")
                             .first_or_initialize(invoice_number: po_number, importer_id: imp_id)
      inv.update_attributes! inv_hsh
      line = inv.commercial_invoice_lines.first_or_initialize
      line.update_attributes! line_hsh
      tariff = line.commercial_invoice_tariffs.first_or_initialize
      tariff.update_attributes! tariff_hsh
    end
  end

end; end; end; end;