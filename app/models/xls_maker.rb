class XlsMaker
  require 'spreadsheet'
  def make(current_search, results)
    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet :name=>"Results"
    date_format = Spreadsheet::Format.new(:number_format => 'YYYY-MM-DD')
    cols = current_search.search_columns.order("rank ASC")
    cols.each do |c|
      mf = ModelField.find_by_uid c.model_field_uid
      sheet.row(0).default_format = Spreadsheet::Format.new :weight => :bold
      sheet.row(0).push(mf.nil? ? "" : mf.label)
    end
    i = 1
    GridMaker.new(results,cols,current_search.module_chain).go do |row,obj|
      col = 0
      row.each {|cell| 
        sheet.row(i).push(cell)
        sheet.row(i).set_format(col,date_format) if cell.is_a? Date
        col += 1
      }
      i += 1
    end
    wb
  end
end
