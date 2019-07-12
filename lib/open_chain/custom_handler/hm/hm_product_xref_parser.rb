require 'open_chain/custom_handler/custom_file_csv_excel_parser'

# Populates the H&M Product Xref table, which maps part numbers to a couple of description values that need to be
# sent, in combination with other data, to duty calc.
module OpenChain; module CustomHandler; module Hm; class HmProductXrefParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  def initialize custom_file
    @custom_file = custom_file
  end

  def self.valid_file? filename
    ['.XLS','.XLSX', '.CSV'].include? File.extname(filename.upcase)
  end

  def can_view? user
    user.in_group?('hm_product_xref_upload')
  end

  def process user
    errors = []
    begin
      errors = process_file @custom_file
    rescue => e
      errors << "The following fatal error was encountered: #{e.message}"
    ensure
      body = "H&M Product Cross Reference processing for file '#{@custom_file.attached_file_name}' is complete."
      subject = "File Processing Complete"
      unless errors.blank?
        body += "\n\n#{errors.join("\n")}"
        subject += " With Errors"
      end
      user.messages.create(:subject=>subject, :body=>body)
    end
    nil
  end

  private
    def process_file custom_file
      errors = []
      # Skip the first line of the file (header).
      foreach(custom_file, skip_headers:true, skip_blank_lines:true) {|row, row_number|
        begin
          parse_row row
        rescue => e
          errors << "Line #{row_number}: #{e.message}"
        end
      }
      errors
    end

    def parse_row row
      sku = row[0]
      raise "SKU is required." unless !sku.blank?

      color_desc = row[3]
      raise "Color Description is required." unless !color_desc.blank?

      size_desc = row[5]
      raise "Size Description is required." unless !size_desc.blank?

      xref = HmProductXref.where(sku:sku).first_or_create
      xref.color_description = color_desc
      xref.size_description = size_desc
      xref.save!
    end

end;end;end;end