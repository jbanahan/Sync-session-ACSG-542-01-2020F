class CommercialInvoiceLine < ActiveRecord::Base
  belongs_to :commercial_invoice
  has_many :commercial_invoice_tariffs
  include CustomFieldSupport
end
