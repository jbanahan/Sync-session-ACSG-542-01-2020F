require 'axlsx'

# Simple interface for building an .xslx Excel file
# 
# This class has absolutely no read functionality (since axlsx doesn't read xlsx files)
# Any reading should be done via the OpenChain::XlClient interfaces.
class XlsxBuilder

  # This is a simple wrapper class that is here as a means to track raw access to any sheet functionality
  # that might be needed.
  class XlsxSheet
    attr_reader :raw_sheet

    def initialize sheet
      @raw_sheet = sheet
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
    sheet = XlsxSheet.new(@workbook.add_worksheet(name: sheet_name))
    if headers && headers.length > 0
      add_header_row(sheet, headers) 
    end
    
    sheet
  end

  # Adds a new row to the worksheet as the last row in the document (or first if there are no rows).
  # Row data is expected to be an array indexed according to the data you want in each row of the sheet.
  # If there are any styles / formats you wish to associate with the columns you may pass the style names
  # in the styles variable (if styles is a single value (not an array) - the style will be applied to all columns in the row)
  #
  # By default, date and datetimes will have default_date and default_datetime styles applied (unless overriden by styles given in the styles param)
  #
  # `
  # xls.add_body_row(sheet, ["Header 1", "Header 2"], styles: :default_header)) # -> Add a row with the :default_header style applied to all columns
  # `
  #
  # `
  # new_style = xls.create_style "my_style", { # style definition here # }
  # xls.add_body_row(sheet, ["Column A", "Column B"], styles: [nil, new_style]) # -> new_style is applied ONLY to column B
  # `
  #
  # Also, for the standard default styles (default_date, default_datetime, default_header, default_currency), you can reference them here
  # without first having to create them.  ALL OTHER styles you must first create.
  def add_body_row sheet, row_data, styles: nil
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
      return existing
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
    {location: url, link_text: link_text, type: :hyperlink}
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

  def self.demo
    load 'xlsx_builder.rb'
    b = self.new
    sheet = b.create_sheet "Testing", headers: ["Test", "Testing"]
    b.add_body_row sheet, ["Testing", 1, 12435.67, Time.zone.now, Time.zone.now, Date.new(2018, 6, 10)], styles: [nil, nil, :default_currency, :default_date, :default_datetime]
    b.add_body_row sheet, ["1"]
    b.add_body_row sheet, BigDecimal("1.23")
    link = b.create_link_cell "http://www.google.com", "Google"
    b.add_body_row sheet, [link]
    b.add_body_row sheet, [nil, "Now is the time for all good men to come to the aid of their country...this is a really long message."]
    # This tests the min width setting
    b.add_body_row sheet, [nil, nil, nil, nil, nil, nil, nil, "Y"]
    b.freeze_horizontal_rows sheet, 1
    b.set_column_widths sheet, 25, nil, 30
    b.apply_min_max_width_to_columns sheet

    b.write "tmp/test.xlsx"
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
        if data.is_a?(String) && data =~ /\A[0-9]*(\.[0-9]+)?\z/
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
      create_style(:default_header, {bg_color: "62BCF3", fg_color: "000000", b: true, alignment: {horizontal: :center}}, prevent_override: false, return_existing: true)
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
      @package = Axlsx::Package.new
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