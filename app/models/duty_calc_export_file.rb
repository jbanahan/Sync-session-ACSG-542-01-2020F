# == Schema Information
#
# Table name: duty_calc_export_files
#
#  created_at  :datetime         not null
#  id          :integer          not null, primary key
#  importer_id :integer
#  updated_at  :datetime         not null
#  user_id     :integer
#
# Indexes
#
#  index_duty_calc_export_files_on_importer_id  (importer_id)
#

require 'zip/filesystem'
require 'spreadsheet'
class DutyCalcExportFile < ActiveRecord::Base
  attr_accessible :importer_id, :user_id

  belongs_to :importer, :class_name=>"Company"
  has_many :duty_calc_export_file_lines, :dependent=>:destroy
  has_one :attachment, as: :attachable, dependent: :destroy

  # Make a new DutyCalcExportFile with an excel zip attached including all unused export lines for the
  # given importer
  def self.generate_for_importer importer, run_by=nil, file_path=nil, extra_where=nil, max_lines_per_file = 65000, max_files_per_zip = 3, duty_calc_format: :legacy
    importer = Company.find(importer) if importer.is_a?(Numeric) || importer.is_a?(String)
    r = []
    begin
      while DutyCalcExportFileLine.where(importer_id:importer.id).where(extra_where ? extra_where : "1=1").where('duty_calc_export_file_id is null').count > 0
        ActiveRecord::Base.transaction do
          fn = "duty_calc_export_#{importer.system_code.blank? ? importer.customs_identifier : importer.system_code}_#{Time.now.to_i}.zip"
          fp = "tmp/#{fn}"
          unless file_path.nil?
            fn = File.basename(file_path)
            fp = file_path
          end
          f, z = generate_excel_zip importer, fp, max_lines_per_file, extra_where, max_files_per_zip, duty_calc_format: duty_calc_format
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
  def self.generate_csv importer, file=Tempfile.new(["dcef", ".csv"]), extra_where = nil, duty_calc_format: :legacy
    d = generate_output_file(importer, extra_where) do |line|
      file << line.make_line_array(duty_calc_format: duty_calc_format).to_csv
    end
    file.flush
    [d, file]
  end

  # Generates a single zip file (in a Tempfile) with one or more excel files in it.  The total content is all available export lines for this importer
  def self.generate_excel_zip importer, file_path, max_lines_per_file=65000, extra_where = nil, max_files = 3, duty_calc_format: :legacy
    d = nil
    Zip::File.open(file_path, Zip::File::CREATE) do |zipfile|
      book = Spreadsheet::Workbook.new
      sheet = book.create_worksheet :name=>"SHEET1"
      row_count = 0
      file_count = 1
      # Headers aren't included in all versions of this file.
      headers = get_headers duty_calc_format
      if headers.length > 0
        r = sheet.row(row_count)
        headers.each_with_index {|v, i| r[i] = v }
        row_count += 1
      end
      limit_size = max_lines_per_file*max_files
      d = generate_output_file(importer, extra_where, limit_size) do |line|
        r = sheet.row(row_count)
        line.make_line_array(duty_calc_format: duty_calc_format).each_with_index {|v, i| r[i] = (v.is_a?(BigDecimal) ? v.to_s.to_f : v)}
        row_count += 1
        if row_count >= max_lines_per_file
          zipfile.file.open("File #{file_count}.xls", "w") {|f| book.write f}
          file_count += 1
          row_count = 0
          book = Spreadsheet::Workbook.new
          sheet = book.create_worksheet :name=>"SHEET1"
        end
      end
      if row_count > 0
        zipfile.file.open("File #{file_count}.xls", "w") {|f| book.write f}
      end
    end
    [d, File.new(file_path)]
  end

  def can_view? u
    u.edit_drawback?
  end

  def self.get_headers duty_calc_format
    arr = []
    # No longer used for original case that needed them (H&M).  Optional, format-specific headers can go here.
    arr
  end

  private
    def self.generate_output_file importer, extra_where, limit_size = nil
      DutyCalcExportFile.transaction do
        d = DutyCalcExportFile.create!(:importer_id=>importer.id)
        dcefl = DutyCalcExportFileLine.where(importer_id: d.importer_id, duty_calc_export_file_id: nil)
        if !extra_where.blank?
          dcefl = dcefl.where(extra_where)
        end

        if limit_size
          dcefl = dcefl.limit(limit_size)
        end

        dcefl.update_all duty_calc_export_file_id: d.id
        d.reload
        d.duty_calc_export_file_lines.each do |line|
          yield line
        end
        d
      end

    end
end
