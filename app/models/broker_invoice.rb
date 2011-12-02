class BrokerInvoice < ActiveRecord::Base
  include CoreObjectSupport
  belongs_to :entry
  belongs_to :bill_to_country, :class_name=>'Country'
  has_many :broker_invoice_lines, :dependent => :destroy

  def can_view? user
    user.view_broker_invoices?
  end

  def self.search_secure user, base_object
    return base_object.where("1=1")
  end
end
