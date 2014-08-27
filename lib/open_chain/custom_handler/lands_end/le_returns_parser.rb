require 'open_chain/custom_handler/lands_end/le_custom_definition_support'
require 'open_chain/s3'

module OpenChain; module CustomHandler; module LandsEnd; class LeReturnsParser
  include OpenChain::CustomHandler::LandsEnd::LeCustomDefinitionSupport

  def initialize custom_file
    @custom_file = custom_file
    @cdefs = self.class.prep_custom_definitions [:part_number, :suffix_indicator, :exception_code, :suffix, :comments]
  end

  def can_view?(user)
    user.company.master? && (MasterSetup.get.system_code == 'www-vfitrack-net' || Rails.env.development?)
  end

  def process user
    path = @custom_file.attached.path
    Tempfile.open(File.basename(path)) do |t|
      Attachment.add_original_filename_method t
      t.original_filename = File.basename(path, ".*") + " Returns.xls"
      t.binmode
      download_and_parse path, t
      t.rewind
      OpenMailer.send_simple_html(user.email, "Lands' End Returns File '#{t.original_filename}'", "Attached is the Lands' End returns file generated from #{File.basename(path)}.  Please correct all colored lines in the attached file and upload corrections to VFI Track.".html_safe, [t]).deliver!
    end
    nil
  end

  def download_and_parse s3_path, write_to
    # CustomFiles are always in production bucket regardless of environment
    OpenChain::S3.download_to_tempfile(OpenChain::S3.bucket_name(:production), s3_path) do |f|
      parse f.path, write_to
    end
    nil
  end

  def parse in_path, out_io
    xl_counter = -1
    csv_counter = 0
    wb = nil
    sheet = nil
    column_widths = []
    header_length = nil
    CSV.foreach(in_path) do |row|
      csv_counter += 1
      if (xl_counter == -1)
        # Just add the Status and Sequence columns to whatever else is in the headers they supplied us with
        # and then tack on the added product columns as well.
        header_length = row.size
        wb = XlsMaker.create_workbook 'Merged Product Data', (["CSV Line #", "Status", "Sequence"] + row + ["SUFFIX_IND", "EXCEPTION_CD", "SUFFIX", "COO", "FACTORY_NBR", "Factory Name", "Phys Addr Line 1", "Phys Addr Line 2", "Phys Addr Line 3", "Phys City", "MID", "HTS_NBR", "COMMENTS"])
        sheet = wb.worksheets.find {|s| s.name == 'Merged Product Data'}
        xl_counter += 1
      else
        # Just ensure the file itself maintains internal integrity (ie looks like a block) if one or two rows have no info towards the end of the columns
        my_row = inflate_to_header_length row, header_length
        output = process_product_row my_row, csv_counter
        output[:rows].each do |p|
          XlsMaker.add_body_row sheet, (xl_counter += 1), p, column_widths, false, format: format_for_status(output[:status], p[2])
        end
      end
    end

    wb.write out_io
    nil
  end

  private

    def inflate_to_header_length row, length
      row << nil while row.length < length

      row
    end

    def format_for_status status, internal_row_counter
      format = nil
      case status
      when :no_coo
        format = (@no_coo_format ||= Spreadsheet::Format.new pattern_fg_color: :yellow, pattern: 1)
      when :no_product
        format = (@no_product_format ||= Spreadsheet::Format.new pattern_fg_color: :orange, pattern: 1)
      when :multiple_factories
        if internal_row_counter > 1
          # Darker Green
          format = (@multiple_factories_2_format ||= Spreadsheet::Format.new pattern_fg_color: :xls_color_49, pattern: 1)
        else
          # Light Green
          format = (@multiple_factories_1_format ||= Spreadsheet::Format.new pattern_fg_color: :xls_color_42, pattern: 1)
        end
      when :multiple_hts
        if internal_row_counter > 1
          # Darker Blue
          format = (@multiple_hts_2_format ||= Spreadsheet::Format.new pattern_fg_color: :xls_color_32, pattern: 1)
        else
          # Light Blue
          format = (@multiple_hts_1_format ||= Spreadsheet::Format.new pattern_fg_color: :xls_color_36, pattern: 1)
        end
      end

      format
    end

    def process_product_row row, csv_row_count
      data = matching_product_data row[13].to_s.strip, row[19].to_s.strip
      output = {status: data[:status], rows: []}
      if data[:status] == :no_product
        output[:rows] << (["No matching Part Number", 1] + row)
      elsif data[:status] == :no_coo
        output[:rows] << (["No matching Country of Origin", 1] + row)
      elsif data[:status] == :ok
        output[:rows] << (["Exact Match", 1] + row + data[:product_data].first)
      else
        output_status = (data[:status] == :multiple_factories) ? "Multiple Factories" : "Multiple HTS #s"
        counter = 0
        data[:product_data].each do |p|
          output[:rows] << ([output_status, (counter+=1)] + row + p)
        end
      end

      rows = []
      output[:rows].each do |r|
        rows << translate_values([csv_row_count] + r)
      end
      output[:rows] = rows

      output
    end

    def matching_product_data part_number, country_origin
      @importer ||= Company.where(system_code: 'LERETURNS').importers.first
      raise "Missing Lands End Importer account." unless @importer

      products = Product.where(importer_id: @importer.id).
                  joins("INNER JOIN custom_values cv ON cv.customizable_id = products.id AND cv.customizable_type = 'Product' AND cv.custom_definition_id = #{@cdefs[:part_number].id} AND cv.string_value = #{Product.sanitize(part_number)}").
                  all
      
      if products.size == 0
        {status: :no_product, product_data: []}
      else
        # At this point we're now just determining which of the possibly many product records should be utilized.
        info = extract_matching_factory_hts_info products, country_origin

        # If there are exactly one HTS and one Factory found then everything is great.
        factories = info.map {|k, v| v[:factories]}.flatten.uniq.compact.sort_by {|a| a.name }
        hts = info.map {|k, v| v[:hts]}.flatten.uniq.compact.sort

        status = nil
        if factories.size == 1 && hts.size == 1
          status = {status: :ok, product_data: [get_added_product_line_info(info.first[1][:product], factories.first, hts.first)]}
        elsif factories.size == 0
          # If there are no factories returned, we need to tell that to the uploader, it's marked as a No Matching Country of Origin status.  No information is added to the upload.
          status = {status: :no_coo, product_data: []}
        else
          # If there are multiple products returned it's either because the product is manufactured by multiple distinct factories per COO,
          # or there's multiple different HTS values.  Generally, the multiple HTS values indicates the part number is a set since for Lands End 
          # set lines are sent to us across different product records (.ie multiple distinct product records).
          # What we do here is send back each distinct line of product data so the uploader can examine it and determine which of the multiple rows
          # is the correct one to use - or in the case of sets, adjust the quantities/unit costs on each exploaded lines.
          product_data = []
          factories.each do |factory| 
            hts.each do |hts|
              p = info.values.find {|v| v[:hts].include?(hts) && v[:factories].include?(factory)}
              if p
                product_data << get_added_product_line_info(p[:product], factory, hts)
              end
            end
          end

          # If we have multiple HTS numbers, put that as the error first...then fall back to multiple factories.
          status = {status: (hts.size > 1 ? :multiple_hts : :multiple_factories), product_data: product_data}
        end

        # Add the MID for all the lines where possible (.ie Factory Code and HTS are not blank)
        status[:product_data].each do |data|
          if !data[4].blank? && !data[11].blank?
            data[10] = DataCrossReference.find_lands_end_mid data[4].strip, data[11].gsub(".", "").strip
          end
        end
        status        
      end
    end

    def extract_matching_factory_hts_info products, country_origin
      info = {}

      products.each do |p| 
        hts_numbers = []
        factories = p.factories.joins(:country).where(countries: {iso_code: country_origin}).all

        p.classifications.joins(:country).where(countries: {iso_code: "US"}).each do |c|
          c.tariff_records.each do |t|
            hts_numbers << t.hts_1.hts_format unless t.hts_1.blank?
          end
        end

        # Don't consider a product unless we have both a factory and an HTS number.
        # Technically, every product record should have an HTS number, but with the data now being in 
        # VFI Track the possibility exists of the HTS #'s being bad and not uploading or someone/thing loading
        # bad parts data into the LANDS account.
        if (factories.size > 0 && hts_numbers.size > 0)
          info[p.unique_identifier] = {factories: factories, hts: hts_numbers, product: p} 
        end
      end
      info
    end

    def get_added_product_line_info p, factory, hts
      [cv(p, :suffix_indicator), cv(p, :exception_code), cv(p, :suffix), factory.country.iso_code, factory.system_code, factory.name, factory.line_1, factory.line_2, factory.line_3, factory.city, "", hts, cv(p, :comments)]
    end

    def cv p, v
      p.get_custom_value(@cdefs[v]).value
    end

    def translate_values row
      # Some of the values from the file should be turned into numeric values, do so here
      # NOTE: The numbers here represent the actual output columns as the values will appear in to the recipient of the file, not 
      # as the came in from the input file.
      row[23] = row[23].to_i unless row[23].blank?
      row[24] = BigDecimal.new(row[24].to_s) unless row[24].blank?
      row[25] = BigDecimal.new(row[25].to_s) unless row[25].blank?
      row[30] = BigDecimal.new(row[30].to_s) unless row[30].blank?
      row[31] = BigDecimal.new(row[31].to_s) unless row[31].blank?
      row[32] = BigDecimal.new(row[32].to_s) unless row[32].blank?
      row[33] = BigDecimal.new(row[33].to_s) unless row[33].blank?
      row[34] = row[34].to_i unless row[34].blank?

      row
    end


end; end; end; end;