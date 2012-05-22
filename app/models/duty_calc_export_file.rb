class DutyCalcExportFile < ActiveRecord::Base
  has_many :duty_calc_export_file_lines, :dependent=>:destroy

  # Collects all existing DutyCalcExportFileLines that are not already assigned to another file
  # and creates a new file with them.  
  # 
  # It will generate and return an array with the generated object and a reference the physical file that was created.
  #
  # Usage:
  #     duty_calc_export_file_object, real_output_file = DutyCalcExportFile.generate_file
  def self.generate_csv file=nil
    f = file.nil? ? Tempfile.new(["dcef",".csv"]) : file
    d = DutyCalcExportFile.create!
    d.connection.execute "UPDATE duty_calc_export_file_lines SET duty_calc_export_file_id = #{d.id} WHERE duty_calc_export_file_id is null;"
    d.reload
    d.duty_calc_export_file_lines.each do |line|
      f << line.make_line_array.to_csv
    end
    f.flush
    [d,f]
  end
end
