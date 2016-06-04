class TppHtsOverride < ActiveRecord::Base
  include CoreObjectSupport
  belongs_to :trade_preference_program, inverse_of: :tpp_hts_overrides

  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :hts_code, presence: true

  def self.active for_date=Date.current
    where(active_where_clause(for_date))
  end

  # this is separate from the active method so the ModelField implementation can access it directly
  # when building search queries
  def self.active_where_clause for_date=Date.current
    "tpp_hts_overrides.start_date <= ':effective_date' AND tpp_hts_overrides.end_date >= ':effective_date'".gsub(/:effective_date/,for_date.to_formatted_s(:db))
  end

  def active? for_date=Date.current
    return false unless self.start_date && self.end_date
    return for_date >= self.start_date && for_date <= self.end_date
  end

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
