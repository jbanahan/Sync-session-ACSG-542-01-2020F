# Methods shared amongst parsers feeding data into VFI Track entry tables.  Much of this code formerly resided in
# KewillEntry Parser.
module OpenChain; module CustomHandler; module EntryParserSupport

  def process_special_tariffs entry
    return unless entry.import_date

    # relation Entry#commercial_invoice_tariffs empty until entry is saved
    tariffs = entry.commercial_invoices.map{ |ci| ci.commercial_invoice_lines.map{ |cil| cil.commercial_invoice_tariffs}}.flatten
    special_tariffs = SpecialTariffCrossReference.where(special_hts_number: tariffs.map(&:hts_code).uniq)
                          .where(import_country_iso: "US")
                          .where("effective_date_start <= ?", entry.import_date)
                          .where("effective_date_end >= ? OR effective_date_end IS NULL", entry.import_date)
                          .map{ |st| st.special_hts_number }

    tariffs.each{ |t| t.special_tariff = true if special_tariffs.include? t.hts_code }

    entry.special_tariff = true if tariffs.find{ |t| t.special_tariff }
  end

  def calculate_duty_rates invoice_tariff, invoice_line, effective_date, customs_value
    calculate_primary_duty_rate invoice_tariff, customs_value
    calculate_classification_related_rates invoice_tariff, invoice_line, effective_date
  end

  def calculate_primary_duty_rate invoice_tariff, customs_value
    invoice_tariff.duty_rate = customs_value > 0 ? ((invoice_tariff.duty_amount.presence || 0) / customs_value).round(3) : 0
    nil
  end

  def calculate_classification_related_rates invoice_tariff, invoice_line, effective_date
    classification = find_tariff_classification(effective_date, invoice_tariff.hts_code)
    if classification
      rate_data = classification.extract_tariff_rate_data(invoice_line.country_origin_code, invoice_tariff.spi_primary)
      invoice_tariff.advalorem_rate = rate_data[:advalorem_rate]
      invoice_tariff.specific_rate = rate_data[:specific_rate]
      invoice_tariff.specific_rate_uom = rate_data[:specific_rate_uom]
      invoice_tariff.additional_rate = rate_data[:additional_rate]
      invoice_tariff.additional_rate_uom = rate_data[:additional_rate_uom]
    end
    nil
  end

  def tariff_effective_date entry
    d = entry.first_it_date
    if d.nil?
      d = entry.import_date
    end
    d
  end

  def multi_value_separator
    "\n "
  end

  private
    def find_tariff_classification effective_date, tariff_no
      return nil if effective_date.nil? || tariff_no.blank?

      @tariffs ||= Hash.new do |h, k|
        h[k] = TariffClassification.find_effective_tariff us, k[0], k[1]
      end

      @tariffs[[effective_date, tariff_no]]
    end

    def us
      @us ||= Country.where(iso_code: "US").first
      @us
    end

end; end; end