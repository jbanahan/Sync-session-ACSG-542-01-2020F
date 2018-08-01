module OpenChain; module Report; class JCrewBillingReport

  def initialize opts = {}
    @opts = opts.with_indifferent_access
  end

  def self.permission? user
    MasterSetup.get.custom_feature?("WWW VFI Track Reports") && user.company.master?
  end

  # run_by required by reporting interface
  def self.run_report run_by, opts = {}, &block
    JCrewBillingReport.new(opts).run &block
  end

  def self.run_schedulable opts = {}
    opts = opts.with_indifferent_access

    email_to = opts.delete :email_to
    raise "Email address is required." if email_to.blank?

    start_date, end_date = calculate_start_end_dates(opts, Time.zone.now.to_date)

    opts[:start_date] = start_date.to_s
    opts[:end_date] = end_date.to_s

    self.run_report(User.integration, opts) do |tempfile|
      OpenMailer.send_simple_html(email_to, "J Crew Billing #{start_date.strftime("%m/%d/%Y")} - #{end_date.strftime("%m/%d/%Y")}", "Please find attached the J Crew Billing file data for the time period of #{start_date.strftime("%m/%d/%Y")} - #{end_date.strftime("%m/%d/%Y")}.", tempfile).deliver!
    end
  end

  def self.calculate_start_end_dates opts, reference_date
    start_date = nil
    if opts[:start_date]
      start_date = ActiveSupport::TimeZone["America/New_York"].parse(opts[:start_date].to_s).to_date
    else
      # If no date is given, use the begining of the previous week
      start_date = (reference_date - 1.week).at_beginning_of_week(:sunday).to_date
    end

    if opts[:end_date]
      end_date = ActiveSupport::TimeZone["America/New_York"].parse(opts[:end_date].to_s).to_date
    else
      end_date = (reference_date - 1.week).at_end_of_week(:sunday).to_date
    end

    [start_date, end_date]
  end

  def run
    start_date = @opts[:start_date].to_date
    end_date = @opts[:end_date].to_date
    
    invoice_date = ActiveSupport::TimeZone["America/New_York"].now.to_date
    invoice_number = "VG-WE#{invoice_date.strftime "%Y%m%d"}"

    header_row = ["Invoice", nil, "2003513", "Draft", invoice_date.strftime("%m/%d/%Y"), "No", "No", "Martha.long@jcrew.com", "770"]
    
    invoice_sheets = []
    rows = []
    current_entry_rows = []
    duty_gl_total = BigDecimal("0")

    entries(start_date, end_date).each do |entry|
      invoice_data = sum_brokerage_amounts_for_entry entry, start_date, end_date
      next if invoice_data.blank?

      buckets = create_commercial_invoice_buckets entry, invoice_data[:previously_invoiced]
      prorate_by_po_counts(entry, invoice_data[:amount], buckets) if invoice_data[:amount] > 0
      entry_duty = BigDecimal("0")

      # For each division, we need to see if there is any invoice / duty amounts that needs to be sent
      [:direct, :retail, :factory, :factory_direct, :madewell_retail, :madewell_direct, :madewell_wholesale].each do |division_key|
        # Crew has two primary expenses they want the invoice data logged as: Duty (duty_amount) and Brokerage Fees (line_amount)
        [:line_amount, :duty_amount].each do |expense_type|

          charge_amount = buckets[division_key].try(:[], expense_type)

          if charge_amount && charge_amount.nonzero?
            current_entry_rows << build_line_data(invoice_data[:invoice_number], charge_amount, jcrew_account_data(division_key, expense_type))
            entry_duty += charge_amount if expense_type == :duty_amount
          end
        end
      end
      
      if rows.length + current_entry_rows.length >= max_row_count
        # If we're adding a new sheet here, it means that we will absolutely be using more than one sheet total, in which case
        # we will need the A,B invoice number suffix, therefore we send the invoice_sheets length to indicate how many invoices have 
        # been done already.
        invoice_sheets << finalize_file_rows(invoice_date, duty_gl_total, rows, invoice_sheets.length)
        rows = []
        duty_gl_total = BigDecimal(0)
      end

      rows.push *current_entry_rows
      duty_gl_total += entry_duty
      current_entry_rows = []
    end

    if rows.length > 0
      # It's possible at this point that we haven't done more than one sheet worth of billing (.ie invoice_sheets.length == 0),
      # if so, then we want to send nil as the invoice_number_count..that will result in no suffix being added to the
      # invoice number generated.
      invoice_sheets << finalize_file_rows(invoice_date, duty_gl_total, rows, (invoice_sheets.length > 0 ? invoice_sheets.length : nil))
    end

    builder = XlsxBuilder.new
    base_filename = "JCrew Billing #{start_date.strftime("%Y-%m-%d")} thru #{end_date.strftime("%Y-%m-%d")}"

    Tempfile.open(["JCrew Billing", ".zip"]) do |tempfile|
      tempfile.binmode
      Attachment.add_original_filename_method tempfile, "#{base_filename}.zip"

      Zip::File.open(tempfile.path, Zip::File::CREATE) do |zipfile|
        write_excel_file(zipfile, base_filename, invoice_sheets)
        write_csv_files(zipfile, invoice_sheets)
      end
    
      tempfile.flush
      tempfile.rewind

      yield tempfile
    end

    nil
  end

  private

    def write_csv_files zipfile, invoice_sheets
      builders = build_csv_files(invoice_sheets)
      builders.each do |builder_data|
        io = StringIO.new
        builder_data[:builder].write io
        io.rewind

        zipfile.file.open("#{builder_data[:invoice_number]}.csv", "w") {|f| f << io.read }
      end
    end

    def build_csv_files invoice_sheets
      csv_builders = []

      if invoice_sheets.length > 0

        invoice_sheets.each do |invoice_sheet|
          inv_no = invoice_number(invoice_sheet)
          builder = CsvBuilder.new
          csv_builders << {invoice_number: inv_no, builder: builder}

          # Use the invoice number as the name of the sheet
          sheet = builder.create_sheet inv_no
          invoice_sheet.each do |row|
            builder.add_body_row sheet, row
          end
        end
      end

      csv_builders
    end

    def write_excel_file zip, base_filename, invoice_sheets
      builder = build_excel_file invoice_sheets
      io = StringIO.new
      builder.write io
      io.rewind

      zip.file.open("#{base_filename}.xlsx", "wb") {|f| f << io.read }
    end

    def build_excel_file invoice_sheets
      builder = XlsxBuilder.new

      if invoice_sheets.length == 0
        sheet = builder.create_sheet "No Invoice"
        builder.add_body_row sheet, ["No billing data returned for this report."]
      else
        invoice_sheets.each do |invoice_sheet|
          # Use the invoice number as the name of the sheet
          sheet = builder.create_sheet invoice_number(invoice_sheet)
          invoice_sheet.each do |row|
            builder.add_body_row sheet, row
          end
        end
      end

      builder
    end

    def invoice_number sheet_data
      sheet_data[5][1]
    end

    def max_row_count
      # Crew's system cannot handle more than 300 rows per file...if 300 rows are generated we need to split
      # We're using 298 here since there's a header row that would be added and a duty summation row that would be added too
      298
    end

    def finalize_file_rows invoice_date, duty_amount, invoice_rows, invoice_number_count
      invoice_number = "VG-WE#{invoice_date.strftime("%Y%m%d")}#{invoice_number_suffix(invoice_number_count)}"
      file_rows = []
      file_rows.push *file_headers

      file_rows << build_header(invoice_number, invoice_date)
      invoice_rows.each_with_index do |row, index|
        # We now need to insert the invoice number and line counter into each row.
        row[1] = invoice_number
        row[4] = index + 1
        file_rows << row
      end

      if duty_amount.try(:nonzero?)
        # The file rows thing is just pulling the last line number utilized and adding one to it
        file_rows << build_duty_total_line(invoice_number, duty_amount, (file_rows[-1][4].to_i + 1))
      end

      file_rows
    end 

    def build_header invoice_number, invoice_date
      header = []
      # Due to how the invoice number can change based on the total number of invoiced lines, we're going to populate these
      # values after we've logged all the data, so they're left out here.
      header[0] = "Invoice"
      header[1] = invoice_number
      header[3] = "2003513"
      header[4] = "Draft"
      header[5] = invoice_date.strftime("%m/%d/%Y")
      header[6] = "No"
      header[10] = "No"
      header[18] = requester_email
      header[21] = "US Purchasing"
      header[22] = "USD"
      header[69] = "770"

      header
    end

    def requester_email
      "martha.long@jcrew.com"
    end

    def build_line_data broker_invoice_number, amount, account_data
      row = []
      # Due to how the invoice number / line number can change based on the total number of invoiced lines, we're going to populate these
      # values after we've logged all the data, so they're left out here.
      row[0] = "Invoice Line"
      row[3] = "2003513"
      row[5] = broker_invoice_number
      row[8] = amount
      row[17] = "EA"
      row[23] = "JC02"
      row[24] = account_data[:b_a]
      row[25] = "General Expense (Non IO)"
      row[26] = account_data[:profit_center]
      row[29] = account_data[:gl_account]
      
      row
    end

    def build_duty_total_line invoice_number, amount, line_number
      row = []
      row[0] = "Invoice Line"
      row[1] = invoice_number
      row[3] = "2003513"
      row[4] = line_number
      row[5] = "#{invoice_number} Credit"
      # The duty amount should be a negative value, I believe what they're doing here is creating an offsetting entry for the duty
      # amounts in a correlated gl account.  .ie forcing us to do their double entry book keeping for them.
      row[8] = (amount * -1)
      row[17] = "EA"
      row[23] = "JC02"
      row[24] = "0022"
      row[25] = "General Expense (Non IO)"
      row[29] = "111295"

      row
    end

    def invoice_number_suffix existing_file_count
      return "" unless existing_file_count

      raise "You cannot bill more than 26 invoice files in a single run." if existing_file_count > 25

      # All we're really doing here is using the ASCII table and then adding the number of files we've done so far
      # to the starting value of 65 (which equates to A).
      # I'm not handling more than 26 numbers (we could doing modulo arithmetic, but there's no situation where we should legitmately
      # have more than 26 files worth of billing as this process should be running weekly).
      (65 + existing_file_count).chr
    end

    def entries start_date, end_date
      Entry.joins(:broker_invoices)
        .where("broker_invoices.invoice_date >= ? AND invoice_date <= ?", start_date, end_date)
        .where("broker_invoices.customer_number in (?)", ['JCREW', 'J0000', 'CREWFTZ'])
        .order(:broker_reference)
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
      previously_invoiced = false

      invoices.each do |inv|
        if inv.invoice_date < start_date
          previously_invoiced = true
          next
        else
          # We're only using the first invoice number from our current dataset as the invoice number we're billing to J Crew
          invoice_number ||= inv.invoice_number
          invoice_date ||= inv.invoice_date

          sum += inv.broker_invoice_lines.inject(BigDecimal.new(0)) {|sum, line| sum + (include_charge_line?(line) ? line.charge_amount : 0)}
        end
      end

      # don't bother including the invoice information if it sums to zero.  We get a number of debit invoices immediately followed by credit invoices
      # due to operational error, so we don't want to bother including these.
      if sum > 0
        {invoice_number: invoice_number, invoice_date: invoice_date, amount: sum, previously_invoiced: previously_invoiced}
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
        end
      end

      # Doing this makes sure we're no longer defaulting hash lookings
      {}.merge buckets
    end

    def include_charge_line? line
      charge_code = line.charge_code.to_i
      description = line.charge_description.upcase

      # Only include lines that have codes less than 1K and do NOT match 
      # the other criteria
      charge_code < 1000 &&
        !(description.include?("COST") ||
          description.include?("FREIGHT") ||
          description.include?("DUTY") ||
          description.include?("WAREHOUSE") ||
          [1,99,105,106,107,108,109,120,208,4,5,98,134,603,
              11,13,20,30,41,48,60,69,71,76,85,87,89,97,128,133,136,141,143,145,
              148,153,155,165,167,169,171,177,179,185,186,188,194,195,201,203,205,
              206,207,213,215,401,402,403,404,410,411,413,414,415,416,417,418,
              419,420,421,429,430,434,435,437,510,511,512,513,514,515,516,517,
              518,519,520,521,524,525,526,527,528,529,530,531,532,533,534,535,
              536,537,540,541,542,543,544,600,601,740,741,905,906,910,914,921,946,
              950,955,956,957,964,980,999].include?(charge_code)
        )
    end

    def bucket_info po_number
      po_number = po_number.to_s.strip

      bucket = nil
      if po_number.start_with?("02")
        bucket = [:madewell_wholesale, 8]
      elsif ["1", "8"].include? po_number[0]
        bucket = [:direct, 1]
      elsif ["2", "5"].include? po_number[0]
        bucket = [:retail, 2]
      elsif ["3", "9"].include? po_number[0]
        bucket = [:factory, 3]
      elsif po_number[0] == "6"
        bucket = [:factory_direct, 4]
      elsif po_number.start_with?("4")
        bucket = [:madewell_retail, 5]
      elsif po_number.start_with?("7")
        bucket = [:madewell_direct, 6]
      else
        # Anything with an unknown bucket (.ie bad PO #) was getting thrown back into the retail columns by the person reviewing the file before
        # forwarding it to JCrew.  There's no reason to force them into doing this manually, if that's all that needs to be done
        # so we'll do it here for them.
        bucket = [:retail, 2]
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
        # The leftover amount needs to get dropped in order of the buckets with the highest value
        # of the truncated amounts (identical amounts are ordered by left to right column ordering in the output)
        sorted_buckets = buckets.collect {|k, v| v unless k == :unknown}.compact.sort {|a, b| s = b[:truncated_amount] <=> a[:truncated_amount]; s == 0 ? a[:rank] <=> b[:rank] : s}
        mod = sorted_buckets.size
        number_of_cents = (charge_amount - total_prorated) * 100
        (0..(number_of_cents - 1)).each do |x|
          # Becuase we're not dropping leftover amounts into the unknown bucket, it's possible there's more leftover change than buckets to drop it into, hence the modulo
          sorted_buckets[x % mod][:line_amount] += BigDecimal.new("0.01")
        end
      end

      nil
    end

    def jcrew_account_data division_key, expense_type
      data = {b_a: "", profit_center: "", gl_account: ((expense_type == :line_amount) ? "211541" : "211521")}
      case division_key
      when :direct
        data[:b_a] = "21"
        data[:profit_center] = "6000"
      when :retail
        data[:b_a] = "23"
        data[:profit_center] = "5023"
      when :factory
        data[:b_a] = "24"
        data[:profit_center] = "5024"
      when :factory_direct
        data[:b_a] = "37"
        data[:profit_center] = "7500"
      when :madewell_retail
        data[:b_a] = "26"
        data[:profit_center] = "5026"
      when :madewell_direct
        data[:b_a] = "27"
        data[:profit_center] = "7300"
      when :madewell_wholesale
        data[:b_a] = "18"
        data[:profit_center] = "18140"
      end

      data[:profit_center] = data[:profit_center].to_s.rjust(7, '0')
      data[:b_a] = data[:b_a].to_s.rjust(4, '0')

      data
    end

    def file_headers
      rows = []
      rows << ["Invoice", "Invoice Number", "Supplier Name", "Supplier Number", "Status", "Invoice Date", "Submit For Approval?", "Handling Amount", "Misc Amount", "Shipping Amount", "Line Level Taxation", "Tax Amount", "Tax Rate", "Tax Code", "Tax Rate Type", "Supplier Note", "Payment Terms", "Shipping Terms", "Requester Email", "Requester Name", "Requester Lookup Name", "Chart of Accounts", "Currency", "Contract Number", "Image Scan Filename", "Image Scan URL", "Local Currency Net", "Taxes In Origin Country Currency", "Local Currency Gross", "Delivery Number", "Delivery Date", "Margin Scheme", "Cash Accounting Scheme Reference", "Exchange Rate", "Gross Total", "Late Payment Penalties", "Credit Reason", "Early Payment Provisions", "Pre-Payment Date", "Self Billing Reference", "Discount Amount", "Reverse Charge Reference", "Discount %", "Credit Note differences with Original Invoice", "Customs Declaration Number", "Customs Office", "Customs Declaration Date", "Payment Order Reference", "Amount of advance payment received", "Type of Relationship", "Ship To Name", "Ship To Id", "Ship To Attention", "Ship To Street1", "Ship To Street2", "Ship To City", "Ship To State", "Ship To Postal Code", "Ship to Country Code", "Ship to Country Name", "Ship to Location Code", "Ship to VAT ID", "Ship to Local Tax Number", "Bill To Address Id", "Bill To Address Legal Entity Name", "Bill To Address Street", "Bill To Address City", "Bill To Address Postal Code", "Bill To Address Country Code", "Bill To Address Location Code", "Bill To Address VAT ID", "Bill To Address Local Tax Number", "Remit To Address Street1", "Remit To Address Street2", "Remit To Address City", "Remit To Address State", "Remit To Address Postal Code", "Remit To Address Country Code", "Remit To Code", "Remit To Tax Prefix", "Remit To Tax Number", "Remit To Tax Country Code", "Remit To VAT ID", "Remit To Local Tax Number", "Invoice From Address Street1", "Invoice From Address Street2", "Invoice From Address City", "Invoice From Address State", "Invoice From Address Postal Code", "Invoice From Address Country Code", "Invoice From Code", "Ship From Address Street1", "Ship From Address Street2", "Ship From Address City", "Ship From Address State", "Ship From Address Postal Code", "Ship From Address Country Code", "Ship From Code", "Original invoice number", "Original invoice date", "Is Credit Note", "Disputed Invoice Number", "Dispute Resolution Credit Note Number", "Supplier Tax Number", "Buyer Tax Number", "Attachment 1", "Attachment 2", "Attachment 3", "Attachment 4", "Attachment 5", "Attachment 6", "Attachment 7", "Attachment 8", "Attachment 9", "Attachment 10", "Job Code"]
      rows << ["Invoice Charge", "Invoice Number", "Supplier Name", "Supplier Number", "Line Number", "Type", "Description", "Total", "Percent", "Line Tax Amount", "Line Tax Rate", "Line Tax Code", "Line Tax Rate Type", "Line Tax Location", "Line Tax Description", "Line Tax Supply Date", "Account Name", "Account Code", "Billing Notes", "Account Segment 1", "Account Segment 2", "Account Segment 3", "Account Segment 4", "Account Segment 5", "Account Segment 6", "Account Segment 7", "Account Segment 8", "Account Segment 9", "Account Segment 10", "Account Segment 11", "Account Segment 12", "Account Segment 13", "Account Segment 14", "Account Segment 15", "Account Segment 16", "Account Segment 17", "Account Segment 18", "Account Segment 19", "Account Segment 20", "Budget Period Name"]
      rows << ["Invoice Line", "Invoice Number", "Supplier Name", "Supplier Number", "Line Number", "Description", "Supplier Part Number", "Auxiliary Part Number", "Price", "Quantity", "Line Tax Amount", "Line Tax Rate", "Line Tax Code", "Line Tax Rate Type", "Line Tax Location", "Line Tax Description", "Line Tax Supply Date", "Unit of Measure", "PO Number", "PO Line Number", "Account Name", "Account Code", "Billing Notes", "Account Segment 1", "Account Segment 2", "Account Segment 3", "Account Segment 4", "Account Segment 5", "Account Segment 6", "Account Segment 7", "Account Segment 8", "Account Segment 9", "Account Segment 10", "Account Segment 11", "Account Segment 12", "Account Segment 13", "Account Segment 14", "Account Segment 15", "Account Segment 16", "Account Segment 17", "Account Segment 18", "Account Segment 19", "Account Segment 20", "Budget Period Name", "Net Weight", "Weight UOM", "Price per Weight", "Match Reference", "Delivery Note Number", "Original Date Of Supply", "Commodity Name", "HSN/SAC", "UNSPSC"]
      rows << ["Account Allocation", "Invoice Number", "Invoice Line Number", "Amount", "Percent", "Budget Period Name", "Account Name", "Account Code", "Account Segment 1", "Account Segment 2", "Account Segment 3", "Account Segment 4", "Account Segment 5", "Account Segment 6", "Account Segment 7", "Account Segment 8", "Account Segment 9", "Account Segment 10", "Account Segment 11", "Account Segment 12", "Account Segment 13", "Account Segment 14", "Account Segment 15", "Account Segment 16", "Account Segment 17", "Account Segment 18", "Account Segment 19", "Account Segment 20"]
      rows << ["Tag", "Object Number", "Line Number", "Name", "Description", "System Tag"]

      rows
    end

end; end; end

