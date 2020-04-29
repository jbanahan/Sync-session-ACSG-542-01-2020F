# == Schema Information
#
# Table name: instant_classification_result_records
#
#  created_at                       :datetime         not null
#  entity_snapshot_id               :integer
#  id                               :integer          not null, primary key
#  instant_classification_result_id :integer
#  product_id                       :integer
#  updated_at                       :datetime         not null
#
# Indexes
#
#  result_ids  (instant_classification_result_id)
#

class InstantClassificationResultRecord < ActiveRecord::Base
  attr_accessible :entity_snapshot_id, :instant_classification_result_id, :product_id

  belongs_to :instant_classification_result
  belongs_to :entity_snapshot
  belongs_to :product

  scope :where_changed, -> { where('entity_snapshot_id is not null') }

  # was the underlying product changed by this record
  def changed_product?
    return !entity_snapshot.blank?
  end
end
