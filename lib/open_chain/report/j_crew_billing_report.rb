require 'open_chain/report/report_helper'

module OpenChain; module Report; class JCrewBillingReport
  include ReportHelper

  def initialize opts = {}
    @opts = opts.with_indifferent_access
  end

  def self.permission? user
    (Rails.env=='development' || MasterSetup.get.system_code=='www-vfitrack-net') && user.company.master?
  end

  # run_by required by reporting interface
  def self.run_report run_by, opts = {}
    JCrewBillingReport.new(opts).run
  end

  def run
    start_date = @opts[:start_date].to_date
    end_date = @opts[:end_date].to_date

    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet :name => "#{start_date.strftime("%Y-%m-%d")} thru #{end_date.strftime("%Y-%m-%d")}"
    row_number = 0
    headers = ["Invoice #", "Invoice Date", "Entry #", "Direct Brokerage", "Direct Duty", "Retail Brokerage", "Retail Duty", "Factory Brokerage", "Factory Duty",
                "Factory Direct Brokerage", "Factory Direct Duty", "Madewell Direct Brokerage", "Madewell Direct Duty", "Madewell Retail Brokerage", "Madewell Retail Duty",
                "Retail T & E Brokerage", "Retail T & E Duty", "Madewell Factory Brokerage", "Madewell Factory Duty", "Total Brokerage", "Total Duty", "Errors"]    
    error_format = Spreadsheet::Format.new :pattern_fg_color => :yellow, :pattern => 1, :pattern_bg_color=>:xls_color_26
    error_with_date = Spreadsheet::Format.new :pattern_fg_color => :yellow, :pattern => 1, :pattern_bg_color=>:xls_color_26, :number_format=>'YYYY-MM-DD'
    column_widths = []

    XlsMaker.add_header_row sheet, row_number, headers, column_widths
    entries(start_date, end_date).each do |entry|
      invoice_data = sum_brokerage_amounts_for_entry entry, start_date, end_date
      next if invoice_data.blank?

      row_number += 1
      sheet.row(row_number).height = 21

      buckets = create_commercial_invoice_buckets entry, invoice_data[:previously_invoiced]
      prorate_by_po_counts(entry, invoice_data[:amount], buckets) if invoice_data[:amount] > 0

      errors_message = nil
      unknown_bucket = buckets[:unknown]
      if unknown_bucket && (unknown_bucket[:duty_amount] > 0 || unknown_bucket[:line_amount] > 0)
        # We're including notes to the recipient of the report telling them that because the PO # was not 
        # able to be identified as belonging to one of the specified J Crew divisions that they must manually 
        # allocate amounts.  We'll give them all the invalid #'s and the unallocated amounts to make it a little easier on them.
        po_numbers = unknown_bucket[:invalid_po].to_a
        errors_message = "Invalid #{"PO #".pluralize(po_numbers.length)}: #{po_numbers.join(", ")}." 
        errors_message << " Unallocated Charges: #{unknown_bucket[:line_amount]}." if unknown_bucket[:line_amount] && unknown_bucket[:line_amount] > 0
        errors_message << " Unallocated Duty: #{unknown_bucket[:duty_amount]}." if unknown_bucket[:duty_amount] && unknown_bucket[:duty_amount] > 0
      end

      row = []
      row << invoice_data[:invoice_number]
      row << invoice_data[:invoice_date]
      row << format_entry_number(entry.entry_number)
      add_bucket_data row, buckets, :direct
      add_bucket_data row, buckets, :retail
      add_bucket_data row, buckets, :factory
      add_bucket_data row, buckets, :factory_direct
      add_bucket_data row, buckets, :madewell_retail
      add_bucket_data row, buckets, :madewell_direct
      row << invoice_data[:t_e_amount]
      row << 0 # There's never any duty on T/E lines since this bucket is just a brokerage fee they want allocated to a different GL account
      add_bucket_data row, buckets, :madewell_factory
      row << invoice_data[:amount] + invoice_data[:t_e_amount]
      row << (invoice_data[:previously_invoiced] ? 0 : [entry.total_fees, entry.total_duty].compact.sum)
      row << errors_message if errors_message

      XlsMaker.add_body_row sheet, row_number, row, column_widths
      if errors_message
        (0..(row.length - 1)).each do |x|
          sheet.row(row_number).set_format(x, (x != 1 ? error_format : error_with_date))
        end
      end
    end

    if row_number == 0
      XlsMaker.add_body_row sheet, row_number + 1, ["No billing data returned for this report."], column_widths
    end

    workbook_to_tempfile wb, "JCrew Billing #{start_date.strftime("%Y-%m-%d")} thru #{end_date.strftime("%Y-%m-%d")} "
  end

  private 
    def entries start_date, end_date
      Entry.joins(:broker_invoices)
        .where("broker_invoices.invoice_date >= ? AND invoice_date <= ?", start_date, end_date)
        .where("broker_invoices.customer_number in (?)", ['JCREW', 'J0000', 'CREWFTZ'])
        .order("broker_invoices.invoice_date ASC")
        .uniq
        .includes(:commercial_invoices=>[:commercial_invoice_lines=>[:commercial_invoice_tariffs]])
        .readonly
    end

    def sum_brokerage_amounts_for_entry entry, start_date, end_date
      # We're purposefully not passing start_date into the query because 
      # we need to find all the broker invoices that may have previously been included on an earlier sheet
      # to make sure we're not double including duty amounts.
      invoices = BrokerInvoice.where(entry_id: entry.id)
        .where("invoice_date <= ?", end_date)
        .includes(:broker_invoice_lines)
        .order("invoice_date ASC, id ASC")
        .readonly

      invoice_number = nil
      invoice_date = nil
      sum = BigDecimal.new 0
      te_sum = BigDecimal.new 0
      previously_invoiced = false

      invoices.each do |inv|
        if inv.invoice_date < start_date
          previously_invoiced = true
          next
        else
          # We're only using the first invoice number from our current dataset as the invoice number we're billing to J Crew
          invoice_number ||= inv.invoice_number
          invoice_date ||= inv.invoice_date

          sum += inv.broker_invoice_lines.inject(BigDecimal.new(0)) {|sum, line| sum + (include_non_t_e_charge_line?(line) ? line.charge_amount : 0)}
          te_sum += inv.broker_invoice_lines.inject(BigDecimal.new(0)) {|sum, line| sum + (t_e_charge_line?(line) ? line.charge_amount : 0)}
        end
      end

      # All charges for entries w/ a T/E charge are set into the T/E bucket, so just set the T/E amount to be sum of other charges + T/E charge
      if te_sum > 0
        te_sum += sum
        sum = BigDecimal.new 0
      end

      # don't bother including the invoice information if it sums to zero.  We get a number of debit invoices immediately followed by credit invoices
      # due to operational error, so we don't want to bother including these.
      if sum > 0 || te_sum > 0
        {invoice_number: invoice_number, invoice_date: invoice_date, amount: sum, t_e_amount: te_sum, previously_invoiced: previously_invoiced}
      else
        {}
      end
    end

    def create_commercial_invoice_buckets entry, previously_invoiced
      buckets = Hash.new {|h, k| h[k] = {:line_count=>0, :duty_amount=>BigDecimal.new(0)}}

      pos = Set.new

      entry.commercial_invoices.each do |inv|
        inv.commercial_invoice_lines.each do |line|
          po = line.po_number.to_s.strip
          bucket, rank = bucket_info po

          buckets[bucket][:line_count] += 1
          buckets[bucket][:duty_amount] += line.duty_plus_fees_amount unless previously_invoiced
          buckets[bucket][:rank] = rank
          pos << po

          if bucket == :unknown
            buckets[bucket][:invalid_po] ||= Set.new
            buckets[bucket][:invalid_po] << po
          end
        end
      end

      # Doing this makes sure we're no longer defaulting hash lookings
      {}.merge buckets
    end

    def include_non_t_e_charge_line? line
      return false if t_e_charge_line?(line)

      charge_code = line.charge_code.to_i
      description = line.charge_description.upcase

      # Only include lines that have codes less than 1K and do NOT match 
      # the other criteria
      charge_code < 1000 &&
        !(description.include?("COST") ||
          description.include?("FREIGHT") ||
          description.include?("DUTY") ||
          description.include?("WAREHOUSE") ||
          [138,1,99,105,106,107,108,109,120,208,4,5,98,134,603,
              11,13,20,30,41,48,60,69,71,76,85,87,89,97,128,133,136,141,143,145,
              148,153,155,165,167,169,171,177,179,185,186,188,194,195,201,203,205,
              206,207,213,215,401,402,403,404,410,411,413,414,415,416,417,418,
              419,420,421,429,430,434,435,437,510,511,512,513,514,515,516,517,
              518,519,520,521,524,525,526,527,528,529,530,531,532,533,534,535,
              536,537,540,541,542,543,544,600,601,740,741,905,906,914,921,946,
              950,955,956,957,964,980,999].include?(charge_code)
        )
    end

    def t_e_charge_line? line
      "0910" == line.charge_code
    end

    def bucket_info po_number
      po_number = po_number.to_s.strip

      bucket = nil
      if ["1", "8"].include? po_number[0]
        bucket = [:direct, 1]
      elsif ["2", "5"].include? po_number[0]
        bucket = [:retail, 2]
      elsif po_number.start_with?("95")
        bucket = [:madewell_factory, 7]
      elsif ["3", "9"].include? po_number[0]
        bucket = [:factory, 3]
      elsif po_number[0] == "6"
        bucket = [:factory_direct, 4]
      elsif po_number.start_with?("4")
          bucket = [:madewell_retail, 5]
      elsif po_number.start_with?("7")
        bucket = [:madewell_direct, 6]
      else
        bucket = [:unknown, 99]
      end
      bucket
    end

    def prorate_by_po_counts entry, charge_amount, buckets
      # Sum the # of po numbers for the entry, then we can use that amount
      # to evenly prorate the total charge amount across each bucket based
      # on the # of PO's in the bucket.  
      # We then add back in the fractional cents remaining based on the highest value of the original
      # proration calculation's truncated amounts.

      total_number_pos = buckets.values.map {|v| v[:line_count]}.sum

      # FTZ files will not have commercial invoices, non-entry files where we bill incidentals will also not have invoices
      return if total_number_pos <= 0

      total_prorated = BigDecimal.new 0
      buckets.values.each do |v|
        original_amount = (BigDecimal.new(v[:line_count]) / total_number_pos) * charge_amount
        po_amount = original_amount.round(2, :truncate)

        v[:line_amount] = po_amount
        total_prorated += po_amount
        v[:truncated_amount] = original_amount - po_amount
      end

      leftover = charge_amount - total_prorated
      if leftover > 0
        # The leftover amount (which will be less than the number of buckets) needs to get dropped in order of the buckets with the highest value
        # of the truncated amounts (identical amounts are ordered by left to right column ordering in the output)
        sorted_buckets = buckets.collect {|k, v| v unless k == :unknown}.compact.sort {|a, b| s = b[:truncated_amount] <=> a[:truncated_amount]; s == 0 ? a[:rank] <=> b[:rank] : s}
        number_of_cents = (charge_amount - total_prorated) * 100
        (0..(number_of_cents - 1)).each do |x|
          sorted_buckets[x][:line_amount] += BigDecimal.new("0.01")
        end
      end

      nil
    end

    def add_bucket_data row, buckets, key
      if buckets[key]
        row << (buckets[key][:line_amount] ? buckets[key][:line_amount] : 0)
        row << (buckets[key][:duty_amount] ? buckets[key][:duty_amount] : 0)
      else
        row << 0
        row << 0
      end
    end

    def format_entry_number entry_number
      en = entry_number.strip
      if en =~ /^0+$/
        en = "316-" + en
      elsif en.length >= 3
        en[3] = "-" + en[3]
      end

      en
    end

end; end; end

