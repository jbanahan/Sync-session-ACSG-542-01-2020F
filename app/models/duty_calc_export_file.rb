require 'zip/zipfilesystem'
require 'spreadsheet'
class DutyCalcExportFile < ActiveRecord::Base
  belongs_to :importer, :class_name=>"Company"
  has_many :duty_calc_export_file_lines, :dependent=>:destroy
  has_one :attachment, as: :attachable, dependent: :destroy

  # Make a new DutyCalcExportFile with an excel zip attached including all unused export lines for the 
  # given importer
  def self.generate_for_importer importer, run_by=nil, file_path=nil, extra_where=nil, max_lines_per_file = 65000, max_files_per_zip = 3
    r = []
    begin
      while DutyCalcExportFileLine.where(importer_id:importer.id).where(extra_where ? extra_where : "1=1").where('duty_calc_export_file_id is null').count > 0
        ActiveRecord::Base.transaction do
          importer = Company.find(importer) if importer.is_a?(Fixnum) || importer.is_a?(String)
          fn = "duty_calc_export_#{importer.system_code.blank? ? importer.alliance_customer_number : importer.system_code}_#{Time.now.to_i}.zip"
          fp = "tmp/#{fn}"
          unless file_path.nil? 
            fn = File.basename(file_path)
            fp = file_path
          end
          f, z = generate_excel_zip importer, fp, max_lines_per_file, extra_where, max_files_per_zip
          Attachment.add_original_filename_method z
          z.original_filename = fn 
          att = f.build_attachment
          att.attached= z
          att.save!
          File.delete z.path
          r << f
        end
      end
    rescue
      $!.log_me
      run_by.messages.create(subject:"Drawback Export File Processing Error",
        body:"Your drawback export file processing has failed. #{r.size} file(s) were created successfully before failure and can be retreived from the drawback upload page.") if run_by
      raise $!
    end
    run_by.messages.create(subject:"Drawback Export File Processing Complete - #{r.size} file(s)",
      body:"The drawback export file processing is complete for importer #{importer.name}. #{r.size} file(s) are available via the drawback upload page."
    ) if run_by
    r
  end

  # Collects all existing DutyCalcExportFileLines that are not already assigned to another file
  # and creates a new file with them.  
  # 
  # It will generate and return an array with the generated object and a reference the physical file that was created.
  #
  # optional extra_where will be added to teh existing where clauses (it doesn't replace the whole where clause)
  #
  # Usage:
  #     duty_calc_export_file_object, real_output_file = DutyCalcExportFile.generate_file importer_id
  def self.generate_csv importer, file=Tempfile.new(["dcef",".csv"]), extra_where = nil
    d = generate_output_file(importer,extra_where) do |line|
      file << line.make_line_array.to_csv
    end
    file.flush
    [d,file]
  end

  # Generates a single zip file (in a Tempfile) with one or more excel files in it.  The total content is all available export lines for this importer
  def self.generate_excel_zip importer, file_path, max_lines_per_file=65000, extra_where = nil, max_files = 3
    d = nil
    Zip::ZipFile.open(file_path,Zip::ZipFile::CREATE) do |zipfile|
      book = Spreadsheet::Workbook.new
      sheet = book.create_worksheet :name=>"SHEET1"
      row_count = 0
      file_count = 1
      limit_size = max_lines_per_file*max_files
      d = generate_output_file(importer,extra_where,limit_size) do |line|
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
    [d,File.new(file_path)]
  end

  def can_view? u
    u.edit_drawback?
  end
  private
  def self.generate_output_file importer, extra_where, limit_size = nil
    DutyCalcExportFile.transaction do
      d = DutyCalcExportFile.create!(:importer_id=>importer.id)
      sql = "UPDATE duty_calc_export_file_lines SET duty_calc_export_file_id = #{d.id} WHERE duty_calc_export_file_id is null and importer_id = #{importer.id} AND (#{extra_where ? extra_where : '1=1'})"
      sql << " LIMIT #{limit_size}" if limit_size
      d.connection.execute sql
      d.reload
      d.duty_calc_export_file_lines.each do |line|
        yield line
      end
      d
    end
    
  end
end
