class XlsMaker
  require 'spreadsheet'
  
  HEADER_FORMAT = Spreadsheet::Format.new :weight => :bold,
                                          :color => :orange,
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
  
  def make_from_search(current_search, results)
    @column_widths = {}
    cols = current_search.search_columns.order("rank ASC")
    wb = prep_workbook cols
    sheet = wb.worksheet 0
    row_number = 1
    GridMaker.new(results,cols,current_search.search_criterions,current_search.module_chain,current_search.user).go do |row,obj|
        process_row sheet, row_number, row, obj
      row_number += 1
    end
    wb
  end

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
  
  def self.add_body_row sheet, row_number, row_data, column_widths = [], no_time = false
    row_data.each_with_index do |cell_base,col| 
      cell = nil
      if cell_base.nil?
        cell = ""
      elsif cell_base.is_a?(BigDecimal)
        cell = cell_base.to_s.to_f #fix BigDecimal bad decimal points bug #629
      else
        cell = cell_base
      end
      sheet.row(row_number).push(cell)
      width = cell.to_s.size + 3
      width = 8 unless width > 8
      if cell.respond_to?(:strftime)
        if cell.is_a?(Date) || no_time
          width = 13
          sheet.row(row_number).set_format(col,DATE_FORMAT) 
        else
          sheet.row(row_number).set_format(col,DATE_TIME_FORMAT)
        end
      end
      width = 23 if width > 23
      XlsMaker.calc_column_width sheet, col, column_widths, width
    end 
  end

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
  
  private
  def prep_workbook cols
    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet :name=>"Results"
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
      sheet.row(row_number).push(Spreadsheet::Link.new(base_object.view_url,"Web View")) if self.include_links 
  end
end
