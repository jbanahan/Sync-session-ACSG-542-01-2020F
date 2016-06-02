class SpiRate < ActiveRecord::Base
  belongs_to :country
  validates :country, presence: true
  validates :special_rate_key, presence: true
  validates :rate_text, presence: true
end
