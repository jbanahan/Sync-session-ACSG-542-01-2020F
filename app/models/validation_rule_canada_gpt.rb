# == Schema Information
#
# Table name: business_validation_rules
#
#  business_validation_template_id :integer
#  created_at                      :datetime         not null
#  delete_pending                  :boolean
#  description                     :string(255)
#  disabled                        :boolean
#  fail_state                      :string(255)
#  group_id                        :integer
#  id                              :integer          not null, primary key
#  mailing_list_id                 :integer
#  message_pass                    :string(255)
#  message_review_fail             :string(255)
#  message_skipped                 :string(255)
#  name                            :string(255)
#  notification_recipients         :text
#  notification_type               :string(255)
#  rule_attributes_json            :text
#  subject_pass                    :string(255)
#  subject_review_fail             :string(255)
#  subject_skipped                 :string(255)
#  suppress_pass_notice            :boolean
#  suppress_review_fail_notice     :boolean
#  suppress_skipped_notice         :boolean
#  type                            :string(255)
#  updated_at                      :datetime         not null
#
# Indexes
#
#  template_id  (business_validation_template_id)
#

class ValidationRuleCanadaGpt < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  GPT_COUNTRIES ||= Set.new [
    'AF', 'AI', 'AO', 'AM', 'BD', 'BZ', 'BJ', 'BT', 'BO', 'IO', 'BF', 'BI', 'KH', 'CM', 'CV', 'CF', 'TD', 'CX', 'CC', 'KM', 'CG', 'CD',
    'CK', 'CI', 'DJ', 'EG', 'SV', 'ER', 'ET', 'FK', 'FJ', 'GM', 'GE', 'GH', 'GT', 'GN', 'GW', 'GY', 'HT', 'HN', 'IQ', 'KE', 'KI', 'LA',
    'LS', 'LR', 'MG', 'MW', 'ML', 'MH', 'MR', 'FM', 'MD', 'MN', 'MS', 'MA', 'MZ', 'NR', 'NP', 'NI', 'NE', 'NG', 'NU', 'NF', 'PK', 'PG', 
    'PY', 'PH', 'PN', 'RW', 'WS', 'SH', 'ST', 'SN', 'SL', 'SB', 'SO', 'LK', 'SD', 'SZ', 'SY', 'TJ', 'TZ', 'TL', 'TG', 'TK', 'TO', 'TM', 
    'TV', 'UG', 'UA', 'UZ', 'VU', 'VN', 'BG', 'YE', 'ZM', 'ZW',
    # All countries listed after this point have GPT expire 1/1/2015
    'DZ', 'AS', 'AG', 'AR', 'AZ', 'BS', 'BH', 'BB', 'BM', 'BA', 'BW', 'BR', 'KY', 'CL', 'CN', 'CO', 'CR', 'HR', 'CU', 'DM', 'DO', 'EC', 
    'CQ', 'PF', 'GA', 'GI', 'GD', 'DU', 'HK', 'IN', 'ID', 'IR', 'IL', 'JM', 'JO', 'KZ', 'KW', 'LB', 'MO', 'MK', 'MY', 'MV', 'MU', 'MX', 
    'NA', 'NC', 'OM', 'PW', 'PA', 'PE', 'QA', 'RU', 'KN', 'LC', 'VC', 'SC', 'SG', 'ZA', 'KR', 'ZA', 'SR', 'TH', 'TT', 'TN', 'TR', 'TC', 
    'AE', 'UY', 'VE', 'VI'
  ]

  def run_child_validation invoice_line
    message = nil

    if GPT_COUNTRIES.include? invoice_line.country_origin_code.try(:upcase)
      invoice_line.commercial_invoice_tariffs.each do |tariff|
        next if tariff.hts_code.blank? || tariff.spi_primary == "9"

        if hts_qualifies_for_gpt? tariff.hts_code
          stop_validation unless has_flag?("validate_all")
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
