class CommercialInvoiceTariff < ActiveRecord::Base
  belongs_to :commercial_invoice_line, :touch=>true, :inverse_of=>:commercial_invoice_tariffs
  include CustomFieldSupport
end
