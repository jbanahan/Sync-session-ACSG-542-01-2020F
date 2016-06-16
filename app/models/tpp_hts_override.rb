require 'open_chain/active_dates_support'
class TppHtsOverride < ActiveRecord::Base
  include CoreObjectSupport
  include OpenChain::ActiveDatesSupport
  belongs_to :trade_preference_program, inverse_of: :tpp_hts_overrides

  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :hts_code, presence: true

  def can_view? user
    return false unless self.trade_preference_program
    return self.trade_preference_program.can_view?(user)
  end

  def can_edit? user
    return false unless self.trade_preference_program
    return self.trade_preference_program.can_edit?(user)
  end

  def self.search_where user
    "tpp_hts_overrides.trade_preference_program_id IN (SELECT id FROM trade_preference_programs WHERE #{TradePreferenceProgram.search_where(user)})"
  end

  def self.search_secure user, base
    base.where search_where user
  end
end
