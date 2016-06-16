require 'open_chain/active_dates_support'
class ProductRateOverride < ActiveRecord::Base
  include CoreObjectSupport
  include OpenChain::ActiveDatesSupport
  belongs_to :product, touch: true, inverse_of: :product_rate_overrides
  belongs_to :origin_country, class_name: 'Country', inverse_of: :trade_lanes_as_origin
  belongs_to :destination_country, class_name: 'Country', inverse_of: :trade_lanes_as_destination
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :product_id, presence: true

  def can_view? user
    return false unless self.product
    return self.product.can_view?(user)
  end

  def can_edit? user
    return false unless self.product
    return self.product.can_classify?(user)
  end

  def self.search_secure user, base_object
    base_object.where(search_where(user))
  end

  def self.search_where user
    "product_rate_overrides.product_id IN (SELECT products.id FROM products WHERE #{Product.search_where(user)})"
  end
end
