# -*- SkipSchemaAnnotations

require 'open_chain/report/report_helper'

class CustomReportEntryTariffBreakdown < CustomReport
  include OpenChain::Report::ReportHelper

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
    distribute_reads do
      execute_report run_by, row_limit
    end
  end

  private

    def execute_report run_by, row_limit = nil
      entries = Entry.search_secure run_by, Entry.group("entries.id")
      self.search_criterions.each {|sc| entries = sc.apply(entries)}
      row_limit = SearchSetup.max_results(run_by) if row_limit.blank?
      entries = entries.limit(row_limit > 1000 ? 1000 : row_limit)
      entries = entries.order(:file_logged_date)

      # This might look weird but in order to eager load the invoices / tariffs we can't add the includes on the search query (some
      # activerecord weirdness happens with the criterions that are added above that results in bad joins).
      # Therefore, we're running the query and then "piping" the ids into a plain active record where clause.
      entry_ids = entries.pluck("entries.id")
      entries = Entry.where(id: entry_ids).includes(commercial_invoices: {commercial_invoice_lines: :commercial_invoice_tariffs})

      # Report is meant to have one row per invoice line, with each line containing rolled up content for all HTS
      # numbers that may be connected to that line.  Unfortunately, since we won't know the max number of HTS numbers
      # involved until we've analyzed all the invoice lines, and the column positioning depends on the max number
      # of HTS numbers, we can't actually build the report output on the first pass through the data.
      max_hts_count = get_max_standard_hts_count entry_ids

      # Make the headers.  These will vary based on the number of HTS groups involved.  If there's more than 1 group,
      # we have to dupe a block of columns for each and add prefixes to them, like "HTS 1", "HTS 2" and so forth.
      headers = build_headers max_hts_count
      row_cursor = -1
      write_headers (row_cursor += 1), headers, run_by

      # We're going to work across groups of 25 entries to try and limit to some degree the number of queries run, but also to
      # keep memory useage at a minimum as well.
      entry_ids.each_slice(25) do |ids|
        entries = Entry.where(id: ids).includes(commercial_invoices: {commercial_invoice_lines: :commercial_invoice_tariffs}).order(:file_logged_date)
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
        end

        return if row_limit && row_cursor >= row_limit # rubocop:disable Lint/NonLocalExitFromIterator
      end
      write_no_data(row_cursor += 1) if row_cursor == 0
      nil
    end

    def get_max_standard_hts_count entry_ids
      # We're going to employ a query to determine the max number of standard HTS codes that are utilized over the
      # full range of entries that are on the report, this should be much faster and less memory intensive than
      # loading all the entries into memory that will appear on the report and parsing through them to count the tariffs utilized
      query = <<~QRY
        SELECT e.id, i.id, l.id, count(t.id)
        FROM entries e
        INNER JOIN commercial_invoices i ON e.id = i.entry_id
        INNER JOIN commercial_invoice_lines l ON l.commercial_invoice_id = i.id
        INNER JOIN commercial_invoice_tariffs t ON t.commercial_invoice_line_id = l.id
        WHERE e.id IN (?)
        AND t.hts_code NOT LIKE '9902%' AND t.hts_code NOT LIKE '9903%'
        GROUP BY e.id, i.id, l.id
        HAVING count(t.id) > 1
        ORDER BY count(t.id) DESC
        LIMIT 1
      QRY
      max_length = 0
      execute_query(ActiveRecord::Base.sanitize_sql_array([query, entry_ids])) do |results|
        max_length = results.first.try(:[], 3).to_i
      end
      max_length > 0 ? max_length : 1
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
      (1..hts_group_count).each do |i|
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
        savings = (non_nil_big_decimal(est_underlying_classification_duty) - non_nil_big_decimal(duty_mtb))
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
        tariff = OfficialTariff.find_by(country_id: country_us.id, hts_code: k)
        h[k] = OfficialTariff.numeric_rate_value(tariff.try(:common_rate), express_as_decimal: true)
      end

      @rates[hts]
    end

    def country_us
      @country_us ||= Country.find_by(iso_code: 'US')
      raise "US country record not found." unless @country_us
      @country_us
    end

    def non_nil_big_decimal bd
      bd || BigDecimal(0)
    end
end
