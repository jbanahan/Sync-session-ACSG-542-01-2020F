class BrokerInvoice < ActiveRecord::Base
  belongs_to :entry
  belongs_to :bill_to_country, :class_name=>'Country'
  has_many :broker_invoice_lines, :dependent => :destroy
end
