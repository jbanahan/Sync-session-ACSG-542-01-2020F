class FileImportResult < ActiveRecord::Base
  belongs_to :imported_file
  belongs_to :run_by, :class_name => "User"
  has_many :change_records

  def changed_objects search_criterions=[]
    r = [] 
    if search_criterions.blank?
      r = self.change_records.collect {|a| a.recordable}
    else
      k = Kernel.const_get self.imported_file.core_module.class_name
      r = k.joins("INNER JOIN change_records on #{k.table_name}.id = change_records.recordable_id and change_records.recordable_type = '#{self.imported_file.core_module.class_name}'").
            where("change_records.file_import_result_id = ?",self.id)
      search_criterions.each do |sc|
        r = sc.apply r 
      end
      r = r.to_a
    end
    r.uniq!
    r.delete nil
    r
  end

  def error_count
    self.change_records.where(:failed=>true).count
  end

end
