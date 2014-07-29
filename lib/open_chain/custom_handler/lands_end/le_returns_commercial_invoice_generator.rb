require 'open_chain/xl_client'

module OpenChain; module CustomHandler; module LandsEnd; class LeReturnsCommercialInvoiceGenerator

  def initialize custom_file
    # Even though we're using CustomFile, we can't really use the CustomFile.parse method on this because we need to pass user
    # params to our parsing process (if there were options on the process method we could do this, but there's not)
    @custom_file = custom_file
  end

  def can_view?(user)
    user.company.master? && (MasterSetup.get.system_code == 'www-vfitrack-net' || Rails.env.development?)
  end

  def generate_and_email user, file_number
    path = @custom_file.attached.path
    send_filename = "VFCI_#{file_number}.xls"
    Tempfile.open(File.basename(path)) do |t|
      Attachment.add_original_filename_method t
      t.original_filename = send_filename
      t.binmode
      process_file path, t, file_number
      t.rewind
      OpenMailer.send_simple_html(user.email, "Lands' End CI Load File #{File.basename(send_filename, ".*")}", "Attached is the Lands' End CI Load file generated from #{File.basename(path)}.  Please verify the file contents before loading the file into the CI Load program.".html_safe, [t]).deliver!
    end
    nil
  end

  def process_file s3_path, write_to, file_number
    counter = -1
    wb = nil
    sheet = nil
    widths = []
    xl_client(s3_path).all_row_values do |row|
      if (counter += 1) == 0
        wb = XlsMaker.create_workbook 'Sheet1', ["File #", "Customer", "Inv#", "Inv Date", "C/O", "Part# / Style", "Pcs", "Mid", "Tariff#", "Cotton Fee y/n", "Value (IV)", "Qty#1", "Qty#2", "Gr wt", "PO#", "Ctns", "FIRST SALE", "ndc/mmv", "dept"]
        sheet = wb.worksheets.find {|s| s.name == 'Sheet1'}
      else
        XlsMaker.add_body_row sheet, counter, extract_ci_load_data(row, file_number), widths
        #TODO Add Drawback Returns tracking
      end
    end

    wb.write write_to
    nil
  end

  private
    def xl_client s3_path
      @xl_client ||= OpenChain::XLClient.new s3_path
    end

    def extract_ci_load_data row, file_number
      extract = []
      extract[0] = file_number # File #
      extract[1] = "LANDS" # Customer
      # Invoice # appears to just be randomly keyed by whatever Ben feels like typing at the moment he runs the existing CI load process.
      extract[2] = "1" # Invoice Number
      extract[3] = nil # Inv Date
      extract[4] = row[21].to_s.strip # C/O
      extract[5] = row[15].to_s.strip # Style
      extract[6] = row[22].to_s.to_i # Units
      extract[7] = row[44].to_s.strip # MID
      extract[8] = row[45].to_s.strip.gsub(".", "") # HTS
      extract[9] = nil # Cotton Fee
      extract[10] = BigDecimal.new(row[23].to_s) # Unit Price
      extract[11] = 1 # Qty 1
      extract[12] = nil  #Qty 2
      extract[13] = nil # Gross Weight
      extract[14] = row[8].to_s.strip # PO #
      extract[15] = nil # Cartons
      extract[16] = 0 # First Sale
      extract[17] = nil # ndc/mmv
      extract[18] = nil # dept

      extract
    end

end; end; end; end;