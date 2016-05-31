class VfiInvoiceLine < ActiveRecord::Base
  belongs_to :vfi_invoice, :inverse_of => :vfi_invoice_lines, :touch => true
  has_many :invoiced_events

  validates :vfi_invoice_id, :presence => true
  validates :charge_description, :presence => true
  validates :charge_amount, :presence => true
end
