class CommercialInvoiceLine < ActiveRecord::Base
  belongs_to :commercial_invoice
  include CustomFieldSupport
end
