# == Schema Information
#
# Table name: variants
#
#  created_at         :datetime         not null
#  id                 :integer          not null, primary key
#  product_id         :integer          not null
#  updated_at         :datetime         not null
#  variant_identifier :string(255)
#
# Indexes
#
#  index_variants_on_product_id  (product_id)
#

class Variant < ActiveRecord::Base
  include CustomFieldSupport
  include ShallowMerger
  include TouchesParentsChangedAt
  include UpdateModelFieldsSupport

  attr_accessible :product_id, :product, :variant_identifier

  belongs_to :product, inverse_of: :variants
  has_many :plant_variant_assignments, inverse_of: :variant, dependent: :destroy

  validates :product, :presence => true
  validates :variant_identifier, uniqueness: { scope: :product_id,
    message: "must have a unique id within the product" }

  dont_shallow_merge :Variant, ['id','created_at','updated_at']

  def can_view? user
    return false unless self.product
    return self.product.can_view?(user)
  end

  def can_edit? user
    return user.edit_variants? && self.can_view?(user)
  end
end
