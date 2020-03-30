require 'axlsx'

# Simple interface for building an .xlsx Excel file
#
# This class has absolutely no read functionality (since axlsx doesn't read xlsx files)
# Any reading should be done via the OpenChain::XlClient interfaces.
class XlsxBuilder

  HEADER_BG_COLOR_HEX ||= "42B0D5"

  # This is a simple wrapper class that is here as a means to track raw access to any sheet functionality
  # that might be needed.
  class XlsxSheet
    attr_reader :raw_sheet

    def initialize sheet
      @raw_sheet = sheet
      # Default to 8.5 x 11
      @raw_sheet.page_setup.paper_size = 1
    end

    def name
      @raw_sheet.name
    end
  end

  # Creates a new workbook
  def initialize
    @workbook = new_workbook
  end

  def output_format
    :xlsx
  end

  # Creates a new worksheet in the workbook. If headers param is given will set the given headers
  # as the first row of the new worksheet.
  # 
  # Returns an XlsSheet wrapper object.
  def create_sheet sheet_name, headers: []
    sheet = XlsxSheet.new(@workbook.add_worksheet(name: sheet_name.truncate(31)))
    if headers && headers.length > 0
      add_header_row(sheet, headers) 
    end
    
    sheet
  end

  # Adds a new row to the worksheet as the last row in the document (or first if there are no rows).
  # Row data is expected to be an array indexed according to the data you want in each row of the sheet.
  # If there are any styles / formats you wish to associate with the columns you may pass the style names
  # in the styles variable (if styles is a single value (not an array) - the style will be applied to all columns in the row)
  # If you wish to merge cells, pass their indexes as a range object (or an array of ranges).
  #
  # By default, date and datetimes will have default_date and default_datetime styles applied (unless overriden by styles given in the styles param)
  #
  # `
  # xls.add_body_row(sheet, ["Header 1", "Header 2"], styles: :default_header, merged_cell_ranges: (0..1))) # -> Add a row with the :default_header style applied to all columns and merge them
  # `
  #
  # `
  # new_style = xls.create_style "my_style", { # style definition here # }
  # xls.add_body_row(sheet, ["Column A", "Column B"], styles: [nil, new_style]) # -> new_style is applied ONLY to column B
  # `
  #
  # Also, for the standard default styles (default_date, default_datetime, default_header, default_currency), you can reference them here
  # without first having to create them.  ALL OTHER styles you must first create.
  def add_body_row sheet, row_data, styles: nil, merged_cell_ranges: []
    opts = {}

    data = prep_row_data(Array.wrap(row_data))
    if data[:types].length > 0
      opts[:types] = data[:types]
    end

    row_styles = Array.wrap(merge_array(data[:default_styles], make_style_param(row_data, styles)))

    if row_styles.length > 0
      opts[:style] = row_styles
    end

    raw_sheet = sheet.raw_sheet
    row = raw_sheet.add_row data[:row], opts
    Array.wrap(merged_cell_ranges).each { |range| sheet.raw_sheet.merge_cells row.cells[range] }

    data[:hyperlinks].each_pair do |index, hyperlink|
      raw_sheet.add_hyperlink location: hyperlink[:location], ref: row[index]
    end

    nil
  end

  # Add a row to the sheet that will be styled as a header
  def add_header_row sheet, headers
    add_body_row sheet, headers, styles: :default_header
    nil
  end

  # Writes the workbook being built to the given output location.
  # Output can be a string, in which case the String is expected to be a file path
  # Otherwise the output parameter is expected to be an IO object (or something that implements write)
  def write output
    if output.is_a?(String)
      @package.serialize(output)
    else
      output.write @package.to_stream.read
      output.flush
    end
    nil
  end

  # Creates a new workbook style, the value returned from this method is the value you must pass to add_body_row to apply the style to the 
  # cell(s) you wish to apply the style to.
  #
  # format_name - string/symbol format identifer
  # prevent_override - this is primarily to prevent overwriting existing styles (you likely won't want / need to use this)
  # return_exisiting - if true (defaults to false) prevents erroring if you try and create a style that already exists..returning the existing style instead.
  def create_style format_name, format_definition, prevent_override: true, return_existing: false
    @styles ||= {}
    existing = @styles[format_name.to_sym]
    if existing && return_existing
      return format_name
    elsif existing && prevent_override
      raise "A format named #{format_name} already exists."
    else
      name = format_name.to_sym
      @styles[name] = create_workbook_style(format_definition)
      name
    end
  end

  # Creates a hyperlink cell...the cell returned can be passed as an value to the add_body_row method
  #
  # xls.add_body_row sheet, ["Column A", xls.create_link_cell("http://www.google.com", link_text: "Click Here"), "Column C"]
  def create_link_cell url, link_text: "Web View"
    {location: url, link_text: url.present? ? link_text : "", type: :hyperlink}
  end

  # Introduces a frozen pane ABOVE the given row index (zero indexed)
  # If you want to freeze the first row, pass a value of 1 as that will be the first zero-indexed row as part of the bottom panel - .ie the scrollable panel
  def freeze_horizontal_rows sheet, starting_bottom_panel_row_index
    sheet.raw_sheet.sheet_view.pane do |pane|
      index = (starting_bottom_panel_row_index + 1)

      pane.top_left_cell = "A#{index}"
      pane.state = :frozen
      pane.active_pane = :bottom_left
      pane.y_split = index - 1
      pane.x_split = 0
    end
    nil
  end

  # Set the column width to a specific width.  
  # By default, columns sizes are auto calculated based on the data contained in them.
  # The index of the given widths array will correspond to column index you wish to update.
  # If you pass for a particular index, that column will be set to auto calculate the width.
  def set_column_widths sheet, *widths
    sheet.raw_sheet.column_widths *widths
    nil
  end

  # Downsizes all columns to the max width given if any exceed it.
  # This method should be applied AFTER all data has been entered for a column.
  # If data is added to a column that exceeds the max width, after this method has been called,
  # the column will grow passed the max width.
  # In other words, call this apply method after all the data in your sheet is present.
  def apply_min_max_width_to_columns sheet, min_width: 8, max_width: 50
    sheet.raw_sheet.column_info.each_with_index do |col, index|
      width = col.width
      if width.nil?
        col.width = min_width
      elsif min_width && width < min_width
        col.width = min_width
      elsif max_width && width > max_width
        col.width = max_width
      end
    end
    nil
  end

  # source is a local file path, e.g. "/app/assets..."
  # opts: {name: <String>, descr: <String>, opacity: <Float>}
  def add_image sheet, source, width, height, start_at_row, start_at_col, hyperlink: nil, opts: {}
    opts.merge!(image_src: source, noSelect: true, noMove: true, hyperlink: hyperlink)
    sheet.raw_sheet.add_image(opts) do |image|
      image.width = width
      image.height = height
      image.start_at start_at_row, start_at_col
    end
  end

  # orientation: one of [:portrait, :landscape]
  #
  # fit_to_(width|height)_pages: a numeric value representing the number of horizontal pages you want to scale the
  # spreadsheet to fit into.  In general, you'll probably want to just set a value of 1, which'll shrink or
  # grow it to fill a single page
  #
  # Margins - should be a hash with numeric values for any/all of :top, :left, :right, :bottom
  def set_page_setup sheet, orientation: nil, fit_to_width_pages: nil, fit_to_height_pages: nil, margins: nil
    setup = sheet.raw_sheet.page_setup
    setup.orientation = orientation unless orientation.nil?
    fits = {}
    fits[:width] = fit_to_width_pages unless fit_to_width_pages.nil?
    fits[:height] = fit_to_height_pages unless fit_to_height_pages.nil?

    setup.fit_to(fits) unless fits.blank?
    sheet.raw_sheet.page_margins.set(margins) unless margins.nil?

    nil
  end

  # To do things like put the page number in the header, etc. 
  # See control characters here: https://github.com/randym/axlsx/blob/master/notes_on_header_footer.md
  #
  # NOTE: If you use page number, that is relative to the number of pages the tab itself takes up, not the whole workbook.
  def set_header_footer sheet, header: nil, footer: nil
    sheet.raw_sheet.header_footer.odd_header = header unless header.blank?
    sheet.raw_sheet.header_footer.odd_footer = footer unless footer.blank?
    nil
  end

  def self.demo
    load 'xlsx_builder.rb'
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
    # This tests that string values with e are always handled as strings, not numerics
    b.add_body_row sheet, ["63002E34", "E1", "6e3", "e"]
    b.add_image sheet, "spec/fixtures/files/attorney.png", 150, 144, 4, 2, hyperlink: "https://en.wikipedia.org/wiki/Better_Call_Saul", opts: { name: "Saul" }
    b.freeze_horizontal_rows sheet, 1
    b.set_column_widths sheet, 25, nil, 30
    b.apply_min_max_width_to_columns sheet
    b.set_page_setup(sheet, orientation: :landscape, fit_to_width_pages: 1, margins: {left: 0.5, right: 0.5})
    b.set_header_footer sheet, header: '&L&F : &A&R&D &T', footer: '&C&Pof&N'

    b.write "tmp/test.xlsx"
  end

  def self.alphabet_column_to_numeric_column column_name
    # Since this is built into Axlsx, we might as well just proxy their method
    Axlsx.name_to_indices("#{column_name.upcase}1")[0]
  end

  def self.numeric_column_to_alphabetic_column number
    # Since this is built into Axlsx, we might as well just proxy their method
    Axlsx.col_ref number
  end

  protected

    # Any styles, types, default data transformations should be done here (like apply default styles or transforming a value)
    def prep_row_data row_data
      # The main thing we're looking for here is if the data is a numeric string...if it is, then we want to make sure it renders
      # as a string and not a number.
      types = []
      hyperlinks = {}
      default_styles = []
      row = []
      row_data.each_with_index do |data, index|
        # For some reason, Excel will identify a string like 1234e12 as 1234 e^12...dumb.  Handle that and tell axlsx to type it as a string instead.
        if data.is_a?(String) && (data =~ /\A[0-9]*(\.[0-9]+)?\z/ || data =~ /\A[0-9]+e[0-9]+\z/i)
          types[index] = :string
        elsif data.is_a?(Hash) && data[:type] == :hyperlink
          hyperlinks[index] = data
          types[index] = :string
          row << data[:link_text]
          next
        elsif data.is_a?(DateTime) || data.is_a?(ActiveSupport::TimeWithZone)
          default_styles[index] = create_default_datetime_style
        elsif data.is_a?(Date)
          default_styles[index] = create_default_date_style
        end

        row << data
      end

      {types: types, row: row, hyperlinks: hyperlinks, default_styles: make_style_param(row_data, default_styles)}
    end

    def create_default_currency_style
      create_style(:default_currency, {format_code: "#,##0.00"}, prevent_override: false, return_existing: true)
      :default_currency
    end

    def create_default_header_style
      create_style(:default_header, {bg_color: HEADER_BG_COLOR_HEX, fg_color: "000000", b: true, alignment: {horizontal: :center}}, prevent_override: false, return_existing: true)
      :default_header
    end

    def create_default_date_style
      create_style(:default_date, {format_code: "YYYY-MM-DD"}, prevent_override: false, return_existing: true)
      :default_date
    end

    def create_default_datetime_style
      create_style(:default_datetime, {format_code: "YYYY-MM-DD HH:MM"}, prevent_override: false, return_existing: true)
      :default_datetime
    end

  private

    def default_stylenames
      @defaults ||= Set.new [:default_currency, :default_header, :default_date, :default_datetime]
    end

    def create_workbook_style style_def
      @workbook.styles.add_style style_def
    end

    def new_workbook
      @package = Axlsx::Package.new author: "VFI Track"
      workbook = @package.workbook

      # Reset the default font size to 10 (default font name is Arial)
      font = workbook.styles.fonts.find {|f| f.name == "Arial"}
      if font
        font.sz = 10
      end

      workbook
    end

    def find_style style_name
      return nil if style_name.nil?

      style_name = style_name.to_sym
      if default_stylenames.include?(style_name)
        self.send("create_#{style_name}_style")
      end

      style = @styles[style_name] if @styles
      raise "No format named '#{style_name}' has been created." if style.nil?
      style
    end

    def make_style_param row_data, styles
      # This can be a single value or it can be an array, we need to preserve that because axlsx does different things 
      # based on if it's one or the other
      if styles.respond_to?(:map)
        # Return an array, which means that axlsx will only style certain columns
        styles.map {|s| find_style s }
      else
        # This is just a single object, but due to the need to combine default styling with this
        # we need to map it to each column from the input row_data
        style = find_style(styles)

        # Basically, return an array using the single style defined as the value for each index
        # This makes applying the style easy, what this is essentially saying is use 
        # this style for every column
        row_data.map {|s| style }
      end
    end

    def merge_array default_formats, overide_formats
      length = [Array.wrap(default_formats).length, Array.wrap(overide_formats).length].max
      formats = [].replace(Array.wrap(default_formats))
      length.times {|x| formats[x] = overide_formats[x] unless overide_formats[x].nil?}

      formats
    end

end
