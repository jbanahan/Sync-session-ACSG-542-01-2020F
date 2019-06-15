# == Schema Information
#
# Table name: spi_rates
#
#  country_id       :integer
#  created_at       :datetime         not null
#  id               :integer          not null, primary key
#  program_code     :string(255)
#  rate             :decimal(8, 4)
#  rate_text        :string(255)
#  special_rate_key :string(255)
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_spi_rates_on_country_id    (country_id)
#  index_spi_rates_on_program_code  (program_code)
#  srk_ici_pc                       (special_rate_key,country_id,program_code)
#

class SpiRate < ActiveRecord::Base
  attr_accessible :country_id, :program_code, :rate, :rate_text, :special_rate_key
  
  belongs_to :country
  validates :country, presence: true
  validates :special_rate_key, presence: true
  validates :rate_text, presence: true
end
