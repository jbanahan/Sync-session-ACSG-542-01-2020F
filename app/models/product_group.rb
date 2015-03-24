class ProductGroup < ActiveRecord::Base

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
