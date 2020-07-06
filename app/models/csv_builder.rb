require 'csv'

# Simple interface for building csv files that mimics the xls(x) builders API...though
# with some methods left unused and some options ignored that don't apply for CSV files (like styles, and links, etc)
#
# This class exists primarily to make the search writer utilize the same interface for all outputs.
class CsvBuilder

  # This is a simple wrapper class that is here as a means to track raw access to any sheet functionality
  # that might be needed.
  class CsvSheet
    attr_reader :raw_sheet

    def initialize sheet, name
      @raw_sheet = sheet
      @name = name
    end

    def name
      @name
    end
  end

  # Creates a new csv file
  # date_format - must be in Ruby format (i.e. strftime syntax) if provided, optional
  def initialize csv_opts: {}, date_format: nil
    @date_format = date_format
    @csv = new_csv(csv_opts)
  end

  def output_format
    :csv
  end

  # Creates a new worksheet in the workbook. If headers param is given will set the given headers
  # as the first row of the new worksheet.
  #
  # Returns an XlsSheet wrapper object.
  def create_sheet sheet_name, headers: []
    sheet = CsvSheet.new(@csv, sheet_name)
    if headers && headers.length > 0
      add_header_row(sheet, headers)
    end

    sheet
  end

  # Adds a new row to the csv as the last row in the document (or first if there are no rows).
  # Row data is expected to be an array indexed according to the data you want in each row of the sheet.
  def add_body_row sheet, row_data, styles: nil, merged_cell_ranges: []
    sheet.raw_sheet << prep_row_data(Array.wrap(row_data))
    nil
  end

  # Literally just a call through to add_body_row for the csv output as there's no styling that
  # can be done.
  def add_header_row sheet, headers
    add_body_row sheet, headers
    nil
  end

  # Writes the workbook being built to the given output location.
  # Output can be a string, in which case the String is expected to be a file path
  # Otherwise the output parameter is expected to be an IO object (or something that implements write)
  def write output
    @buffered_data.flush
    @buffered_data.rewind

    if output.is_a?(String)
      File.open(output, "w") {|f| f << @buffered_data.read }
    else
      output.write @buffered_data.read
    end
    nil
  end

  # This is literally a no-op for csv outputs.
  def create_style format_name, format_definition, prevent_override: true, return_existing: false
    format_name.to_sym
  end

  # No-op.  Styles are not used.
  def create_date_style format_name, date_format, prevent_override: true, return_existing: false
    nil
  end

  # Since csv doesn't support styled hyperlinks, just return back the url given
  def create_link_cell url, link_text = "Web View"
    url
  end

  # No-op...csv doesn't support frozen rows - here merely to maintain api consistency between output formats
  def freeze_horizontal_rows sheet, starting_bottom_panel_row_index
    nil
  end

  # No-op csv doesn't support widths - here merely to maintain api consistency between output formats
  def set_column_widths sheet, *widths
    nil
  end

  # No-op csv doesn't support widths - here merely to maintain api consistency between output formats
  def apply_min_max_width_to_columns sheet, max_width: 50
    nil
  end

  # No-op...csv doesn't support images - here merely to maintain api consistency between output formats
  def add_image sheet, source, width, height, start_at_row, start_at_col, hyperlink: nil, opts: {}
    nil
  end

  # No-op...csv doesn't support this - here merely to maintain api consistency between output formats
  def set_page_setup sheet, orientation: nil, fit_to_width_pages: nil, fit_to_height_pages: nil, margins: nil, header: nil, footer: nil
   nil
  end

  # Not supported by csv, added for API compatibility between builder classes
  def set_header_footer sheet, header: nil, footer: nil
    nil
  end

  # This is just a simple way create a demo document with all the functionality that the builder
  # classes provide.
  def self.demo
    load 'csv_builder.rb'
    b = self.new
    sheet = b.create_sheet "Testing", headers: ["Test", "Testing"]
    b.add_body_row sheet, ["Testing", 1, 12435.67, Time.zone.now, Time.zone.now, Date.new(2018, 6, 10)], styles: [nil, nil, :default_currency, :default_date, :default_datetime]
    b.add_body_row sheet, ["1"]
    b.add_body_row sheet, [BigDecimal("1.23")]
    link = b.create_link_cell "http://www.google.com", link_text: "Google"
    b.add_body_row sheet, [link]
    b.add_body_row sheet, [nil, "Now is the time for all good men to come to the aid of their country...this is a really long message."]
    # This tests the min width setting
    b.add_body_row sheet, [nil, nil, nil, nil, nil, nil, nil, "Y"]
    b.add_image sheet, "spec/fixtures/files/attorney.png", 150, 144, 4, 2, hyperlink: "https://en.wikipedia.org/wiki/Better_Call_Saul", opts: { name: "Saul" }
    # This tests that string values with e are always handled as strings, not numerics
    # The e testing isn't really applicable to csv, but I want to keep the demos the same
    b.add_body_row sheet, ["63002E34", "E1", "6e3", "e"]
    b.freeze_horizontal_rows sheet, 1
    b.set_column_widths sheet, 25, nil, 30
    b.apply_min_max_width_to_columns sheet

    b.write "tmp/test.csv"
  end

  protected

    # Any styles, types, default data transformations should be done here (like apply default styles or transforming a value)
    def prep_row_data row_data
      # The main thing we're looking for here is if the data is a numeric string...if it is, then we want to make sure it renders
      # as a string and not a number.
      row = []
      row_data.each do |data|
        # While technically csv can support newlines the value is quoted correctly, not very many csv readers
        # actually support this - so we're going to remove newlines
        if data.respond_to?(:gsub)
          data = data.gsub(/[\r\n]/, ' ')
        end

        if data.is_a?(DateTime) || data.is_a?(ActiveSupport::TimeWithZone)
          row << data.strftime(@date_format.present? ? "#{@date_format} %H:%M" : '%Y-%m-%d %H:%M')
        elsif data.is_a?(Date)
          row << data.strftime(@date_format.presence || '%Y-%m-%d')
        else
          row << data
        end
      end

      row
    end

  private

    def new_csv csv_opts
      # At some point we may want to write something that transparently transforms the buffer
      # to a tempfile or something if it gets too big.  That way all the data being written to the
      # csv output isn't stored in memory.  For now, this should be ok.
      @buffered_data = StringIO.new
      CSV.new(@buffered_data, csv_opts)
    end

end
