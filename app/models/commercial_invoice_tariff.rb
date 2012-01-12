class CommercialInvoiceTariff < ActiveRecord::Base
  belongs_to :commercial_invoice_line
end
