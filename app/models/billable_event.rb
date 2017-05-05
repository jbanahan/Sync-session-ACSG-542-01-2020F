class BillableEvent < ActiveRecord::Base
  belongs_to :billable_eventable, :polymorphic => true
  belongs_to :entity_snapshot
  has_many :invoiced_events
  has_many :non_invoiced_events

  validates :billable_eventable, presence: true
  validates :entity_snapshot, presence: true
end