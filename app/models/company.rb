# == Schema Information
#
# Table name: companies
#
#  agent                         :boolean
#  alliance_customer_number      :string(255)
#  broker                        :boolean
#  carrier                       :boolean
#  consignee                     :boolean
#  created_at                    :datetime         not null
#  customer                      :boolean
#  drawback                      :boolean
#  drawback_customer             :boolean          default(FALSE), not null
#  ecellerate_customer_number    :string(255)
#  enabled_booking_types         :string(255)
#  factory                       :boolean
#  fenix_customer_number         :string(255)
#  fiscal_reference              :string(255)
#  forwarder                     :boolean
#  id                            :integer          not null, primary key
#  importer                      :boolean
#  irs_number                    :string(255)
#  last_alliance_product_push_at :datetime
#  locked                        :boolean
#  master                        :boolean
#  mid                           :string(255)
#  name                          :string(255)
#  name_2                        :string(255)
#  selling_agent                 :boolean
#  show_business_rules           :boolean
#  slack_channel                 :string(255)
#  system_code                   :string(255)
#  ticketing_system_code         :string(255)
#  updated_at                    :datetime         not null
#  vendor                        :boolean
#
# Indexes
#
#  index_companies_on_agent                       (agent)
#  index_companies_on_alliance_customer_number    (alliance_customer_number)
#  index_companies_on_carrier                     (carrier)
#  index_companies_on_customer                    (customer)
#  index_companies_on_drawback                    (drawback)
#  index_companies_on_ecellerate_customer_number  (ecellerate_customer_number)
#  index_companies_on_factory                     (factory)
#  index_companies_on_fenix_customer_number       (fenix_customer_number)
#  index_companies_on_master                      (master)
#  index_companies_on_system_code                 (system_code)
#  index_companies_on_vendor                      (vendor)
#

