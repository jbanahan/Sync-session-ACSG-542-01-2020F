class FileImportResult < ActiveRecord::Base
  belongs_to :imported_file
  belongs_to :run_by, :class_name => "User"
  has_many :change_records, :order => "failed DESC"

  after_save :update_changed_object_count
  
  def changed_objects search_criterions=[]
    k = Kernel.const_get self.imported_file.core_module.class_name
    r = k.where("#{k.table_name}.id IN (SELECT recordable_id FROM `change_records` WHERE file_import_result_id = ? AND recordable_type = '#{self.imported_file.core_module.class_name}')",self.id)
    search_criterions.each do |sc|
      r = sc.apply r 
    end
    r
  end

  def error_count
    self.change_records.where(:failed=>true).count
  end

  def update_changed_object_count
    if @changed_count_updated #keeps the query from being run on the second save
      @changed_count_updated = false
    end
    changed_count = self.changed_objects.count
    if changed_count != self.changed_object_count
      self.changed_object_count = changed_count
      @changed_count_updated = true
      self.save
    end
  end
end
