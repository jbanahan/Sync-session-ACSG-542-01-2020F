class ImportedFile < ActiveRecord::Base
  
  has_attached_file :attached,
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :s3_permissions => :private,
    :path => "#{MasterSetup.first.uuid}/imported_file/:id/:filename",
    :bucket => 'chain-io'
  before_post_process :no_post
  

  belongs_to :search_setup
    
  def process(options={})
    a_data = options[:attachment_data].nil? ? self.attachment_data : options[:attachment_data]
    FileImportProcessor.process self, a_data
    return self.errors.size == 0
  end
  
  def preview(options={})
    a_data = options[:attachment_data].nil? ? self.attachment_data : options[:attachment_data]
    FileImportProcessor.preview self, a_data
  end
  
  
  def attachment_data
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
