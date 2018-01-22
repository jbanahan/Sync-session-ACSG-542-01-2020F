# == Schema Information
#
# Table name: invoiced_events
#
#  id                     :integer          not null, primary key
#  billable_event_id      :integer          not null
#  vfi_invoice_line_id    :integer
#  invoice_generator_name :string(255)
#  charge_type            :string(255)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_invoiced_events_on_billable_event_id    (billable_event_id)
#  index_invoiced_events_on_vfi_invoice_line_id  (vfi_invoice_line_id)
#

class InvoicedEvent < ActiveRecord::Base
  belongs_to :billable_event
  belongs_to :vfi_invoice_line

  validates :billable_event, presence: true
end
