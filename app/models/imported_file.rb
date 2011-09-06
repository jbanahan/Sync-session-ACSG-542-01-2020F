class ImportedFile < ActiveRecord::Base
  
  require 'open-uri'

  #hash of valid update modes. keys are valid database values, values are acceptable descriptions for the view layer
  UPDATE_MODES = {"any"=>"Add or Update","add"=>"Add Only","update"=>"Update Only"}

  has_attached_file :attached,
    :storage => :s3,
    :s3_credentials => "#{Rails.root}/config/s3.yml",
    :s3_permissions => :private,
    :path => "#{MasterSetup.get.nil? ? "UNKNOWN" : MasterSetup.get.uuid}/imported_file/:id/:filename", #conditional on MasterSetup to allow migrations to run
    :bucket => 'chain-io'
  before_post_process :no_post
  
  belongs_to :search_setup
  belongs_to :user
  has_many :search_runs
  has_many :file_import_results, :dependent=>:destroy
  has_many :search_columns

  before_validation :set_module_type
  validates_presence_of :starting_row
  validates_numericality_of :starting_row, :greater_than=>0
  validates_presence_of :starting_column
  validates_numericality_of :starting_column, :greater_than=>0
  validates_presence_of :module_type
  validates_presence_of :update_mode
  validates_inclusion_of :update_mode, :in => UPDATE_MODES.keys.to_a
  
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
  def can_delete?(user)
    can_view? user
  end

  def deletable?
    self.file_import_results.blank?
  end

  #output the data for a file based on the current state of the items created/updated by this file
  def make_items_file search_criterions=[]
    if self.attached_file_name.downcase.ends_with?("xls") 
      book = XlsMaker.new.make_from_results self.last_file_import_finished.changed_objects(search_criterions), self.search_columns.order("rank asc"), self.core_module.default_module_chain, search_criterions 
      spreadsheet = StringIO.new 
      book.write spreadsheet 
      spreadsheet.string
    else
      CsvMaker.new.make_from_results self.last_file_import_finished.changed_objects(search_criterions), self.search_columns.order("rank ASC"), self.core_module.default_module_chain, search_criterions
    end
  end

  def email_items_file current_user, email_addresses, search_criterions=[]
     OpenMailer.send_uploaded_items(email_addresses,self,make_items_file(search_criterions),current_user).deliver
  end

  def process(user,options={})
    begin
      self.save! if self.new_record? #make sure we're actually in the database
      import_search_columns      
      @a_data = options[:attachment_data] if !options[:attachment_data].nil?
      fj = FileImportProcessJob.new(self,user)
      if options[:defer]
        self.delay.process user
      else
        fj.call nil
      end
    rescue => e 
      self.errors[:base] << "There was an error processing the file: #{e.message}"
      e.log_me ["Imported File ID: #{self.id}"]
    end
    OpenMailer.send_imported_file_process_fail(self, self.search_setup.user).deliver if self.errors.size>0
    return self.errors.size == 0
  end
  
  def preview(user,options={})
    @a_data = options[:attachment_data] if !options[:attachment_data].nil?
    msgs = FileImportProcessor.preview self
    OpenMailer.send_imported_file_process_fail(self, self.search_setup.user).deliver if self.errors.size>0
    msgs
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

  def import_search_columns
    if !self.search_setup.nil? && self.search_columns.blank?
      no_copy = [:id,:created_at,:updated_at,:search_setup_id,:imported_file_id]
      self.search_setup.search_columns.each do |col|
        my_col = self.search_columns.build
        col.attributes.each { |attr, value| 
          eval("my_col.#{attr}= col.#{attr}") unless no_copy.include?(attr.to_sym)} 
        my_col.save
      end
    end
  end

  #callback to set the module_type if it's empty and the search_setup has one
  def set_module_type
    self.module_type = self.search_setup.module_type unless self.module_type || self.search_setup.nil?
  end

  class FileImportProcessJob
    def initialize imported_file, user_id
      @imported_file = imported_file
      @user_id = user_id
    end

    def call job
      FileImportProcessor.process @imported_file, [FileImportProcessorListener.new(@imported_file,@user_id)]
    end
  end
  
  class FileImportProcessorListener

    def initialize(imported_file,user_id)
      @imported_file = imported_file
      @fr = @imported_file.file_import_results.build(:run_by=>User.find(user_id))
    end

    def process_row row_number, object, messages, failed=false
      cr = ChangeRecord.create(:record_sequence_number=>row_number,:recordable=>object,:failed=>failed,:file_import_result_id=>@fr.id)
      unless messages.blank?
        msg_sql = []
        messages.each {|m| msg_sql << "(#{cr.id}, '#{m.gsub(/\\/, '\&\&').gsub(/'/, "''")}')" }
        sql = "INSERT INTO change_record_messages (`change_record_id`,`message`) VALUES #{msg_sql.join(", ")}"
        begin
          ActiveRecord::Base.connection.execute sql
        rescue
          $!.log_me
        end
      end
      object.create_snapshot(@fr.run_by) if object.respond_to?('create_snapshot')
    end

    def process_start time
      @fr.started_at=time
      @fr.save
    end

    def process_end time
      @fr.finished_at= time
      @fr.save
      error_count = @fr.error_count
      body = "File #{@imported_file.attached_file_name} has completed.<br />Records Saved: #{@fr.changed_objects.size}<br />"
      body << "Errors: #{error_count}<br />" if error_count>0
      body << "<br />Click <a href='#{Rails.application.routes.url_helpers.imported_file_path(@imported_file)}'>here</a> to see the results." unless @imported_file.id.nil?
      @fr.run_by.messages.create(:subject=>"File Processing Complete #{error_count>0 ? "("+error_count.to_s+" Errors)" : ""}", :body=>body) unless @imported_file.id.nil?
    end
  end
end
