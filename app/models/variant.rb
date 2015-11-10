class Variant < ActiveRecord::Base
  include CustomFieldSupport
  include ShallowMerger
  include TouchesParentsChangedAt
  include UpdateModelFieldsSupport
  
  belongs_to :product, inverse_of: :variants
  validates :product, :presence => true
  validates :variant_identifier, uniqueness: { scope: :product_id,
    message: "must have a unique id within the product" }

  dont_shallow_merge :Variant, ['id','created_at','updated_at']
end
