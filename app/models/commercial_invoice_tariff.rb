class CommercialInvoiceTariff < ActiveRecord::Base
  include CustomFieldSupport

  belongs_to :commercial_invoice_line, :touch=>true, :inverse_of=>:commercial_invoice_tariffs
  has_one :entry, through: :commercial_invoice_line
  has_many :commercial_invoice_lacey_components, dependent: :destroy, autosave: true
end
