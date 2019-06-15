# == Schema Information
#
# Table name: tpp_hts_overrides
#
#  created_at                  :datetime         not null
#  end_date                    :date
#  hts_code                    :string(255)
#  id                          :integer          not null, primary key
#  note                        :text
#  rate                        :decimal(8, 4)
#  start_date                  :date
#  trade_preference_program_id :integer
#  updated_at                  :datetime         not null
#
# Indexes
#
#  active_dates                         (start_date,end_date)
#  index_tpp_hts_overrides_on_hts_code  (hts_code)
#  tpp_id                               (trade_preference_program_id)
#

require 'open_chain/active_dates_support'
class TppHtsOverride < ActiveRecord::Base
  include CoreObjectSupport
  include OpenChain::ActiveDatesSupport

  attr_accessible :end_date, :hts_code, :note, :rate, :start_date, :trade_preference_program_id
  
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
