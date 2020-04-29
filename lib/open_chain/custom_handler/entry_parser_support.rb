# Methods shared amongst parsers feeding data into VFI Track entry tables.  Much of this code formerly resided in
# KewillEntry Parser.
module OpenChain; module CustomHandler; module EntryParserSupport

  def process_special_tariffs entry
    return unless entry.import_date

    # relation Entry#commercial_invoice_tariffs empty until entry is saved
    tariffs = entry.commercial_invoices.map { |ci| ci.commercial_invoice_lines.map { |cil| cil.commercial_invoice_tariffs}}.flatten
    special_tariffs = SpecialTariffCrossReference.where(special_hts_number: tariffs.map(&:hts_code).uniq)
                          .where(import_country_iso: "US")
                          .where("effective_date_start <= ?", entry.import_date)
                          .where("effective_date_end >= ? OR effective_date_end IS NULL", entry.import_date)
                          .map { |st| st.special_hts_number }

    tariffs.each { |t| t.special_tariff = true if special_tariffs.include? t.hts_code }

    entry.special_tariff = true if tariffs.find { |t| t.special_tariff }
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

  # This class was extracted from KewillEntryParser.  Note that this means much of this code will throw
  # exceptions if used for entries where the import country is not the US.  Beware.
  class HoldReleaseSetter
    attr_accessor :entry, :updated_before_one_usg, :updated_after_one_usg

    def initialize ent
      @entry = ent
      @updated_before_one_usg = {}
      @updated_after_one_usg = {}
    end

    def set_any_hold_date date, attribute
      hold_date_attr, release_date_attr = entry.hold_attributes.find { |att| att[:hold] == attribute }.values_at(:hold, :release)
      # allow blank dates for testing
      if date.blank?
        entry[hold_date_attr] = date
        return
      end
      # any hold date earlier than or equal to One USG is treated as a correction (i.e., as if it had been received first)
      if entry.one_usg_date && entry.one_usg_date >= date
        entry[release_date_attr] = entry.one_usg_date unless entry[hold_date_attr].present?
        # secondary hold so blank the corresponding release date
      elsif entry[hold_date_attr].present?
        entry[release_date_attr] = nil
      end

      updated_before_one_usg.delete release_date_attr
      updated_after_one_usg.delete release_date_attr
      entry[hold_date_attr] = date
    end

    # Sets release date only if corresponding hold date already set; if it's One USG, assigns that date to release dates for all active holds
    def set_any_hold_release_date date, attribute
      if attribute == :one_usg_date
        set_one_usg_date date
      else
        hold_date_attr = entry.hold_attributes.find { |att| att[:release] == attribute }[:hold]
        if entry[hold_date_attr].present?
          entry[attribute] = date
          return if date.blank? # allow blank dates for testing
          # any release date earlier than One USG is treated as a correction (i.e., as if it had been received first)
          if entry.one_usg_date && entry.one_usg_date <= date
            updated_after_one_usg[attribute] = date
          else
            updated_before_one_usg[attribute] = date
          end
        end
      end
    end

    def set_on_hold
      entry.on_hold = entry.active_holds.present?
    end

    def set_summary_hold_date
      entry.hold_date = entry.populated_holds.map { |pair| pair[:hold][:value] }.min
    end

    # If entry isn't on hold: Sets hold_release to One USG if One USG exists and hasn't been overridden, to most recent hold
    # release since One USG was overridden, or to most recent hold release overall when One USG hasn't been set.
    def set_summary_hold_release_date
      set_on_hold
      if entry.on_hold?
        entry.hold_release_date = nil
      else
        dates = entry.one_usg_date ? updated_after_one_usg : updated_before_one_usg
        latest = dates.values.compact.max
        if entry.populated_holds.map { |pair| pair[:release][:value] }.compact.present?
          entry.hold_release_date = latest || entry.one_usg_date
        else
          entry.hold_release_date = nil
        end
      end
    end

    private
      def set_one_usg_date date
        entry.one_usg_date = date
        return if date.blank?  # allow blank dates for testing
        entry.active_holds.each do |h|
          release_date_attr = h[:release][:attribute]
          entry[release_date_attr] = date
        end
      end
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