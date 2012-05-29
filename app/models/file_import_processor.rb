class FileImportProcessor 
  require 'open_chain/field_logic.rb'

#YOU DON'T NEED TO CALL ANY INSTANCE METHODS, THIS USES THE FACTORY PATTERN, JUST CALL FileImportProcessor.preview or .process
  def self.process(import_file,listeners=[])
    find_processor(import_file,listeners).process_file
  end
  def self.preview(import_file)
    find_processor(import_file,[PreviewListener.new]).preview_file
  end

  def initialize(import_file, data, listeners=[])
    @import_file = import_file
    @search_setup = import_file.search_setup
    @core_module = CoreModule.find_by_class_name(import_file.module_type)
    @module_chain = @core_module.default_module_chain
    @data = data
    @listeners = listeners
    @custom_definition_map = {}
    CustomDefinition.all.each do |cd|
      @custom_definition_map[cd.id] = cd
    end
  end
  
  
  def process_file
    begin
      fire_start
      fire_row_count self.row_count
      processed_row = false
      r = @import_file.starting_row - 1
      get_rows do |row|
        begin
          obj = do_row r+1, row, true
          obj.errors.full_messages.each {|m| @import_file.errors[:base] << "Row #{r+1}: #{m}"}
        rescue => e
          @import_file.errors[:base] << "Row #{r+1}: #{e.message}"
        end
        r += 1
      end
    rescue => e
      e.log_me ["Imported File ID: #{@import_file.id}"]
      @import_file.errors[:base] << "Row #{r+1}: #{e.message}"
    ensure
      fire_end
    end 
  end
  
  def preview_file
    get_rows do |row|
      do_row @import_file.starting_row, row, false
      return @listeners.first.messages
    end
  end
  def self.find_processor import_file, listeners=[]
    if import_file.attached_file_name.downcase.ends_with?("xls") 
      return SpreadsheetImportProcessor.new(import_file,import_file.attachment_as_workbook,listeners)
    else
      return CSVImportProcessor.new(import_file,import_file.attachment_data,listeners)
    end
  end
  def do_row row_number, row, save
    messages = []
    object_map = {}
    begin
      ActiveRecord::Base.transaction do
        data_map = {}
        @module_chain.to_a.each do |mod|
          data_map[mod] = {}
        end
        columns = @import_file.sorted_columns.blank? ? @search_setup.sorted_columns : @import_file.sorted_columns
        columns.each do |col|
          mf = col.find_model_field
          r = row[col.rank + @import_file.starting_column - 1]
          r = r.strip if r.is_a? String
          data_map[mf.core_module][mf.uid]=r unless mf.uid==:_blank
        end
        @module_chain.to_a.each do |mod|
          if fields_for_me_or_children? data_map, mod
            parent_mod = @module_chain.parent mod
            obj = parent_mod.nil? ? mod.new_object : parent_mod.child_objects(mod,object_map[parent_mod]).build
            @core_object = obj if parent_mod.nil? #this is the top level object
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
            obj = merge_or_create obj, save, !parent_mod #if !parent_mod then we're at the top level
            @core_object = obj unless parent_mod #this is the replaced top level object
            object_map[mod] = obj
            cv_map = {}
            obj.custom_values.each {|c| cv_map[c.custom_definition_id]=c}
            custom_fields.each do |mf,data|
              cd = @custom_definition_map[mf.custom_id]
              cv = cv_map[cd.id]
              cv = obj.custom_values.build(:custom_definition_id=>cd.id) if cv.nil?
              orig_value = cv.value
              if cd.data_type.to_sym==:boolean
                set_boolean_value cv, data
              else
                cv.value = data
              end
              messages << "#{cd.label} set to #{cv.value}"
              cv.save! if save && !(orig_value.blank? && data.blank?) 
            end
            object_map[mod] = obj
          end
        end
        if save
          object_map.values.each do |obj|
            if obj.class.include?(StatusableSupport)
              obj.set_status
              obj.save!
            end
          end
        end
        Rails.logger.info "object_map[@core_module] is nill for row #{row_number} in imported_file: #{@import_file.id}" if object_map[@core_module].nil?
        OpenChain::FieldLogicValidator.validate! object_map[@core_module] unless object_map[@core_module].nil?
        fire_row row_number, object_map[@core_module], messages
      end
    rescue OpenChain::ValidationLogicError
      my_base = $!.base_object
      my_base = @core_object unless my_base
      my_base = object_map[@core_module] unless my_base
      my_base.errors.full_messages.each {|m| 
        messages << "ERROR: #{m}"
      }
      fire_row row_number, nil, messages, true #true = failed
    rescue
      fire_row row_number, nil, messages, true
      raise $!
    end
    @core_object
  end

  #is this record allowed to be added / updated based on the search_setup's update mode
  def update_mode_check obj, update_mode, was_new
    case update_mode
    when "add"
      @created_objects = [] unless @created_objects
      FileImportProcessor.raise_validation_exception obj, "Cannot update record when Update Mode is set to \"Add Only\"." if !was_new && !@created_objects.include?(obj.id)
      @created_objects << obj.id #mark that this object was created in this session so we know it can be updated again even in add mode
    when "update"
      FileImportProcessor.raise_validation_exception obj, "Cannot add a record when Update Mode is set to \"Update Only\"." if was_new
    end
  end
  
  def set_boolean_value cv, data
    if !data.nil? && data.to_s.length>0
      dstr = data.to_s.downcase.strip
      if ["y","t"].include?(dstr[0])
        cv.value = true
      elsif ["n","f"].include?(dstr[0])
        cv.value = false
      end
    end
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
  
  def merge_or_create(base,save,is_top_level,options={})
    dest = base.find_same
    if dest.nil?
      dest = base
    else
      base.destroy
      before_merge base, dest
      dest.shallow_merge_into base, options
    end
    is_new = dest.new_record?
    before_save dest
    dest.save! if save
    #if this is the top level object, check against the search_setup#update_mode
    update_mode_check(dest,@import_file.update_mode,is_new) if is_top_level
    return dest
  end
  
  def before_save(dest)
    get_rules_processor.before_save dest, @core_object
  end
  
  def before_merge(shell,database_object)
    get_rules_processor.before_merge shell, database_object, @core_object
  end

  def get_rules_processor
    if @rules_processor.nil?
      p = {
      :Order => OrderRulesProcessor,
      :Product => ProductRulesProcessor,
      :SalesOrder => SaleRulesProcessor
      }
      h = p[@import_file.search_setup.module_type.intern]
      @rules_processor = h.nil? ? RulesProcessor.new : h.new
    end
    @rules_processor
  end

  def self.raise_validation_exception core_object, message
    core_object.errors[:base] << message
    raise OpenChain::ValidationLogicError.new(core_object)
  end

  class CSVImportProcessor < FileImportProcessor

    def row_count 
      @data.lines.count - (@import_file.starting_row - 1)
    end
    def get_rows &block
      r = 0
      start_row = @import_file.starting_row - 1
      CSV.parse(@data,{:skip_blanks=>true}) do |row|
        yield row if r >= start_row
        r += 1
      end
    end
  end

  class SpreadsheetImportProcessor < FileImportProcessor
    def row_count
      s = @data.worksheet(0).row_count - (@import_file.starting_row - 1)
    end
    def get_rows &block
      @data
      s = @data.worksheet 0
      s.each (@import_file.starting_row-1) do |row|
        process = false
        row.each do |v|
          if !v.blank?
            process = true
            break
          end
        end
        yield row if process
      end
    end
  end
    
  class RulesProcessor
    def before_save obj, top_level_object
      #stub
    end
    def before_merge obj, database_object, top_level_object
      #stub
    end
  end

  class ProductRulesProcessor < RulesProcessor
    def before_save obj, top_level_object
      if obj.is_a? TariffRecord
        #make sure the tariff is valid
        country_id = obj.classification.country_id
        [obj.hts_1,obj.hts_2,obj.hts_3].each_with_index do |h,i|
          unless h.blank?
            ot = OfficialTariff.find_cached_by_hts_code_and_country_id h.strip, country_id 
            FileImportProcessor.raise_validation_exception top_level_object, "HTS Number #{h.strip} is invalid for #{Country.find_cached_by_id(country_id).iso_code}." if ot.nil?
          end
        end
        #make sure the line number is populated (we don't allow auto-increment line numbers in file uploads)
        FileImportProcessor.raise_validation_exception top_level_object, "Line cannot be processed with empty #{ModelField.find_by_uid(:hts_line_number).label}." if obj.line_number.blank?
      elsif obj.is_a? Classification
        #make sure there is a country
        if obj.country_id.blank? && obj.country.blank?
          FileImportProcessor.raise_validation_exception top_level_object, "Line cannot be processed with empty classification country."
        end
      end
    end
    
    def before_merge(shell,database_object,top_level_object)
      if shell.class==Product && !shell.vendor_id.nil? && !database_object.vendor_id.nil? && shell.vendor_id != database_object.vendor_id
          FileImportProcessor.raise_validation_exception top_level_object, "An product's vendor cannot be changed via a file upload."
      end
    end
  end

  class OrderRulesProcessor < RulesProcessor
    
    def before_merge(shell,database_object,top_level_object)
      if shell.class == Order && !shell.vendor_id.nil? && shell.vendor_id != database_object.vendor_id
          FileImportProcessor.raise_validation_exception top_level_object, "An order's vendor cannot be changed via a file upload."
      end
    end
  end

  class SaleRulesProcessor < CSVImportProcessor
    def before_merge(shell,database_object,top_level_object)
      if shell.class == SalesOrder && !shell.customer_id.nil? && shell.customer_id!=database_object.customer_id
        FileImportProcessor.raise_validation_exception top_level_object, "A sale's customer cannot be changed via a file upload."
      end
    end
  end

  private
  def fire_start
    fire_event :process_start, Time.now
  end

  def fire_row_count count
    fire_event :process_row_count, count
  end
  def fire_row row_number, obj, messages, failed=false
    @listeners.each {|ls| ls.process_row row_number, obj, messages, failed if ls.respond_to?('process_row')}
  end

  def fire_end
    fire_event :process_end, Time.now
  end

  def fire_event method, data 
    @listeners.each {|ls| ls.send method, data if ls.respond_to?(method) }
  end

  class PreviewListener
    attr_accessor :messages
    def process_row row_number, object, messages, failed=false
      self.messages = messages
    end

    def process_start time
      #stub
    end

    def process_end time
      #stub
    end
  end
end


