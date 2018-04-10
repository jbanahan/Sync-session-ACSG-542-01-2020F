# == Schema Information
#
# Table name: product_rate_overrides
#
#  created_at             :datetime         not null
#  destination_country_id :integer
#  end_date               :date
#  id                     :integer          not null, primary key
#  notes                  :text
#  origin_country_id      :integer
#  product_id             :integer
#  rate                   :decimal(8, 4)
#  start_date             :date
#  updated_at             :datetime         not null
#
# Indexes
#
#  countries  (origin_country_id,destination_country_id)
#  prod_id    (product_id)
#  start_end  (start_date,end_date)
#

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
