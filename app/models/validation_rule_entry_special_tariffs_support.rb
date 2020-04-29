module ValidationRuleEntrySpecialTariffsSupport
  extend ActiveSupport::Concern

  def special_tariffs entry, use_special_hts_number: false
    # We might want to consider some sort of LRU cache below so that every invocation of this
    # method doesn't have to do a full lookup of the special tariffs every time.
    countries = entry.split_newline_values(entry.origin_country_codes)

    # Allow only specific tariff types to be validated against
    special_tariff_types = nil
    # rule_attributes is defined in BusinessValidationRule...this module should only be included
    # on one of those.
    if rule_attributes["special_tariff_types"]
      special_tariff_types = rule_attributes["special_tariff_types"]
    end

    # Convert this to eastern time zone and then a date since the tariff hash effective dates work off actual dates, not datetimes
    # Eastern Timezone, since that's the timezone Customs Management works off
    reference_date = entry.release_date.try(:in_time_zone, "America/New_York").try(:to_date)

    SpecialTariffCrossReference.find_special_tariff_hash entry.import_country.try(:iso_code), false, reference_date: reference_date, country_origin_iso: countries, special_tariff_types: special_tariff_types, use_special_number_as_key: use_special_hts_number
  end

  def tariff_exceptions
    @hts_exceptions ||= begin
      TariffNumberSet.new Array.wrap(rule_attributes["skip_hts_numbers"])
    end
  end

  def tariff_inclusions
    @hts_inclusions ||= begin
      TariffNumberSet.new Array.wrap(rule_attributes["only_hts_numbers"])
    end
  end
end