class Company < ActiveRecord::Base
  include CoreObjectSupport

  attr_accessible :agent, :alliance_customer_number, :broker, :carrier,
                  :consignee, :customer, :drawback, :ecellerate_customer_number,
                  :enabled_booking_types, :factory, :fenix_customer_number,
                  :fiscal_reference, :forwarder, :importer, :irs_number,
                  :last_alliance_product_push_at, :locked, :master, :mid, :name, :name_2,
                  :selling_agent, :show_business_rules, :slack_channel, :system_code,
                  :ticketing_system_code, :vendor, :linked_companies, :addresses

  validates :name,  presence: true
  validate :master_lock
  validates :system_code, uniqueness: { if: -> { self.system_code.present? } }
  after_save :clear_customs_identifier

  has_many  :addresses, dependent: :destroy, autosave: true
  has_many  :divisions, dependent: :destroy
  has_many  :importer_products, class_name: 'Product', foreign_key: 'importer_id', inverse_of: :importer
  has_many  :importer_orders, class_name: 'Order', foreign_key: 'importer_id', dependent: :destroy, inverse_of: :importer
  has_many  :factory_orders, class_name: 'Order', foreign_key: 'factory_id', inverse_of: :factory
  has_many  :vendor_orders, class_name: "Order", foreign_key: "vendor_id", dependent: :destroy, inverse_of: :vendor
  has_many  :vendor_shipments, class_name: "Shipment", foreign_key: "vendor_id", dependent: :destroy, inverse_of: :vendor
  has_many  :carrier_shipments, class_name: "Shipment", foreign_key: "carrier_id", dependent: :destroy, inverse_of: :carrier
  has_many  :carrier_deliveries, class_name: "Delivery", foreign_key: "carrier_id", dependent: :destroy, inverse_of: :carrier
  has_many  :customer_sales_orders, class_name: "SalesOrder", foreign_key: "customer_id", dependent: :destroy, inverse_of: :customer
  has_many  :customer_deliveries, class_name: "Delivery", foreign_key: "customer_id", dependent: :destroy, inverse_of: :customer
  has_many  :users, -> { order(:first_name, :last_name, :username) }, dependent: :destroy, inverse_of: :company
  has_many  :orders, through: :divisions, dependent: :destroy
  has_many  :products, through: :divisions, dependent: :destroy
  has_many  :histories, dependent: :destroy
  has_many  :power_of_attorneys, dependent: :destroy
  has_many  :drawback_claims, foreign_key: "importer_id", inverse_of: :importer
  has_many  :charge_categories, dependent: :destroy
  has_many  :attachment_archives
  has_many  :attachment_archive_manifests, dependent: :destroy
  has_many  :surveys, dependent: :destroy
  has_many  :attachments, as: :attachable, dependent: :destroy # rubocop:disable Rails/InverseOf
  has_many  :plants, dependent: :destroy, inverse_of: :company
  has_many  :plant_variant_assignments, through: :plants
  has_many  :active_variants_as_vendor, -> { where(plant_variant_assignments: {disabled: [nil, 0]}) }, through: :plant_variant_assignments, source: :variant
  has_many  :all_variants_as_vendor, through: :plant_variant_assignments, source: :variant
  has_many  :summary_statements, foreign_key: :customer_id, inverse_of: :customer
  has_many  :product_vendor_assignments, dependent: :destroy, foreign_key: :vendor_id, inverse_of: :vendor
  has_many  :products_as_vendor, through: :product_vendor_assignments, source: :product
  has_many  :vfi_invoices, dependent: :destroy, foreign_key: "customer_id", inverse_of: :customer
  has_many  :fiscal_months
  has_many  :mailing_lists
  has_many  :system_identifiers, dependent: :destroy, inverse_of: :company
  has_many :calendars, dependent: :destroy, inverse_of: :company

  has_one :attachment_archive_setup, dependent: :destroy

  has_and_belongs_to_many :linked_companies, class_name: "Company", join_table: "linked_companies", foreign_key: 'parent_id', association_foreign_key: 'child_id' # rubocop:disable Rails/HasAndBelongsToMany Layout/LineLength
  has_and_belongs_to_many :parent_companies, class_name: "Company", join_table: "linked_companies", foreign_key: 'child_id', association_foreign_key: 'parent_id' # rubocop:disable Rails/HasAndBelongsToMany Layout/LineLength

  scope :carriers, -> { where(carrier: true) }
  scope :vendors, -> { where(vendor: true) }
  scope :customers, -> { where(customer: true) }
  scope :importers, -> { where(importer: true) }
  scope :consignees, -> { where(consignee: true) }
  scope :agents, -> { where(agent: true) }
  scope :brokers, -> { where(broker: true) }
  scope :by_name, -> { order("companies.name ASC") }
  scope :active_importers, -> { where("companies.id in (select importer_id from products where products.created_at > '2011') or companies.id in (select importer_id from entries where entries.file_logged_date > '2011')") } # rubocop:disable Layout/LineLength
  # find all companies that have attachment_archive_setups that include a start date
  scope :attachment_archive_enabled, -> { joins("LEFT OUTER JOIN attachment_archive_setups on companies.id = attachment_archive_setups.company_id").where("attachment_archive_setups.start_date is not null") } # rubocop:disable Layout/LineLength
  scope :has_slack_channel, -> { where('slack_channel IS NOT NULL AND slack_channel <> ""') }
  scope :with_customs_management_number, ->(code) { joins(:system_identifiers).where(system_identifiers: {system: "Customs Management", code: code}) }
  scope :with_cargowise_number, ->(code) { joins(:system_identifiers).where(system_identifiers: {system: "Cargowise", code: code}) }
  scope :with_fenix_number, ->(code) { joins(:system_identifiers).where(system_identifiers: {system: "Fenix", code: code}) }
  scope :with_identifier, ->(system, code) { joins(:system_identifiers).where(system_identifiers: {system: system, code: code}) }
  scope :for_system, ->(system) { joins(:system_identifiers).where(system_identifiers: {system: system})  }

  def linked_company? c
    (self == c) || self.linked_companies.include?(c)
  end

  def self.find_can_view(user)
    if user.company.master
      Company.where("1=1")
    else
      Company.where(id: user.company_id)
    end
  end

  def has_vfi_invoice? # rubocop:disable Naming/PredicateName
    ([self] + linked_companies).map { |co| co.vfi_invoices.count != 0 }.any?
  end

  def plants_user_can_view user
    self.plants.select {|plant| plant.can_view?(user)}
  end

  def self.search_secure user, base_search
    base_search.where(secure_search(user))
  end

  def self.secure_search user
    if user.company.master?
      '1=1'
    else
      "companies.id = #{user.company_id} OR (companies.id IN (SELECT linked_companies.child_id FROM linked_companies WHERE linked_companies.parent_id = #{user.company_id}))"
    end
  end

  def self.search_where user
    # Since we only do full searches on Vendors, scope it only to vendor companies.
    "companies.vendor = 1 AND " + secure_search(user)
  end

  # find all companies that aren't children of this one through the linked_companies relationship
  def unlinked_companies select: "distinct companies.*"
    c = Company.joins("LEFT OUTER JOIN (select child_id as cid FROM linked_companies where parent_id = #{self.id}) as lk on companies.id = lk.cid")
               .where("lk.cid IS NULL")
               .where("NOT companies.id = ?", self.id)
    c = c.select(select) if select.present?
    c
  end

  def can_edit?(user)
    return true if user.admin?
    return true if self.vendor? && user.edit_vendors?
    false
  end

  def can_view?(user)
    if user.company.master
      true
    else
      user.company == self || user.company.linked_company?(self)
    end
  end

  def can_view_as_vendor?(user)
    self.vendor &&
      user.view_vendors? && (
      user.company.master? || user.company == self || user.company.linked_company?(self)
    )
  end

  def can_attach?(user)
    return true if user.admin?
    return true if self.can_view_as_vendor?(user) && user.attach_vendors?
    false
  end

  def can_comment?(user)
    return true if user.admin?
    return true if self.can_view_as_vendor?(user) && user.comment_vendors?
    false
  end

  def self.not_locked
    Company.where("locked = ? OR locked is null", false)
  end

  def self.find_master
    Company.first_or_create(master: true, name: 'Master Company')
  end

  def visible_companies
    if self.master?
      Company.all
    else
      Company.where("companies.id = ? OR companies.master = ? OR companies.id IN (select child_id from linked_companies where parent_id = ?)", self.id, true, self.id)
    end
  end

  def visible_companies_with_users
    visible_companies.where('companies.id IN (SELECT DISTINCT company_id FROM users)')
  end

  def parent_system_code
    @parent_system_code ||= self.parent_companies.where("system_code IS NOT NULL").order(id: :asc).first&.system_code
  end

  # permissions
  def view_security_filings?
    master_setup.security_filing_enabled? && (self.master? || self.broker? || self.importer?)
  end

  def edit_security_filings?
    master_setup.security_filing_enabled? && (self.master? || self.broker?)
  end

  def comment_security_filings?
    view_security_filings?
  end

  def attach_security_filings?
    view_security_filings?
  end

  def view_drawback?
    master_setup.drawback_enabled?
  end

  def edit_drawback?
    master_setup.drawback_enabled?
  end

  def view_surveys?
    true
  end

  def edit_surveys?
    true
  end

  def view_commercial_invoices?
    master_setup.invoices_enabled?
  end
  alias view_customer_invoices? view_commercial_invoices?
  def edit_commercial_invoices?
    master_setup.invoices_enabled?
  end
  alias edit_customer_invoices? edit_commercial_invoices?
  def view_broker_invoices?
    master_setup.broker_invoice_enabled && (self.master? || self.importer?)
  end

  def edit_broker_invoices?
    master_setup.broker_invoice_enabled && self.master?
  end

  def view_vfi_invoices?
    master_setup.vfi_invoice_enabled && (self.master? || self.has_vfi_invoice?)
  end

  def edit_vfi_invoices?
    false
  end

  def view_entries?
    master_setup.entry_enabled && (self.master? || self.importer? || self.broker?)
  end

  def comment_entries?
    self.view_entries?
  end

  def attach_entries?
    self.view_entries?
  end

  def edit_entries?
    master_setup.entry_enabled && self.master?
  end

  def view_orders?
    master_setup.order_enabled && (self.master? || self.vendor? || self.importer? || self.agent?)
  end

  def add_orders?
    master_setup.order_enabled && self.master?
  end

  def edit_orders?
    master_setup.order_enabled && (self.master? || self.importer? || self.vendor? || self.agent?)
  end

  def delete_orders?
    master_setup.order_enabled && self.master?
  end

  def attach_orders?
    master_setup.order_enabled && (self.master? || self.vendor? || self.importer? || self.agent?)
  end

  def comment_orders?
    master_setup.order_enabled && (self.master? || self.vendor? || self.importer? || self.agent?)
  end

  def view_vendors?
    master_setup.vendor_management_enabled?
  end

  def view_products?
    true
  end

  def add_products?
    self.master? || self.importer?
  end

  def edit_products?
    self.master? || self.importer?
  end

  def create_products?
    add_products?
  end

  def delete_products?
    self.master?
  end

  def attach_products?
    view_products?
  end

  def comment_products?
    view_products?
  end

  def view_sales_orders?
    master_setup.sales_order_enabled && (self.master? || self.customer?)
  end

  def add_sales_orders?
    master_setup.sales_order_enabled && self.master?
  end

  def edit_sales_orders?
    master_setup.sales_order_enabled && self.master?
  end

  def delete_sales_orders?
    master_setup.sales_order_enabled && self.master?
  end

  def attach_sales_orders?
    master_setup.sales_order_enabled && (self.master? || self.customer?)
  end

  def comment_sales_orders?
    master_setup.sales_order_enabled && (self.master? || self.customer?)
  end

  def view_shipments?
    company_view_edit_shipments?
  end

  def add_shipments?
    company_view_edit_shipments?
  end

  def edit_shipments?
    company_view_edit_shipments?
  end

  def delete_shipments?
    master_setup.shipment_enabled? && self.master?
  end

  def comment_shipments?
    company_view_edit_shipments?
  end

  def attach_shipments?
    company_view_edit_shipments?
  end

  def view_deliveries?
    company_view_deliveries?
  end

  def add_deliveries?
    company_edit_deliveries?
  end

  def edit_deliveries?
    company_edit_deliveries?
  end

  def delete_deliveries?
    master_setup.delivery_enabled && self.master?
  end

  def comment_deliveries?
    company_view_deliveries?
  end

  def attach_deliveries?
    company_view_deliveries?
  end

  def add_classifications?
    master_setup.classification_enabled && edit_products?
  end

  def edit_classifications?
    add_classifications?
  end

  def add_variants?
    master_setup.variant_enabled && edit_products?
  end

  def edit_variants?
    add_variants?
  end

  def view_trade_lanes?
    self.master? && master_setup.trade_lane_enabled?
  end

  def edit_trade_lanes?
    self.master? && master_setup.trade_lane_enabled?
  end

  def attach_trade_lanes?
    self.master? && master_setup.trade_lane_enabled?
  end

  def comment_trade_lanes?
    self.master? && master_setup.trade_lane_enabled?
  end

  def view_trade_preference_programs?
    self.view_trade_lanes?
  end

  def edit_trade_preference_programs?
    self.edit_trade_lanes?
  end

  def attach_trade_preference_programs?
    self.attach_trade_lanes?
  end

  def comment_trade_preference_programs?
    self.comment_trade_lanes?
  end

  def view_statements?
    (self.master? || self.importer?) && master_setup.customs_statements_enabled?
  end

  def name_with_customer_number
    n = self.name
    identifier = self.customs_identifier
    n += " (#{identifier})" if identifier.present?
    n
  end

  def name_with_system_code
    n = self.name
    n += " (#{self.system_code})" if self.system_code.present?
    n
  end

  def enabled_booking_types_array
    # ['product','order','order_line','container']
    self.enabled_booking_types.to_s.split("\n").map(&:strip)
  end

  def self.booking_types
    {"Product" => 'product', "Order" => 'order', 'Order Line' => 'order_line', "Container" => 'container'}
  end

  def enabled_users
    users.enabled.all
  end

  def self.options_for_companies_with_system_identifier system, code_attribute: :code, value_attribute: [:companies, :id], order: :name, in_relation: nil, join_type: :inner
    c = Company
    if join_type == :outer
      if Array.wrap(system).length > 1
        c = c.joins(
          ActiveRecord::Base.sanitize_sql_array(["LEFT OUTER JOIN system_identifiers ON system_identifiers.company_id = companies.id AND system_identifiers.system IN (?)",
                                                 system])
        )
      else
        c = c.joins(
          ActiveRecord::Base.sanitize_sql_array(["LEFT OUTER JOIN system_identifiers ON system_identifiers.company_id = companies.id AND system_identifiers.system = ?",
                                                 system])
        )
      end
    else
      c = c.joins(:system_identifiers).where(system_identifiers: {system: system})
    end
    c = c.order(order)

    if in_relation
      c = c.where(id: in_relation)
    end

    # the pluck method calls unique on the values passed to it, which means if we get something like (:name, :code, :code)
    # the select statement executed only has name, code in it (.ie only 2 columns).  This is annoying AF, since we want all 3 columns.
    # Construct a string instead to specify the full set of actual values we always want returned
    pluck = ["name", code_attribute, value_attribute].map do |v|
      v = Array.wrap(v)
      table_name = nil
      column_name = nil
      if v.length == 1
        column_name = v[0]
      else
        table_name = v[0]
        column_name = v[1]
      end

      if table_name.blank?
        ActiveRecord::Base.connection.quote_column_name(column_name).to_s
      else
        "#{ActiveRecord::Base.connection.quote_table_name(table_name)}.#{ActiveRecord::Base.connection.quote_column_name(column_name)}"
      end
    end.join(", ")

    c.pluck(pluck).map do |r|
      label = r[0]
      label += " (#{r[1]})" if r[1].present?
      [label, r[2]]
    end
  end

  def kewill_customer_number
    @kewill_customer_number ||= SystemIdentifier.system_identifier_code(self, "Customs Management")
  end

  # This name would normally be fenix_customer_number, but since that's already an attribute
  # on the Company, I don't want to shadow it. Once the attribute is removed, we can alias
  # fenix_customer_number to this method so that this method aligns with the other 2 *_customer_number methods
  def fenix_customer_identifier
    @fenix_customer_identifier ||= SystemIdentifier.system_identifier_code(self, "Fenix")
  end

  def cargowise_customer_number
    @cargowise_customer_number ||= SystemIdentifier.system_identifier_code(self, "Cargowise")
  end

  def customs_identifier
    @customs_identifier ||= begin
      ids = ['Customs Management', 'Fenix', 'Cargowise']
      queries = []
      ids.each do |id|
        queries << ActiveRecord::Base.sanitize_sql_array(["SELECT code FROM system_identifiers WHERE company_id = ? AND system = ?", self.id, id])
      end

      ActiveRecord::Base.connection.execute(queries.join(" UNION DISTINCT ")).map {|r| r[0] }.first
    end
  end

  def clear_customs_identifier
    remove_instance_variable(:@customs_identifier) if instance_variable_defined?(:@customs_identifier)
  end

  def set_system_identifier system, code
    id = self.system_identifiers.find_by(system: system)
    return nil if id.nil? && code.blank?

    if code.blank?
      id&.destroy
      self.system_identifiers.reload
      nil
    else
      id = self.system_identifiers.build(system: system) if id.nil?
      id.code = code
      id.save!
      id
    end
  end

  # use alias .by_uid to appease rubocop
  def self.find_by_system_code system, code
    Company.joins(:system_identifiers).find_by(system_identifiers: {system: system, code: code})
  end

  singleton_class.send(:alias_method, :by_system_code, :find_by_system_code)

  def self.find_or_create_company! system, code, create_attributes, lock_name: nil
    lock_name = "Company-#{system}-#{code}" if lock_name.blank?

    base_query = SystemIdentifier.where(system: system, code: code)
    id = base_query.first
    if id.nil?
      Lock.acquire(lock_name) do
        id = base_query.first_or_create!
      end
    end

    company = id.company
    if company.nil?
      Lock.db_lock(id) do
        company = id.company
        # In the time we waited for the lock, company may have been added to db
        if company.nil?
          company = id.create_company! create_attributes
          id.save!
        end
      end
    end

    company
  end

  private

  def master_setup
    MasterSetup.get
  end

  def master_lock
    errors.add(:base, "Master company cannot be locked.") if self.master && self.locked
  end

  def company_view_deliveries?
    company_edit_deliveries? || (self.customer? && master_setup.delivery_enabled)
  end

  def company_edit_deliveries?
    master_setup.delivery_enabled && (self.master? || self.carrier?)
  end

  def company_view_edit_shipments?
    master_setup.shipment_enabled && (self.master? || self.vendor? || self.carrier? || self.agent? || self.importer? || self.forwarder?)
  end
end
