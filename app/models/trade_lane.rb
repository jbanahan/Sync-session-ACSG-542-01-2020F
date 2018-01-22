# == Schema Information
#
# Table name: trade_lanes
#
#  id                           :integer          not null, primary key
#  origin_country_id            :integer
#  destination_country_id       :integer
#  tariff_adjustment_percentage :decimal(5, 2)
#  notes                        :text
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#
# Indexes
#
#  index_trade_lanes_on_destination_country_id  (destination_country_id)
#  index_trade_lanes_on_origin_country_id       (origin_country_id)
#  unique_country_pair                          (origin_country_id,destination_country_id) UNIQUE
#

class TradeLane < ActiveRecord::Base
  include CoreObjectSupport

  belongs_to :origin_country, class_name: 'Country', inverse_of: :trade_lanes_as_origin
  belongs_to :destination_country, class_name: 'Country', inverse_of: :trade_lanes_as_destination

  validates_uniqueness_of :destination_country_id, scope: :origin_country_id
  validates :destination_country_id, presence: true
  validates :origin_country_id, presence: true

  def trade_preference_programs
    TradePreferenceProgram.where(origin_country_id:self.origin_country_id,destination_country_id:self.destination_country_id)
  end

  def can_view? u
    return u.view_trade_lanes?
  end

  def can_edit? u
    return u.edit_trade_lanes?
  end

  def can_attach? u
    return u.attach_trade_lanes?
  end

  def can_comment? u
    return u.comment_trade_lanes?
  end

  def self.search_where u
    return u.view_trade_lanes? ? '1=1' : '1=0'
  end

  def self.search_secure user, base
    base.where search_where user
  end

end
