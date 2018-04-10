# == Schema Information
#
# Table name: imported_files
#
#  attached_content_type :string(255)
#  attached_file_name    :string(255)
#  attached_file_size    :integer
#  attached_updated_at   :datetime
#  created_at            :datetime         not null
#  id                    :integer          not null, primary key
#  module_type           :string(255)
#  note                  :text
#  processed_at          :datetime
#  search_setup_id       :integer
#  starting_column       :integer          default(1)
#  starting_row          :integer          default(1)
#  update_mode           :string(255)
#  updated_at            :datetime         not null
#  user_id               :integer
#
# Indexes
#
#  index_imported_files_on_user_id  (user_id)
#

require 'open_chain/xl_client'
require 'open_chain/s3'
class ImportedFile < ActiveRecord::Base
  
  require 'open-uri'

  #hash of valid update modes. keys are valid database values, values are acceptable descriptions for the view layer
  UPDATE_MODES = {"any"=>"Add or Update","add"=>"Add Only","update"=>"Update Only"}

  has_attached_file :attached, :path => ":master_setup_uuid/imported_file/:id/:filename"
  # Paperclip, as of v4, forces you to list all the attachment types you allow to be uploaded.  We don't restrict these
  # at all, so this disables that validation.
  do_not_validate_attachment_file_type :attached
  before_create :sanitize
  before_post_process :no_post
  
  belongs_to :search_setup
  belongs_to :user
  has_many :search_runs
  has_many :file_import_results, :dependent=>:destroy
  has_many :search_columns
  has_many :search_criterions, :dependent=>:destroy
  has_many :entity_snapshots #snapshots generated by processing this imported file
  has_many :imported_file_downloads, :dependent=>:destroy
  has_one :result_cache, :as=>:result_cacheable, :dependent=>:destroy

  before_validation :set_module_type
  validates_presence_of :starting_row
  validates_numericality_of :starting_row, :greater_than=>0
  validates_presence_of :starting_column
  validates_numericality_of :starting_column, :greater_than=>0
  validates_presence_of :module_type
  validates_presence_of :update_mode
  validates_inclusion_of :update_mode, :in => UPDATE_MODES.keys.to_a
  
  #always returns empty array (here for duck typing with SearchSetup)
  def sort_criterions
    []
  end

  def result_keys_from 
    "INNER JOIN (select distinct recordable_id from change_records inner join (select id from file_import_results where imported_file_id = #{self.id} order by finished_at DESC limit 1) as fir ON change_records.file_import_result_id = fir.id) as change_recs on change_recs.recordable_id = #{core_module.table_name}.id"
  end

  #return keys from last file import result
  def result_keys opts={}
    qry = "select distinct recordable_id from change_records inner join (select id from file_import_results where imported_file_id = #{self.id} order by finished_at DESC limit 1) as fir ON change_records.file_import_result_id = fir.id"
    execute_query(qry).collect {|r| r[0]}
  end

  def execute_query query
    # This method is solely for testing purposes to avoid stubbing the connection, which interferes with any transactional fixture
    # handling.
    ActiveRecord::Base.connection.execute(query)
  end
  private :execute_query

  def sorted_columns
    self.search_columns.order("rank ASC")
  end
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
      book = XlsMaker.new.make_from_results self.last_file_import_finished.changed_objects(search_criterions), self.search_columns.order("rank asc"), self.core_module.default_module_chain, self.user, search_criterions 
      spreadsheet = StringIO.new 
      book.write spreadsheet 
      spreadsheet.string
    else
      CsvMaker.new.make_from_results self.last_file_import_finished.changed_objects(search_criterions), self.search_columns.order("rank ASC"), self.core_module.default_module_chain, self.user, search_criterions
    end
  end

  #email a new file that has in place updates to the original file with the current data in the database
  def email_updated_file current_user, to, cc, subject, body, opts={}
    s3_path = make_updated_file(opts)
    additional_countries = []
    additional_countries = opts[:extra_country_ids].collect {|id| Country.find(id).iso_code} unless opts[:extra_country_ids].blank?
    make_imported_file_download_from_s3_path s3_path, current_user, additional_countries
    OpenMailer.send_s3_file(current_user, to, cc, subject, body, 'chain-io', s3_path, self.attached_file_name).deliver!
  end


  #create a new file that does in place updates on the original file with the current data in the database
  def make_updated_file opts={}
    client = OpenChain::XLClient.new self.attached.path
    module_chain = self.core_module.default_module_chain 
    used_modules = Set.new
    key_column_hash = {}
    self.search_columns.each do |sc|
      if sc.model_field.core_module #blank won't have core module
        cm = sc.model_field.core_module       
        used_modules << cm
        key_column_hash[cm] = sc if sc.key_column?
      end
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
      unless k.first.nil?
        values = GridMaker.single_row(k.first, self.search_columns, search_criterions, module_chain,self.user)
        self.search_columns.each_with_index do |sc,i|
          if !sc.key_column? && !sc.model_field.blank?
            v = values[sc.rank]
            v = "" if v.nil?
            client.set_cell(0,row_number,sc.rank,v)
          end
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
    self.save! if self.new_record? #make sure we're actually in the database
    import_search_columns
    @a_data = options[:attachment_data] if !options[:attachment_data].nil?
    fj = FileImportProcessJob.new(self,user)
    if options[:defer]
      # Run the job via the delayed job processor
      fj.enqueue_job
    else
      fj.perform
    end
    # The perform call sets info into the imported files errors hash (which is only useful if the process isn't delayed)
    return self.errors.size == 0
  end
  
  def preview(user,options={})
    @a_data = options[:attachment_data] if !options[:attachment_data].nil?
    msgs = FileImportProcessor.preview self
    OpenMailer.send_imported_file_process_fail(self, self.search_setup.user).deliver if self.errors.size>0 && MasterSetup.get.custom_feature?('LogImportedFileErrors')
    msgs
  end
  
  
  def attachment_as_workbook
    t = OpenChain::S3.download_to_tempfile attached.options[:bucket], attached.path
    Spreadsheet.open t
  end

  def attachment_data
    return @a_data unless @a_data.nil?
    OpenChain::S3.get_data attached.options[:bucket], attached.path
  end

  def self.process_integration_imported_file bucket, remote_path, original_path
    begin
      dir, fname = Pathname.new(original_path).split
      folder_list = dir.to_s.split('/')
      user = User.where(:username=>folder_list[1]).first
      raise "Username #{folder_list[1]} not found." unless user
      raise "User #{user.username} is locked." unless user.active?
      ss = user.search_setups.where(:module_type=>folder_list[3],:name=>folder_list[4]).first
      raise "Search named #{folder_list[4]} not found for module #{folder_list[3]}." unless ss
    
      OpenChain::S3.download_to_tempfile(bucket, remote_path, original_filename: fname.to_s) do |tmp|      
        imp = ss.imported_files.build(:starting_row=>1,:starting_column=>1,:update_mode=>'any')
        imp.attached = tmp
        imp.module_type = ss.module_type
        imp.user = user
        imp.save!
        imp.process user, {:defer=>true}
      end
    rescue => e
      e.log_me ["Failed to process imported file with original path '#{original_path}'."]
    end
  end

  def max_results user
    # this is for duck typing to search_setup, we're using a really high value so as to not actually limit results
    1000000
  end
  
  private
  def no_post
    false
  end

  def sanitize
    Attachment.sanitize_filename self, :attached
  end

  def make_imported_file_download_from_s3_path s3_path, user, additional_countries=[]
    ifd = self.imported_file_downloads.build(:user=>user,:additional_countries=>additional_countries.join(", "))
    tmp = OpenChain::S3.download_to_tempfile 'chain-io', s3_path
    Attachment.add_original_filename_method tmp
    tmp.original_filename= self.attached_file_name
    ifd.attached = tmp
    ifd.save
    tmp.close
    nil
  end

  #make the search criterion based on the key column and the excel row
  def make_search_criterion core_module, column, row
    cell = OpenChain::XLClient.find_cell_in_row row, column.rank
    val = ''
    if cell
      if cell['datatype']=='number' && column.model_field.data_type==:string && cell['value'].to_s.end_with?('.0')
        v = cell['value'].to_s
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
      perform
    end

    # Conform to DelayedJob job interface
    def perform
      # If there's a delayed job already running this particular imported file, then we're going to just requeue
      # this file until we see that other one is completed.
      if another_instance_running?
        # Requeue to run at a random interval sometime between 3 and 3.5 minutes from now
        # This is just to help combat any situation where multiple of the same file may run at nearly identical times.  They both should
        # show as processing here, but then the next run, given the random wait period one should run before the other and win out.
        enqueue_job (Time.zone.now + (Random.rand(180..210)).seconds)
      else
        begin
          FileImportProcessor.process @imported_file, [FileImportProcessorListener.new(@imported_file,@user_id)]
        rescue => e
          @imported_file.errors[:base] << "There was an error processing the file: #{e.message}"
          e.log_me ["Imported File ID: #{@imported_file.id}"]
        end
        OpenMailer.send_imported_file_process_fail(@imported_file, @imported_file.search_setup.user).deliver if @imported_file.errors.size>0 && MasterSetup.get.custom_feature?('LogImportedFileErrors')
      end
    end

    def enqueue_job run_at = nil
      options = {}
      if run_at
        options[:run_at] = run_at
      end
      Delayed::Job.enqueue self, options
    end

    def another_instance_running? 
      # Since this class is also currently running and will have the filename in it, we're looking for more than one instance running.
      Delayed::Job.where("locked_at IS NOT NULL AND locked_by IS NOT NULL").where("handler like ?", "%#{@imported_file.attached_file_name}%").count > 1
    end
  end
  
  class FileImportProcessorListener

    def initialize(imported_file,user_id)
      @imported_file = imported_file
      @fr = @imported_file.file_import_results.build(:run_by=>User.find(user_id))
    end

    def process_row_count count
      @fr.update_attributes(:expected_rows=>(count - @imported_file.starting_row - 1))
    end
    def process_row row_number, object, messages, failed=false
      key_model_field_value, messages = messages.partition{ |m| m.respond_to?(:unique_identifier?) && m.unique_identifier? }
      cr = ChangeRecord.create(:unique_identifier=>key_model_field_value[0], :record_sequence_number=>row_number,:recordable=>object,
                               :failed=>failed,:file_import_result_id=>@fr.id)
      unless messages.blank?
        msg_sql = []
        messages.each {|m| msg_sql << "(#{cr.id}, '#{m.gsub(/\\/, '\&\&').gsub(/'/, "''")}')" }
        sql = "INSERT INTO change_record_messages (`change_record_id`,`message`) VALUES #{msg_sql.join(", ")};"    
        ActiveRecord::Base.connection.execute sql
        ActiveRecord::Base.connection.execute "UPDATE file_import_results SET rows_processed = #{row_number - (@imported_file.starting_row - 1)} WHERE ID = #{@fr.id};"
      end
      
      object.update_attributes(:last_updated_by_id=>@fr.run_by.id) if object.respond_to?(:last_updated_by_id)
      object.create_snapshot(@fr.run_by,@imported_file, @imported_file.note) if object.respond_to?(:create_snapshot)
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
