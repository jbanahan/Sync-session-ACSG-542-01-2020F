class CommercialInvoiceTariff < ActiveRecord::Base
  belongs_to :commercial_invoice_line, :touch=>true, :inverse_of=>:commercial_invoice_tariffs
  has_one :entry, through: :commercial_invoice_line
  include CustomFieldSupport
end
