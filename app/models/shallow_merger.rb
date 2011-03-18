module ShallowMerger

  DONT_SHALLOW_MERGE = {}
  def self.included(base)
      base.extend(ClassMethods)
  end
  
  module ClassMethods
    def dont_shallow_merge base_class, field_array
      DONT_SHALLOW_MERGE[base_class] = field_array
    end
  end

  def shallow_merge_into(other_obj,options={})
    dsm = DONT_SHALLOW_MERGE[self.class.to_s.to_sym]
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
