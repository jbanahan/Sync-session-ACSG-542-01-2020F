# == Schema Information
#
# Table name: non_invoiced_events
#
#  billable_event_id      :integer          not null
#  created_at             :datetime         not null
#  id                     :integer          not null, primary key
#  invoice_generator_name :string(255)
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_non_invoiced_events_on_billable_event_id  (billable_event_id)
#

class NonInvoicedEvent < ActiveRecord::Base
  belongs_to :billable_event

  validates :billable_event, presence: true
end
