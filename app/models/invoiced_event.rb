# == Schema Information
#
# Table name: invoiced_events
#
#  billable_event_id      :integer          not null
#  charge_type            :string(255)
#  created_at             :datetime         not null
#  id                     :integer          not null, primary key
#  invoice_generator_name :string(255)
#  updated_at             :datetime         not null
#  vfi_invoice_line_id    :integer
#
# Indexes
#
#  index_invoiced_events_on_billable_event_id    (billable_event_id)
#  index_invoiced_events_on_vfi_invoice_line_id  (vfi_invoice_line_id)
#

class InvoicedEvent < ActiveRecord::Base
  attr_accessible :billable_event_id, :billable_event, :charge_type,
    :invoice_generator_name, :updated_at, :vfi_invoice_line_id, :vfi_invoice_line

  belongs_to :billable_event
  belongs_to :vfi_invoice_line

  validates :billable_event, presence: true
end
