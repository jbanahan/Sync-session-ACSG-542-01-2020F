# == Schema Information
#
# Table name: billable_events
#
#  billable_eventable_id   :integer          not null
#  billable_eventable_type :string(255)      not null
#  created_at              :datetime         not null
#  entity_snapshot_id      :integer          not null
#  event_type              :string(255)
#  id                      :integer          not null, primary key
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_billable_events_on_billable_eventable  (billable_eventable_type,billable_eventable_id)
#  index_billable_events_on_entity_snapshot_id  (entity_snapshot_id)
#

class BillableEvent < ActiveRecord::Base
  belongs_to :billable_eventable, :polymorphic => true
  belongs_to :entity_snapshot
  has_many :invoiced_events
  has_many :non_invoiced_events

  validates :billable_eventable, presence: true
  validates :entity_snapshot, presence: true
end
