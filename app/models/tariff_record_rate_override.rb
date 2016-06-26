class TariffRecordRateOverride < ActiveRecord::Base
  include CoreObjectSupport
  belongs_to :product, inverse_of: :tariff_record_rate_overrides
  belongs_to :origin_country, class_name: 'Country', inverse_of: :tariff_record_rate_overrides_as_origin
  belongs_to :destination_country, class_name: 'Country', inverse_of: :tariff_record_rate_overrides_as_destination

  def can_view? user
    return false unless self.tariff_record
    return self.tariff_record.can_view?(user)
  end

  def can_edit? user
    return false unless self.tariff_record
    return self.tariff_record.can_edit?(user)
  end

  def self.search_secure user, base_object
    base_object.where(search_where(user))
  end

  def self.search_where user
    "tariff_record_rate_overrides.tariff_record_id IN (SELECT tariff_records.id from tariff_records WHERE #{TariffRecord.search_where(user)})"
  end
end
