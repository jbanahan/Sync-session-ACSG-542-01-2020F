require 'spreadsheet'

# Simple interface for building an old-style .xls Excel file.
#
# This class has absolutely no read functionality
# Any reading should be done via the OpenChain::XlClient interfaces.
class XlsBuilder

  # This is a simple wrapper class that is here as a means to track raw access to any sheet functionality
  # that might be needed.
  class XlsSheet
    attr_reader :raw_sheet

    def initialize sheet
      @raw_sheet = sheet
    end

    def name
      @raw_sheet.name
    end
  end

  # Creates a new workbook, if a workbook object is given it will initialize from that
  # and start writing at the end of it
  def initialize
    @workbook = new_workbook
  end

  def output_format
    :xls
  end

  # Creates a new worksheet in the workbook. If headers param is given will set the given headers
  # as the first row of the new worksheet.
  # 
  # Returns an XlsSheet wrapper object.
  def create_sheet sheet_name, headers: []
    sheet = XlsSheet.new(@workbook.create_worksheet(name: sheet_name))
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
  # By default, date and datetimes will have default_date and default_date_time styles applied (unless overriden by styles given in the styles param)
  #
  # `
  # xls.add_body_row(sheet, ["Header 1", "Header 2"], styles: :default_header), merged_cell_ranges: (0..1)) # -> Add a row with the :default_header style applied to all columns and merge the first two
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
    row_data = Array.wrap(row_data)

    styles = make_style_param(row_data, styles, merged_cell_ranges)
    
    data = prep_row_data(Array.wrap(row_data))

    row_num = row_number(sheet)

    raw_sheet = sheet.raw_sheet

    raw_sheet.insert_row(row_num, data[:row])
    # This takes all the default styles returned from prep_row_data (like for dates)
    # and then overlays any styles passed in on top of them.
    formats = merge_array(data[:default_styles], styles)
    if formats.length > 0 
      row = raw_sheet.row(row_num)

      formats.each_with_index do |style, x|
        row.set_format(x, style) unless style.nil?
      end
    end

    # the spreadsheet gem does not support autocalculating column widths
    # so we're just doing it ourselves in a very basic manner.
    recalculate_column_widths(raw_sheet, data[:row], formats)
    set_row_number(sheet, row_num + 1)

    nil
  end

  # Add a row to the sheet that will be styled as a header
  def add_header_row sheet, headers
    add_body_row sheet, headers, styles: :default_header
  end

  # Writes the workbook being built to the given output location.
  # Output can be a string, in which case the String is expected to be a file path
  # Otherwise the output parameter is expected to be an IO object (or something that implements write)
  def write output
    @workbook.writer(output).write(@workbook)
    output.flush if output.respond_to?(:flush)
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
    @style_definitions ||= {}
    existing = @styles[format_name.to_sym]
    if existing && return_existing
      return existing
    elsif existing && prevent_override
      raise "A format named #{format_name} already exists."
    else
      id = format_name.to_sym
      @styles[id] = create_workbook_style(format_name, format_definition)
      @style_definitions[id] = format_definition
    end

    id
  end

  # Creates a hyperlink cell...the cell returned can be passed as an value to the add_body_row method
  #
  # xls.add_body_row sheet, ["Column A", xls.create_link_cell("http://www.google.com", "Click Here"), "Column C"]
  def create_link_cell url, link_text: "Web View"
    Spreadsheet::Link.new(url, url.present? ? link_text : "")
  end

  # Introduces a frozen pane ABOVE the given row index (zero indexed)
  # If you want to freeze the first row, pass a value of 1 as that will be the first zero-indexed row as part of the bottom panel - .ie the scrollable panel
  def freeze_horizontal_rows sheet, starting_bottom_panel_row_index
    # This is a no-op because the spreadsheets the gem creates with frozen headers causes Excel (not OpenOffice) to
    # fail validation, and the user must clear it...therefore we're not locking xls files.
    
    # I'm leaving in how to do this just in case there's a situation where we MUST write an xls
    # file w/ frozen rows

    #sheet.raw_sheet.freeze!(starting_bottom_panel_row_index, 0)
    nil
  end

  # Set the column width to a specific width.  
  # By default, columns sizes are auto calculated based on the data contained in them.
  # The index of the given widths array will correspond to column index you wish to update.
  # If you pass for a particular index, that column will be set to auto calculate the width.
  def set_column_widths sheet, *widths
    raw_sheet = sheet.raw_sheet
    Array.wrap(widths).each_with_index do |width, x|
      raw_sheet.column(x).width = width unless width.nil?
    end
    nil
  end

  # Downsizes all columns to the max width given if any exceed it.
  # This method should be applied AFTER all data has been entered for a column.
  # If data is added to a column that exceeds the max width, after this method has been called,
  # the column will grow passed the max width.
  # In other words, call this apply method after all the data in your sheet is present.
  def apply_min_max_width_to_columns sheet, min_width: 8, max_width: 50
    sheet.raw_sheet.columns.each_with_index do |col, index|
      width = col.width
      if max_width && width > max_width
        col.width = max_width
      elsif min_width && width < min_width
        col.width = min_width
      end
    end
  end

  # No-op...Spreadsheet gem doesn't support images - here merely to maintain api consistency between output formats
  def add_image sheet, source, width, height, start_at_row, start_at_col, hyperlink: nil, opts: {}
    nil
  end

  # orientation: one of [:portrait, :landscape]
  #
  # fit_to_(width|height)_pages: a numeric value representing the number of horizontal pages you want to scale the
  # spreadsheet to fit into.  In general, you'll probably want to just set a value of 1, which'll shrink or
  # grow it to fill a single page
  #
  # Margins - should be a hash with numeric values for any/all of :top, :left, :right, :bottom
  def set_page_setup sheet, orientation: nil, fit_to_width_pages: nil, fit_to_height_pages: nil, margins: nil
    sheet.raw_sheet.pagesetup[:orientation] = orientation unless orientation.nil?
    if !margins.nil?
      m = {}
      [:top, :left, :right, :bottom].each {|v| m[v] = margins[v] if margins[v] }
      sheet.raw_sheet.margins.merge!(margins)
    end

    # fit_to_width/height isn't supported by spreadsheet gem 
    nil
  end

  # Not supported by spreadsheet gem, added for API compatibility between builder classes
  def set_header_footer sheet, header: nil, footer: nil
    nil
  end

  def self.demo
    load 'xls_builder.rb'
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
    # The spreadsheet gem handles this internally, unlike axlsx (where we have to deal with it)
    b.add_body_row sheet, ["63002E34", "E1", "6e3", "e"]
    b.add_image sheet, "spec/fixtures/files/attorney.png", 150, 144, 4, 2, hyperlink: "https://en.wikipedia.org/wiki/Better_Call_Saul", opts: { name: "Saul" }
    b.freeze_horizontal_rows sheet, 1
    b.set_column_widths sheet, 25, nil, 30
    b.apply_min_max_width_to_columns sheet
    b.set_page_setup(sheet, orientation: :landscape, fit_to_width_pages: 1, margins: {left: 0.5, right: 0.5})

    b.write "tmp/test.xls"
  end


  protected

    # Any styles, types, default data transformations should be done here (like apply default styles or transforming a value)
    def prep_row_data row_data
      default_styles = []
      hyperlinks = {}
      row = []
      row_data.each_with_index do |data, index|
        if data.is_a?(BigDecimal)
          # Supposedly this is being done to fix a bug (a really old one in Chain)...not sure why, it's losing potential precision.
          row << data.to_s.to_f
          next
        elsif data.is_a?(DateTime) || data.is_a?(ActiveSupport::TimeWithZone)
          default_styles[index] = create_default_datetime_style
        elsif data.is_a?(Date)
          default_styles[index] = create_default_date_style
        elsif data.nil?
          row << ""
          next
        end

        row << data
      end

      {default_styles: default_styles.map {|s| find_style(s)}, row: row}
    end

    def create_default_currency_style
      create_style(:default_currency, {number_format: '#,##0.00'}, prevent_override: false, return_existing: true)
      :default_currency
    end

    def create_default_header_style
      @default_header ||= begin
        # This is kind of a hacky way to remap our company color to a numeric color, but it's the only way I 
        # saw that we can actually use custom colors in the spreadsheet gem.
        # RGB(98, 187, 243) -> Hex 0x62BBF3
        # First 41 param means we're mapping this to xl_color_41 in spreadsheet gem
        @workbook.set_custom_color(41, 98, 187, 243) if @workbook.palette[41] != [98, 187, 243]
        true
      end

      create_style(:default_header, {weight: :bold, color: :black,  pattern_fg_color: :xls_color_41, pattern: 1, horizontal_align: :center}, prevent_override: false, return_existing: true)
      :default_header
    end

    def create_default_date_style
      create_style(:default_date, {number_format: 'YYYY-MM-DD'}, prevent_override: false, return_existing: true)
      :default_date
    end

    def create_default_datetime_style
      create_style(:default_datetime, {number_format: 'YYYY-MM-DD HH:MM'}, prevent_override: false, return_existing: true)
      :default_datetime
    end

  private

    def default_stylenames
      @defaults ||= Set.new [:default_currency, :default_header, :default_date, :default_datetime]
    end

    def create_workbook_style format_name, style_def
      f = Spreadsheet::Format.new style_def
      f.name = format_name.to_s
      f
    end

    def new_workbook
      @workbook = Spreadsheet::Workbook.new
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

    def make_style_param row_data, styles, merged_cell_ranges=[]
      # This can be a single value or it can be an array, we need to preserve that because axlsx does different things 
      # based on if it's one or the other
      if !styles.respond_to?(:map)
        # Basically, return an array using the single style defined as the value for each index
        # This makes applying the style easy, what this is essentially saying is use 
        # this style for every column
        styles = row_data.map {|s| styles }
      end

      styles = merge_cell_styles styles, merged_cell_ranges
      styles.map{ |s| find_style s }
    end

    def merge_cell_styles styles, merged_cell_ranges
      # Combine the styles in merged cells along with the :merge flag into a new style which overwrites the original
      # Leaves styles unchanged if there aren't any merged cells.
      Array.wrap(merged_cell_ranges).each do |mcr|
        combined_style = { horizontal_align: :merge }
        styles[mcr].each { |s| combined_style.merge!(@style_definitions[s]) if s }
        style_name = combined_style.hash.to_s.to_sym
        create_style style_name, combined_style, prevent_override: false, return_existing: true
        styles[mcr] = Array.new mcr.count, style_name
      end
      styles
    end

    def merge_array default_formats, overide_formats
      length = [Array.wrap(default_formats).length, Array.wrap(overide_formats).length].max
      formats = [].replace(Array.wrap(default_formats))
      length.times {|x| formats[x] = overide_formats[x] unless overide_formats[x].nil?}

      formats
    end

    def row_number sheet
      @row_numbers ||= {}
      @row_numbers[sheet.name] ||= 0
      @row_numbers[sheet.name]
    end

    def set_row_number sheet, row_number
      @row_numbers ||= {}
      @row_numbers[sheet.name] = row_number
    end

    def recalculate_column_widths sheet, row, styles
      row_widths = calculate_row_widths(row, styles)
      row_widths.each_with_index do |width, index|
        col = sheet.column(index)
        col.width = width if col.width.nil? || col.width < width
      end
    end

    def calculate_row_widths row, styles
      # These calculations are mostly based on the legacy ones in XlsMaker
      widths = []
      row.each_with_index do |val, index|
        date_width = 11
        if val.respond_to?(:acts_like_date?) && val.acts_like_date? && (!val.respond_to?(:acts_like_time?) || !val.acts_like_time?)
          widths[index] = date_width
        elsif val.respond_to?(:acts_like_time?) && val.acts_like_time?
          style = styles[index]
          widths[index] = (style && style.name == 'default_date') ? date_width : 16
        else
          widths[index] = val.to_s.length + 3
        end
      end

      widths
    end
end
