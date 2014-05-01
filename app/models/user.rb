require 'securerandom'

class User < ActiveRecord::Base
  cattr_accessor :current

  acts_as_authentic do |config|
    # By default, authlogic expires password resets after 10 minutes...that's too short, allow an hour
    config.perishable_token_valid_for 1.hour
    # Default options to make sure Authlogic cookies are set to only be accessible over ssl and only http only.
    # SSL only for prod since we don't run dev environment over SSL
    UserSession.secure = Rails.env.production?
    UserSession.httponly = true
  end
  
  attr_accessible :username, :email, :password, 
    :password_confirmation, :time_zone, 
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
    :classification_view, :classification_edit,
    :commercial_invoice_view, :commercial_invoice_edit,
    :security_filing_view, :security_filing_edit, :security_filing_comment, :security_filing_attach,
    :support_agent,
    :password_reset,
    :simple_entry_mode,
    :tariff_subscribed, :homepage
  
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

  validates  :company, :presence => true

  before_save :authlogic_persistence
  after_save :reset_timestamp_flag

  def self.find_not_locked(login) 
    u = User.where(:username => login).first
    unless u.nil? || u.company.locked
      return u
    else
      return nil
    end
  end

  def debug_active?
    !self.debug_expires.blank? && self.debug_expires>Time.now
  end

  #send password reset email to user
  def deliver_password_reset_instructions!
    reset_password_prep
    OpenMailer.send_password_reset(self, self.updated_at + 1.hour).deliver
  end

  # Preparations needed for resetting a users password.
  def reset_password_prep
    # The reason we're touching ourselves is because authlogic uses 'updated_at' to implement an expiration time on the
    # perishable token.  However, since we've disabled setting updated_at for caching reasons (perishable token is reset every request)
    # if only perishable_token is updated (as happens below on 'reset_perishable_token!') then, unless the user account has been 
    # updated within the last hour, the user won't be able to use the password reset email because his token will be considered out of date already.
    self.touch
    reset_perishable_token!
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
        # password in an email, the only way we can send them a cleartext password is if we generate one here.
        password = update_with_random_password user
        OpenMailer.send_invite(user, password).deliver
      end
    end
    nil
  end
  
  # is an administrator within the application (as opposed to a sys_admin who is an Aspect 9 employee with master control)
  # If you are a sys_admin, you are automatically an admin (as long as this method is called instead of looking directly at the db value)
  def admin?
    self.admin || self.sys_admin
  end

  # is a super administrator (generally an Aspect 9 employee) who can control settings not visible to other users
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
  def authlogic_persistence
    self.record_timestamps = false if (self.changed - ['perishable_token','persistence_token','last_request_at']).empty?
    true
  end
  def reset_timestamp_flag
    self.record_timestamps = true
    true
  end

  # Generates a random password, saves it into the user, forces password reset and returns the cleartext version of the password
  # that was generated.
  def self.update_with_random_password user
    # Generates a purely random 8 character password
    cleartext = SecureRandom.urlsafe_base64(12, false)[0, 8]

    user.password = cleartext
    user.password_confirmation = cleartext
    user.password_reset = true
    user.save!
    user.reset_perishable_token!

    cleartext
  end
  private_class_method :update_with_random_password
end
