class CustomReportEntryTariffBreakdown < CustomReport
  def self.template_name
    "Entry Tariff Breakdown"
  end

  def self.description
    "Shows all Entry Tariff and Duty Rates assigned, including MTB and 301 Tariff information."
  end

  def self.column_fields_available user
    CoreModule::ENTRY.model_fields(user).values + CoreModule::COMMERCIAL_INVOICE.model_fields(user).values + CoreModule::COMMERCIAL_INVOICE_LINE.model_fields(user).values
  end

  def self.criterion_fields_available user
    CoreModule::ENTRY.model_fields(user).values
  end

  def self.can_view? user
    user.view_entries?
  end

  def run run_by, row_limit = nil
    entries = Entry.search_secure run_by, Entry.group("entries.id")
    self.search_criterions.each {|sc| entries = sc.apply(entries)}
    row_limit = SearchSetup.max_results(run_by) if row_limit.blank?
    entries = entries.limit(row_limit)

    # This might look weird but in order to eager load the invoices / tariffs we can't add the includes on the search query (some 
    # activerecord weirdness happens with the criterions that are added above that results in bad joins).
    # Therefore, we're running the query and then "piping" the ids into a plain active record where clause.
    entries = Entry.where(id: entries.pluck("entries.id")).includes(commercial_invoices: {commercial_invoice_lines: :commercial_invoice_tariffs})

    # Report is meant to have one row per invoice line, with each line containing rolled up content for all HTS
    # numbers that may be connected to that line.  Unfortunately, since we won't know the max number of HTS numbers
    # involved until we've analyzed all the invoice lines, and the column positioning depends on the max number
    # of HTS numbers, we can't actually build the report output on the first pass through the data.
    max_hts_count = get_max_standard_hts_count entries, row_limit

    # Make the headers.  These will vary based on the number of HTS groups involved.  If there's more than 1 group,
    # we have to dupe a block of columns for each and add prefixes to them, like "HTS 1", "HTS 2" and so forth.
    headers = build_headers max_hts_count
    row_cursor = -1
    write_headers (row_cursor += 1), headers, run_by

    # Write the report data.  This involves a hash we already put together of HTS values, combining all HTS values for
    # an invoice line into one report line.
    entries.each do |ent|
      ent.commercial_invoices.each do |inv|
        inv.commercial_invoice_lines.each do |inv_line|
        
          user_selected_cols = []
          self.search_columns.each do |col|
            mf = col.model_field
            if mf.core_module.klass == Entry
              user_selected_cols << mf.process_export(ent, run_by)
            elsif mf.core_module.klass == CommercialInvoice
              user_selected_cols << mf.process_export(inv, run_by)
            elsif mf.core_module.klass == CommercialInvoiceLine
              user_selected_cols << mf.process_export(inv_line, run_by)
            end
          end

          row_data = user_selected_cols + get_hts_row_content(inv_line, max_hts_count)
          write_row (row_cursor += 1), ent, row_data, run_by
        end
      end

      return if row_limit && row_cursor >= row_limit
    end

    write_no_data (row_cursor +=1) if row_cursor == 0
    nil
  end

  private
    def get_max_standard_hts_count entries, row_limit
      invoice_line_count = 0
      inv_line_to_hts_content_hash = {}
      max_length = 0
      entries.each do |ent|
        ent.commercial_invoices.each do |invoice|
          invoice.commercial_invoice_lines.each do |invoice_line|
            tariff_count = invoice_line.commercial_invoice_tariffs.reject { |t| special_tariff?(t.hts_code) }.length
            max_length = tariff_count if tariff_count > max_length
          end
        end
      end
      max_length
    end

    def special_tariff? hts_code
      ninety_nine_code_mtb?(hts_code) || ninety_nine_code_301?(hts_code)
    end

    def ninety_nine_code_mtb? hts_code
      hts_code.starts_with?("9902")
    end

    def ninety_nine_code_301? hts_code
      hts_code.starts_with?("9903")
    end

    def build_headers hts_group_count
      headers = self.search_columns
      for i in 1..hts_group_count
        # No need for HTS count prefix if there's only one group of HTS number fields involved in the report (e.g.
        # no invoice line had more than one standard tariff against it).
        prefix = hts_group_count > 1 ? "HTS #{i} " : ""
        headers += ["#{prefix}Underlying Classification", "#{prefix}Underlying Classification Rate",
                    "#{prefix}Underlying Classification Duty"]
      end
      headers += ["Est Underlying Classification Duty", "MTB Classification", "MTB Classification Rate",
                  "MTB Classification Duty", "301 Classification", "301 Classification Rate", "301 Classification Duty",
                  "Tariff Entered Value", "Total Duty Paid", "MTB Savings"]
      headers
    end

    def get_hts_row_content invoice_line, hts_group_count
      row_content = []
      total_duty = BigDecimal("0")
      total_entered_value = BigDecimal("0")

      tariff_mtb = nil
      tariff_301 = nil
      common_rates = []

      tariffs_added = 0

      invoice_line.commercial_invoice_tariffs.each do |t|
        # Typically the first tariff line carries the entered value.  All the rest have zero, but we can still sum all of them together just
        # in case something changes.
        total_entered_value += t.entered_value unless t.entered_value.nil?
        total_duty += t.duty_amount unless t.duty_amount.nil?

        if ninety_nine_code_mtb?(t.hts_code)
          tariff_mtb = t
        elsif ninety_nine_code_301?(t.hts_code)
          tariff_301 = t
        else
          common_rate = get_hts_common_rate(t.hts_code)
          common_rates << (common_rate.presence || BigDecimal("0"))

          row_content.push t.hts_code&.hts_format, common_rate, t.duty_amount
          tariffs_added += 1
        end
      end

      # Since we're exploding out the tariff data horizontally, some invoice lines won't have 2, 3, 4, etc lines..for those just push nil values
      (hts_group_count - tariffs_added).times { row_content.push nil, nil, nil }

      # Now we need to estimate the classification duty by taking the common rates we've seen so far, multiplying each rate by the total entered value, 
      # and then summing it all together.
      est_underlying_classification_duty = common_rates.map {|r| (total_entered_value * r).round(2) }.compact.sum

      row_content << est_underlying_classification_duty

      classification_mtb, rate_mtb, duty_mtb = tariff_mtb_data(tariff_mtb)
      row_content.push classification_mtb, rate_mtb, duty_mtb

      classification_301, rate_301, duty_301 = tariff_301_data(tariff_301)
      row_content.push classification_301, rate_301, duty_301
      row_content << total_entered_value
      row_content << total_duty

      if tariff_mtb
        savings = (non_nil_big_decimal(est_underlying_classification_duty) - non_nil_big_decimal(total_duty))
        row_content << (savings > 0 ? savings : BigDecimal("0"))
      else
        row_content << BigDecimal("0")
      end

      row_content
    end

    def tariff_mtb_data tariff_mtb_line
      [tariff_mtb_line&.hts_code&.hts_format, get_hts_common_rate(tariff_mtb_line&.hts_code), tariff_mtb_line&.duty_amount]
    end

    def tariff_301_data tariff_301_line
      [tariff_301_line&.hts_code&.hts_format, get_hts_common_rate(tariff_301_line&.hts_code), tariff_301_line&.duty_amount]
    end

    def get_hts_common_rate hts
      return nil if hts.blank?

      @rates ||= Hash.new do |h, k|
        tariff = OfficialTariff.where(country_id:country_us.id, hts_code:k).first
        h[k] = OfficialTariff.numeric_rate_value(tariff.try(:common_rate), express_as_decimal:true)
      end

      @rates[hts]
    end

    def country_us
      @country_us ||= Country.where(iso_code:'US').first
      raise "US country record not found." unless @country_us
      @country_us
    end

    def non_nil_big_decimal bd
      bd ? bd : BigDecimal(0)
    end
end
