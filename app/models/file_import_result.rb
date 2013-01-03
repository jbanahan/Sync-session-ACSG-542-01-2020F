class FileImportResult < ActiveRecord::Base
  belongs_to :imported_file
  belongs_to :run_by, :class_name => "User"
  has_many :change_records, :order => "failed DESC, record_sequence_number ASC"

  after_save :update_changed_object_count
  
  def changed_objects search_criterions=[]
    cm = self.imported_file.core_module
    k = Kernel.const_get cm.class_name
    r = k.select("DISTINCT `#{cm.table_name}`.*").joins(:change_records).where('change_records.file_import_result_id = ?',self.id)
    search_criterions.each do |sc|
      r = sc.apply r 
    end
    #really bad hack here to accomodate bug: https://github.com/rails/rails/issues/5554
    def r.count
      self.to_a.size
    end
    def r.size
      self.to_a.size
    end
    r
  end

  # return the total minutes to process the file or nil if the file does not have a start_at and finish_at value
  # returns 1 (never 0) if the time is less than one minute
  def time_to_process
    return nil unless self.started_at && self.finished_at
    seconds = self.finished_at - self.started_at
    minutes = (seconds/60).round
    minutes == 0 ? 1 : minutes
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
