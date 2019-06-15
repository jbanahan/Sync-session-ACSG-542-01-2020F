# == Schema Information
#
# Table name: master_setups
#
#  broker_invoice_enabled      :boolean
#  classification_enabled      :boolean          default(TRUE), not null
#  created_at                  :datetime         not null
#  custom_features             :text
#  customs_statements_enabled  :boolean
#  delivery_enabled            :boolean          default(TRUE), not null
#  drawback_enabled            :boolean
#  entry_enabled               :boolean
#  friendly_name               :string(255)
#  ftp_polling_active          :boolean
#  id                          :integer          not null, primary key
#  invoices_enabled            :boolean
#  last_delayed_job_error_sent :datetime         default(2001-01-01 00:00:00 UTC)
#  logo_image                  :string(255)
#  migration_host              :string(255)
#  order_enabled               :boolean          default(TRUE), not null
#  project_enabled             :boolean
#  request_host                :string(255)
#  sales_order_enabled         :boolean          default(TRUE), not null
#  security_filing_enabled     :boolean
#  send_test_files_to_instance :string(255)      default("vfi-test")
#  shipment_enabled            :boolean          default(TRUE), not null
#  stats_api_key               :string(255)
#  suppress_email              :boolean
#  suppress_ftp                :boolean
#  system_code                 :string(255)
#  system_message              :text
#  target_version              :string(255)
#  trade_lane_enabled          :boolean
#  updated_at                  :datetime         not null
#  uuid                        :string(255)
#  variant_enabled             :boolean
#  vendor_management_enabled   :boolean
#  vfi_invoice_enabled         :boolean
#

require 'uuidtools'
require "open_chain/git"
require 'open_chain/database_utils'

