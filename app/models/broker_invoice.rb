class BrokerInvoice < ActiveRecord::Base
  include CoreObjectSupport
  belongs_to :entry
  belongs_to :bill_to_country, :class_name=>'Country'
  has_many :broker_invoice_lines, :dependent => :destroy

  def can_view? user
    user.view_broker_invoices? && (user.company.master? || (self.entry && ( self.entry.importer_id==user.company_id || user.company.linked_companies.include?(self.entry.importer))))
  end

  def self.search_secure user, base_object
    Entry.search_secure user, base_object.includes(:entry)
  end
end
