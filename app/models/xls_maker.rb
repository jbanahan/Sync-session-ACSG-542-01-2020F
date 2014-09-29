class XlsMaker
  require 'spreadsheet'
  
  HEADER_FORMAT = Spreadsheet::Format.new :weight => :bold,
                                          :color => :white,
                                          :pattern_fg_color => :navy,
                                          :pattern => 1,
                                          :name=>"Heading"
  DATE_FORMAT = Spreadsheet::Format.new :number_format=>'YYYY-MM-DD'
  DATE_TIME_FORMAT = Spreadsheet::Format.new :number_format=>'YYYY-MM-DD HH:MM'

  attr_accessor :include_links
  attr_accessor :no_time #hide timestamps on output

  def initialize opts={}
    inner_opts = {:include_links=>false,:no_time=>false}.merge(opts)
    @include_links = inner_opts[:include_links]
    @no_time = inner_opts[:no_time]
  end
  
  def make_from_search_query search_query, search_query_opts = {}
    @column_widths = {}
    ss = search_query.search_setup
    errors = []
    raise errors.first unless ss.downloadable?(errors)

    max_results = ss.max_results
    cols = search_query.search_setup.search_columns.order('rank ASC')
    wb = prep_workbook cols
    sheet = wb.worksheet 0
    row_number = 1
    base_objects = {}
    search_query.execute(search_query_opts) do |row_hash|
      #it's ok to fill with nil objects if we're not including links because it'll save a lot of DB calls
      key = row_hash[:row_key]
      base_objects[key] ||= (@include_links ? ss.core_module.find(key) : nil)
      process_row sheet, row_number, row_hash[:result], base_objects[key]
      
      raise "Your report has over #{max_results} rows.  Please adjust your parameter settings to limit the size of the report." if (row_number += 1) > max_results
    end
    wb
  end

  #delay job friendly version of make_from_search_query
  def make_from_search_query_by_search_id_and_user_id search_id, user_id
    sq = SearchQuery.new(SearchSetup.find(search_id),User.find(user_id))
    make_from_search_query sq
  end

  #deprecated
  def make_from_results results, columns, module_chain, user, search_criterions=[]
    @column_widths = {}
    wb = prep_workbook columns
    sheet = wb.worksheet 0
    row_number = 1
    GridMaker.new(results,columns,search_criterions,module_chain,user).go do |row,obj|
      process_row sheet, row_number, row, obj
      row_number += 1
    end
    wb
  end

  def self.excel_url relative_url
    request_host = nil
    # Caching this call ends up creating an ordering dependency in unit tests...so only do it in production
    if Rails.env.production?
      @@req_host ||= MasterSetup.get.request_host
      request_host = @@req_host
    else
      request_host = MasterSetup.get.request_host
    end
    
    raise "Cannot generate view_url because MasterSetup.request_host not set." unless request_host
    # We need to do the redirect because of how Excel/Windows use an IE component to view the URL and hand off the 
    # URL's resulting response to the user's default browser.  The IE component used doesn't have access to any session
    # cookies so, effectively, every link will force the user to re-login - annoying.  
    # The redirect gets around this by providing the IE discovery component the correct URL to hand off to the default browser.

    # The relative url is encoded so any page parameters are not fed to the redirect page.
    "http://#{request_host}/redirect.html?page=#{CGI.escape(relative_url)}"
  end
  
  def self.add_body_row sheet, row_number, row_data, column_widths = [], no_time = false, options = {}
    make_body_row sheet, row_number, 0, row_data, column_widths, {:no_time => no_time}.merge(options)
  end

  # Method allows insertion of a row data array into a middle column of a spreadsheet row.
  def self.insert_body_row sheet, row_number, starting_column_number, row_data, column_widths = [], no_time = false
    make_body_row sheet, row_number, starting_column_number, row_data, column_widths, {:no_time => no_time, :insert=>true}
  end

  def self.insert_cell_value sheet, row_number, column_number, cell_base, column_widths = [], options = {}
    set_cell_value sheet, row_number, column_number, cell_base, column_widths, {insert: true}.merge(options)
  end

  def self.set_cell_value sheet, row_number, column_number, cell_base, column_widths = [], options = {}
    cell = nil
    if cell_base.nil?
      cell = ""
    elsif cell_base.is_a?(BigDecimal)
      cell = cell_base.to_s.to_f #fix BigDecimal bad decimal points bug #629
    else
      cell = cell_base
    end
    
    if options[:insert] == true
      sheet.row(row_number).insert(column_number, cell)
    else
      # If insert is false, we're effectively ignoring the passed in column number
      # so we need to make sure we're going to be updating the format/sizing
      # for the actual column we've pushed the data into
      row = sheet.row(row_number)
      row.push(cell)
      column_number = (row.length - 1)
    end

    width = cell.to_s.size + 3
    width = 8 unless width > 8
    if cell.respond_to?(:strftime)
      if (cell.is_a?(Date) && !cell.is_a?(DateTime)) || options[:no_time] == true
        width = 13
        sheet.row(row_number).set_format(column_number,DATE_FORMAT) unless options[:format]
      else
        sheet.row(row_number).set_format(column_number,DATE_TIME_FORMAT) unless options[:format]
      end
    end
    width = 23 if width > 23
    XlsMaker.calc_column_width sheet, column_number, column_widths, width

    if options[:format]
      sheet.row(row_number).set_format(column_number, options[:format])
    end
    nil
  end
  private_class_method :set_cell_value

  def self.make_body_row sheet, row_number, starting_column_number, row_data, column_widths = [], options = {}
    row_data.each_with_index do |cell_base, col| 
      col = starting_column_number + col
      set_cell_value sheet, row_number, col, cell_base, column_widths, options
    end
  end
  private_class_method :make_body_row

  def self.add_header_row sheet, row_number, header_labels, column_widths = []
    header_labels.each_with_index do |label, i|
      sheet.row(row_number).default_format = HEADER_FORMAT
      sheet.row(row_number).push(label)
      width = (label.size + 3 > 23 ? 23 : label.size + 3)
      XlsMaker.calc_column_width sheet, i, column_widths, width
    end
  end

  def self.calc_column_width sheet, col, column_widths, width
    if column_widths[col].nil? || column_widths[col] < width
      sheet.column(col).width = width
      column_widths[col] = width
    end
  end

  def self.create_workbook sheet_name, headers = []
    wb = new_workbook
    create_sheet wb, sheet_name, headers
    wb
  end

  def self.new_workbook 
    Spreadsheet::Workbook.new
  end

  def self.create_sheet workbook, sheet_name, headers = []
    sheet = workbook.create_worksheet :name=> sheet_name
    XlsMaker.add_header_row(sheet, 0, headers) if headers.length > 0
    sheet
  end

  def self.create_link_cell url, link_text = "Web View"
    Spreadsheet::Link.new(url,link_text)
  end
  
  private
  def prep_workbook cols
    wb = XlsMaker.create_workbook "Results"
    sheet = wb.worksheet "Results"
    headers = []
    cols.each_with_index do |c,i|
      mf = ModelField.find_by_uid c.model_field_uid
      headers << (mf.nil? ? "" : mf.label)
    end

    XlsMaker.add_header_row sheet, 0, headers, @column_widths
    sheet.row(0).push("Links") if self.include_links
    wb
  end

  def process_row sheet, row_number, row_data, base_object
    XlsMaker.add_body_row sheet, row_number, row_data, @column_widths, @no_time
    sheet.row(row_number).push(self.class.create_link_cell(base_object.excel_url)) if self.include_links 
  end

end
