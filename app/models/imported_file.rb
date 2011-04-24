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
  belongs_to :user
  has_many :search_runs
  has_many :file_import_results, :dependent=>:destroy

  validates_presence_of :module_type
  
  def last_file_import
    self.file_import_results.order("created_at DESC").first
  end
  def last_file_import_finished
    self.file_import_results.order("finished_at DESC").first
  end
  
  def core_module
    CoreModule.find_by_class_name self.module_type
  end
  def can_view?(user)
    return true if user.sys_admin? || user.admin?
    return false if self.user_id.nil? 
    return true if self.user_id==user.id
    return true if self.user.company==user.company
    return false
  end

  def process(user,options={})
    begin
      @a_data = options[:attachment_data] if !options[:attachment_data].nil?
      FileImportProcessor.process self, [FileImportProcessorListener.new(self,user)]
    rescue => e 
      self.errors[:base] << "There was an error processing the file: #{e.message}"
    end
    OpenMailer.send_imported_file_process_fail(self, self.search_setup.user).deliver if self.errors.size>0
    return self.errors.size == 0
  end
  
  def preview(user,options={})
    begin
      @a_data = options[:attachment_data] if !options[:attachment_data].nil?
      msgs = FileImportProcessor.preview self
      OpenMailer.send_imported_file_process_fail(self, self.search_setup.user).deliver if self.errors.size>0
      msgs
    rescue => e
      self.errors[:base] << e.message
      OpenMailer.send_imported_file_process_fail(self, self.search_setup.user).deliver
      return ["There was an error reading the file: #{e.message}"]
    end
  end
  
  
  def attachment_as_workbook
    #http://www.webmantras.com/blog/?p=554
    u = AWS::S3::S3Object.url_for attached.path, attached.options[:bucket], {:expires_in => 10.minutes, :use_ssl => true}
    book = nil
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

  class FileImportProcessorListener

    def initialize(imported_file,user)
      @fr = imported_file.file_import_results.build(:run_by=>user)
    end

    def process_row row_number, object, messages
      @fr.change_records.create(:record_sequence_number=>row_number,:recordable=>object)
    end

    def process_start time
      @fr.started_at=time
      @fr.save
    end

    def process_end time
      @fr.finished_at= time
      @fr.save
    end
  end
end
