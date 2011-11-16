require 'open_chain/xl_client'
require 'open_chain/s3'
class ImportedFile < ActiveRecord::Base
  
  require 'open-uri'

  #hash of valid update modes. keys are valid database values, values are acceptable descriptions for the view layer
  UPDATE_MODES = {"any"=>"Add or Update","add"=>"Add Only","update"=>"Update Only"}

  has_attached_file :attached,
    :storage => :fog,
    :fog_credentials => FOG_S3,
    :fog_public => false,
    :fog_directory => 'chain-io',
    :path => "#{MasterSetup.get.nil? ? "UNKNOWN" : MasterSetup.get.uuid}/imported_file/:id/:filename" #conditional on MasterSetup to allow migrations to run
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

  #email a new file that has in place updates to the original file with the current data in the database
  def email_updated_file current_user, to, cc, subject, body, opts={}
    OpenMailer.send_s3_file(current_user, to, cc, subject, body, 'chain-io', make_updated_file(opts), self.attached_file_name).deliver!
  end

  #create a new file that does in place updates on the original file with the current data in the database
  def make_updated_file opts={}
    client = OpenChain::XLClient.new self.attached.path
    module_chain = self.core_module.default_module_chain 
    used_modules = Set.new
    key_column_hash = {}
    self.search_columns.each do |sc|
      cm = sc.model_field.core_module
      used_modules << cm
      key_column_hash[cm] = sc if sc.key_column?
    end

    # clone tariff rows for extra countries
    extra_countries = opts[:extra_country_ids]
    unless extra_countries.blank?
      country_columns = []
      self.search_columns.each do |sc|
        country_columns << sc if sc.key_column? && sc.model_field.core_module == CoreModule::CLASSIFICATION
      end
      base_last_row = client.last_row_number 0
      extra_countries.each do |c_id|
        ((self.starting_row-1)..base_last_row).each_with_index do |row_number,i|
          current_last_row = client.last_row_number 0
          new_row_number = current_last_row+1
          client.copy_row 0, row_number, new_row_number 
          country_columns.each do |cc|
            val = ''
            case cc.model_field_uid
              when 'class_cntry_name'
                val = Country.find(c_id).name
              when 'class_cntry_iso'
                val = Country.find(c_id).iso_code
            end
            client.set_cell(0,new_row_number,cc.rank,val)
          end
        end
      end
    end

    ((self.starting_row-1)..client.last_row_number(0)).each do |row_number|
      row = client.get_row 0, row_number
      top_criterion = make_search_criterion(module_chain.first,key_column_hash[module_chain.first],row)
      k = top_criterion.apply module_chain.first.klass
      search_criterions = [top_criterion]
      used_modules.each {|ch| search_criterions << make_search_criterion(ch,key_column_hash[ch],row)}
      values = k.first.nil? ? [] : GridMaker.single_row(k.first, self.search_columns, search_criterions, module_chain)
      self.search_columns.each_with_index do |sc,i|
        if !sc.key_column? && sc.model_field_uid!='_blank'
          v = values[sc.rank]
          v = "" if v.nil?
          client.set_cell(0,row_number,sc.rank,v)
        end
      end
    end
    target_location = "#{MasterSetup.get.uuid}/updated_imported_files/#{self.user_id}/#{Time.now.to_i}.#{self.attached_file_name.split('.').last}" 
    client.save target_location
    target_location
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
    t = OpenChain::S3.download_to_tempfile attached.options.fog_directory, attached.path
    Spreadsheet.open t
  end

  def attachment_data
    return @a_data unless @a_data.nil?
    s3 = AWS::S3.new AWS_CREDENTIALS
    s3.buckets[attached.options.fog_directory].objects[attached.path].read
  end
  
  private
  def no_post
    false
  end

  #make the search criterion based on the key column and the excel row
  def make_search_criterion core_module, column, row
    cell = OpenChain::XLClient.find_cell_in_row row, column.rank
    val = ''
    if cell
      if cell['datatype']=='number' && column.model_field.data_type==:string && cell['value'].end_with?('.0')
        v = cell['value']
        val = v[0,v.length-2]
      else
        val = cell['value'].respond_to?('strip') ? cell['value'].strip : cell['value'].to_s
      end
    end
    return SearchCriterion.new(:model_field_uid=>column.model_field_uid,:operator=>'eq',:value=>val)
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
