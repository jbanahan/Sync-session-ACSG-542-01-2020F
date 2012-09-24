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
  def self.generate_csv importer, file=nil
    d = nil
    f = nil
    DutyCalcExportFile.transaction do
      f = file.nil? ? Tempfile.new(["dcef",".csv"]) : file
      d = DutyCalcExportFile.create!(:importer_id=>importer.id)
      d.connection.execute "UPDATE duty_calc_export_file_lines SET duty_calc_export_file_id = #{d.id} WHERE duty_calc_export_file_id is null and importer_id = #{importer.id};"
      d.reload
      d.duty_calc_export_file_lines.each do |line|
        f << line.make_line_array.to_csv
      end
      f.flush
    end
    [d,f]
  end
end
