class ValidationRuleCanadaGpt < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  GPT_COUNTRIES ||= Set.new [
    'AF', 'AI', 'AO', 'AM', 'BD', 'BZ', 'BJ', 'BT', 'BO', 'IO', 'BF', 'BI', 'KH', 'CM', 'CV', 'CF', 'TD', 'CX', 'CC', 'KM', 'CG', 'CD',
    'CK', 'CI', 'DJ', 'EG', 'SV', 'ER', 'ET', 'FK', 'FJ', 'GM', 'GE', 'GH', 'GT', 'GN', 'GW', 'GY', 'HT', 'HN', 'IQ', 'KE', 'KI', 'LA',
    'LS', 'LR', 'MG', 'MW', 'ML', 'MH', 'MR', 'FM', 'MD', 'MN', 'MS', 'MA', 'MZ', 'NR', 'NP', 'NI', 'NE', 'NG', 'NU', 'NF', 'PK', 'PG', 
    'PY', 'PH', 'PN', 'RW', 'WS', 'SH', 'ST', 'SN', 'SL', 'SB', 'SO', 'LK', 'SD', 'SZ', 'SY', 'TJ', 'TZ', 'TL', 'TG', 'TK', 'TO', 'TM', 
    'TV', 'UG', 'UA', 'UZ', 'VU', 'VN', 'BG', 'YE', 'ZM', 'ZW'
  ]

  def run_child_validation invoice_line
    message = nil

    if GPT_COUNTRIES.include? invoice_line.country_origin_code.try(:upcase)
      invoice_line.commercial_invoice_tariffs.each do |tariff|
        next if tariff.hts_code.blank? || tariff.spi_primary == "9"

        if hts_qualifies_for_gpt? tariff.hts_code
          stop_validation
          message = "Tariff Treatment should be set to 9 when HTS qualifies for special GPT rates.  Country: #{invoice_line.country_origin_code} HTS: #{tariff.hts_code}"
          break
        end
      end
    end
  
    message
  end

  private 
    def hts_qualifies_for_gpt? hts_code
      @tariff_map ||= Hash.new do |hash, key|
        ot = OfficialTariff.joins(:country).where(hts_code: hts_code, countries: {iso_code: "CA"}).first

        hash[key] = (ot && ot.special_rates =~ /[(\,]\s*GPT\s*[,)]{0,1}/i)
      end

      @tariff_map[hts_code]
    end
end