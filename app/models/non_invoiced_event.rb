class NonInvoicedEvent < ActiveRecord::Base
  belongs_to :billable_event

  validates :billable_event, presence: true
end