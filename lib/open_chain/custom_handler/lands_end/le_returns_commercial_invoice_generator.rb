require 'open_chain/custom_handler/custom_file_csv_excel_parser'

module OpenChain; module CustomHandler; module LandsEnd; class LeReturnsCommercialInvoiceGenerator
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  def initialize custom_file
    @custom_file = custom_file
  end

  def can_view?(user)
    user.company.master? && MasterSetup.get.custom_feature?("WWW VFI Track Reports")
  end

  def process user, params
    file_number = params[:file_number]
    xl_builder = process_file(file_number)

    Tempfile.open([file_number, xl_builder.output_format.to_s]) do |t|
      filename = "VFCI_#{file_number}.#{xl_builder.output_format}"
      Attachment.add_original_filename_method t, filename
      t.binmode
      xl_builder.write t
      t.rewind

      OpenMailer.send_simple_html(user.email, "Lands' End CI Load File #{File.basename(filename, ".*")}", "Attached is the Lands' End CI Load file generated from #{custom_file.attached_file_name}.  Please verify the file contents before loading the file into the CI Load program.".html_safe, [t]).deliver_now
    end
  end

  def process_file file_number
    xl_builder = builder
    sheet = create_sheet(xl_builder)

    foreach(custom_file, skip_headers: true) do |row|
      data = extract_ci_load_data(row, file_number)
      xl_builder.add_body_row(sheet, data) unless data.nil?
    end

    xl_builder
  end

  def builder
    XlsxBuilder.new
  end

  def create_sheet builder
    builder.create_sheet "Sheet1", headers: ["File #", "Customer", "Inv#", "Inv Date", "C/O", "Part# / Style", "Pcs", "Mid", "Tariff#", "Cotton Fee y/n", "Value (IV)", "Qty#1", "Qty#2", "Gr wt", "PO#", "Ctns", "FIRST SALE", "ndc/mmv", "dept"]
  end

  private

    def extract_ci_load_data row, file_number
      # Skip lines without styles units and hts
      return nil if row[15].blank? && row[23].blank? && row[39].blank?

      # Invoice # / Weight / Invoice Date / Qty 1 / Qty 2 are all added / adjusted by hand after the file is returned to the user.
      extract = []
      extract[0] = file_number # File #
      extract[1] = "LANDS" # Customer
      extract[2] = "1" # Invoice Number
      extract[3] = nil # Inv Date
      extract[4] = text_value(row[37]).strip # C/O
      extract[5] = text_value(row[15]).strip # Style
      extract[6] = integer_value(row[23]) # Units
      extract[7] = text_value(row[38]).strip # MID
      extract[8] = text_value(row[39]).strip.gsub(".", "").gsub("-", "") # HTS
      extract[9] = nil # Cotton Fee
      extract[10] = decimal_value(row[25]) # Total Value
      extract[11] = 1 # Qty 1
      extract[12] = nil  # Qty 2
      extract[13] = nil # Gross Weight
      extract[14] = text_value(row[9]).strip # PO #
      extract[15] = nil # Cartons
      extract[16] = 0 # First Sale
      extract[17] = nil # ndc/mmv
      extract[18] = nil # dept

      extract
    end

    def custom_file
      @custom_file
    end

end; end; end; end;