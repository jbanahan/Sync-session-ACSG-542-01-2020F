require 'open_chain/custom_handler/lumber_liquidators/lumber_summary_invoice_support'
require 'open_chain/custom_handler/lumber_liquidators/lumber_costing_report'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberInvoiceReport
  include OpenChain::CustomHandler::LumberLiquidators::LumberSummaryInvoiceSupport

  def self.run_schedulable
    r = self.new
    invoices = r.find_invoices *start_end_dates

    r.generate_and_send_report invoices, ActiveSupport::TimeZone["America/New_York"].now.to_date
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
    # We can ONLY send invoices that were sent via the cost file sync between the start and end dates.
    invoices = BrokerInvoice.
      joins(BrokerInvoice.need_sync_join_clause('LL BILLING')).
      where(customer_number: "LUMBER", source_system: "Alliance").
      where("sync_records.id IS NULL OR sync_records.sent_at IS NULL").
      order("broker_invoices.invoice_date, broker_invoices.invoice_number").
      joins("INNER JOIN sync_records cost_sync ON cost_sync.trading_partner = '#{OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport.sync_code}'" + 
            " AND cost_sync.syncable_type = 'Entry' AND cost_sync.syncable_id = broker_invoices.entry_id AND cost_sync.sent_at >= '#{start_date.to_s(:db)}'" + 
            " AND cost_sync.sent_at < '#{end_date.to_s(:db)}'").
      all

    # Reject any invoices that have failing rules OR were not included on the costing file sent for the entry (lumber_costing_report.rb).  
    # There can be invoices issued AFTER the cost file, in that case, these will go to Lumber as invoices on the supplemental invoice feed
    # and should be ignored here.
    invoices.reject {|i| i.entry.any_failed_rules? || i.sync_records.find {|sr| sr.trading_partner == OpenChain::CustomHandler::LumberLiquidators::LumberCostingReport.sync_code}.nil? }
  end

  def generate_and_send_report invoices, invoice_date
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

        OpenMailer.send_simple_html("otwap@lumberliquidators.com", "Vandegrift, Inc. Billing for #{invoice_date.strftime "%b %d, %Y"}", "Attached is the Vandegrift weekly invoice file.", file).deliver!
      end
    end
  end

  def generate_report broker_invoices, invoice_date
    wb, sheet = XlsMaker.create_workbook_and_sheet "Summary", []
    generate_summary_invoice_page sheet, broker_invoices, invoice_date

    sheet = XlsMaker.create_sheet wb, "Details", ["VFI Invoice Number", "Invoice Date", "Invoice Total", "PO Number", "Container Number", "Ocean Freight", "Duty", "Fees", "PO Total"]
    
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

        po_container_values = [po, container, values[:zlf1], values[:zlf3], values[:zlf4], [values[:zlf1], values[:zlf3], values[:zlf4]].sum]

        row = rows > 0 ? (["", "", ""] + po_container_values) : (first_row + po_container_values)

        XlsMaker.add_body_row sheet, (row_number += 1), row, [], true
        XlsMaker.set_cell_formats sheet, row_number, [nil, nil, invoice_amount_format, nil, nil, line_amount_format, line_amount_format, line_amount_format, line_amount_format]

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
      totals = Hash.new do |h, k|
        h[k] = BigDecimal("0")
      end
      po_container_values = Hash.new do |h, k|
        h[k] = {entered_value: BigDecimal("0"), zlf3: BigDecimal("0")}
      end

      invoice.entry.commercial_invoice_lines.each do |line|
        key = "#{line.po_number}~#{line.container.try(:container_number)}"
        po_container_values[key][:entered_value] += line.total_entered_value
        po_container_values[key][:zlf3] += line.duty_plus_fees_add_cvd_amounts
      end

      total_invoiced_duty = po_container_values.values.map {|v| v[:zlf3] }.sum

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

        totals[bucket] += line.charge_amount
      end

      # Now prorate the amount from the buckets across the po/container values
      report_amounts = Hash.new do |h, k|
        h[k] = {zlf1: BigDecimal("0"), zlf3: BigDecimal("0"), zlf4: BigDecimal("0")}
      end

      totals.each_pair do |k, v|
        # If we have a zlf3 value (.ie Duty), then compare the duty amount from the actual commercial
        # invoice lines.  If the total values match, then use the actual line amounts instead of prorating
        # the duty amount across the containers.  By using the actual sums, we provide Lumber with a much more
        # accurate picture of the duty amounts.

        # Duty amounts may not match because duty may have been recalced and changed since the invoice we're
        # handling was cut.  In that case, all we really have to go on is the amount from the invoice, so our
        # only choice is to prorate the duty amount.
        if k == :zlf3 && v == total_invoiced_duty
          po_container_values.each_pair do |cont, values|
            report_amounts[cont][:zlf3] = values[:zlf3]
          end
        else
          prorations = prorate(po_container_values, v)

          prorations.each_pair do |cont, value|
            report_amounts[cont][k] += value
          end
        end
      end

      total = BigDecimal("0")
      report_amounts.each_pair do |k, v|
        total += v.values.sum
      end

      report_amounts[:total] = total

      # Dup the report_amount so we don't send back a hash w/ the defaul key-lookup in place
      report_amounts.dup
    end

    def prorate values, amount_to_prorate
      total_entered_value = values.values.map {|v| v[:entered_value] }.sum

      prorations = Hash.new do |h, k|
        h[k] = BigDecimal("0")
      end

      # If we're dealing w/ a negative number, just make it positive, and then we'll flip values back to negative before passing them back
      negative = amount_to_prorate.to_f < 0
      if negative
        amount_to_prorate = amount_to_prorate * -1.0
      end

      proration_left = amount_to_prorate
      values.each_pair do |k, value_hash|
        entered_value = value_hash[:entered_value]
        ideal_proration = ((total_entered_value.nonzero? ? (entered_value / total_entered_value) : 0) * amount_to_prorate).round(2, BigDecimal::ROUND_HALF_UP)

        if proration_left - ideal_proration > 0
          prorations[k] += ideal_proration
          proration_left -= ideal_proration
        else
          prorations[k] += proration_left
          proration_left = 0
        end
      end

      if proration_left > 0
        begin
          prorations.each_pair do |k, v|
            # Don't add leftover proration amounts into buckets that have no existing value, it basically means that 
            # there was no entered value on them so they shouldn't have any of the leftover amount dropped back into them.

            # Since we're only adding the proration amounts to lines with entered value, make sure that there's at least one
            # line with entered value (should ONLY ever happen in a testing scenario since I don't know how an entry could have
            # have a cotton fee without any lines with entered values), but it'll hang here if that does happen
            next if v.zero? && total_entered_value.nonzero?

            prorations[k] = (v + BigDecimal("0.01"))
            proration_left -= BigDecimal("0.01")

            break if proration_left <= 0
          end
        end while proration_left > 0
      end

      if negative
        prorations.each_pair do |k, v|
          prorations[k] = v * -1.0
        end
      end

      prorations
    end

end; end; end; end;