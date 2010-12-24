class ImportedFile < ActiveRecord::Base
  
  has_attachment :max_size => 10.megabyte,
                 :storage => :s3,
                 :s3_access => :private
  
  validates_as_attachment
  
  belongs_to :import_config
    
  def process(options={})
    processor = options[:processor].nil? ? find_processor : options[:processor]
    a_data = options[:attachment_data].nil? ? self.attachment_data : options[:attachment_data]
    processor.process a_data, self
    return self.errors.size == 0
  end
  
  def preview(options={})
    processor = options[:processor].nil? ? OrderCSVImportProcessor : options[:processor]
    a_data = options[:attachment_data].nil? ? self.attachment_data : options[:attachment_data]
    processor.preview a_data, self
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
    :order => {:csv => OrderCSVImportProcessor},
    :product => {:csv => ProductCSVImportProcessor}
    }
    p[self.import_config.model_type.intern][self.import_config.file_type.intern]
  end
end

class CSVImportProcessor
  def self.process(data, imp_file)
    ic = imp_file.import_config
    processed_row = false
    begin
      r = ic.ignore_first_row ? 1 : 0
      FasterCSV.parse(data,{:skip_blanks=>true,:headers => ic.ignore_first_row}) do |row|
        begin
          do_row row, ic, true
        rescue => e
          imp_file.errors[:base] << "Row #{r+1}: #{e.message}"
        end
        r += 1
      end
    rescue => e
      imp_file.errors[:base] << "Row #{r+1}: #{e.message}"
    end 
  end
  
  def self.preview(data, imp_file)
    ic = imp_file.import_config
    FasterCSV.parse(data,{:headers => ic.ignore_first_row}) do |row|
      return do_row row, ic, false
    end
  end
  
  private
  def self.do_row(row, ic, save)
    messages = []
    has_detail = false #only save detail records if there are detail fields
    detail_data_exists = false
    o = ic.new_base_object
    d = ic.new_detail_object
    can_blank = []
    ic.import_config_mappings.order("column ASC").each do |m|
      m_field = m.find_model_field
      can_blank << m_field.field.to_s
      to_send = m_field.detail? ? d : o
      data = row[m.column-1]
      if m_field.detail? 
        has_detail = true
        detail_data_exists = true if data.length > 0
      end
      messages << m_field.process_import(to_send,row[m.column-1])
    end
    o = merge_or_create(o,save,{:can_blank => can_blank})
    d = merge_or_create(d,save,{:can_blank => can_blank, :parent => o}) if has_detail && detail_data_exists
    return messages
  end 
  
  def self.merge_or_create(base,save,options={})
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
  
  def self.before_save(dest)
    #do nothing
  end
  def self.set_detail_parent(detail,parent)
    #default is no child objects so nothing to do here
  end
  
  def self.before_merge(shell,database_object)
    #default is no validations so nothing to do here
  end
end

class ProductCSVImportProcessor < CSVImportProcessor
  def self.before_save(obj)
    #default to first division in database
    if obj.division_id.nil? 
      obj.division_id = Division.first.id
    end
  end
  
  def self.before_merge(shell,database_object)
    if !shell.vendor_id.nil? && shell.vendor_id != database_object.vendor_id
        raise "An product's vendor cannot be changed via a file upload."
    end
  end
end

class OrderCSVImportProcessor < CSVImportProcessor
  def self.set_detail_parent(detail,parent)
    detail.order = parent
  end
  
  def self.before_merge(shell,database_object)
    if !shell.vendor_id.nil? && shell.vendor_id != database_object.vendor_id
        raise "An order's vendor cannot be changed via a file upload."
    end
  end
end
