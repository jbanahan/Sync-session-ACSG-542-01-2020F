class FileImportProcessor 
  def initialize(import_file, data)
    @import_file = import_file
    @search_setup = import_file.search_setup
    @core_module = CoreModule.find_by_class_name(@search_setup.module_type)
    @module_chain = @core_module.default_module_chain
    @data = data
  end
  
  def process
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
  
  def preview
    CSV.parse(@data,{:headers => @import_file.ignore_first_row}) do |row|
      return do_row row, false
    end
  end
  
  private
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
            custom_fields[uid] = data
          else
            messages << mf.process_import(obj, data)
          end
        end
        obj = merge_or_create obj, save
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
=begin
  def do_row(row, save)
    messages = []
    o = @core_module.new_object
    detail_hash = {}
    detail_data_exists = {}
    can_blank = []
		custom_fields = []
    @search_setup.sorted_columns.each do |m|
      mf = m.find_model_field
      can_blank << mf.field_name.to_s
      to_send = object_to_send(detail_hash, o, mf)
      data = row[m.rank]
      if data
        if mf.custom?
          custom_fields << {:field => mf, :data => data}
        else
          detail_data_exists[mf.core_module] = true if data.length > 0 && detail_field?(mf)
          messages << mf.process_import(to_send,row[m.rank])
        end
      end
    end
    o = merge_or_create(o,save,{:can_blank => can_blank})
    detail_hash.each {|core_module,d|
      unless detail_data_exists[core_module].nil? 
        d = merge_or_create(d,save,{:can_blank => can_blank, :parent => o})
      end
    }
		custom_fields.each do |h|
			obj = object_to_send(detail_hash,o,h[:field])
			cd = CustomDefinition.find(h[:field].custom_id)
			cv = obj.get_custom_value(cd)
			cv.value = h[:data]
			messages << "#{cd.label} set to #{cv.value}"
			cv.save if save
		end
    return messages
  end 
=end  
  def detail_field?(m_field)
    m_field.core_module!=@core_module
  end
  
  def object_to_send(d_hash,o,m_field)
    return o if !detail_field?(m_field)
    mcm = m_field.core_module
    d_hash[mcm] =  mcm.new_object if d_hash[mcm].nil?
    return d_hash[mcm]
  end
  
  def merge_or_create(base,save,options={})
#set_detail_parent base, options[:parent] unless options[:parent].nil?
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
#def set_detail_parent(detail,parent)
    #default is no child objects so nothing to do here
#end
  
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
#def set_detail_parent(detail,parent)
#     detail.order = parent
#   end
    
    def before_merge(shell,database_object)
      if shell.class == Order && !shell.vendor_id.nil? && shell.vendor_id != database_object.vendor_id
          raise "An order's vendor cannot be changed via a file upload."
      end
    end
  end
end


