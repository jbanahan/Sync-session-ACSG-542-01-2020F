# == Schema Information
#
# Table name: tariff_classification_rates
#
#  created_at                :datetime         not null
#  id                        :integer          not null, primary key
#  rate_additional           :decimal(14, 8)
#  rate_advalorem            :decimal(14, 8)
#  rate_specific             :decimal(14, 8)
#  special_program_indicator :string(255)
#  tariff_classification_id  :integer
#  updated_at                :datetime         not null
#
# Indexes
#
#  idx_tariff_classification_rates_on_tariff_id_spi  (tariff_classification_id,special_program_indicator)
#

class TariffClassificationRate < ActiveRecord::Base
  belongs_to :tariff_classification, inverse_of: :tariff_classification_rates
end
