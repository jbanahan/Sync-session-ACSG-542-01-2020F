class ImportedFile < ActiveRecord::Base
  
  require 'open-uri'

  has_attached_file :attached,
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :s3_permissions => :private,
    :path => "#{MasterSetup.first.uuid}/imported_file/:id/:filename",
    :bucket => 'chain-io'
  before_post_process :no_post
  

  belongs_to :search_setup
    
  def process(options={})
    @a_data = options[:attachment_data] if !options[:attachment_data].nil?
    FileImportProcessor.process self
    return self.errors.size == 0
  end
  
  def preview(options={})
    @a_data = options[:attachment_data] if !options[:attachment_data].nil?
    FileImportProcessor.preview self
  end
  
  
  def attachment_as_workbook
    #http://www.webmantras.com/blog/?p=554
    u = AWS::S3::S3Object.url_for attached.path, attached.options[:bucket], {:expires_in => 10.minutes, :use_ssl => true}
    book = nil
    puts "URI!!!!!!!!!!!!!!: #{u}"
    open u do |f|
      book = Spreadsheet.open f
    end
    book
  end

  def attachment_data
    return @a_data unless @a_data.nil?
    retries = 0
    begin
      uri = URI.parse(AWS::S3::S3Object.url_for attached.path, attached.options[:bucket], {:expires_in => 10.minutes, :use_ssl => true})
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
  def no_post
    false
  end
end
