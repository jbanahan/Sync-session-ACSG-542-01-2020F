# Cache of search result primary keys
# Expects result_cacheable to implmenent result_keys and take has with :per_page & :page
class ResultCache < ActiveRecord::Base
  attr_accessible :object_ids, :page, :per_page, :result_cacheable_id, :result_cacheable_type, :result_cacheable

  belongs_to :result_cacheable, :polymorphic=>true

  def next current_object_id
    a = id_array
    idx = a.index current_object_id #find the index of the current object
    return nil unless idx #return nil unless the current object was found
    return a[idx+1] unless idx>=a.size-1 #return the next object in the cache unless this is the last object
    load_next_page
    a = id_array
    idx = a.index(current_object_id) #index of this object in the next page
    while !idx.nil? && a.last==current_object_id #as long as this object is the last object in the page, keep going to the next page
      load_next_page
      a = id_array
      idx = a.index(current_object_id)
    end
    return nil if a.empty?
    return a.first unless idx #return the first object from the next page unless this object is found in the page
    return a[idx+1]
  end

  def previous current_object_id
    a = id_array
    idx = id_array.index current_object_id
    return nil unless idx
    return nil if idx==0 && page==1
    return a[idx-1] unless idx==0
    load_previous_page
    a = id_array
    idx = a.index(current_object_id)
    while !idx.nil? && idx == 0
      load_previous_page
      a = id_array
      idx = a.index(current_object_id)
    end
    return nil if a.empty?
    return a.last unless a.last==current_object_id
    return a[idx-1]
  end

  private
  #parse the object_ids into an array of integers
  def id_array
    load_current_page if self.object_ids.blank?
    JSON.parse self.object_ids
  end
  def load_current_page
    self.page = 1 if self.page.blank? || self.page < 1
    self.object_ids = self.result_cacheable.result_keys(:per_page=>self.per_page,:page=>self.page).to_json
    self.save!
  end
  def load_next_page
    self.page += 1 unless self.page.blank?
    load_current_page
  end
  def load_previous_page
    self.page -= 1 unless self.page.blank?
    load_current_page
  end
end
