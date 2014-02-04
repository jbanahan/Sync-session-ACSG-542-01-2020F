class SearchRun < ActiveRecord::Base

  PAGE_SIZE = 20

  before_save :set_user
  before_save :set_last_accessed

  belongs_to :search_setup
  belongs_to :imported_file
  belongs_to :custom_file
  belongs_to :user
  has_many :search_criterions, :dependent=>:destroy

  def self.find_last_run user, core_module
    SearchRun.
      joins("LEFT OUTER JOIN search_setups ON search_runs.search_setup_id = search_setups.id").
      joins("LEFT OUTER JOIN imported_files ON search_runs.imported_file_id = imported_files.id").
      joins("LEFT OUTER JOIN custom_files ON search_runs.custom_file_id = custom_files.id").
      where("search_setups.module_type = :core_module OR imported_files.module_type = :core_module OR custom_files.module_type = :core_module",:core_module=>core_module.class_name).
      where(:user_id=>user.id).
      order("ifnull(search_runs.last_accessed,1900-01-01) DESC").
      readonly(false). #http://stackoverflow.com/questions/639171/what-is-causing-this-activerecordreadonlyrecord-error/3445029#3445029
      first
  end

  #get the parent object (either search_run, imported_file, or custom_file)
  def parent
    return self.search_setup unless self.search_setup.blank?
    return self.imported_file unless self.imported_file.blank?
    return self.custom_file unless self.custom_file.blank?
    nil
  end

  def total_objects
    find_all_object_keys.size
  end

  def find_all_object_keys
    if @object_keys.blank?
      if !self.search_setup.nil? || !self.imported_file.nil?
        query = nil
        if !self.search_setup.nil?
          query = SearchQuery.new self.search_setup, self.user
        else
          # make sure we utilize the imported file's search aspect since we don't actually want to 
          # return every single result from the imported file if the user created a search over the imported result set
          query = SearchQuery.new self.imported_file, self.user, :extra_from=>self.imported_file.result_keys_from
        end
        
        @object_keys = query.result_keys
      elsif !self.custom_file.nil?
        # Avoid the linear key load from looping over the cf.custom_file_record's association also avoid pointless full object load
        @object_keys = CustomFileRecord.where(custom_file_id: self.custom_file.id).pluck(:linked_object_id)
      end
    end

    if block_given?
      @object_keys.each {|k| yield k}
    else
      @object_keys.to_enum(:each) {@object_keys.size}
    end
  end

  private 
  def set_user
    return unless self.user_id.blank? && self.user.blank?
    p = self.parent
    self.user = p.user if p && p.respond_to?(:user)
    self.user = p.uploaded_by if self.user.blank? && p && p.respond_to?(:uploaded_by)
    return
  end
  def set_last_accessed
    self.last_accessed = Time.now unless self.last_accessed
  end
end
