class ImportedFile < ActiveRecord::Base
  
  has_attachment :max_size => 10.megabyte,
                 :storage => :s3,
                 :s3_access => :private
  
  validates_as_attachment
  
  belongs_to :import_config
    
  def process(options={})
    processor = options[:processor].nil? ? find_processor : options[:processor]
    a_data = options[:attachment_data].nil? ? self.attachment_data : options[:attachment_data]
    processor.new(self,a_data).process
    return self.errors.size == 0
  end
  
  def preview(options={})
    processor = options[:processor].nil? ? OrderCSVImportProcessor : options[:processor]
    a_data = options[:attachment_data].nil? ? self.attachment_data : options[:attachment_data]
    processor.new(self,a_data).preview
  end
  
  
  def attachment_data
    retries = 0
    begin
      uri = URI.parse(self.authenticated_s3_url(:expires_in => 2.minutes, :use_ssl => true))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = http.request(Net::HTTP::Get.new(uri.request_uri))
      response.body
    rescue
      retries+=1
      retry if retries < 3
      raise "File data could not be retrieved from the database."
    end
  end
  
  private
  def find_processor   
    p = {
    :Order => {:csv => OrderCSVImportProcessor},
    :Product => {:csv => ProductCSVImportProcessor}
    }
    p[self.import_config.model_type.intern][self.import_config.file_type.intern]
  end
end

class CSVImportProcessor
  
  def initialize(import_file, data)
    @import_file = import_file
    @import_config = import_file.import_config
    @core_module = CoreModule.find_by_class_name(@import_config.model_type)
    @data = data
  end
  
  def process
    processed_row = false
    begin
      r = @import_config.ignore_first_row ? 1 : 0
      FasterCSV.parse(@data,{:skip_blanks=>true,:headers => @import_config.ignore_first_row}) do |row|
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
    FasterCSV.parse(@data,{:headers => @import_config.ignore_first_row}) do |row|
      return do_row row, false
    end
  end
  
  private
  def do_row(row, save)
    messages = []
    o = @core_module.new_object
    detail_hash = {}
    detail_data_exists = {}
    can_blank = []
		custom_fields = []
    @import_config.import_config_mappings.order("column ASC").each do |m|
      mf = m.find_model_field
      can_blank << mf.field_name.to_s
      to_send = object_to_send(detail_hash, o, mf)
      data = row[m.column-1]
			if mf.custom?
				custom_fields << {:field => mf, :data => data}
			else
				detail_data_exists[mf.core_module] = true if data.length > 0 && detail_field?(mf)
				messages << mf.process_import(to_send,row[m.column-1])
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
    set_detail_parent base, options[:parent] unless options[:parent].nil?
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
  def set_detail_parent(detail,parent)
    #default is no child objects so nothing to do here
  end
  
  def before_merge(shell,database_object)
    #default is no validations so nothing to do here
  end
end

class ProductCSVImportProcessor < CSVImportProcessor
  def before_save(obj)
    #default to first division in database
    if obj.division_id.nil? 
      obj.division_id = Division.first.id
    end
  end
  
  def before_merge(shell,database_object)
    if !shell.vendor_id.nil? && shell.vendor_id != database_object.vendor_id
        raise "An product's vendor cannot be changed via a file upload."
    end
  end
end

class OrderCSVImportProcessor < CSVImportProcessor
  def set_detail_parent(detail,parent)
    detail.order = parent
  end
  
  def before_merge(shell,database_object)
    if shell.class == Order && !shell.vendor_id.nil? && shell.vendor_id != database_object.vendor_id
        raise "An order's vendor cannot be changed via a file upload."
    end
  end
end
