class FileImportResult < ActiveRecord::Base
  belongs_to :imported_file
  belongs_to :run_by, :class_name => "User"
  has_many :change_records

  def changed_objects
    r = self.change_records.collect {|a| a.recordable}
    r.uniq!
    r.delete nil
    r
  end

  def error_count
    self.change_records.where(:failed=>true).count
  end

end
