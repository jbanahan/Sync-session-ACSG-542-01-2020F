# == Schema Information
#
# Table name: product_groups
#
#  created_at :datetime         not null
#  id         :integer          not null, primary key
#  name       :string(255)
#  updated_at :datetime         not null
#

class ProductGroup < ActiveRecord::Base
  attr_accessible :name

  has_many :plant_product_group_assignments, inverse_of: :product_group, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  before_destroy :validate_in_use

  #linked to another object?
  def in_use?
    return false
  end

  def validate_in_use
    if self.in_use?
      errors[:base] << "Cannot delete Product Group while in use."
      return false
    end
    return true
  end
  private :validate_in_use
end
