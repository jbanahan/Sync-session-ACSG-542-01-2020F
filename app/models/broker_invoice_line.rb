class BrokerInvoiceLine < ActiveRecord::Base
  include CustomFieldSupport
  belongs_to :broker_invoice
end
