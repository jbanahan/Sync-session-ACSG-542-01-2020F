# == Schema Information
#
# Table name: users
#
#  User                    :string(255)
#  active_days             :integer          default(0)
#  admin                   :boolean
#  api_auth_token          :string(255)
#  api_request_counter     :integer
#  broker_invoice_edit     :boolean
#  broker_invoice_view     :boolean
#  classification_edit     :boolean
#  commercial_invoice_edit :boolean
#  commercial_invoice_view :boolean
#  company_id              :integer
#  confirmation_token      :string(128)
#  created_at              :datetime         not null
#  crypted_password        :string(255)
#  current_login_at        :datetime
#  debug_expires           :datetime
#  delivery_attach         :boolean
#  delivery_comment        :boolean
#  delivery_delete         :boolean
#  delivery_edit           :boolean
#  delivery_view           :boolean
#  department              :string(255)
#  disabled                :boolean
#  disallow_password       :boolean
#  drawback_edit           :boolean
#  drawback_view           :boolean
#  email                   :string(255)
#  email_format            :string(255)
#  email_new_messages      :boolean          default(FALSE)
#  encrypted_password      :string(128)
#  entry_attach            :boolean
#  entry_comment           :boolean
#  entry_edit              :boolean
#  entry_view              :boolean
#  failed_login_count      :integer          default(0), not null
#  failed_logins           :integer          default(0)
#  first_name              :string(255)
#  forgot_password         :boolean
#  google_name             :string(255)
#  hidden_message_json     :text
#  homepage                :string(255)
#  host_with_port          :string(255)
#  id                      :integer          not null, primary key
#  last_login_at           :datetime
#  last_name               :string(255)
#  last_request_at         :datetime
#  oauth_expires_at        :datetime
#  oauth_token             :string(255)
#  order_attach            :boolean
#  order_comment           :boolean
#  order_delete            :boolean
#  order_edit              :boolean
#  order_view              :boolean
#  password_changed_at     :datetime
#  password_expired        :boolean          default(FALSE)
#  password_locked         :boolean          default(FALSE)
#  password_reset          :boolean
#  password_salt           :string(255)
#  perishable_token        :string(255)      default(""), not null
#  persistence_token       :string(255)
#  portal_mode             :string(255)
#  product_attach          :boolean
#  product_comment         :boolean
#  product_delete          :boolean
#  product_edit            :boolean
#  product_view            :boolean
#  project_edit            :boolean
#  project_view            :boolean
#  provider                :string(255)
#  remember_token          :string(128)
#  run_as_id               :integer
#  sales_order_attach      :boolean
#  sales_order_comment     :boolean
#  sales_order_delete      :boolean
#  sales_order_edit        :boolean
#  sales_order_view        :boolean
#  search_open             :boolean
#  security_filing_attach  :boolean
#  security_filing_comment :boolean
#  security_filing_edit    :boolean
#  security_filing_view    :boolean
#  shipment_attach         :boolean
#  shipment_comment        :boolean
#  shipment_delete         :boolean
#  shipment_edit           :boolean
#  shipment_view           :boolean
#  simple_entry_mode       :boolean
#  statement_view          :boolean
#  support_agent           :boolean
#  survey_edit             :boolean
#  survey_view             :boolean
#  sys_admin               :boolean
#  system_user             :boolean
#  tariff_subscribed       :boolean
#  task_email              :boolean
#  time_zone               :string(255)
#  trade_lane_attach       :boolean
#  trade_lane_comment      :boolean
#  trade_lane_edit         :boolean
#  trade_lane_view         :boolean
#  uid                     :string(255)
#  updated_at              :datetime         not null
#  username                :string(255)
#  variant_edit            :boolean
#  vendor_attach           :boolean
#  vendor_comment          :boolean
#  vendor_edit             :boolean
#  vendor_view             :boolean
#  vfi_invoice_edit        :boolean
#  vfi_invoice_view        :boolean
#
# Indexes
#
#  index_users_on_remember_token  (remember_token)
#  index_users_on_username        (username)
#

