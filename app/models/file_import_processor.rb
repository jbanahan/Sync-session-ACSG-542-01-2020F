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
  end
  
  
  def process_file
    begin
      fire_start
      fire_row_count self.row_count
      processed_row = false
      r = @import_file.starting_row - 1
      get_rows do |row|
        begin
          obj = do_row r+1, row, true, @import_file.starting_column - 1, @import_file.user
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
      do_row @import_file.starting_row, row, false, @import_file.starting_column - 1, @import_file.user
      return @listeners.first.messages
    end
  end
  def self.find_processor import_file, listeners=[]
    if import_file.attached_file_name.downcase.ends_with?("xls") or import_file.attached_file_name.downcase.ends_with?("xlsx")
      return SpreadsheetImportProcessor.new(import_file, OpenChain::XLClient.new(import_file.attached.path), listeners)
    else
      return CSVImportProcessor.new(import_file,import_file.attachment_data,listeners)
    end
  end
  # get the array of SearchColumns to be used by the processor
  def get_columns
    @import_file.sorted_columns.blank? ? @search_setup.sorted_columns : @import_file.sorted_columns
  end
  def do_row row_number, row, save, base_column, user
    messages = []
    object_map = {}
    begin
      data_map = make_data_map row, base_column
      # Throw away the name of the key field, don't really care here
      *, key_model_field_value = find_module_key_field(data_map, @core_module)

      # The following lock prevents any other process from attempting a concurrent data import on the same 
      # Core Module + Key combination.  The process attempts to retry the lock wait up to 5 times (default aquire time
      # is 60 seconds, so that's waiting up to 5 minutes for the lock to clear across other processes).

      # We could have attempted to just lock on the object itself once it was found, but then we're not covering
      # the case of multiple file importing NEW objects at the same time, ending up w/ multiple object creates.
      # It'd also require a bit of a re-write of the following code-flow.
      Lock.acquire("#{@core_module.class_name}-#{key_model_field_value}", times: 5, temp_lock: true) do
        error_messages = []
        @module_chain.to_a.each do |mod|
          if fields_for_me_or_children? data_map, mod
            parent_mod = @module_chain.parent mod
            obj = find_or_build_by_unique_field data_map, object_map, mod 
            @core_object = obj if parent_mod.nil? #this is the top level object
            object_map[mod] = obj
            custom_fields = {}
            data_map[mod].each do |uid,data|
              mf = ModelField.find_by_uid uid
              # Rails evaluates boolean false as blank (boo!), so if we've got a boolean false value
              # don't skip it since we're likely dealing w/ a boolean field and should actually handle the value.
              if data.blank? && !(data === false)
                messages << "Blank value skipped for #{mf.label}"
                next
              end
              if mf.custom?
                cv = obj.custom_values.find {|cv| mf.custom_definition.id == cv.custom_definition_id}
                if cv.nil?
                  cv = obj.custom_values.build
                  cv.custom_definition = mf.custom_definition
                end
                is_boolean = mf.custom_definition.data_type.to_sym==:boolean
                val = is_boolean ? get_boolean_value(data) : data
                orig_value = cv.value
                # If field is a boolean and the value is not nil OR
                # if either of the original or new value is not blank.
                if (is_boolean && !val.nil?) || !(orig_value.blank? && val.blank?) 
                  process_import mf, cv, val, user, messages, error_messages
                else
                  # Don't think this condition ever actually happens since we're already skipping blank values above
                  cv.mark_for_destruction
                end
              else
                process_import mf, obj, data, user, messages, error_messages
              end
            end
            obj = merge_or_create obj, save, !parent_mod #if !parent_mod then we're at the top level
            object_map[mod] = obj
          end
        end
        if save
          object_map.values.each do |obj|
            if obj.class.include?(StatusableSupport)
              sr = obj.status_rule
              obj.set_status
              obj.save! unless sr == obj.status_rule #only save if status changed
            end
          end
        end
        
        # If we get blank rows in here somehow (should be prevented elsewhere) it's possible that the object map will be
        # blank, in which case we don't want to do anything of the following
        if object_map[@core_module]
          object = object_map[@core_module]

          # Add our object errors before validating since the validator may raise an error and we want our
          # process_import errors included in the object too.
          object.errors[:base].push(*error_messages) unless error_messages.blank?
          
          # Reload and freeze all custom values
          if object.respond_to?(:freeze_all_custom_values_including_children)
            CoreModule.walk_object_heirarchy(object) {|cm, obj| obj.custom_values.reload if obj.respond_to?(:custom_values)}
            object.freeze_all_custom_values_including_children
          end

          OpenChain::FieldLogicValidator.validate! object, false, true
          # FieldLogicValidator only raises an error if a rule fails, we still want to raise an error if any of our process import calls resulted
          # in an error.
          raise OpenChain::ValidationLogicError.new(nil, object) unless object.errors[:base].empty?
          fire_row row_number, object, messages
        end
        
      end
    rescue OpenChain::ValidationLogicError, MissingCoreModuleFieldError => e
      my_base = e.base_object if e.respond_to?(:base_object)
      my_base = @core_object unless my_base
      my_base = object_map[@core_module] unless my_base
      # Put the major error (missing fields) first here
      messages << "ERROR: #{e.message}" if e.is_a? MissingCoreModuleFieldError
      if my_base
        my_base.errors.full_messages.each {|m| 
          messages << "ERROR: #{m}"
        } 
      end
      fire_row row_number, nil, messages, true #true = failed
    rescue => e
      e.log_me(["Imported File ID: #{@import_file.id}"])
      messages << "SYS ERROR: #{e.message}"
      fire_row row_number, nil, messages, true
      raise e
    end
    r_val = @core_object
    @core_object = nil
    r_val
  end

  def process_import mf, obj, data, user, messages, error_messages
    message = mf.process_import(obj, data, user)
    unless message.blank?
      if message.error?
        error_messages << message 
      else
        messages << message
      end
    end
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
  
  def get_boolean_value  data
    if !data.nil? && data.to_s.length>0
      dstr = data.to_s.downcase.strip
      if ["y","t", "1"].include?(dstr[0])
        return true
      elsif ["n","f", "0"].include?(dstr[0])
        return false
      end
    end
    nil
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
    dest = base
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
      h = p[@import_file.module_type.intern]
      @rules_processor = h.nil? ? RulesProcessor.new : h.new
    end
    @rules_processor
  end

  def self.raise_validation_exception core_object, message
    core_object.errors[:base] << message
    raise OpenChain::ValidationLogicError.new(nil, core_object)
  end

  class CSVImportProcessor < FileImportProcessor

    def row_count 
      @data.lines.count - (@import_file.starting_row - 1)
    end
    def get_rows &block
      r = 0
      start_row = @import_file.starting_row - 1
      CSV.parse(@data,{:skip_blanks=>true}) do |row|
        # Skip blanks apparently only skips lines consisting solely of a newline,
        # it doesn't skip lines that solely consist of commas.
        # If find returns any non-blank value then we can process the line.
        has_values = row.find {|c| !c.blank?}
        yield row if r >= start_row && has_values
        r += 1
      end
    end
  end

  class SpreadsheetImportProcessor < FileImportProcessor

    def row_count
      s = @data.last_row_number(0) - (@import_file.starting_row - 2) #-2 instead of -1 now since the counting methods index at 0 and 1
    end

    def get_rows &block
      @data.all_row_values(0, @import_file.starting_row - 1).each do |row|
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
            if ot.nil?
              @countries_without_hts ||= []
              if !@countries_without_hts.include?(country_id) && !Country.find(country_id).official_tariffs.empty?
                FileImportProcessor.raise_validation_exception top_level_object, "HTS Number #{h.strip} is invalid for #{Country.find_cached_by_id(country_id).iso_code}." 
              elsif !@countries_without_hts.include?(country_id)
                @countries_without_hts << country_id
              end
            end
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

  class MissingCoreModuleFieldError < StandardError
  end

  private

  # find or build a new object based on the unique identfying column optionally scoped by the parent object
  def find_or_build_by_unique_field data_map, object_map, my_core_module

    search_scope = my_core_module.klass.scoped #search the whole table unless parent is found below

    # get the next core module up the chain
    parent_core_module = @module_chain.parent my_core_module
    if parent_core_module
      parent_object = object_map[parent_core_module]
      search_scope = parent_core_module.child_objects my_core_module, parent_object
    end    

    key_model_field, key_model_field_value = find_module_key_field(data_map, my_core_module)

    unless key_model_field
      # Tell the users what actual field they're missing data for.
      uids = my_core_module.key_model_field_uids
      if uids.length == 1
        e = "Cannot load #{my_core_module.label} data without a value in the '#{ModelField.find_by_uid(uids[0]).label(false)}' field."
      else
        e = "Cannot load #{my_core_module.label} data without a value in one of the #{uids.map {|v| "'#{ModelField.find_by_uid(v).label(false)}'"}.join(" or ")} fields."
      end

      raise MissingCoreModuleFieldError, e
    end
    obj = search_scope.where("#{ModelField.find_by_uid(key_model_field).qualified_field_name} = ?", key_model_field_value).first
    obj = search_scope.build if obj.nil?
    obj
  end

  def find_module_key_field data_map, core_module
    key_model_field = nil
    key_model_field_value = nil
    core_module.key_model_field_uids.each do |mfuid|
      key_model_field_value = data_map[core_module][mfuid.to_sym]
      key_model_field = mfuid.to_sym unless key_model_field_value.blank?
      break if key_model_field
    end
    [key_model_field, key_model_field_value]
  end

  # map a row from the file into data elements mapped by CoreModule & ModelField.uid
  def make_data_map row, base_column
    data_map = {}
    @module_chain.to_a.each do |mod|
      data_map[mod] = {}
    end
    get_columns.each do |col|
      mf = col.find_model_field
      r = row[col.rank + base_column]
      r = r.value if r.respond_to? :value #get real value for Excel formulas
      r = r.strip if r.is_a? String
      data_map[mf.core_module][mf.uid] = sanitize_file_data(r, mf) unless mf.blank?
    end
    data_map
  end

  def sanitize_file_data value, mf
    # Primarily we're concerned here when the data type is a string and we get back a numeric from the file reader.
    # What seems to happen is that the rails query interface handles taking the numeric value, say 1.0, 
    # and when used in a where clause for something like a find_by_unique_identifier clause produces
    # "where unique_identifier = 1.0", but then when you actually go to save the product record,
    # the data is converted to a string to be "1" and used in an insert caluse, which can end up causing primary 
    # key validation errors.
    # We'll handle turning decimal -> string data here by trimming out any trailing zeros / decimal points.
    if value
      if model_field_character_type?(mf) && value.is_a?(Numeric)
        # BigDecimal to_s uses engineering notation (stupidly) by default
        value = value.is_a?(BigDecimal) ? value.to_s("F") : value.to_s
        trailing_zeros = value.index /\.0+$/
        if trailing_zeros 
          value = value[0, trailing_zeros]
        end
      elsif model_field_integer_type?(mf) && value.is_a?(Numeric)
        # This is included primarily for display reasons, so the change record message will show a value like "Field set to 1" instead of "Field set to 1.0"
        # for integer fields.
        value = value.to_i
      end
    end

    value
  end

  def model_field_character_type? mf
    mf.data_type == :string || mf.data_type == :text
  end

  def model_field_integer_type? mf
    mf.data_type == :fixnum || mf.data_type == :integer
  end

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

end


