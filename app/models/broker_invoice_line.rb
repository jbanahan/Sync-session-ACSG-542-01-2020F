class BrokerInvoiceLine < ActiveRecord::Base
  include CustomFieldSupport
  belongs_to :broker_invoice, :touch=>true
  has_one :entry, :through=>:broker_invoice

  validates_presence_of :charge_description
  validates_presence_of :charge_amount

end
