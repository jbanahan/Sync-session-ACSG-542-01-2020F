# == Schema Information
#
# Table name: broker_invoices
#
#  bill_to_address_1    :string(255)
#  bill_to_address_2    :string(255)
#  bill_to_city         :string(255)
#  bill_to_country_id   :integer
#  bill_to_name         :string(255)
#  bill_to_state        :string(255)
#  bill_to_zip          :string(255)
#  broker_reference     :string(255)
#  created_at           :datetime         not null
#  currency             :string(255)
#  customer_number      :string(255)
#  entry_id             :integer
#  fiscal_date          :date
#  fiscal_month         :integer
#  fiscal_year          :integer
#  id                   :integer          not null, primary key
#  invoice_date         :date
#  invoice_number       :string(255)
#  invoice_total        :decimal(11, 2)
#  last_file_bucket     :string(255)
#  last_file_path       :string(255)
#  locked               :boolean
#  source_system        :string(255)
#  suffix               :string(255)
#  summary_statement_id :integer
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_broker_invoices_on_broker_reference_and_source_system  (broker_reference,source_system)
#  index_broker_invoices_on_customer_number                     (customer_number)
#  index_broker_invoices_on_entry_id                            (entry_id)
#  index_broker_invoices_on_invoice_date                        (invoice_date)
#  index_broker_invoices_on_invoice_number                      (invoice_number)
#  index_broker_invoices_on_summary_statement_id                (summary_statement_id)
#

class BrokerInvoice < ActiveRecord::Base
  include CoreObjectSupport
  include IntegrationParserSupport
  belongs_to :entry, touch: true, inverse_of: :broker_invoices
  belongs_to :bill_to_country, :class_name=>'Country'
  belongs_to :summary_statement
  has_many :broker_invoice_lines, :dependent => :destroy, :inverse_of=>:broker_invoice
  
  before_validation {self.currency = "USD" if self.currency.blank?}
  validates_uniqueness_of :invoice_number, {:scope => :source_system}

  accepts_nested_attributes_for :broker_invoice_lines, :allow_destroy=>true, :reject_if => lambda {|q|
    q[:charge_description].blank? || q[:charge_amount].blank?
  }
  
  #finalize the invoice by applying HST and saving
  def complete!
    hst_code = ChargeCode.find_or_create_by_code("HST",:description=>"HST (ON)",:apply_hst=>false) 
    hst_charge = nil
    self.broker_invoice_lines.each {|line| hst_charge = line if line.charge_code == hst_code.code}
    hst_amount = self.hst_amount
    if hst_amount == 0 && hst_charge
      hst_charge.destroy
    elsif hst_charge
      hst_charge.charge_amount = hst_amount
    elsif hst_amount != 0
      self.broker_invoice_lines.build(:charge_code=>hst_code.code,:charge_description=>hst_code.description,:charge_amount=>hst_amount)
    end
    self.invoice_total = self.broker_invoice_lines.inject(0) {|sum,line| sum + line.charge_amount}
    self.save!
  end
  #calculate HST by looking up all included charge codes and calculating HST amount at 13% fixed rate for Ontario
  def hst_amount
    self.broker_invoice_lines.each.inject(BigDecimal("0.00")) {|sum,line| sum + (line.hst_percent.blank? || line.charge_amount.blank? ? 0 : (line.hst_percent * line.charge_amount))}
  end

  def can_view? user
    self.class.can_view? user, self.entry
  end
  
  def can_edit? user
    !self.locked? && can_view?(user) && user.edit_broker_invoices?
  end

  def self.search_secure user, base_object
    Entry.search_secure user, base_object.includes(:entry)
  end

  def self.search_where user
    "entry_id in (select id from entries where #{Entry.search_where user})"
  end

  def self.can_view? user, entry
    user.view_broker_invoices? && (user.company.master? || (entry && ( entry.importer_id==user.company_id || user.company.linked_companies.include?(entry.importer))))
  end

  def total_billed_duty_amount
    return BigDecimal("0") if self.marked_for_destruction?

    self.broker_invoice_lines.map {|l| (!l.marked_for_destruction? && l.charge_amount && l.charge_code.to_s == "0001") ? l.charge_amount : 0 }.sum
  end
end
