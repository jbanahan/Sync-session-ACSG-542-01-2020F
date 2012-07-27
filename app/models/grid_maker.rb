#generates grids from search results
class GridMaker

  #returns an array of for the object given in the same order as the given model fields
  def self.single_row object, model_fields, search_criterions, module_chain, user
    r = []
    GridMaker.new([object],model_fields,search_criterions,module_chain, user).go {|v,o| r = v}
    r
  end

  def initialize(base_objects,model_field_list,search_criterion_list,module_chain,user)
    @objs = base_objects
    @fields = model_field_list
    #if we have more than 2 custom columns, then pre-cache the custom values
    @custom_ids = @fields.collect {|f| f.model_field.custom_id }
    @chain = module_chain
    @criteria = search_criterion_list
    @criteria.each {|sc| @custom_ids << sc.model_field.custom_id}
    @custom_ids.compact!
    @user = user
    load_used_modules
  end

  def go(&block)
    recursive_go @chain.first, @objs, {}, &block
  end

  private

  def recursive_go(cm,base_object_collection,row_objects,&block)
    child_modules = @chain.child_modules cm #all modules lower than this one in the chain
    custom_value_hash = {}
    unless @custom_ids.blank?
      base_object_collection.in_groups_of(50,false) do |base_objects|
        ids = base_objects.collect {|bo| bo.id}
        vals = CustomValue.where("custom_values.customizable_id IN (?)",ids).
          where("custom_values.customizable_type = ?",cm.class_name).
          where("custom_values.custom_definition_id IN (?)",@custom_ids)
        vals.each do |v| 
          custom_value_hash[v.customizable_id] ||= []
          custom_value_hash[v.customizable_id] << v
        end
        base_objects.each {|b| b.lock_custom_values = true if b.respond_to?(:lock_custom_values)}
      end
    end 
    base_object_collection.each do |o| 
      if o.respond_to?(:inject_custom_value) && !custom_value_hash[o.id].blank?
        custom_value_hash[o.id].each {|cv| o.inject_custom_value cv}
      end
#      o.load_custom_values custom_value_hash[o.id] if !custom_value_hash[o.id].blank? && o.respond_to?(:load_custom_values) && !@custom_ids.blank?
      row_objects[cm] = o #add myself to row_objects
      #there are lower level modules being used, recurse
      if (@used_modules & child_modules).length > 0 && cm.child_objects(child_modules.first,o).length > 0
        recursive_go child_modules.first, cm.child_objects(child_modules.first, o), row_objects, &block
      else #we're at the bottom of the chain, make the row
        make_row row_objects, &block
      end
      row_objects[cm] = nil #remove myself from row objects
    end    
  end

  def make_row(row_objects,&block)
    return nil unless test_row(row_objects) #test against criteria before rendering row
    r = []
    @fields.each do |f|
      if f.model_field_uid=="_blank"
        r << ""
      else
        mf = f.model_field
        row_obj = row_objects[mf.core_module]
        if row_obj.nil?
          r << ""
        else
          r << mf.process_export(row_objects[mf.core_module],@user)
        end
      end
    end
    yield r, row_objects[@chain.first]
  end

  def test_row(row_objects)
    @criteria.each do |c|
      mf = c.find_model_field
      obj = row_objects[mf.core_module]
      val = mf.process_export(obj,@user)
      if obj.nil? && ["null","nq"].include?(c.operator)
        #ok, just continue to testing the next criterion
      elsif obj.nil? || !c.test?(obj)
        return false
      end
    end
    true
  end

  def load_used_modules
    um = Set.new
    @fields.each { |f| um << f.model_field.core_module unless f.model_field_uid=="_blank" }
    @used_modules = um.to_a
  end
end
