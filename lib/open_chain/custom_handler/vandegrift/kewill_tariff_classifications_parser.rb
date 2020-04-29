require 'open_chain/integration_client_parser'

# This class processes full tariff information about US tariffs.  This includes full rate breakdowns
# for each tariff.  The FULL set of rates are expected to be sent for every tariff number, not partials
# as any existing rates for the tariff number are removed and rebuilt from the data in the file.
#
module OpenChain; module CustomHandler; module Vandegrift; class KewillTariffClassificationsParser
  include OpenChain::IntegrationClientParser

  def self.parse_file file_contents, log, opts = {}
    self.new.parse_json JSON.parse(file_contents)
  end

  def parse_json json
    counter = 0
    json.each do |tariff|
      process_tariff_classification(us, tariff)
      counter += 1
    end
    inbound_file.add_info_message "Processed #{counter} tariff #{"update".pluralize(counter)}."
    nil
  end

  def process_tariff_classification country, t
    effective_date = parse_date(t["date_tariff_effective"])
    return if t["tariff_no"].blank? || effective_date.nil?

    last_exported_from_source = parse_datetime(t["extract_time"])
    tariff = TariffClassification.where(country_id: us.id, tariff_number: t["tariff_no"], effective_date_start: effective_date).first_or_create!
    Lock.db_lock(tariff) do
      if process_tariff?(tariff, last_exported_from_source)
        tariff.tariff_classification_rates.destroy_all
        tariff.last_exported_from_source = last_exported_from_source

        parse_tariff_data(tariff, t)
        Array.wrap(t["tariff_rates"]).each do |r|
          rate = tariff.tariff_classification_rates.build
          parse_tariff_rate_data(rate, r)
        end

        tariff.save!

        return tariff
      end
    end

    nil
  end

  private
    def parse_tariff_data tariff, json
      tariff.effective_date_end = parse_date(json["date_tariff_expiration"])
      tariff.number_of_reporting_units = json["no_of_rpt_units"]
      tariff.unit_of_measure_1 = json["uom_1"]
      tariff.unit_of_measure_2 = json["uom_2"]
      tariff.unit_of_measure_3 = json["uom_3"]
      tariff.duty_computation = json["duty_computation"]
      tariff.base_rate_indicator = json["base_rate_indicator"]
      tariff.tariff_description = json["tariff_desc"]
      tariff.countervailing_duty = parse_boolean(json["countervailing_duty_flag"])
      tariff.antidumping_duty = parse_boolean(json["antidumping_duty_flag"])
      tariff.blocked_record = parse_boolean(json["blocked_record"])

      nil
    end

    def parse_tariff_rate_data rate, json
      rate.special_program_indicator = json["country_code_column"]
      rate.rate_advalorem = parse_rate(json["rate_advalorem"])
      rate.rate_specific = parse_rate(json["rate_specific"])
      rate.rate_additional = parse_rate(json["rate_additional"])

      nil
    end

    def process_tariff? tariff, last_exported_from_source
      tariff.last_exported_from_source.nil? || tariff.last_exported_from_source <= last_exported_from_source
    end

    def parse_date time
      Date.strptime(time.to_s, "%Y%m%d") rescue nil
    end

    def parse_datetime data
      Time.zone.parse(data.to_s) rescue nil
    end

    def parse_boolean data
      ["Y", "1"].include? data.to_s[0]
    end

    def parse_rate data, decimal_places: 8
      # The rates from kewill can be up to 12 digits long, with 8 of those being for decimal places
      # The kicker is they don't zero pad anything either.
      data = data.to_s.rjust(12, '0')
      rate = BigDecimal(data.insert(data.length - decimal_places, ".")) rescue nil

      # If the rate is 9999.xxxx then it means, essentially, that the tariff rate shouldn't be used.  We're going to nil
      # these values out to show they're invalid.
      # It looks like most of the cases where this occurs in Kewill data are for expired trade treaties.  Not sure why
      # the ABI data from customs doesn't just remove these numbers, but they're still there.
      if rate.to_i == 9999
        rate = nil
      end

      rate
    end

    def us
      @us ||= Country.where(iso_code: "US").first
    end

end; end; end; end