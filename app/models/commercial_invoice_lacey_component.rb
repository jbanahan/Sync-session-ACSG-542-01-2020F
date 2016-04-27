class CommercialInvoiceLaceyComponent < ActiveRecord::Base
  belongs_to :commercial_invoice_tariff, inverse_of: :commercial_invoice_lacey_components
end