require 'securerandom'
require 'digest/sha1'
require 'email_validator'
require 'open_chain/user_support/user_permissions'
require 'open_chain/user_support/groups'
require 'open_chain/user_support/failed_password_handler'
require 'open_chain/registries/password_validation_registry'

class User < ActiveRecord::Base
  include Clearance::User
  include OpenChain::UserSupport::UserPermissions
  include OpenChain::UserSupport::Groups
  include CoreObjectSupport

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
    :vendor_view, :vendor_edit, :vendor_comment, :vendor_attach,
    :vfi_invoice_view, :vfi_invoice_edit,
    :trade_lane_view, :trade_lane_edit, :trade_lane_comment, :trade_lane_attach,
    :broker_invoice_view, :broker_invoice_edit,
    :variant_edit,
    :classification_edit,
    :commercial_invoice_view, :commercial_invoice_edit,
    :security_filing_view, :security_filing_edit, :security_filing_comment, :security_filing_attach,
    :support_agent,
    :simple_entry_mode,
    :tariff_subscribed, :homepage,
    :provider, :uid, :google_name, :oauth_token, :oauth_expires_at, :disallow_password, :group_ids,
    :portal_mode,
    :system_user, :statement_view, :department

  belongs_to :company
  belongs_to :run_as, :class_name => "User"

  has_many   :user_password_histories, :dependent => :destroy
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
  validate :valid_email
  scope :enabled, lambda { where(disabled: [false, nil]) }
  scope :non_system_user, lambda { where(system_user: [false, nil]) }

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
        email:'bug+api_admin@vandegriftinc.com',
        system_user: true
        )
      u.admin = true
      pwd = generate_authtoken(u)
      u.password = pwd
      u.disallow_password = true
      u.api_auth_token = generate_authtoken(u)
      u.time_zone = "Eastern Time (US & Canada)"
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
        email:'bug+integration@vandegriftinc.com',
        system_user: true
      }
      add_all_permissions_to_hash h
      u = Company.find_master.users.build(h)
      u.admin = true
      pwd = generate_authtoken(u)
      u.password = pwd
      u.disallow_password = true
      u.api_auth_token =  generate_authtoken(u)
      u.time_zone = "Eastern Time (US & Canada)"
      u.save!
    end
    u
  end


  # This is overriding the standard clearance email find and replacing with a lookup by username instead
  def self.authenticate username, password
    r = nil
    user = User.where(username: username).first

    if user
      # Authenticated? is the clearance method for validating the user's supplied password matches
      # the stored password hash.
      if !user.disallow_password?
        r = user.authenticated?(user.password_salt, password)
        OpenChain::UserSupport::FailedPasswordHandler.call(user) if r.blank?
      end
    end

    r.present? ? user : nil
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
        errors << "Google email account #{auth_info[:info][:email]} has not been set up in VFI Track." +
                  " If you would like to request an account, please click the 'Need an account?' link below."
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

  # Clobber Clearance's normalize_email to prevent it from stripping out spaces from emails.
  def self.normalize_email email
    email.to_s.strip
  end

  # return hash suitable for api controller (doing it here since we also use it outside of the controller)
  def api_hash include_permissions: true
    hash = {
      id: self.id,
      full_name: self.full_name,
      first_name: self.first_name,
      last_name: self.last_name,
      email: self.email,
      email_new_messages: self.email_new_messages,
      username: self.username,
      company_id: self.company_id,
      department: self.department
    }

    if include_permissions
      hash[:permissions] = {
        admin: self.admin?,
        sys_admin: self.sys_admin?,
        view_orders: self.view_orders?,
        edit_orders: self.edit_orders?,
        view_vendor_portal: self.view_vendor_portal?,
        view_products: self.view_products?,
        edit_products: self.edit_products?,
        view_official_tariffs: self.view_official_tariffs?,
        view_shipments: self.view_shipments?,
        edit_shipments: self.edit_shipments?,
        view_security_filings: self.view_security_filings?,
        view_entries: self.view_entries?,
        view_broker_invoices: self.view_broker_invoices?,
        view_summary_statements: self.view_summary_statements?,
        edit_summary_statements: self.edit_summary_statements?,
        view_drawback: self.view_drawback?,
        edit_drawback: self.edit_drawback?,
        upload_drawback: self.edit_drawback?,
        view_survey_responses: !self.survey_responses.empty? || self.view_surveys?,
        view_surveys: self.view_surveys?,
        view_vendors: self.view_vendors?,
        create_vendors: self.create_vendors?,
	      view_trade_lanes: self.view_trade_lanes?,
	      edit_trade_lanes: self.edit_trade_lanes?,
        view_trade_preference_programs: self.view_trade_preference_programs?,
        edit_trade_preference_programs: self.edit_trade_preference_programs?,
        view_vfi_invoices: self.view_vfi_invoices?,
        edit_vfi_invoices: self.edit_vfi_invoices?,
        view_statements: self.view_statements?,
        view_commercial_invoices: self.view_commercial_invoices?
      }
    end

    hash
  end

  def recent_password_hashes(password_count=5)
    user_password_histories.order('created_at DESC').limit(password_count).map { |password| password }
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

  def self.valid_password? user, password
    OpenChain::Registries::PasswordValidationRegistry.valid_password? user, password
  end

  def update_user_password password, password_confirmation, snapshot=true
    # Fail if the password is blank, under no circumstance do we want to accidently set someone's password
    # to a blank string.
    valid = false
    if password.blank?
      errors.add(:password, "cannot be blank.")
    else
      if password != password_confirmation
        errors.add(:password, "must match password confirmation.")
      elsif !User.valid_password?(self, password)
        valid = false
      else
        # This is the clearance method for updating the password.
        valid = update_password(password)
      end
    end

    if valid
      self.password_changed_at = Time.zone.now
      self.password_locked = false
      self.password_expired = false
      self.forgot_password = false
      self.failed_logins = 0
      self.save!
      self.create_snapshot(User.integration, nil, 'Password changed') if snapshot

      self.user_password_histories.create!(hashed_password: self.encrypted_password, password_salt: self.password_salt)
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
    self.failed_logins = 0
    save validate: false

    History.create({:history_type => 'login', :user_id => self.id, :company_id => self.company_id})
  end

  def debug_active?
    !self.debug_expires.blank? && self.debug_expires > Time.zone.now
  end

  #send password reset email to user
  def deliver_password_reset_instructions!
    forgot_password!
    OpenMailer.send_password_reset(self).deliver
  end

  def locked?
    active? && ( password_expired? || password_locked? )
  end
  
  # is an administrator within the application (as opposed to a sys_admin who is an Vandegrift employee with master control)
  # If you are a sys_admin, you are automatically an admin (as long as this method is called instead of looking directly at the db value)
  def admin?
    self.admin || self.sys_admin?
  end

  # is a super administrator (generally an Vandegrift employee) who can control settings not visible to other users
  def sys_admin?
    self.sys_admin == true
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

  def full_name_and_username
    "#{full_name} (#{username})"
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

  def user_auth_token
    if self.api_auth_token.blank?
      self.api_auth_token = User.generate_authtoken(self)
      self.save!
    end

    "#{self.username}:#{self.api_auth_token}"
  end

  def master_company?
    @mc ||= self.company.master?
    @mc
  end

  # return redirect path if user has a valid portal_mode
  def portal_redirect_path
    return '/vendor_portal' if self.portal_mode=='vendor'
    return nil
  end

  # adds all permissions with value set to true
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
    :security_filing_view, :security_filing_edit, :security_filing_comment, :security_filing_attach, :statement_view].each do |p|
      h[p] = true
    end
  end

  def url
    Rails.application.routes.url_helpers.company_user_url(host: MasterSetup.get.request_host,
                                                          company_id: company.id,
                                                          id: id,
                                                          protocol: (Rails.env.development? ? "http" : "https"))
  end

  private_class_method :add_all_permissions_to_hash

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

  def valid_email
    rejected = email.split(/,|;/).map{ |e| e.strip}.reject{ |e| EmailValidator.valid? e }
    error_message = rejected.count > 1 ? "invalid: #{rejected.join(', ')}" : "invalid"
    errors.add(:email, error_message) unless rejected.empty?
  end
end
