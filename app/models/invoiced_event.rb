class InvoicedEvent < ActiveRecord::Base
  belongs_to :billable_event
  belongs_to :vfi_invoice_line

  validates :billable_event, presence: true
end