class DutyCalcImportFile < ActiveRecord::Base
  has_many :duty_calc_import_file_lines, :dependent=>:destroy
  belongs_to :importer, :class_name=>"Company"


  def self.generate_file user, f=Tempfile.new(['duty_calc_import_','.csv'])
    dif = DutyCalcImportFile.create!(:user_id=>user.id)
    DutyCalcImportFile.connection.execute("INSERT INTO duty_calc_import_file_lines (duty_calc_import_file_id,drawback_import_line_id) SELECT #{dif.id}, dil.id FROM drawback_import_lines dil left outer join duty_calc_import_file_lines difl ON dil.id = difl.drawback_import_line_id WHERE difl.id is NULL;")
    dif.reload
    dif.duty_calc_import_file_lines.includes(:drawback_import_line).each do |difl|
      f << difl.drawback_import_line.duty_calc_line
    end
    f.close
    f
  end
end
