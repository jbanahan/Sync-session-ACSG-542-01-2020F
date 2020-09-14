class FileImportProcessor
  require 'open_chain/field_logic.rb'

  # YOU DON'T NEED TO CALL ANY INSTANCE METHODS, THIS USES THE FACTORY PATTERN, JUST CALL FileImportProcessor.preview or .process
  def self.process(import_file, listeners = [])
    find_processor(import_file, listeners).process_file
  end

  def self.preview(import_file)
    find_processor(import_file, [PreviewListener.new]).preview_file
  end

  def initialize(import_file, data, listeners = [])
    @import_file = import_file
    @search_setup = import_file.search_setup
    @core_module = CoreModule.by_class_name(import_file.module_type)
    @module_chain = @core_module.default_module_chain
    @data = data
    @listeners = listeners
  end

  def process_file
      fire_start
      fire_row_count self.row_count
      r = @import_file.starting_row - 1
      get_rows do |row|
        begin
          obj = do_row r + 1, row, true, @import_file.starting_column - 1, @import_file.user, set_blank: @import_file.set_blank?
          obj.errors.full_messages.each {|m| @import_file.errors[:base] << "Row #{r + 1}: #{m}"}
        rescue => e # rubocop:disable Style/RescueStandardError
          @import_file.errors[:base] << "Row #{r + 1}: #{e.message}"
        end
        r += 1
      end
  rescue => e # rubocop:disable Style/RescueStandardError
      e.log_me ["Imported File ID: #{@import_file.id}"]
      @import_file.errors[:base] << "Row #{r + 1}: #{e.message}"
  ensure
      fire_end
  end

  def preview_file
    get_rows(preview: true) do |row|
      do_row @import_file.starting_row, row, false, @import_file.starting_column - 1, @import_file.user, set_blank: @import_file.set_blank?
      return @listeners.first.messages
    end
  end

  def self.find_processor import_file, listeners = []
    if import_file.attached_file_name.downcase.ends_with?("xls") || import_file.attached_file_name.downcase.ends_with?("xlsx")
      SpreadsheetImportProcessor.new(import_file, OpenChain::XLClient.new(import_file.attached.path), listeners)
    else
      CSVImportProcessor.new(import_file, import_file.attachment_data, listeners)
    end
  end

  # get the array of SearchColumns to be used by the processor
  def columns
    @import_file.sorted_columns.presence || @search_setup.sorted_columns
  end

  def do_row row_number, row, save, base_column, user, set_blank: false
    messages = []
    object_map = {}
    begin
      data_map = make_data_map row, base_column
      # Throw away the name of the key field, don't really care here
      *, key_model_field_value = find_module_key_field(data_map, @core_module)
      if key_model_field_value
        def key_model_field_value.unique_identifier?
          true
        end
        messages << key_model_field_value
      end

      # The following lock prevents any other process from attempting a concurrent data import on the same
      # Core Module + Key combination.  The process attempts to retry the lock wait up to 5 times (default aquire time
      # is 60 seconds, so that's waiting up to 5 minutes for the lock to clear across other processes).

      # We could have attempted to just lock on the object itself once it was found, but then we're not covering
      # the case of multiple file importing NEW objects at the same time, ending up w/ multiple object creates.
      # It'd also require a bit of a re-write of the following code-flow.

      # If you change this lock name, make sure you also modify the lock name in OpenChain::CoreModuleProcessor#lock_name
      Lock.acquire("#{@core_module.class_name}-#{key_model_field_value}", times: 5, temp_lock: true) do
        error_messages = []
        any_object_saved = false
        @module_chain.to_a.each do |mod|
          if fields_for_me_or_children? data_map, mod
            parent_mod = @module_chain.parent mod
            obj = find_or_build_by_unique_field data_map, object_map, mod
            @core_object = obj if parent_mod.nil? # this is the top level object
            object_map[mod] = obj
            data_map[mod].each do |uid, data|
              mf = ModelField.by_uid uid
              data = get_boolean_value(data) if mf.data_type == :boolean
              # Rails evaluates boolean false as blank (boo!), so if we've got a boolean false value
              # don't skip it since we're likely dealing w/ a boolean field and should actually handle the value.
              if data.blank? && (data != false) && !set_blank
                messages << "Blank value skipped for #{mf.label}"
                next
              end

              process_import mf, obj, data, user, messages, error_messages
            end

            obj, saved = merge_or_create obj, save, !parent_mod # if !parent_mod then we're at the top level
            object_map[mod] = obj
            any_object_saved = true if saved
          end
        end

        # If we get blank rows in here somehow (should be prevented elsewhere) it's possible that the object map will be
        # blank, in which case we don't want to do anything of the following
        if object_map[@core_module]
          object = object_map[@core_module]

          # Add our object errors before validating since the validator may raise an error and we want our
          # process_import errors included in the object too.
          object.errors[:base].push(*error_messages) if error_messages.present?

          # Reload and freeze all custom values
          if object.respond_to?(:freeze_all_custom_values_including_children)
            CoreModule.walk_object_heirarchy(object) {|_cm, obj| obj.custom_values.reload if obj.respond_to?(:custom_values)}
            object.freeze_all_custom_values_including_children
          end

          OpenChain::FieldLogicValidator.validate! object, false, true
          # FieldLogicValidator only raises an error if a rule fails, we still want to raise an error if any of our process import calls resulted
          # in an error.
          raise OpenChain::ValidationLogicError.new(nil, object) unless object.errors[:base].empty?

          # If anything in the object heirarchy changed then we want the top level object
          # to reflect a new updated_at value
          object.touch if any_object_saved # rubocop:disable Rails/SkipsModelValidations

          fire_row row_number, object, messages, failed: false, saved: any_object_saved
        end

      end
    rescue OpenChain::ValidationLogicError, MissingCoreModuleFieldError => e
      my_base = e.base_object if e.respond_to?(:base_object)
      my_base ||= @core_object
      my_base ||= object_map[@core_module]
      # Put the major error (missing fields) first here
      messages << "ERROR: #{e.message}" if e.is_a? MissingCoreModuleFieldError
      if my_base
        my_base.errors.full_messages.each do |m|
          messages << "ERROR: #{m}"
        end
      end
      fire_row row_number, nil, messages, failed: true, saved: false
    rescue => e # rubocop:disable Style/RescueStandardError
      e.log_me(["Imported File ID: #{@import_file.id}"])
      messages << "SYS ERROR: #{e.message}"
      fire_row row_number, nil, messages, failed: true, saved: false
      raise e
    end
    r_val = @core_object
    @core_object = nil
    r_val
  end

  def process_import mf, obj, data, user, messages, error_messages
    message = mf.process_import(obj, data, user)
    if message.present?
      if message.error?
        error_messages << message
      else
        messages << message
      end
    end
  end

  # is this record allowed to be added / updated based on the search_setup's update mode
  def update_mode_check obj, update_mode, was_new
    case update_mode
    when "add"
      @created_objects ||= Set.new
      FileImportProcessor.raise_validation_exception obj, "Cannot update record when Update Mode is set to \"Add Only\"." if !was_new && !@created_objects.include?(obj.id)
      @created_objects << obj.id # mark that this object was created in this session so we know it can be updated again even in add mode
    when "update"
      FileImportProcessor.raise_validation_exception obj, "Cannot add a record when Update Mode is set to \"Update Only\"." if was_new
    end
  end

  def get_boolean_value  data
    if !data.nil? && data.to_s.length > 0
      dstr = data.to_s.downcase.strip
      if ["y", "t", "1"].include?(dstr[0])
        return true
      elsif ["n", "f", "0"].include?(dstr[0])
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
    false
  end

  def data_map_has_values? data_map_hash
    data_map_hash.each_value do |v|
      return true if v.present?
    end
    false
  end

  def merge_or_create base, save, is_top_level
    dest = base
    is_new = dest.new_record?
    before_save dest
    # If we've turned off the save function, then don't save no matter what
    # (not really even sure where this value ultimately gets passed in from originally)
    saved = false
    if save
      # Don't actually save the object, unless it was actually changed somewhere in its heirarchy.
      # The reason we have to actually walk the object heirarchy is because some of the virtual fields (like First US HTS 1)
      # will set values (.ie hts_1 ) on child or grandchild objects.
      if is_new || any_object_in_heirarchy_changed?(dest)
        dest.save!
        saved = true
      end
    end
    # if this is the top level object, check against the search_setup#update_mode
    update_mode_check(dest, @import_file.update_mode, is_new) if is_top_level
    [dest, saved]
  end

  # This method walks the core module object heirarchy and returns true if any object in the chain
  # has been changed (either a custom value or the object itself has been changed).
  def any_object_in_heirarchy_changed? object
    return true if object.changed?

    # The use of loaded here and below is an assumption that if the actual AR proxy collection
    # referenced isn't actually loaded, then nothing would actually have been changed on the object
    if object.respond_to?(:custom_values) && object.custom_values.loaded?
      return true if object.custom_values.any?(&:changed?)
    end

    cm = CoreModule.by_object(object)
    CoreModule.by_object(object).children.each do |child_core_module|
      child_association = cm.child_association_name(child_core_module)
      association = object.public_send(child_association.to_sym)
      if association.loaded?
        return true if association.any? {|child| any_object_in_heirarchy_changed?(child) }
      end
    end

    false
  end

  def before_save(dest)
    rules_processor.before_save dest, @core_object
  end

  def before_merge(shell, database_object)
    rules_processor.before_merge shell, database_object, @core_object
  end

  def rules_processor
    if @rules_processor.nil?
      p = {
        Order: OrderRulesProcessor,
        Product: ProductRulesProcessor,
        SalesOrder: SaleRulesProcessor
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

    def get_rows preview: false, &block
      start_row = @import_file.starting_row - 1
      begin
        utf_8_parse @data, start_row, preview, block
      rescue ArgumentError => e
        if e.message =~ /invalid byte sequence in UTF-8/
          windows_1252_parse @data, start_row, preview, block
        else
          raise e
        end
      end
    end

    private

    def utf_8_parse _data, start_row, preview, block
      row_num = 0
      CSV.parse(@data, skip_blanks: true) do |row|
        had_content = skip_comma_blanks row, row_num, start_row, block
        row_num += 1
        break if had_content && preview
      end
    end

    def windows_1252_parse data, start_row, preview, block
      row_num = 0
      CSV.parse(data.force_encoding("Windows-1252"), skip_blanks: true) do |row|
        converted_row = row.map {|r| r&.encode("UTF-8", undef: :replace, invalid: :replace, replace: "?") }
        had_content = skip_comma_blanks converted_row, row_num, start_row, block
        row_num += 1
        break if had_content && preview
      end
    end

    def skip_comma_blanks row, row_num, start_row, block
      # Skip blanks apparently only skips lines consisting solely of a newline,
      # it doesn't skip lines that solely consist of commas.
      # If find returns any non-blank value then we can process the line.
      has_values = row.find(&:present?)
      if row_num >= start_row && has_values
        block.call(row)
        true
      else
        false
      end
    end
  end

  class SpreadsheetImportProcessor < FileImportProcessor

    def row_count
      @data.last_row_number(0) - (@import_file.starting_row - 2) #-2 instead of -1 now since the counting methods index at 0 and 1
    end

    def get_rows preview: false
      params = {starting_row_number: @import_file.starting_row - 1}

      # Only return a single row at a time if we're previewing
      params[:chunk_size] = 1 if preview

      @data.all_row_values(**params) do |row|
        process = false
        row.each do |v|
          if v.present?
            process = true
            break
          end
        end
        if process
          yield row
          # If we're in preview mode, just yield a single row...and tell the xl client to stop polling
          throw :stop_polling if preview
        end
      end
    end

  end

  class RulesProcessor
    def before_save obj, top_level_object
      # stub
    end

    def before_merge obj, database_object, top_level_object
      # stub
    end
  end

  class ProductRulesProcessor < RulesProcessor
    def before_save obj, top_level_object
      if obj.is_a? TariffRecord
        # make sure the tariff is valid
        country_id = obj.classification.country_id
        [obj.hts_1, obj.hts_2, obj.hts_3].each_with_index do |h, _i|
          if h.present?
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
        # make sure the line number is populated (we don't allow auto-increment line numbers in file uploads)
        if obj.line_number.blank?
          FileImportProcessor.raise_validation_exception top_level_object, "Line cannot be processed with empty #{ModelField.by_uid(:hts_line_number).label}."
        end
      elsif obj.is_a? Classification
        # make sure there is a country
        if obj.country_id.blank? && obj.country.blank?
          FileImportProcessor.raise_validation_exception top_level_object, "Line cannot be processed with empty classification country."
        end
      end
    end

    def before_merge(shell, database_object, top_level_object); end
  end

  class OrderRulesProcessor < RulesProcessor

    def before_merge(shell, database_object, top_level_object)
      if shell.class == Order && !shell.vendor_id.nil? && shell.vendor_id != database_object.vendor_id
          FileImportProcessor.raise_validation_exception top_level_object, "An order's vendor cannot be changed via a file upload."
      end
    end
  end

  class SaleRulesProcessor < CSVImportProcessor
    def before_merge(shell, database_object, top_level_object)
      if shell.class == SalesOrder && !shell.customer_id.nil? && shell.customer_id != database_object.customer_id
        FileImportProcessor.raise_validation_exception top_level_object, "A sale's customer cannot be changed via a file upload."
      end
    end
  end

  class PreviewListener
    attr_accessor :messages
    def process_row _row_number, _object, messages, failed: false, saved: true # rubocop:disable Lint/UnusedMethodArgument
      self.messages = messages.reject { |m| m.respond_to?(:unique_identifier?) && m.unique_identifier? }
    end

    def process_start time
      # stub
    end

    def process_end time
      # stub
    end
  end

  class MissingCoreModuleFieldError < StandardError
  end

  private

  # find or build a new object based on the unique identfying column optionally scoped by the parent object
  def find_or_build_by_unique_field data_map, object_map, my_core_module
    search_scope = my_core_module.klass.all # search the whole table unless parent is found below

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
        e = "Cannot load #{my_core_module.label} data without a value in the '#{ModelField.by_uid(uids[0]).label(false)}' field."
      else
        e = "Cannot load #{my_core_module.label} data without a value in one of the #{uids.map {|v| "'#{ModelField.by_uid(v).label(false)}'"}.join(" or ")} fields."
      end

      raise MissingCoreModuleFieldError, e
    end
    obj = search_scope.where("#{ModelField.by_uid(key_model_field).qualified_field_name} = ?", key_model_field_value).first # rubocop:disable Rails/FindBy
    obj = search_scope.build if obj.nil?
    obj
  end

  def find_module_key_field data_map, core_module
    key_model_field = nil
    key_model_field_value = nil
    core_module.key_model_field_uids.each do |mfuid|
      key_model_field_value = data_map[core_module][mfuid.to_sym]
      key_model_field = mfuid.to_sym if key_model_field_value.present?
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
    columns.each do |col|
      mf = col.model_field
      r = row[col.rank + base_column]
      r = r.value if r.respond_to? :value # get real value for Excel formulas
      r = r.strip_all_whitespace if r.is_a? String
      data_map[mf.core_module][mf.uid] = sanitize_file_data(r, mf) if mf.present?
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
        trailing_zeros = value.index(/\.0+$/)
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
    fire_event :process_start, Time.zone.now
  end

  def fire_row_count count
    fire_event :process_row_count, count
  end

  def fire_row row_number, obj, messages, failed: false, saved: false
    @listeners.each {|ls| ls.process_row row_number, obj, messages, failed: failed, saved: saved if ls.respond_to?('process_row')}
  end

  def fire_end
    fire_event :process_end, Time.zone.now
  end

  def fire_event method, data
    @listeners.each {|ls| ls.send method, data if ls.respond_to?(method) }
  end

end
