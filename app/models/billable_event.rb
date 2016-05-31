class BillableEvent < ActiveRecord::Base
  belongs_to :eventable, :polymorphic => true
  belongs_to :entity_snapshot
  has_many :invoiced_events

  validates :eventable, presence: true
  validates :entity_snapshot, presence: true
end