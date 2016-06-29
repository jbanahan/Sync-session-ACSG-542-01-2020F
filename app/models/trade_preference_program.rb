class TradePreferenceProgram < ActiveRecord::Base
  include CoreObjectSupport
  belongs_to :origin_country, class_name: 'Country', inverse_of: :trade_lanes_as_origin
  belongs_to :destination_country, class_name: 'Country', inverse_of: :trade_lanes_as_destination

  has_many :product_trade_preference_programs, dependent: :destroy
  has_many :products, through: :product_trade_preference_programs
  has_many :tpp_hts_overrides, dependent: :destroy, inverse_of: :trade_preference_program
  has_many :surveys, inverse_of: :trade_preference_program

  validates :destination_country_id, presence: true
  validates :origin_country_id, presence: true
  validates :name, presence: true

  def trade_lane
    @lane ||= TradeLane.where(
      origin_country_id:self.origin_country_id,
      destination_country_id:self.destination_country_id
    ).first
    @lane
  end

  def long_name
    oc_iso = self.origin_country ? self.origin_country.iso_code : ''
    dc_iso = self.destination_country ? self.destination_country.iso_code : ''
    "#{oc_iso} > #{dc_iso}: #{self.name}"
  end

  def can_view? user
    ln = trade_lane
    return false unless ln
    return ln.can_view?(user)
  end

  def can_edit? user
    ln = trade_lane
    return false unless ln
    return ln.can_edit?(user)
  end

  def can_attach? user
    ln = trade_lane
    return false unless ln
    return ln.can_attach?(user)
  end

  def can_comment? user
    ln = trade_lane
    return false unless ln
    return ln.can_comment?(user)
  end

  def self.search_where u
    return u.view_trade_preference_programs? ? '1=1' : '1=0'
  end

  def self.search_secure user, base
    base.where search_where user
  end
end