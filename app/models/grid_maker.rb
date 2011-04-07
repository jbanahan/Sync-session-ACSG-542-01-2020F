#generates grids from search results
class GridMaker
  
  @objs
  @fields
  @chain
  @used_modules
  @criteria

  def initialize(base_objects,model_field_list,search_criterion_list,module_chain)
    @objs = base_objects
    @fields = model_field_list
    @chain = module_chain
    @criteria = search_criterion_list
    load_used_modules
  end

  def go(&block)
    recursive_go @chain.first, @objs, {}, &block
  end

  private

  def recursive_go(cm,base_object_collection,row_objects,&block)
    child_modules = @chain.child_modules cm #all modules lower than this one in the chain
    base_object_collection.each do |o| 
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
        mf = ModelField.find_by_uid f.model_field_uid
        row_obj = row_objects[mf.core_module]
        if row_obj.nil?
          r << ""
        else
          r << mf.process_export(row_objects[mf.core_module])
        end
      end
    end
    yield r, row_objects[@chain.first]
  end

  def test_row(row_objects)
    @criteria.each do |c|
      mf = c.find_model_field
      obj = row_objects[mf.core_module]
      val = mf.process_export(obj)
      return false if obj.nil? || !c.passes?(val) 
    end
    true
  end

  def load_used_modules
    um = Set.new
    @fields.each { |f| um << ModelField.find_by_uid(f.model_field_uid).core_module unless f.model_field_uid=="_blank" }
    @used_modules = um.to_a
  end
end
