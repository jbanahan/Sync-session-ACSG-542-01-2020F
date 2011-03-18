class FileImportProcessor 
#YOU DON'T NEED TO CALL ANY INSTANCE METHDOS, THIS USES THE FACTORY PATTERN, JUST CALL FileImportProcessor.preview or .process
  def self.process(import_file, data)
    find_processor(import_file, data).process_file
  end
  def self.preview(import_file, data)
    find_processor(import_file, data).preview_file
  end

  def initialize(import_file, data)
    @import_file = import_file
    @search_setup = import_file.search_setup
    @core_module = CoreModule.find_by_class_name(@search_setup.module_type)
    @module_chain = @core_module.default_module_chain
    @data = data
  end
  
  
  def process_file
    processed_row = false
    begin
      r = @import_file.ignore_first_row ? 1 : 0
      CSV.parse(@data,{:skip_blanks=>true,:headers => @import_file.ignore_first_row}) do |row|
        begin
          do_row row, true
        rescue => e
          @import_file.errors[:base] << "Row #{r+1}: #{e.message}"
        end
        r += 1
      end
    rescue => e
      @import_file.errors[:base] << "Row #{r+1}: #{e.message}"
    end 
  end
  
  def preview_file
    CSV.parse(@data,{:headers => @import_file.ignore_first_row}) do |row|
      return do_row row, false
    end
  end
  def self.find_processor import_file, data  
    p = {
    :Order => {:csv => OrderCSVImportProcessor},
    :Product => {:csv => ProductCSVImportProcessor},
    :SalesOrder => {:csv => SaleCSVImportProcessor}
    }
    h = p[import_file.search_setup.module_type.intern]
    r = h.nil? ? CSVImportProcessor : h[:csv]
    r.new(import_file, data)
  end
  def do_row row, save
    messages = []
    data_map = {}
    @module_chain.to_a.each do |mod|
      data_map[mod] = {}
    end
    @search_setup.sorted_columns.each do |col|
      mf = col.find_model_field
      data_map[mf.core_module][mf.uid]=row[col.rank]
    end
    object_map = {}
    @module_chain.to_a.each do |mod|
      if fields_for_me_or_children? data_map, mod
        parent_mod = @module_chain.parent mod
        obj = parent_mod.nil? ? mod.new_object : parent_mod.child_objects(mod,object_map[parent_mod]).build
        object_map[mod] = obj
        custom_fields = {}
        data_map[mod].each do |uid,data|
          mf = ModelField.find_by_uid uid
          if mf.custom?
            custom_fields[mf] = data
          else
            messages << mf.process_import(obj, data)
          end
        end
        obj = merge_or_create obj, save
        custom_fields.each do |mf,data|
          cd = CustomDefinition.find mf.custom_id
          cv = obj.get_custom_value cd
          cv.value = data
          messages << "#{cd.label} set to #{cv.value}"
          cv.save if save
        end
        object_map[mod] = obj
      end
    end
    messages
  end

  def fields_for_me_or_children? data_map, cm
    return true if data_map_has_values? data_map[cm] 
    @module_chain.child_modules(cm).each do |child|
      return true if data_map_has_values? data_map[child]
    end
    return false
  end

  def data_map_has_values? data_map_hash
    data_map_hash.values.each do |v|
      return true unless v.blank?
    end
    return false
  end
  
  def merge_or_create(base,save,options={})
    dest = base.find_same
    if dest.nil?
      dest = base
    else
      before_merge base, dest
      dest.shallow_merge_into base, options
    end
    before_save dest
    dest.save! if save
    return dest
  end
  
  def before_save(dest)
    #do nothing
  end
  
  def before_merge(shell,database_object)
    #default is no validations so nothing to do here
  end

  class CSVImportProcessor < FileImportProcessor


  end
    
  class ProductCSVImportProcessor < CSVImportProcessor
    def before_save(obj)
      #default to first division in database
      if obj.class==Product && obj.division_id.nil? 
        obj.division_id = Division.first.id
      end
    end
    
    def before_merge(shell,database_object)
      if shell.class==Product && !shell.vendor_id.nil? && shell.vendor_id != database_object.vendor_id
          raise "An product's vendor cannot be changed via a file upload."
      end
    end
  end

  class OrderCSVImportProcessor < CSVImportProcessor
    
    def before_merge(shell,database_object)
      if shell.class == Order && !shell.vendor_id.nil? && shell.vendor_id != database_object.vendor_id
          raise "An order's vendor cannot be changed via a file upload."
      end
    end
  end

  class SaleCSVImportProcessor < CSVImportProcessor
    def before_merge(shell,database_object)
      if shell.class == SalesOrder && !shell.customer_id.nil? && shell.customer_id!=database_object.customer_id
        raise "A sale's customer cannot be changed via a file upload."
      end
    end
  end
end