class MasterSetup < ActiveRecord::Base
  attr_accessible :broker_invoice_enabled, :classification_enabled, 
    :custom_features, :customs_statements_enabled, :delivery_enabled, 
    :drawback_enabled, :entry_enabled, :friendly_name, :ftp_polling_active, 
    :invoices_enabled, :last_delayed_job_error_sent, :logo_image, 
    :migration_host, :order_enabled, :project_enabled, :request_host, 
    :sales_order_enabled, :security_filing_enabled, 
    :send_test_files_to_instance, :shipment_enabled, :stats_api_key, 
    :suppress_email, :suppress_ftp, :system_code, :system_message, 
    :target_version, :trade_lane_enabled, :uuid, :variant_enabled, 
    :vendor_management_enabled, :vfi_invoice_enabled
  
  cattr_accessor :current

  CACHE_KEY = "MasterSetup:setup"

  after_update :update_cache
  after_find :update_cache

  # Returns true if Rails.env indicates production
  def self.production_env?
    rails_env.production?
  end

  # Returns true if Rails.env indicates test
  def self.test_env?
    rails_env.test?
  end

  # Returns true if Rails.env indicates development
  def self.development_env?
    rails_env.development?
  end

  # Simple mockable means for accessing rails secrets.
  def self.secrets
    Rails.application.secrets
  end

  # Simple mockable means for accessing rails config
  def self.rails_config
    Rails.application.config
  end

  # Simple mockable means for accessing specific rails config keys
  def self.rails_config_key key
    config.send(key.to_s)
  end

  # This method exists as a straight forward way to mock out 
  # the rails environment setting for test cases where functionality
  # may rely on which Rails.env it's running in.  You code can 
  # call MasterSetup.rails_env (or see the simple abstraction methods above)
  # and then you can easily set an expectation
  # on MasterSetup.rails_env to change the environment without affecting
  # the actual rails environment for the rest of unit test ecosystem.
  def self.rails_env
    Rails.env
  end
  
  def self.current_repository_version
    # Allow fudging the branch name as a tag name on dev machines, but not production.
    # Production should ALWAYS be running against a tag.
    OpenChain::Git.current_tag_name allow_branch_name: !production_env?
  end

  # We want to make sure the version # never updates.  The version the config file stated
  # when this code was loaded is always the version # we care to relay.  This is especially
  # important during an upgrade when the version number on disk my not exactly match what's
  # code is currently running.
  CURRENT_VERSION ||= current_repository_version

  def self.current_code_version
    CURRENT_VERSION
  end

  #get the master setup for this instance, first trying the cache, then trying the DB, then creating and returning a new one
  def self.get use_in_memory_version=true
    m = (use_in_memory_version ? MasterSetup.current : nil)

    if m.nil?
      begin
        m = CACHE.get CACHE_KEY unless m
      rescue
      end

      if m.nil? || !m.is_a?(MasterSetup)
        # The `after_find :update_cache` above will actually handle setting the cache in this case, so 
        # we don't have to do it again here.
        m = MasterSetup.first
      end
    end

    if m.nil? && !MasterSetup.test_env?
      m = init_base_setup
      # If there's no actual master setup table in existence, then nil is returned.  This would only ever happen
      # in initializers that run as a new system is being deployed.  For any of those initializers, they need to be
      # be aware that get MIGHT return nil and handle accordingly.  No "real" code outside of initializers should ever
      # need to handle a nil return value.
      return nil if m.nil?
      CACHE.set CACHE_KEY, m
    end

    m
  end

  def self.get_migration_lock host: nil
    h = hostname(host)
    begin
      found_host = nil
      ms = MasterSetup.first
      Lock.with_lock_retry(ms) do
        if ms.migration_host.nil?
          ms.update_column(:migration_host, h)
        end
        found_host = ms.migration_host
      end

      return found_host==h
    ensure
      MasterSetup.first #makes sure the after_find callback is called to update the cache
    end
  end

  def self.need_upgrade?
    ms = MasterSetup.get(false)
    !ms.target_version.blank? && current_code_version.strip!=ms.target_version.strip
  end

  def self.hostname hostname = nil
    hostname.blank? ? Rails.application.config.hostname : hostname
  end

  def self.release_migration_lock host: nil, force_release: false
    h = hostname(host)
    begin
      ms = MasterSetup.first
      Lock.with_lock_retry(ms) do
        # Don't clobber the migration host if it's someone else's, unless specifically told to
        ms.update_column(:migration_host, nil) if force_release || ms.migration_host == h
      end
    ensure
      MasterSetup.first #makes sure the after_find callback is called to update the cache
    end
  end

  def self.master_setup_initialized?
    @@initialized ||= begin
      ActiveRecord::Base.connection.table_exists?("master_setups") && !MasterSetup.first.nil?
    end
  end

  def self.init_base_setup company_name: "My Company", sys_admin_email: "support@vandegriftinc.com", init_script: false, host_name: nil, system_code: nil
    return nil unless ActiveRecord::Base.connection.table_exists?("master_setups")

    m = MasterSetup.first
    return m unless m.nil?

    if !MasterSetup.test_env?
      raise "You must run the script/init_base_setup.rb script" unless init_script

      ActiveRecord::Base.transaction do
        m = MasterSetup.create!(uuid: UUIDTools::UUID.timestamp_create.to_s, system_code: system_code, request_host: host_name, target_version: OpenChain::Git.current_tag_name(allow_branch_name: MasterSetup.development_env?))
        # If there's no users, create a user and company (.all is used here is make sure there's no weird default scope applied)
        if User.all.first.nil?
          c = Company.first_or_create!(name:company_name, master:true)
          if c.users.empty?
            u = c.users.build(username: "sysadmin", email: sys_admin_email, first_name: "System", last_name: "Administrator")
            u.sys_admin = true
            u.admin = true
            # Any old random password works here, this is simply to get around a validation in user.  The invite email below
            # actually changes the password to a temp one before emailing it to a user.
            u.password = Digest::SHA256.hexdigest(Time.zone.now.to_s)
            u.save!
            if production_env? || development_env?
              User.send_invite_emails u.id
            end
          end
        end
      end
    else
      # Just create a blank master setup in test env, don't create! one because that'll throw off test cases ability to create
      # their own internally in the db for test usage.
      m = MasterSetup.new
    end
    m
  end

  def self.init_test_setup
    return unless Rails.env.test?
    MasterSetup.first_or_create! :uuid => UUIDTools::UUID.timestamp_create.to_s
  end

  def self.ftp_enabled?
    # Never enable ftp for development / test environments
    if production_env?
      !MasterSetup.get.suppress_ftp?
    else
      false
    end
  end

  def self.email_enabled?
    # Never enable ftp for development / test environments
    if production_env?
      !MasterSetup.get.suppress_email?
    else
      false
    end
  end

  # Returns the real, absolute path to the rails root for this instance.
  # This is mostly here to provide an easily mockable shim method.
  def self.instance_directory
    Rails.root.realpath
  end

  # checks to see if the given custom feature is in the custom features list
  def custom_feature? feature
    custom_features_list.map {|l| l.upcase}.include? feature.to_s.upcase
  end

  # get the custom features enabled for this system as an array
  def custom_features_list
    return [] if self.custom_features.blank?
    features = self.custom_features.split($/).to_a
    features.collect {|f| f.strip}

  end

  # set the custom features enabled for this system by passing an array or a string
  def custom_features_list= data
    d = data
    if data.respond_to? 'join'
      d = data.join($/)
    elsif data.respond_to? "gsub"
      d = data.gsub("\r\n",$/).gsub("\r",$/).gsub("\n",$/)
    end
    self.custom_features = d
  end

  def update_cache
    CACHE.set CACHE_KEY, self
  end

  def self.clear_cache
    CACHE.set CACHE_KEY, nil
  end

  # Returns the database host from the config file.  If machine_name_only is specified, only returns the
  # first address segment in the URL (.ie machine.segment.domain.com -> machine)
  def self.database_host machine_name_only: false
    host = OpenChain::DatabaseUtils.primary_database_configuration[:host].to_s

    trim_to = -1
    if machine_name_only
      trim_to = host.index(".")
      if trim_to 
        trim_to -= 1
      else
        trim_to = -1
      end
    end

    host[0..trim_to]
  end

  def self.database_name
    OpenChain::DatabaseUtils.primary_database_configuration[:database].to_s
  end

  def production?
    self.custom_feature?('Production')
  end

  def self.instance_identifier
    @@root ||= begin
      # System code may be blank on an initial instance deployment, so fall back to the rails root for that,
      # on a follow up start the system code should be set and it will get used
      code = MasterSetup.get.system_code
      code.blank? ? Rails.root.basename : code
    end
    @@root
  end

  def self.config_true?(settings_key) 
    result = vfitrack_config[settings_key].to_s == "true"

    if block_given?
      yield if result
    end

    result
  end

  def self.config_value(settings_key, default: nil, yield_if_equals: nil)
    result = vfitrack_config[settings_key]
    return_val = result.nil? ? default : result

    if block_given?
      # If the yield_if_equals option is used only yield if the value actually equals the give value
      yield return_val if !return_val.nil? && (yield_if_equals.nil? || return_val == yield_if_equals)
    end

    return_val
  end

  def self.vfitrack_config
    rails_config.vfitrack
  end
  private_class_method :vfitrack_config


  def self.upgrades_allowed?
    if self.config_true?(:prevent_upgrades)
      return false
    elsif self.get.custom_feature?("Prevent Upgrades") 
      return false
    else
      return true
    end
  end
end
