module ShallowMerger

  DONT_SHALLOW_MERGE = []

  def shallow_merge_into(other_obj,options={})
    dsm = DONT_SHALLOW_MERGE
    dont_copy = dsm.nil? ? [] : dsm    
    can_blank = options[:can_blank].nil? ? [] : options[:can_blank]

    updated_attribs = {}
    self.attributes.each_key do |k|
      unless dont_copy.include?(k)
        if other_obj.attribute_present?(k)
        updated_attribs[k] = other_obj.attributes[k]
        elsif can_blank.include?(k)
        updated_attribs[k] = nil
        end
      end
    end
    self.attributes= updated_attribs
  end
end
