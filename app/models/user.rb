require 'securerandom'
require 'digest/sha1'

class User < ActiveRecord::Base
  include Clearance::User

  cattr_accessor :current
  
  attr_accessible :username, :email, :time_zone, 
    :email_format, :company_id,
    :first_name, :last_name, :search_open,
    :order_view, :order_edit, :order_delete, :order_attach, :order_comment,
    :shipment_view, :shipment_edit, :shipment_delete, :shipment_attach, :shipment_comment,
    :sales_order_view, :sales_order_edit, :sales_order_delete, :sales_order_attach, :sales_order_comment,
    :delivery_view, :delivery_edit, :delivery_delete, :delivery_attach, :delivery_comment,
    :product_view, :product_edit, :product_delete, :product_attach, :product_comment,
    :entry_view, :entry_comment, :entry_attach, :entry_edit, :drawback_edit, :drawback_view,
    :survey_view, :survey_edit,
    :project_view, :project_edit,
    :broker_invoice_view, :broker_invoice_edit,
    :classification_edit,
    :commercial_invoice_view, :commercial_invoice_edit,
    :security_filing_view, :security_filing_edit, :security_filing_comment, :security_filing_attach,
    :support_agent,
    :password_reset,
    :simple_entry_mode,
    :tariff_subscribed, :homepage,
    :provider, :uid, :google_name, :oauth_token, :oauth_expires_at, :disallow_password, :group_ids
  
  belongs_to :company
  belongs_to :run_as, :class_name => "User"
  
  has_many   :histories, :dependent => :destroy
  has_many   :item_change_subscriptions, :dependent => :destroy
  has_many   :search_setups, :dependent => :destroy
  has_many   :custom_reports, :dependent=> :destroy
  has_many   :messages, :dependent => :destroy
  has_many   :debug_records, :dependent => :destroy
  has_many   :dashboard_widgets, :dependent => :destroy
  has_many   :imported_files
  has_many   :imported_file_downloads
  has_many   :instant_classification_results, :foreign_key => :run_by_id
  has_many   :report_results, :foreign_key => :run_by_id
  has_many   :survey_responses
  has_many   :part_number_correlations, :dependent => :destroy
  has_many   :support_tickets, :foreign_key => :requestor_id
  has_many   :support_tickets_assigned, :foreign_key => :agent_id, :class_name=>"SupportTicket"
  has_many   :event_subscriptions, inverse_of: :user, dependent: :destroy, autosave: true
  has_and_belongs_to_many :groups, join_table: "user_group_memberships", after_add: :add_to_group_cache, after_remove: :remove_from_group_cache

  validates  :company, :presence => true
  validates  :username, presence: true, uniqueness: { case_sensitive: false }

  before_save :should_update_timestaps?
  after_save :reset_timestamp_flag

  # find or create the ApiAdmin user
  def self.api_admin
    u = User.find_by_username('ApiAdmin')
    if !u
      u = Company.find_master.users.build(
        username:'ApiAdmin',
        first_name:'API',
        last_name:'Admin',
        email:'bug+api_admin@vandegriftinc.com'
        )
      u.admin = true
      pwd = generate_authtoken(u)
      u.password = pwd
      u.disallow_password = true
      u.api_auth_token =  generate_authtoken(u)
      u.save!
    end
    u
  end

  #find or create the integration user
  def self.integration
    u = User.find_by_username('integration')
    if !u
      h = {
        username:'integration',
        first_name:'Integration',
        last_name:'User',
        email:'bug+integration@vandegriftinc.com'
      }
      add_all_permissions_to_hash h
      u = Company.find_master.users.build(h)
      u.admin = true
      pwd = generate_authtoken(u)
      u.password = pwd
      u.disallow_password = true
      u.save!
    end
    u
  end

  def self.add_all_permissions_to_hash h
    [:order_view, :order_edit, :order_delete, :order_attach, :order_comment,
    :shipment_view, :shipment_edit, :shipment_delete, :shipment_attach, :shipment_comment,
    :sales_order_view, :sales_order_edit, :sales_order_delete, :sales_order_attach, :sales_order_comment,
    :delivery_view, :delivery_edit, :delivery_delete, :delivery_attach, :delivery_comment,
    :product_view, :product_edit, :product_delete, :product_attach, :product_comment,
    :entry_view, :entry_comment, :entry_attach, :entry_edit, :drawback_edit, :drawback_view,
    :survey_view, :survey_edit,
    :project_view, :project_edit,
    :broker_invoice_view, :broker_invoice_edit,
    :classification_edit,
    :commercial_invoice_view, :commercial_invoice_edit,
    :security_filing_view, :security_filing_edit, :security_filing_comment, :security_filing_attach].each do |p|
      h[p] = true
    end
  end

  # This is overriding the standard clearance email find and replacing with a lookup by username instead
  def self.authenticate username, password
    r = nil
    user = User.where(username: username).first

    if user
      # Authenticated? is the clearance method for validating the user's supplied password matches
      # the stored password hash.
      r = !user.disallow_password? && user.authenticated?(password) ? user : nil
    end

    r
  end

  def self.from_omniauth(omniauth_provider, auth_info)
    errors = []
    if omniauth_provider == "pepsi-saml"
      user = User.where(username: auth_info.uid).first
      errors << "Pepsi User ID #{auth_info.uid} has not been set up in VFI Track." unless user
    elsif omniauth_provider == "google_oauth2"
      if user = User.where(email: auth_info[:info][:email]).first
        user.provider = auth_info.provider
        user.uid = auth_info.uid
        user.google_name = auth_info.info.name
        user.oauth_token = auth_info.credentials.token
        user.oauth_expires_at = Time.at(auth_info.credentials.expires_at)
        user.save!
      else
        errors << "Google email account #{auth_info[:info][:email]} has not been set up in VFI Track."
      end
    end

    return {user: user, errors: errors}
  end

  def self.generate_authtoken user
    # Removing the Base64 padding (ie. equals) from digest due to rails 3 authorization header token parsing bug
    Digest::SHA1.base64digest("#{Time.zone.now}#{MasterSetup.get.uuid}#{user.username}").gsub("=", "")
  end

  def self.access_allowed? user
    !(user.nil? || user.disabled? || user.company.locked)
  end

  # Runs the passed in block of code using any global
  # user settings that can be extracted from the passed in user.
  # In effect, it sets User.current and Time.zone for the given block of code
  # and then unsets it after the block has been run.
  # In general, this is only really useful in background jobs since these values
  # are already set by the application controller in a web context.
  def self.run_with_user_settings user
    previous_user = User.current
    previous_time_zone = Time.zone
    begin
      User.current = user
      Time.zone = user.time_zone unless user.time_zone.blank?
      yield
    ensure
      User.current = previous_user
      Time.zone = previous_time_zone
    end
  end

  # Sends each user id listed an email informing them of their account login / temporary password
  def self.send_invite_emails ids
    unless ids.respond_to? :each_entry
      ids = [ids]
    end

    ids.each_entry do |id|
      user = User.where(id: id).first
      if user
        # Because we only store hashed versions of passwords, if we're going to relay users their temporary 
        # password in an email, the only way we can send them a cleartext password is if we generate and save one here.
        cleartext = SecureRandom.urlsafe_base64(12, false)[0, 8]
        user.update_user_password cleartext, cleartext
        user.update_column :password_reset, true
        OpenMailer.send_invite(user, cleartext).deliver
      end
    end
    nil
  end

  # override default clearance email authentication
  def email_optional?
    true
  end

  # return all companies that I as a user can see that are importers
  def available_importers
    r = Company.importers
    r = r.where("(companies.id IN (SELECT child_id FROM linked_companies WHERE parent_id = #{self.company_id}) OR companies.id = #{self.company_id})") unless self.company.master?
    r
  end

  def update_user_password password, password_confirmation
    # The password will be blank most of the time on the user maint screen, unless the user
    # is actually trying to update their password.
    valid = password.blank?
    unless valid
      if password != password_confirmation
        valid = false
        errors.add(:password, "must match password confirmation.")
      else
        # This is the clearance method for updating the password.
        valid = update_password(password)
      end
    end
    valid
  end

  def on_successful_login request
    if request && self.host_with_port.blank?
      self.host_with_port = request.host_with_port
    end

    self.last_login_at = self.current_login_at
    self.current_login_at = Time.zone.now
    self.failed_login_count = 0
    save validate: false

    History.create({:history_type => 'login', :user_id => self.id, :company_id => self.company_id})
  end

  def debug_active?
    !self.debug_expires.blank? && self.debug_expires>Time.now
  end

  #send password reset email to user
  def deliver_password_reset_instructions!
    forgot_password!
    OpenMailer.send_password_reset(self).deliver
  end
  
  # is an administrator within the application (as opposed to a sys_admin who is an Vandegrift employee with master control)
  # If you are a sys_admin, you are automatically an admin (as long as this method is called instead of looking directly at the db value)
  def admin?
    self.admin || self.sys_admin
  end

  # is a super administrator (generally an Vandegrift employee) who can control settings not visible to other users
  def sys_admin?
    self.sys_admin
  end
  
  def active?
    return !self.disabled
  end
  
  #should the advanced search box be open on the user's screen
  def search_open?
    return self.search_open
  end

  def full_name
    n = (self.first_name.nil? ? '' : self.first_name + " ") + (self.last_name.nil? ? '' : self.last_name)
    n = self.username if n.strip.length==0
    return n
  end
  
  #should a user message be hidden for this user
  def hide_message? message_name
    parse_hidden_messages
    @parsed_hidden_messages.include? message_name.upcase
  end

  #add a message to the list that shouldn't be displayed for this user
  def add_hidden_message message_name 
    parse_hidden_messages
    @parsed_hidden_messages << message_name.upcase
    store_hidden_messages
  end

  def remove_hidden_message message_name
    parse_hidden_messages
    @parsed_hidden_messages.delete message_name.upcase
    store_hidden_messages
  end

  def can_view?(user)
    return user.admin? || self==user
  end
  
  def can_edit?(user)
    return user.admin? || self==user
  end


  # Can the given user view items for the given module
  def view_module? core_module
    case core_module
    when CoreModule::ORDER
      return self.view_orders?
    when CoreModule::SHIPMENT
      return self.view_shipments?
    when CoreModule::PRODUCT
      return self.view_products?
    when CoreModule::SALE
      return self.view_sales_orders?
    when CoreModule::DELIVERY
      return self.view_deliveries?
    when CoreModule::ORDER_LINE
      return self.view_orders?
    when CoreModule::SHIPMENT_LINE
      return self.view_shipments?
    when CoreModule::DELIVERY_LINE
      return self.view_deliveries?
    when CoreModule::SALE_LINE
      return self.view_sales_orders?
    when CoreModule::TARIFF
      return self.view_products?
    when CoreModule::CLASSIFICATION
      return self.view_products?
    when CoreModule::OFFICIAL_TARIFF
      return self.view_official_tariffs? 
    when CoreModule::ENTRY
      return self.view_entries?
    when CoreModule::BROKER_INVOICE
      return self.view_broker_invoices?
    when CoreModule::BROKER_INVOICE_LINE
      return self.view_broker_invoices?
    when CoreModule::COMMERCIAL_INVOICE
      return self.view_commercial_invoices?
    when CoreModule::COMMERCIAL_INVOICE_LINE
      return self.view_commercial_invoices?
    when CoreModule::COMMERCIAL_INVOICE_TARIFF
      return self.view_commercial_invoices?
    when CoreModule::SECURITY_FILING
      return self.view_security_filings?
    end
    return false
  end
  
  #permissions
  def view_business_validation_results?
    self.company.master?
  end
  def edit_business_validation_results?
    self.company.master?
  end  
  def view_business_validation_rule_results?
    self.company.master?
  end
  def edit_business_validation_rule_results?
    self.company.master?
  end
  def view_official_tariffs?
    self.company.master?
  end
  def view_attachment_archives?
    self.company.master? && self.view_entries?
  end
  def edit_attachment_archives?
    self.view_attachment_archives?
  end
  def view_security_filings?
    self.security_filing_view? && self.company.view_security_filings? 
  end
  def edit_security_filings?
    self.security_filing_edit? && self.company.edit_security_filings? 
  end
  def attach_security_filings?
    self.security_filing_attach? && self.company.attach_security_filings? 
  end
  def comment_security_filings?
    self.security_filing_comment? && self.company.comment_security_filings? 
  end
  def view_drawback?
    self.drawback_view? && MasterSetup.get.drawback_enabled?
  end
  def edit_drawback?
    self.drawback_edit? && MasterSetup.get.drawback_enabled?
  end
  def view_commercial_invoices?
    self.commercial_invoice_view? && MasterSetup.get.entry_enabled?
  end
  def edit_commercial_invoices?
    self.commercial_invoice_edit? && MasterSetup.get.entry_enabled?
  end
  def view_surveys?
    self.survey_view?
  end
  def edit_surveys?
    self.survey_edit?
  end
  def view_broker_invoices?
    self.broker_invoice_view && self.company.view_broker_invoices?
  end
  def edit_broker_invoices?
    self.broker_invoice_edit && self.company.edit_broker_invoices?
  end
  def view_entries?
    self.entry_view? && self.company.view_entries?
  end
  def comment_entries?
    self.entry_comment? && self.company.view_entries?
  end
  def attach_entries?
    self.entry_attach? && self.company.view_entries?
  end
  def edit_entries?
    self.entry_edit? && self.company.broker?
  end
  def view_orders?
    self.order_view? && self.company.view_orders? 
  end
  def add_orders?
    self.order_edit? && self.company.add_orders?
  end
  def edit_orders?
    self.order_edit? && self.company.edit_orders?
  end
  def delete_orders?
    self.order_delete? && self.company.delete_orders?
  end
  def attach_orders?
    self.order_attach? && self.company.attach_orders?
  end
  def comment_orders?
    self.order_comment? && self.company.comment_orders?
  end
  
  def view_products?
    self.product_view? && self.company.view_products? 
  end
  def add_products?
    self.product_edit? && self.company.add_products?
  end
  def edit_products?
    self.product_edit? && self.company.edit_products?
  end
  def create_products?
    add_products?
  end
  def delete_products?
    self.product_delete? && self.company.delete_products?
  end
  def attach_products?
    self.product_attach? && self.company.attach_products?
  end
  def comment_products?
    self.product_comment? && self.company.comment_products?
  end
  
  def view_sales_orders?
    self.sales_order_view? && self.company.view_sales_orders? 
  end
  def add_sales_orders?
    self.sales_order_edit? && self.company.add_sales_orders?
  end
  def edit_sales_orders?
    self.sales_order_edit? && self.company.edit_sales_orders?
  end
  def delete_sales_orders?
    self.sales_order_delete? && self.company.delete_sales_orders?
  end
  def attach_sales_orders?
    self.sales_order_attach? && self.company.attach_sales_orders?
  end
  def comment_sales_orders?
    self.sales_order_comment? && self.company.comment_sales_orders?
  end

  
  def view_shipments?
    self.shipment_view && self.company.view_shipments?
  end
  def add_shipments?
    self.shipment_edit? && self.company.add_shipments?
  end
  def edit_shipments?
    self.shipment_edit? && self.company.edit_shipments?
  end
  def delete_shipments?
    self.shipment_delete? && self.company.delete_shipments?
  end
  def comment_shipments?
    self.shipment_comment? && self.company.comment_shipments?
  end
  def attach_shipments?
    self.shipment_attach? && self.company.attach_shipments?
  end
  
  def view_deliveries?
    self.delivery_view? && self.company.view_deliveries?
  end
  def add_deliveries?
    self.delivery_edit? && self.company.add_deliveries?
  end
  def edit_deliveries?
    self.delivery_edit? && self.company.edit_deliveries?
  end
  def delete_deliveries?
    self.delivery_delete? && self.company.delete_deliveries?
  end
  def comment_deliveries?
    self.delivery_comment? && self.company.comment_deliveries?
  end
  def attach_deliveries?
    self.delivery_attach? && self.company.attach_deliveries?
  end

  def add_classifications?
    self.classification_edit? && self.company.add_classifications?
  end
  def edit_classifications?
    add_classifications?
  end

  def view_projects?
    self.project_view && self.master_company?
  end
  def edit_projects?
    self.project_edit && self.master_company?
  end


  def edit_milestone_plans?
    self.admin?
  end
  
  def edit_status_rules?
    self.admin?
  end

  def master_company?
    @mc ||= self.company.master?
    @mc
  end

  def in_group? group
    cache = group_cache(true)
    to_find = group.respond_to?(:system_code) ? group.system_code : group
    cache.include? to_find.to_s
  end

  def in_any_group? groups
    groups.each do |g|
      return true if self.in_group? g
    end
    return false
  end

  def user_group_codes
    group_cache(true).to_a
  end

  private
  def parse_hidden_messages
    @parsed_hidden_messages ||= (self.hidden_message_json.blank? ? [] : JSON.parse(self.hidden_message_json))
  end
  def store_hidden_messages
    self.hidden_message_json = @parsed_hidden_messages.to_json unless @parsed_hidden_messages.nil?
  end
  def master_setup
    MasterSetup.get 
  end
  def should_update_timestaps?
    no_timestamp_reset_fields = ['confirmation_token','remember_token','last_request_at', 'last_login_at', 'current_login_at', 'failed_login_count', 'host_with_port']
    self.record_timestamps = false if (self.changed - no_timestamp_reset_fields).empty?
    true
  end
  def reset_timestamp_flag
    self.record_timestamps = true
    true
  end

  def group_cache(ensure_created)
    if @group_cache.nil? && ensure_created
      @group_cache = SortedSet.new self.groups.map(&:system_code)
    end

    @group_cache
  end

  def add_to_group_cache group
    group_cache(true) << group.system_code
    nil
  end

  def remove_from_group_cache group
    group_cache(false).try(:delete, group.system_code)
    nil
  end
end
