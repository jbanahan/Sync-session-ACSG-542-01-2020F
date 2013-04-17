require 'will_paginate/array'
class SearchRun < ActiveRecord::Base

  PAGE_SIZE = 20

  belongs_to :search_setup
  belongs_to :imported_file
  belongs_to :custom_file
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
    r = all_objects.size
    r.is_a?(Hash) ? r.size : r #if the search has a group by, then the first size call will return an ordered hash
  end

  def all_objects
    return @changed_objects unless @changed_objects.blank?
    r = []
    if !self.search_setup.nil?
      r = self.search_setup.search.readonly(false) 
    elsif !self.imported_file.nil? 
      fir = self.imported_file.last_file_import_finished
      r = fir.changed_objects unless fir.nil?
    elsif !self.custom_file.nil?
      r = self.custom_file.custom_file_records.collect {|cfr| cfr.linked_object}
    end
    @changed_objects = r
    return @changed_objects
  end
end
