class SearchSetup < ActiveRecord::Base


  validates   :name, :presence => true
  validates   :user, :presence => true
  validates   :module_type, :presence => true
  
  has_many :search_criterions, :dependent => :destroy
  has_many :sort_criterions, :dependent => :destroy
  has_many :search_columns, :dependent => :destroy
  has_many :search_schedules, :dependent => :destroy
  has_many :imported_files 
  has_many :dashboard_widgets, :dependent => :destroy
  has_one :search_run, :dependent => :destroy

  belongs_to :user
  
  accepts_nested_attributes_for :search_criterions, :allow_destroy => true, 
    :reject_if => lambda { |a| 
      r_val = false
      [:model_field_uid,:operator].each { |f|
        r_val = true if a[f].blank?
      } 
      r_val
    }
  accepts_nested_attributes_for :sort_criterions, :allow_destroy => true, 
    :reject_if => lambda { |a| a[:model_field_uid].blank? }
  accepts_nested_attributes_for :search_columns, :allow_destroy => true,
    :reject_if => lambda { |a| a[:model_field_uid].blank? }
  accepts_nested_attributes_for :search_schedules, :allow_destroy => true,
    :reject_if => lambda { |a| a[:email_addresses].blank? && 
      a[:ftp_server].blank? && 
      a[:_destroy].blank?
    }
    
  scope :for_user, lambda {|u| where(:user_id => u)} 
  scope :for_module, lambda {|m| where(:module_type => m.class_name)}
  
  def self.find_last_accessed user, core_module
    SearchSetup.for_user(user).for_module(core_module).
      joins("left outer join search_runs on search_runs.search_setup_id = search_setups.id").
      order("ifnull(search_runs.last_accessed,1900-01-01) DESC").
      first
  end

  def sorted_columns
    self.search_columns.order("rank ASC")
  end
  
  def search
    private_search true
  end

  #executes the search without securing it against user permissions
  def public_search
    private_search false
  end

  def core_module
    CoreModule.find_by_class_name(self.module_type)
  end

  def module_chain
    core_module.default_module_chain
  end
  
  def touch
    sr = self.search_run
    sr = self.build_search_run(:position=>0) if sr.nil?
    sr.last_accessed = Time.now
    sr.user_id = self.user_id
    sr.save
  end

  def last_accessed
    sr = self.search_run
    sr.nil? ? nil : sr.last_accessed
  end

  # Returns a new, saved search setup with the columns passed from the given array
  def self.create_with_columns(model_field_uids,user,name="Default")
    ss = SearchSetup.create(:name=>name,:user => user,:module_type=>ModelField.find_by_uid(model_field_uids[0]).core_module.class_name,
        :simple=>false)
    model_field_uids.each_with_index do |uid,i|
      ss.search_columns.create(:rank=>i,:model_field_uid=>uid)
    end
    ss
  end
  
  # Makes a deep copy of the search and assigns it to the given user
  def give_to other_user
    ss = deep_copy self.name+" (From #{self.user.full_name})", true
    ss.user = other_user
    ss.save
  end

  # Returns a copy of the SearchSetup with matching columns, search & sort criterions 
  # all built.
  #
  # If a true parameter is provided, everything in the tree will be saved to the database.
  def deep_copy(new_name, save_obj=false) 
    ss = SearchSetup.new(:name => new_name, :module_type => self.module_type, :user => self.user, :simple => self.simple, :download_format => self.download_format, :include_links=>self.include_links)
    ss.save if save_obj
    self.search_criterions.each do |sc|
      new_sc = ss.search_criterions.build(:operator => sc.operator, :value => sc.value,  
        :status_rule_id => sc.status_rule_id, :model_field_uid => sc.model_field_uid, :search_setup_id => sc.search_setup_id,
        :custom_definition_id => sc.custom_definition_id      
      )
      new_sc.save if save_obj
    end
    self.search_columns.each do |sc|
      new_sc = ss.search_columns.build(:search_setup_id=>sc.search_setup_id, :rank=>sc.rank, 
        :model_field_uid=>sc.model_field_uid, :custom_definition_id=>sc.custom_definition_id
      )
      new_sc.save if save_obj
    end
    self.sort_criterions.each do |sc|
      new_sc = ss.sort_criterions.build(:search_setup_id=>sc.search_setup_id, :rank=>sc.rank,
        :model_field_uid => sc.model_field_uid, :custom_definition_id => sc.custom_definition_id,
        :descending => sc.descending
      )
      new_sc.save if save_obj
    end
    ss
  end

  def core_module
    CoreModule.find_by_class_name self.module_type
  end

  #does this search have the appropriate columns set to be used as a file upload?
  #acceptes an optional array that will have any user facing messages appended to it
  def uploadable? messages=[]
    #refactor later to use setup within CoreModule to figure this out instead of hard codes
    start_messages_count = messages.size
    cm = core_module 
    messages << "Search's core module not set." if cm.nil?

    if cm==CoreModule::ENTRY
      messages << "Upload functionality is not available for Entries."
    end
    if cm==CoreModule::BROKER_INVOICE
      messages << "Upload functionality is not available for Invoices."
    end
    if cm==CoreModule::DELIVERY
      messages << "You do not have permission to edit Deliveries." unless self.user.edit_deliveries?
      messages << "#{label "del_ref"} field is required to upload Deliveries." unless has_column "del_ref"
      messages << "#{combined_company_fields "del", "cust"} is required to upload Deliveries." unless has_company "del", "cust"
    end
    if cm==CoreModule::SALE
      messages << "You do not have permission to edit Sales." unless self.user.edit_sales_orders?
      messages << "#{label "sale_order_number"} field is required to upload Sales." unless has_column "sale_order_number"
      messages << "#{combined_company_fields "sale", "cust"} is required to upload Sales." unless has_company "sale", "cust"
      
      if contains_module CoreModule::SALE_LINE
        messages << "#{label "soln_line_number"} is required to upload Sale Lines." unless has_column "soln_line_number"
        messages << "#{combine_field_names ["soln_puid","soln_pname"]} is required to upload Sale Lines." unless has_one_of ["soln_puid","soln_pname"]
      end
    end
    if cm==CoreModule::SHIPMENT
      messages << "You do not have permission to edit Shipments." unless self.user.edit_shipments?
      messages << "#{label "shp_ref"} field is required to upload Shipments." unless has_column "shp_ref"
      messages << "#{combined_company_fields "shp", "ven"} is required to upload Shipments." unless has_company "shp", "ven"
      if contains_module CoreModule::SHIPMENT_LINE
        messages << "#{label "shpln_line_number"} is required to upload Shipment Lines." unless has_column "shpln_line_number"
        messages << "#{combine_field_names ["shpln_puid","shpln_pname"]} is required to upload Shipment Lines." unless has_one_of ["shpln_puid","shpln_pname"]
      end
    end
    if cm==CoreModule::PRODUCT
      messages << "You do not have permission to edit Products." unless self.user.edit_products?
      messages << "#{label "prod_uid"} field is required to upload Products." unless has_column "prod_uid"

      if contains_module CoreModule::CLASSIFICATION
        messages << "To include Classification fields, you must also include #{combine_field_names ["class_cntry_name","class_cntry_iso"]}." unless has_classification_country_column
      end
      if contains_module CoreModule::TARIFF
        messages << "To include Tariff fields, you must also include #{combine_field_names ["class_cntry_name","class_cntry_iso"]}." unless has_classification_country_column
        messages << "To include Tariff fields, you must also include #{label "hts_line_number"}." unless has_column "hts_line_number"
      end
    end

    if cm==CoreModule::ORDER
      messages << "You do not have permission to edit Orders." unless self.user.edit_orders?
      messages << "#{label "ord_ord_num"} field is required to upload Orders." unless has_column "ord_ord_num"
      messages << "#{combined_company_fields "ord","ven"} is required to upload Orders." unless has_company "ord","ven"

      if contains_module CoreModule::ORDER_LINE
        messages << "#{label "ordln_line_number"} is required to upload Order Lines." unless has_column "ordln_line_number"
        messages << "#{combine_field_names ["ordln_puid","ordln_pname"]} is required to upload Order Lines." unless has_one_of ["ordln_puid","ordln_pname"]
      end
    end

    return messages.size == start_messages_count
  end

  private 
  def has_company(model_prefix,type_prefix)
    has_one_of ["#{model_prefix}_#{type_prefix}_name","#{model_prefix}_#{type_prefix}_id","#{model_prefix}_#{type_prefix}_syscode"]
  end
  
  def has_column(model_field_uid)
    !self.search_columns.where(:model_field_uid=>model_field_uid).empty?
  end
  
  def has_one_of columns
    columns.each {|c| return true if has_column c}
    return false
  end
  
  def has_classification_country_column
    has_one_of ["class_cntry_name","class_cntry_iso"]
  end
  
  def contains_module(m)
    self.search_columns.each {|c| 
      return true if  ModelField.find_by_uid(c.model_field_uid).core_module == m
    }
    false
  end
  
  def private_search(secure=true)
    base = Kernel.const_get(self.module_type)
    
    self.search_criterions.each do |sc|
      base = sc.apply(base)
    end

    self.sort_criterions.order("rank ASC").each do |sort|
      base = sort.apply(base)
    end
    
    base = base.group("#{base.table_name}.id") #prevents duplicate rows in search results
    base = base.search_secure self.user, base if secure && base.respond_to?(:search_secure)

    #rebuild search_run
    unless self.id.nil? #only if in database
      if self.search_run.nil?
        self.create_search_run
      else
        self.search_run.reset_cursor
        self.search_run.save
      end
    end
    base
  end
  
  def label model_field_uid
    ModelField.find_by_uid(model_field_uid).label
  end
  
  def combine_field_names model_field_uids
    r = ""
    model_field_uids.each_with_index do |f,i|
      r << "or " if i==model_field_uids.size-1
      r << label(f)
      r << ", " if i<(model_field_uids.size-1)
    end
    r
  end
  
  def combined_company_fields module_prefix, company_type
    p = "#{module_prefix}_#{company_type}"
    combine_field_names ["#{p}_name","#{p}_id","#{p}_syscode"]
  end
end
