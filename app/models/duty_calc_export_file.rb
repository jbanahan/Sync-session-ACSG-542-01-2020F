require 'zip/zipfilesystem'
require 'spreadsheet'
class DutyCalcExportFile < ActiveRecord::Base
  belongs_to :importer, :class_name=>"Company"
  has_many :duty_calc_export_file_lines, :dependent=>:destroy

  # Collects all existing DutyCalcExportFileLines that are not already assigned to another file
  # and creates a new file with them.  
  # 
  # It will generate and return an array with the generated object and a reference the physical file that was created.
  #
  # Usage:
  #     duty_calc_export_file_object, real_output_file = DutyCalcExportFile.generate_file importer_id
  def self.generate_csv importer, file=Tempfile.new(["dcef",".csv"])
    d = generate_output_file(importer) do |line|
      file << line.make_line_array.to_csv
    end
    file.flush
    [d,file]
  end

  # Generates a single zip file (in a Tempfile) with one or more excel files in it.  The total content is all available export lines for this importer
  def self.generate_excel_zip importer, file_path, max_lines_per_file=65000
    Zip::ZipFile.open(file_path,Zip::ZipFile::CREATE) do |zipfile|
      book = Spreadsheet::Workbook.new
      sheet = book.create_worksheet :name=>"SHEET1"
      row_count = 0
      file_count = 1
      generate_output_file(importer) do |line|
        r = sheet.row(row_count)
        line.make_line_array.each_with_index {|v,i| r[i] = (v.is_a?(BigDecimal) ? v.to_s.to_f : v)}
        row_count += 1
        if row_count >= max_lines_per_file
          zipfile.file.open("File #{file_count}.xls","w") {|f| book.write f}
          file_count += 1
          row_count = 0
          book = Spreadsheet::Workbook.new
          sheet = book.create_worksheet :name=>"SHEET1"
        end
      end
      if row_count > 0
        zipfile.file.open("File #{file_count}.xls","w") {|f| book.write f}
      end
    end
    File.new(file_path)
  end

  private
  def self.generate_output_file importer
    DutyCalcExportFile.transaction do
      d = DutyCalcExportFile.create!(:importer_id=>importer.id)
      d.connection.execute "UPDATE duty_calc_export_file_lines SET duty_calc_export_file_id = #{d.id} WHERE duty_calc_export_file_id is null and importer_id = #{importer.id};"
      d.reload
      d.duty_calc_export_file_lines.each do |line|
        yield line
      end
      d
    end
    
  end
end
