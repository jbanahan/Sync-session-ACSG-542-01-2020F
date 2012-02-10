class CommercialInvoiceTariff < ActiveRecord::Base
  belongs_to :commercial_invoice_line
  include CustomFieldSupport
end
