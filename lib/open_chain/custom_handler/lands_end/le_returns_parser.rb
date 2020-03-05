require 'open_chain/custom_handler/custom_file_csv_excel_parser'

module OpenChain; module CustomHandler; module LandsEnd; class LeReturnsParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser
  
  def initialize custom_file
    @custom_file = custom_file
  end

  def can_view?(user)
    user.company.master? && MasterSetup.get.custom_feature?("WWW VFI Track Reports")
  end

  def process user
    begin
      file_builder = process_file custom_file
      output_file_name = "#{File.basename(custom_file.attached_file_name, ".*")}.#{file_builder.output_format}"
      Tempfile.open([File.basename(output_file_name, ".*"), file_builder.output_format.to_s]) do |t|
        Attachment.add_original_filename_method t, output_file_name
        file_builder.write t
        OpenMailer.send_simple_html(user.email, "Lands' End Returns File '#{output_file_name}'", "Attached is the Lands' End returns file generated from #{custom_file.attached_file_name}.  Please correct all yellow lines in the attached file and upload corrections to VFI Track.".html_safe, [t]).deliver_now
      end

      user.messages.create subject: "File Processing Complete", body: "Land's End Product Upload processing for file #{custom_file.attached_file_name} is complete."
    rescue => e
      user.messages.create subject: "File Processing Complete With Errors", body: "Unable to process file #{custom_file.attached_file_name} due to the following error:<br>#{e.message}"
    end
    nil
  end

  def process_file custom_file
    xl_builder = nil
    sheet = nil
    row_count = 0
    header_length = 0
    error_style = nil

    foreach(custom_file, skip_headers: false) do |row|
      row_count += 1

      if xl_builder.nil?
        xl_builder, sheet = process_header_row(row)
        header_length = row.length
      else
        output_row, error = process_body_row(row, row_count, header_length)
        styles = style_array(xl_builder, output_row, error)
        xl_builder.add_body_row sheet, output_row, styles: styles
      end
    end

    xl_builder
  end

  private

    def custom_file
      @custom_file
    end

    def process_header_row row
      # Just add the Status and Sequence columns to whatever else is in the headers they supplied us with
      # and then tack on the added product columns as well.
      xl_builder = builder
      sheet = xl_builder.create_sheet("Merged Product Data", headers: (["CSV Line #", "Status", "Sequence"] + row + ["COO", "MID", "HTS_NBR", "COMMENTS"]))
      xl_builder.freeze_horizontal_rows(sheet, 1)

      [xl_builder, sheet]
    end

    def process_body_row row, row_number, row_length
      product = find_product(row)
      mid = find_mid(row)
      tariff = find_tariff(product, row)
      country = country_origin(row)

      error = nil
      if tariff.blank?
        error = "No matching Part Number."
      elsif mid.blank?
        error = "No matching MID."
      elsif country.blank?
        error = "No Country of Origin."
      end

      prefix = [row_number, (error.presence || "Exact Match"), 1]
      suffix = [country, mid, tariff, ""]
      new_row = inflate_to_header_length(row.clone, row_length)
      ensure_row_values(new_row)

      output_row = prefix + new_row + suffix

      [output_row, error.present?]
    end

    def find_product row
      part_number = sku(row)
      return nil if part_number.blank?

      i = importer
      Product.where(unique_identifier: "#{i.system_code}-#{part_number}", importer: i).first
    end

    def sku row
      text_value(row[12]).to_s
    end

    def find_mid row
      factory_code = text_value(row[14])
      return nil if factory_code.blank?

      @mids ||= Hash.new do |h, k|
        h[k] = DataCrossReference.find_mid(k, importer)
      end

      @mids[factory_code]
    end

    def find_tariff product, row
      @us ||= Country.where(iso_code: "US").first

      hts = nil
      if product.present?
        c = product.classifications.find {|c| c.country_id == @us.id}
        t = c.tariff_records.first
        hts = t&.hts_1.to_s
      end

      # It's possible the file itself has the HTS, if so, I think it's valid to use it.
      if hts.blank?
        hts_from_file = text_value(row[18]).to_s.strip.gsub(".", "")
        # It looks like sometimes the HTS is all 0's...if so, ignore those.
        if !hts_from_file.match?(/^0+$/)
          hts = hts_from_file
        end
      end

      hts
    end

    def country_origin row
      text_value(row[19])
    end

    def inflate_to_header_length row, length
      row << nil while row.length < length

      row
    end

    def ensure_row_values row
      # Some of the values from the file should be turned into numeric values, do so here
      # NOTE: The numbers here represent the actual output columns as the values will appear in to the recipient of the file, not 
      # as the came in from the input file.
      row[20] = decimal_value(row[20]) # Quantity
      row[21] = decimal_value(row[21]) # Unit Price
      row[22] = decimal_value(row[22]) # Total
      row[23] = date_value(row[23], date_format: "%d/%m/%Y") # Date Imported To Canada
      row[25] = date_value(row[25], date_format: "%d/%m/%Y") # B3 Date
      row[27] = decimal_value(row[27]) # Duty on Importation
      row[28] = decimal_value(row[28]) # GST On Importation
      row[29] = decimal_value(row[29]) # HTS / PST On Importation
      row[30] = decimal_value(row[30]) # Excise Tax on Importation
      row[31] = integer_value(row[31]) # Days in Canada
      row[32] = date_value(row[32], date_format: "%d/%m/%Y") # Order Date
      row[33] = date_value(row[33], date_format: "%d/%m/%Y") # Date Return Processed

      row
    end

    def importer
      @importer ||= Company.find_by(system_code: "LANDS1")
      raise "'LANDS1' importer not found!" unless @importer
      @importer
    end

    def builder
      XlsxBuilder.new
    end

    def style_array xl_builder, row, error
      styles = nil
      if error
        @error_style ||= xl_builder.create_style(:error, {fg_color: "FF000000", bg_color: "FFFF66"})
        @error_date_style ||= xl_builder.create_style(:date_error, {fg_color: "FF000000", bg_color: "FFFF66", format_code: "YYYY-MM-DD"})
        # These column numbers are 3 off from those defined above due to the prefix columns added by the parser
        date_columns = Set.new([26, 28, 35, 36])
        styles = []
        row.each_with_index do |v, idx|
          styles << (date_columns.include?(idx) ? @error_date_style : @error_style)
        end
      end

      styles
    end

end; end; end; end;