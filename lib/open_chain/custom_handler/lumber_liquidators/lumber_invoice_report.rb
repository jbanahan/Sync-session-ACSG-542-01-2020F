require 'open_chain/custom_handler/lumber_liquidators/lumber_summary_invoice_support'
require 'open_chain/custom_handler/lumber_liquidators/lumber_costing_report'
require 'open_chain/custom_handler/lumber_liquidators/lumber_supplemental_invoice_sender'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberInvoiceReport
  include OpenChain::CustomHandler::LumberLiquidators::LumberSummaryInvoiceSupport

  def self.run_schedulable settings = {}
    raise "Report must have an email_to attribute configured." unless Array.wrap(settings['email_to']).length > 0
    r = self.new
    invoices = r.find_invoices(*start_end_dates)

    r.generate_and_send_report invoices, ActiveSupport::TimeZone["America/New_York"].now.to_date, email_to: settings['email_to']
  end

  def self.start_end_dates time_zone = "America/New_York"
    # Calculate start/end dates using the run date as the previous workweek (Monday - Sunday)
    now = Time.zone.now.in_time_zone(time_zone)
    start_date = (now - 7.days)
    # Subtract days until we're at a Monday
    start_date -= 1.day while start_date.wday != 1
    # Basically, we're formatting these dates so the represent the Monday @ Midnight and the following Monday @ midnight, relying on the
    # where clause being >= && <.  We don't want any results showing that are actually on the following Monday based on Eastern timezone
    [start_date.beginning_of_day.in_time_zone("UTC"), (start_date + 7.days).beginning_of_day.in_time_zone("UTC")]
  end

  def find_invoices start_date, end_date
    # We can ONLY send invoices that were sent via the cost file sync OR the supplement invoice feed between the start and end dates.

    # Find all the invoices that were on a cost file feed this week.
    base_query = BrokerInvoice.joins(BrokerInvoice.need_sync_join_clause('LL BILLING'))
                              .where(customer_number: "LUMBER", source_system: "Alliance")
                              .where("sync_records.id IS NULL OR sync_records.sent_at IS NULL")

    cost_file_invoices = base_query.joins(ActiveRecord::Base.sanitize_sql_array(["INNER JOIN sync_records cost_sync ON cost_sync.trading_partner = ?" \
                            " AND cost_sync.syncable_type = 'BrokerInvoice' AND cost_sync.syncable_id = broker_invoices.id AND cost_sync.sent_at >= ?" \
                            " AND cost_sync.sent_at < ?",
                            OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport.sync_code, start_date.to_s(:db), end_date.to_s(:db)])).to_a

    # Find all invoices that were on a supplemental invoice this past week
    supplemental_invoices = base_query.joins(ActiveRecord::Base.sanitize_sql_array(["INNER JOIN sync_records supp_sync ON supp_sync.trading_partner = ?" \
                                " AND supp_sync.syncable_type = 'BrokerInvoice' AND supp_sync.syncable_id = broker_invoices.id AND supp_sync.sent_at >= ?" \
                                " AND supp_sync.sent_at < ?",
                                OpenChain::CustomHandler::LumberLiquidators::LumberSupplementalInvoiceSender.sync_code, start_date.to_s(:db), end_date.to_s(:db)])).to_a

    # reject any invoices that have failed business rules
    invoices = (cost_file_invoices + supplemental_invoices).reject {|i| i.entry.any_failed_rules? }

    invoices.sort do |a, b|
      order = a.invoice_date <=> b.invoice_date
      if order == 0
        order = a.invoice_number <=> b.invoice_number
      end

      order
    end
  end

  def generate_and_send_report invoices, invoice_date, email_to: nil
    workbook = generate_report invoices, invoice_date
    Tempfile.open(["LL_Billing_Report", ".xls"]) do |file|
      Attachment.add_original_filename_method file, "VFI Weekly Invoice #{invoice_date.strftime("%Y-%m-%d")}.xls"
      workbook.write file
      file.flush
      file.rewind

      ActiveRecord::Base.transaction do
        invoices.each do |invoice|
          sr = invoice.sync_records.where(trading_partner: "LL BILLING").first_or_initialize
          sr.sent_at = Time.zone.now
          sr.confirmed_at = (Time.zone.now + 1.minute)
          sr.save!
        end

        OpenMailer.send_simple_html(email_to, "Vandegrift, Inc. Billing for #{invoice_date.strftime "%b %d, %Y"}",
                                    "Attached is the Vandegrift weekly invoice file.", file, bcc: "payments@vandegriftinc.com").deliver_now
      end
    end
  end

  def generate_report broker_invoices, invoice_date
    wb, sheet = XlsMaker.create_workbook_and_sheet "Summary", []
    generate_summary_invoice_page sheet, broker_invoices, invoice_date

    sheet = XlsMaker.create_sheet wb, "Details", ["VFI Invoice Number", "Invoice Date", "Invoice Total", "PO Number", "Container Number",
                                                  "Ocean Freight", "Duty", "Additional Duty", "ADD/CVD", "Fees", "PO Total"]

    bold_format = XlsMaker.create_format "Bolded", weight: :bold
    invoice_amount_format = XlsMaker.create_format "Invoice Amount", number_format: "[$$-409]#,##0.00;[RED]-[$$-409]#,##0.00"
    invoice_total_format = XlsMaker.create_format "Invoice Total", weight: :bold, number_format: "[$$-409]#,##0.00;[RED]-[$$-409]#,##0.00"
    line_amount_format = XlsMaker.create_format "Invoice Line Amount", number_format: "#,##0.00;[RED]-#,##0.00"

    row_number = 0
    grand_total = BigDecimal("0")
    broker_invoices.each do |inv|
      amounts = invoice_amounts inv
      total = amounts.delete :total
      grand_total += total

      invoice_cell = inv.entry ? XlsMaker.create_link_cell(inv.entry.excel_url, inv.invoice_number.to_s) : inv.invoice_number
      first_row = [invoice_cell, inv.invoice_date, total]

      rows = 0
      amounts.each_pair do |po_cont, values|
        po, container = po_cont.split "~"

        totalled_values = [values[:zlf1], values[:zlf3_standard], values[:zlf3_additional], values[:zlf3_add_cvd], values[:zlf4]]
        po_container_values = [po, container] + totalled_values + [totalled_values.sum]

        row = rows > 0 ? (["", "", ""] + po_container_values) : (first_row + po_container_values)

        XlsMaker.add_body_row sheet, (row_number += 1), row, [], true
        XlsMaker.set_cell_formats sheet, row_number, [nil, nil, invoice_amount_format, nil, nil] + Array.new(6, line_amount_format)

        rows += 1
      end
    end

    XlsMaker.add_body_row sheet, (row_number += 2), ["GRAND TOTAL", "", grand_total]
    XlsMaker.set_cell_formats sheet, row_number, [bold_format, nil, invoice_total_format]

    XlsMaker.set_column_widths sheet, [20, 15, 15, 20, 20, 15, 15, 15, 15]

    wb
  end

  private

    def invoice_amounts invoice
      # The report is broken down by PO / Container, and then the charge values are prorated across these lines.
      # First, figure out the total charges per each bucket (ZLF1, ZLF3, ZLF4)
      bi_totals = Hash.new do |h, k|
        h[k] = BigDecimal("0")
      end
      po_container_values = Hash.new do |h, k|
        h[k] = {entered_value: BigDecimal("0"), zlf3_standard: BigDecimal("0"), zlf3_additional: BigDecimal("0"),
                zlf3_add_cvd: BigDecimal("0"), gross_weight: BigDecimal("0")}
      end

      invoice.entry.commercial_invoice_lines.each do |line|
        key = "#{line.po_number}~#{line.container.try(:container_number)}"
        po_container_values[key][:entered_value] += line.total_entered_value

        additional_duty = line.total_supplemental_tariff(:duty_amount)
        po_container_values[key][:zlf3_additional] += additional_duty
        po_container_values[key][:zlf3_standard] += (line.total_fees + (line.total_duty - additional_duty))
        po_container_values[key][:zlf3_add_cvd] += [line.add_duty_amount, line.cvd_duty_amount].compact.sum

        po_container_values[key][:gross_weight] += line.gross_weight
      end

      ci_duty_totals = Hash.new { |h, k| h[k] = BigDecimal("0")}

      po_container_values.each_value do |v|
        ci_duty_totals[:zlf3_standard] += v[:zlf3_standard]
        ci_duty_totals[:zlf3_additional] += v[:zlf3_additional]
        ci_duty_totals[:zlf3_add_cvd] += v[:zlf3_add_cvd]
      end

      total_ci_duty = ci_duty_totals.values.sum

      # find what fraction of zlf3 each type represents
      ci_duty_perc = [:zlf3_standard, :zlf3_additional, :zlf3_add_cvd].map do |type|
        [type, (ci_duty_totals[type] / total_ci_duty)]
      end.to_h

      invoice.broker_invoice_lines.each do |line|
        next unless line.charge_amount

        bucket = case line.charge_code
                 when "0001"
                   :zlf3
                 when "0004"
                   :zlf1
                 else
                   :zlf4
                 end

        bi_totals[bucket] += line.charge_amount
      end

      # Since broker invoices lump all zlf3 together, split them back out based on ratio from commercial invoice
      total_bi_zlf3 = bi_totals.delete :zlf3
      bi_totals[:zlf3_standard] = (total_bi_zlf3 * ci_duty_perc[:zlf3_standard]).round(2)
      bi_totals[:zlf3_additional] = (total_bi_zlf3 * ci_duty_perc[:zlf3_additional]).round(2)
      bi_totals[:zlf3_add_cvd] = (total_bi_zlf3 * ci_duty_perc[:zlf3_add_cvd]).round(2)

      # If the split left extra pennies, distribute them across the zlf3 types
      total_bi_zlf3_after_split = [bi_totals[:zlf3_standard], bi_totals[:zlf3_additional], bi_totals[:zlf3_add_cvd]].sum
      if total_bi_zlf3 != total_bi_zlf3_after_split
        min, max = [total_bi_zlf3, total_bi_zlf3_after_split].minmax
        pennies = ((max - min) * 100).round
        [:zlf3_standard, :zlf3_additional, :zlf3_add_cvd].cycle.take(pennies).each do |zlf3_type|
          bi_totals[zlf3_type] += (total_bi_zlf3.positive? ? 0.01 : -0.01)
        end
      end

      # Now prorate the amount from the buckets across the po/container values
      report_amounts = Hash.new do |h, k|
        h[k] = {zlf1: BigDecimal("0"), zlf3_standard: BigDecimal("0"), zlf3_additional: BigDecimal("0"),
                zlf3_add_cvd: BigDecimal("0"), zlf4: BigDecimal("0")}
      end

      invoices_match = total_bi_zlf3 == total_ci_duty
      bi_totals.each_pair do |k, v|
        # If we have a zlf3 value (.ie Duty), then compare the duty amount from the actual commercial
        # invoice lines.  If the total values match, then use the actual line amounts instead of prorating
        # the duty amount across the containers.  By using the actual sums, we provide Lumber with a much more
        # accurate picture of the duty amounts.

        # Duty amounts may not match because duty may have been recalced and changed since the invoice we're
        # handling was cut.  In that case, all we really have to go on is the amount from the invoice, so our
        # only choice is to prorate the duty amount.
        if invoices_match && k.to_s =~ /zlf3/
          po_container_values.each_pair do |cont, values|
            report_amounts[cont][k] = values[k]
          end
        else
          prorations = prorate(po_container_values, v, k == :zlf1)

          prorations.each_pair do |cont, value|
            report_amounts[cont][k] += value
          end
        end
      end

      total = BigDecimal("0")
      report_amounts.each_value do |v|
        total += v.values.sum
      end

      report_amounts[:total] = total

      # Dup the report_amount so we don't send back a hash w/ the defaul key-lookup in place
      report_amounts.dup
    end

    # TODO could probably use LumberCostFileCalculationsSupport here (though it would take some rework)
    def prorate values, amount_to_prorate, gross_weight_proration
      total_entered_value = values.values.map {|v| v[:entered_value] }.sum

      prorations = Hash.new do |h, k|
        h[k] = BigDecimal("0")
      end

      # If we're dealing w/ a negative number, just make it positive, and then we'll flip values back to negative before passing them back
      negative = amount_to_prorate.to_f < 0
      if negative
        amount_to_prorate *= -1.0
      end

      proration_left = amount_to_prorate
      values.each_pair do |k, value_hash|
        if gross_weight_proration
          # For gross weight-based proration, we're not really prorating at all.  The amount is divided up
          # evenly among the containers.  Each item in the values hash represents a unique container.
          # We might need to deal with pennies in the end if the charge amount is not evenly divisible by
          # the number of containers.
          ideal_proration = (amount_to_prorate / values.length).round(2, BigDecimal::ROUND_HALF_UP)
        else
          ideal_proration = ((total_entered_value.nonzero? ? (value_hash[:entered_value] / total_entered_value) : 0) * amount_to_prorate).round(2, BigDecimal::ROUND_HALF_UP)
        end

        if proration_left - ideal_proration > 0
          prorations[k] += ideal_proration
          proration_left -= ideal_proration
        else
          prorations[k] += proration_left
          proration_left = 0
        end
      end

      if proration_left > 0 && total_entered_value.nonzero?
        # This counter exists to catch extremely-unlikely-in-real-use situations where none of the lines have
        # a value set in them (could happen if no gross weights at tariff level, potentially).
        iteration_count = 0
        begin
          prorations.each_pair do |k, v|
            iteration_count += 1

            # Don't add leftover proration amounts into buckets that have no existing value, it basically means that
            # there was no entered value on them so they shouldn't have any of the leftover amount dropped back into them.
            next if v.zero?

            prorations[k] = (v + BigDecimal("0.01"))
            proration_left -= BigDecimal("0.01")

            break if proration_left <= 0
          end
        end while proration_left > 0 && iteration_count < 1000
      end

      if negative
        prorations.each_pair do |k, v|
          prorations[k] = v * -1.0
        end
      end

      prorations
    end

end; end; end; end
