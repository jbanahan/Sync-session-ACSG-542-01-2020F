require 'open3'
require 'zip'
require 'open_chain/s3'
require 'open_chain/tariff_finder'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module JCrew; class JCrewReturnsParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  ProductData ||= Struct.new(:product_id, :hts, :qty, :price, :total_price, :coo, :description, :po)

  def initialize custom_file
    @custom_file = custom_file
    @cdefs = self.class.prep_custom_definitions [:prod_import_restricted]
  end

  def self.can_view? user
    MasterSetup.get.custom_feature?("WWW VFI Track Reports") && user.company.master?
  end

  def can_view? user
    self.class.can_view? user
  end

  def process user
    errors = []
    results = {}
    begin
      results = parse_and_send @custom_file, user
    rescue
      errors << "Unrecoverable errors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."
      raise
    ensure
      body = "JCrew Returns File '#{@custom_file.attached_file_name}' has finished processing.  You should receive an email with the results shortly."

      subject = "JCrew Returns Processing Complete"
      if !errors.blank?  || (results[:bad_row_count] && results[:bad_row_count] > 0)
        subject += " With Errors"

        body += "\n\n#{errors.join("\n")}" unless errors.blank?
      end

      user.messages.create(:subject=>subject, :body=>body)
    end
    nil
  end

  def parse_and_send custom_file, user
    OpenChain::S3.download_to_tempfile(custom_file.bucket, custom_file.path, original_filename: File.basename(custom_file.path)) do |file|
      Tempfile.open([File.basename(file.path, ".*"), File.extname(file.path)]) do |dest_file|
        if parse_uploaded_file(file, dest_file)
          dest_file.rewind
          filename = output_filename(custom_file.attached_file_name)
          Attachment.add_original_filename_method dest_file, filename
          OpenMailer.send_simple_html(user.email, "JCrew Returns File #{filename}", "Attached is the processed J Crew Returns file.", [dest_file]).deliver_now
        end
      end
    end
  end

  def parse_uploaded_file file, dest_file, raise_on_unexpected_files = true
    case File.extname(file.path).downcase
    when ".csv", ".txt"
      parse_csv_file file, dest_file
    when ".pdf"
      parse_pdf_file file, dest_file
    when ".zip"
      parse_zip_file file, dest_file
    else
      raise "Unexpected file type found for file #{File.basename(file.original_filename)}" if raise_on_unexpected_files
      nil
    end
  end

  def parse_pdf_file file, dest_file
    dest_file << convert_pdf_to_csv_layout(file.path)
    dest_file.flush

    true
  end

  def parse_csv_file file, dest_file
    # We're turning off quoting because these JCrew files are totally screwed up in their quoting, so we have to manually try and fix them
    # See clean_up_unquoted_data
    csv = CSV.new(file, col_sep: "|", quote_char: "\x00")
    csv.each do |row|
      row = clean_up_unquoted_data row

      style = row[4]

      next if style.blank?

      result = tariff_info style

      dest_file << (row + [result[:hts], result[:mfid], result[:coo]]).to_csv
    end
    dest_file.flush
    true
  end


  # What we're doing here is extracting out all the parsable files from the zip, parsing them, and then zipping the 
  # parsed versions of the files back into a zip file into the given IO object
  def parse_zip_file source_file, dest_file
    # Techincally, we should be able to use the write_buffer method of Zip::OutputStream to directly write to the dest_file
    # There appears to be a bug w/ zip that prevents that from happening.  So, we'll write to it via the path.
    Zip::OutputStream.open(dest_file.path) do |zip_os|
      Zip::File.open_buffer(source_file) do |zip_file|
        zip_file.each do |entry|
          # Cheat, only handle filenames we know will work
          if [".csv", ".txt", ".pdf", ".zip"].include? File.extname(entry.name)
            Tempfile.open([File.basename(entry.name, ".*"), File.extname(entry.name)]) do |zip_output|
              zip_output.binmode
              # Extract the zip entry to the given tempfile
              write_zip_entry_to_file entry, zip_output
              zip_output.rewind

              parsed_output_name = output_filename(entry.name)

              # Create a tempfile for the parser to write it's output to, which we'll then insert into the zip file stream we're building
              Tempfile.open([File.basename(parsed_output_name, ".*"), File.extname(parsed_output_name)]) do |parse_output|
                parse_output.binmode


                parse_uploaded_file zip_output, parse_output
                parse_output.rewind

                # Now write the data that was parsed back into the zip file we're creating..
                zip_os.put_next_entry(parsed_output_name)
                zip_os.write(parse_output.read(Zip::Decompressor::CHUNK_SIZE)) until parse_output.eof?
              end
            end
          end
        end
      end
    end

    true
  end

  private
    def write_zip_entry_to_file entry, file
      entry.get_input_stream do |input|
        file.write(input.read(Zip::Decompressor::CHUNK_SIZE, '')) until input.eof?
      end
      file.flush
    end

    def output_filename source_filename
      ext = case File.extname(source_filename).downcase
            when ".csv", ".txt", ".pdf"
              ".csv"
            when ".zip"
              ".zip"
            else
              File.extname(source_filename)
            end

      File.basename(source_filename, ".*") + ext
    end


    def convert_pdf_to_csv_layout file_path
      pdf_text = convert_pdf_to_text(file_path)
      convert_pdf_text_to_csv_layout(pdf_text)
    end

    def convert_pdf_to_text file_path
      # Utilize the command line program 'pdftotext' to extract text from the pdf..requires Xpdf/Poppler to be installed.
      cmd = ["pdftotext", "-layout", "-enc", "UTF-8", "-eol", "unix", file_path, "-"]
      std_out, std_err, status = Open3.capture3 *cmd

      raise "An error occurred trying to extract text from the file #{File.basename(file_path)}: #{std_err}" unless status.success?

      std_out
    end

    def convert_pdf_text_to_csv_layout pdf_text
      CSV.generate(write_headers:true, row_sep: "\n", headers: ["Product ID", "COO", "HTS", "Description", "PO", "Qty", "Price", "Total Price", "Prior HTS", "Prior MID", "Prior COO"]) do |csv|
        extract_product_data_from_pdf_text(pdf_text).each do |p|
          row = []
          row << p.product_id
          row << p.coo
          row << p.hts
          row << p.description
          row << p.po
          row << p.qty
          row << p.price
          row << p.total_price

          result = tariff_info p.product_id
          row << result[:hts]
          row << result[:mfid]
          row << result[:coo]

          csv << row
        end
      end
    end

    def extract_product_data_from_pdf_text pdf_text
      products = []
      headers = true
      current_product = nil
      counter = 0
      pdf_text.lines.each do |line|
        counter += 1
        split_line = line.split(/\s{2,}/)

        if split_line[0] =~ /\A\s*Number of/i && split_line[1] =~ /\A\s*Type of/i
          headers = false
        end

        next if headers

        if split_line[0] =~ /^\d{1,4}(?!\-)$/

          if current_product
            products << current_product
          end

          current_product = ProductData.new
          # Apparently from time to time the description is going to be missing,
          # account for that.
          if split_line.length >= 6
            current_product.product_id = split_line[1].to_s.strip
            current_product.description = split_line[2].to_s.strip
            current_product.qty = split_line[3][0..-4].to_s.strip.to_i
            current_product.price = split_line[4].to_s.strip.to_f
            current_product.total_price = split_line[5].to_s.strip.to_f
          else
            current_product.product_id = split_line[1].to_s.strip
            current_product.qty = split_line[2][0..-4].to_s.strip.to_i
            current_product.price = split_line[3].to_s.strip.to_f
            current_product.total_price = split_line[4].to_s.strip.to_f
          end
          
        else 
          if split_line[1] && split_line[1].upcase.start_with?("HS:")
            current_product.hts = split_line[1][4..-1].to_s.strip
          end

          if split_line[2] && split_line[2].upcase.start_with?("COUNTRY OF ORIGIN:")
            current_product.coo = split_line[2][19..-1].to_s.strip
          end

          if split_line[1] && split_line[1].upcase.start_with?("COUNTRY OF ORIGIN:")
            current_product.coo = split_line[1][19..-1].to_s.strip
          end

          if split_line[1] && split_line[1].upcase.start_with?("PO:")
            current_product.po = split_line[1][4..-1].to_s.strip
          end
        end
      end

      if current_product
        products << current_product
      end

      products
    end

    def tariff_info style
      @tariff_cache ||= {}
      @tariff_finder ||= OpenChain::TariffFinder.new("US", Company.with_customs_management_number(['J0000','JCREW']).to_a)
      tyle = style[0..4]
      style = style.rjust(5, "0")

      results = @tariff_cache[style]
      unless results
        # Crew has some "restricted" styles that they don't re-import into the country, check if this style is on that list
        restricted = Product.joins(:custom_values).where(unique_identifier: "JCREW-#{style}", custom_values: {custom_definition_id: @cdefs[:prod_import_restricted].id}).first

        if restricted && restricted.custom_value(@cdefs[:prod_import_restricted])
          results = {mfid: 'RESTRICTED', hts: 'RESTRICTED', coo: 'RESTRICTED'}
        else
          tariff = @tariff_finder.find_by_style style
          results = {mfid: "", hts: "", coo: ""}
          if tariff
            results[:mfid] = tariff.mid
            results[:hts] = tariff.hts_code
            results[:coo] = tariff.country_origin_code
          end
        end

        @tariff_cache[style] = results
      end
      
      results
    end

    def clean_up_unquoted_data row
      # This cleans up any quotes with leading or trailing spaces, which causes the ruby parser to puke (stupidly, even if it's technically not to csv spec)
      row.each_with_index do |v, x|
        row[x] = (v.to_s.gsub /(\A\s*")|("\s*\z)/, "").strip
      end

      row
    end

end; end; end; end;