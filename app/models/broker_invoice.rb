class BrokerInvoice < ActiveRecord::Base
  belongs_to :entry
  belongs_to :bill_to_country, :class=>'Country'
  has_many :broker_invoices
end
