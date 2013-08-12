require 'zip/zipfilesystem'
require 'spreadsheet'
class DutyCalcImportFile < ActiveRecord::Base
  has_many :duty_calc_import_file_lines, :dependent=>:destroy
  has_one :attachment, as: :attachable, dependent: :destroy
  belongs_to :importer, :class_name=>"Company"

  #make zip of excel files and attach to object
  def self.generate_for_importer importer, run_by, file_path=nil
    ActiveRecord::Base.transaction do
      importer = Company.find(importer) if importer.is_a?(Fixnum) || importer.is_a?(String)
      fn = "duty_calc_import_#{importer.system_code.blank? ? importer.alliance_customer_number : importer.system_code}_#{Time.now.to_i}.zip"
      fp = "tmp/#{fn}"
      unless file_path.nil? 
        fn = File.basename(file_path)
        fp = file_path
      end
      f, z = generate_excel_zip importer, run_by, fp
      Attachment.add_original_filename_method z
      z.original_filename = fn 
      att = f.build_attachment
      att.attached= z
      att.save!
      run_by.messages.create(subject:"Drawback Import File Processing Complete - #{fn}",
        body:"The drawback import file #{fn} has finished processing and can be retreived from the drawback upload page."
      )
      [f,z]
    end
  end
  
  #make zip of excel files
  def self.generate_excel_zip importer, user, file_path, max_lines_per_file=65000
    d = nil
    Zip::ZipFile.open(file_path,Zip::ZipFile::CREATE) do |zipfile|
      book = Spreadsheet::Workbook.new
      sheet = book.create_worksheet :name=>"SHEET1"
      row_count = 0
      file_count = 1
      d = generate_output_file(importer,user) do |line|
        r = sheet.row(row_count)
        line.drawback_import_line.duty_calc_line_array.each_with_index {|v,i| r[i] = (v.is_a?(BigDecimal) ? v.to_s.to_f : v)}
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
  #make CSV file
  def self.generate_file importer, user, f=Tempfile.new(['duty_calc_import_','.csv'])
    d = generate_output_file(importer,user) do |difl|
      f << difl.drawback_import_line.duty_calc_line
    end
    f.close
    [d,f]
  end

  def can_view? u
    u.edit_drawback?
  end
  private
  def self.generate_output_file importer, user
    ActiveRecord::Base.transaction do 
      dif = DutyCalcImportFile.create!(:user_id=>user.id,:importer_id=>importer.id)
      DutyCalcImportFile.connection.execute("INSERT INTO duty_calc_import_file_lines (duty_calc_import_file_id,drawback_import_line_id) SELECT #{dif.id}, dil.id FROM drawback_import_lines dil left outer join duty_calc_import_file_lines difl ON dil.id = difl.drawback_import_line_id WHERE difl.id is NULL AND dil.importer_id = #{importer.id};")
      dif.reload
      dif.duty_calc_import_file_lines.includes(:drawback_import_line).each do |difl|
        yield difl
      end
      dif
    end
  end
end
