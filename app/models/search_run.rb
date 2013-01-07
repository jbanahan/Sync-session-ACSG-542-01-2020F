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

  def total_objects
    r = all_objects.size
    r.is_a?(Hash) ? r.size : r #if the search has a group by, then the first size call will return an ordered has
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

  def current_id
    c_obj = current_object
    c_obj.nil? ? nil : c_obj.id
  end

  def current_object
    find_object 0
  end

  def previous_object
    find_object -1
  end

  def previous_id
    p_obj = previous_object
    p_obj.nil? ? nil : p_obj.id
  end

  def next_object
    find_object 1
  end

  def next_id
    n_obj = next_object
    n_obj.nil? ? nil : n_obj.id
  end

  #advances internal cursor by 1
  def move_forward
    self.position = cursor+1
  end
  #moves internal cursor back by 1
  def move_back
    self.position = cursor-1
  end

  def cursor
    if self.position.nil?
      self.position=0
    end
    return self.position
  end

  def reset_cursor 
    self.position=nil
    self.result_cache=nil
    self.starting_cache_position = nil
  end

  private

  def find_object cursor_offset
    target = cursor + cursor_offset
    return nil if target < 0
    if !self.search_setup_id.nil?
      in_cache = !self.starting_cache_position.nil? && 
        !self.result_cache.nil? && 
        target >= self.starting_cache_position &&
        target < self.starting_cache_position+PAGE_SIZE
      if !in_cache
        target_page = target / PAGE_SIZE
        load_cache target_page 
      end
      get_object_from_cache target
    else
      if @changed_objects.nil?
        @changed_objects = all_objects
      end
      return target < @changed_objects.size ? @changed_objects[target] : nil
    end
  end

  def load_cache target_page
    @object_cache = search_setup.search.paginate(:per_page => PAGE_SIZE, :page => target_page+1) #target_page+1 because Will_paginate pages start with 1, not 0
    ids = @object_cache.collect {|o| o.id}
    self.result_cache = ids.to_yaml
    self.starting_cache_position = PAGE_SIZE * target_page
  end

  def get_object_from_cache target_position
    if target_position >= self.starting_cache_position && target_position < (self.starting_cache_position + PAGE_SIZE)
      cache_ids = YAML::load(self.result_cache)
      position_within_cache = target_position % PAGE_SIZE
      if position_within_cache < cache_ids.size
        target_id = cache_ids[position_within_cache]
        return self.search_setup.core_module.find target_id
      end
    end
    nil
  end

end
