class BrokerInvoice < ActiveRecord::Base
  include CoreObjectSupport
  belongs_to :entry
  belongs_to :bill_to_country, :class_name=>'Country'
  has_many :broker_invoice_lines, :dependent => :destroy, :inverse_of=>:broker_invoice
  
  before_validation {self.currency = "USD" if self.currency.blank?}
  validates_uniqueness_of :suffix, {:scope => :entry_id}

  accepts_nested_attributes_for :broker_invoice_lines, :allow_destroy=>true, :reject_if => lambda {|q|
    q[:charge_description].blank? || q[:charge_amount].blank?
  }
  def can_view? user
    user.view_broker_invoices? && (user.company.master? || (self.entry && ( self.entry.importer_id==user.company_id || user.company.linked_companies.include?(self.entry.importer))))
  end
  
  def can_edit? user
    !self.locked? && can_view?(user) && user.edit_broker_invoices?
  end

  def self.search_secure user, base_object
    Entry.search_secure user, base_object.includes(:entry)
  end
end
