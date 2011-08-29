class InstantClassificationResultRecord < ActiveRecord::Base
  belongs_to :instant_classification_result
  belongs_to :entity_snapshot
  belongs_to :product

  #was the underlying product changed by this record
  def changed_product?
    return !entity_snapshot.blank?
  end
end
