class XlsMaker
  require 'spreadsheet'
  def make_from_search(current_search, results)
    cols = current_search.search_columns.order("rank ASC")
    wb = prep_workbook cols
    sheet = wb.worksheet 0
    row_number = 1
    GridMaker.new(results,cols,current_search.search_criterions,current_search.module_chain).go do |row,obj|
      process_row sheet, row_number, row, obj
      row_number += 1
    end
    wb
  end

  def make_from_results results, columns, module_chain, search_criterions=[]
    wb = prep_workbook columns
    sheet = wb.worksheet 0
    row_number = 1
    GridMaker.new(results,columns,search_criterions,module_chain).go do |row,obj|
      process_row sheet, row_number, row, obj
      row_number += 1
    end
    wb
  end

  private
  def prep_workbook cols
    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet :name=>"Results"
    @date_format = Spreadsheet::Format.new(:number_format => 'YYYY-MM-DD')
    cols.each do |c|
      mf = ModelField.find_by_uid c.model_field_uid
      sheet.row(0).default_format = Spreadsheet::Format.new :weight => :bold
      sheet.row(0).push(mf.nil? ? "" : mf.label)
    end
    wb
  end
  
  def process_row sheet, row_number, row_data, base_object
      row_data.each_with_index {|cell,col| 
        sheet.row(row_number).push(cell)
        sheet.row(row_number).set_format(col,@date_format) if cell.is_a? Date
      }
  end
end
