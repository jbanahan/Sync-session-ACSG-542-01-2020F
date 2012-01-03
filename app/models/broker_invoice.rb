class BrokerInvoice < ActiveRecord::Base
  include CoreObjectSupport
  belongs_to :entry
  belongs_to :bill_to_country, :class_name=>'Country'
  has_many :broker_invoice_lines, :dependent => :destroy

  def can_view? user
    user.view_broker_invoices? && (user.company.master? || (self.entry && self.entry.importer_id==user.company_id))
  end

  def self.search_secure user, base_object
    return user.company.master? ? base_object.where("1=1") : base_object.includes(:entry).where("entries.importer_id = ?", user.company_id)
  end
end
