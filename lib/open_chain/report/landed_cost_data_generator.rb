# This class generates data for a replication of an Alliance Landed Cost report.  The report
# is based on data from the Entry and Broker Invoices associated with the entry.  The 
# output of the public methods is a single hash representing the landed cost data for the entries
# being reported on.
module OpenChain; module Report
  class LandedCostDataGenerator

    # Generate landed cost data for a single entry.  An entry model object or entry id
    # value may be passed.
    def landed_cost_data_for_entry entry
      if !entry.is_a? Entry
        entry = Entry.where(:id => entry)
      end

      generate_data find_entries entry
    end

    private 

      def find_entries query
        if query.is_a? Entry
          [query]
        else
          query.includes(:commercial_invoices=>{:commercial_invoice_lines => :commercial_invoice_tariffs}, :broker_invoices=>:broker_invoice_lines).all
        end
      end

      def generate_data entries
        data = {}
        data[:totals] = initialize_charge_columns
        data[:entries] = []

        entries.each do |entry|
          # We're assuming this report is localized to a single importer
          data[:customer_name] ||= entry.customer_name
          ed = {}
          data[:entries] << ed
          ed[:totals] = initialize_charge_columns
          ed[:per_unit] = initialize_charge_columns
          ed[:percentage] = initialize_charge_columns
          ed[:release_date] = entry.release_date
          ed[:transport_mode_code] = entry.transport_mode_code
          ed[:entry_number] = entry.entry_number
          ed[:broker_reference] = entry.broker_reference
          ed[:customer_reference] = entry.customer_references.split("\n")

          # We're going to include all PO #'s as customer references as well (making sure not to include them twice since po# could also be a customer reference value)
          ed[:customer_references] = (entry.po_numbers.split("\n") | entry.customer_references.split("\n")).select {|v| !v.blank?}

          ed[:commercial_invoices] = []
          # Find the total # of units so we can calculate the proration percentages for
          # the brokerage, other charges and possibly freight charges.
          total_units = BigDecimal.new "0"
          invoice_line_prorations = {}

          # Use the invoices -> lines linkage since we've already pre-loaded the data
          entry.commercial_invoices.each do |inv|
            inv.commercial_invoice_lines.each do |line|
              if line.quantity
                total_units += line.quantity
                invoice_line_prorations[line.id] = {:quantity=>line.quantity}
              end
            end
          end

          # Although there's a broker_invoice_total field on the entry, that's actually the sum of Broker Fees
          # and Other Fees, we need to split those things out here.

          # The proration is the per unit proration applied to each invoice line across the whole of the entry.  This value only
          # makes sense displaying for at the entry level for values where an across the entry proration occurs.
          ed[:per_unit][:brokerage] = calculate_broker_invoice_charge_proration total_units, entry, invoice_line_prorations, :brokerage, "R"
          ed[:per_unit][:other] = calculate_broker_invoice_charge_proration total_units, entry, invoice_line_prorations, :other, "O", "C"
          ed[:per_unit][:inland_freight] = calculate_broker_invoice_charge_proration total_units, entry, invoice_line_prorations, :inland_freight, "T"

          invoice_specific_freight_lines = find_per_invoice_freight_charges entry, *entry.commercial_invoices.collect {|i| i.invoice_number}

          # The freight listed here is the total amount that is NOT associated with a specific invoice.
          # In theory, this should be zero, but we're bound to have users typo'ing the charge description or invoice number
          # or fogetting to do it or just not doing it for the customer.  When that happens we can fall back to making the freight
          # proration be across the whole entry.
          intl_freight_proration = calculate_freight_proration total_units, entry, invoice_line_prorations, invoice_specific_freight_lines

          # We're only going to actually display the int'l freight proration when there are no invoice specific freight charges
          # Otherwise, the per unit freight costs will be different for each invoice and showing a total per entry amount is problematic at best.
          ed[:per_unit][:international_freight] = intl_freight_proration unless invoice_specific_freight_lines.length > 0

          ed[:number_of_invoice_lines] = 0
          entry.commercial_invoices.each do |inv|
            i = {}
            ed[:commercial_invoices] << i
            i[:invoice_number] = inv.invoice_number
            i[:first_logged] = entry.file_logged_date

            total_invoice_quantity = BigDecimal.new "0"
            inv.commercial_invoice_lines.each {|l| total_invoice_quantity += l.quantity if l.quantity}

            freight_amount_per_invoice = invoice_specific_freight_lines[inv.invoice_number] ? invoice_specific_freight_lines[inv.invoice_number] : BigDecimal.new("0")
            proration = safe_divide freight_amount_per_invoice, total_invoice_quantity
            freight_remainder = freight_amount_per_invoice
            
            line_count = 0
            i[:commercial_invoice_lines] = []
            inv.commercial_invoice_lines.each do |line|
              line_count += 1
              l = {}
              i[:commercial_invoice_lines] << l

              l[:part_number] = line.part_number
              l[:po_number] = line.po_number
              l[:country_origin_code] = line.country_origin_code
              l[:mid] = line.mid
              l[:quantity] = (line.quantity ? line.quantity : BigDecimal.new("0"))

              # Gather all the unique tariff numbers for this line
              hts = []
              line.commercial_invoice_tariffs.each {|t| hts << t.hts_code unless t.hts_code.blank?}
              l[:hts_code] = hts.uniq

              l[:entered_value] = calculate_entered_value_per_line line
              l[:duty] = calculate_duty_per_line line
              l[:hmf] = line.hmf ? line.hmf : BigDecimal.new("0")
              l[:mpf] = line.mpf ? line.mpf : BigDecimal.new("0")
              l[:cotton_fee] = line.cotton_fee ? line.cotton_fee : BigDecimal.new("0")
              l[:fee] = calculate_fees_per_line line
              l[:brokerage] = invoice_line_prorations[line.id][:brokerage] ? invoice_line_prorations[line.id][:brokerage] : BigDecimal.new("0")
              l[:inland_freight] = invoice_line_prorations[line.id][:inland_freight] ? invoice_line_prorations[line.id][:inland_freight] : BigDecimal.new("0")
              l[:other] = invoice_line_prorations[line.id][:other] ? invoice_line_prorations[line.id][:other] : BigDecimal.new("0")
              l[:international_freight] = invoice_line_prorations[line.id][:international_freight] ? invoice_line_prorations[line.id][:international_freight] : BigDecimal.new("0")

              # Now lets add in any invoice level freight prorations
              if line_count != inv.commercial_invoice_lines.size
                amount = (l[:quantity] * proration).round(2, BigDecimal::ROUND_HALF_UP)
                freight_remainder -= amount
                l[:international_freight] += amount
              else
                l[:international_freight] += freight_remainder
              end

              l[:landed_cost] = calculate_landed_cost l

              # Calculate the per unit costs
              l[:per_unit] = initialize_charge_columns

              # Don't bother rounding at this point..the output can handle rounding / truncation
              l[:per_unit][:entered_value] = safe_divide l[:entered_value], l[:quantity]
              l[:per_unit][:duty] = safe_divide l[:duty], l[:quantity]
              l[:per_unit][:fee] = safe_divide l[:fee], l[:quantity]
              l[:per_unit][:international_freight] = safe_divide l[:international_freight], l[:quantity]
              l[:per_unit][:inland_freight] = safe_divide l[:inland_freight], l[:quantity]
              l[:per_unit][:brokerage] = safe_divide l[:brokerage], l[:quantity]
              l[:per_unit][:other] = safe_divide l[:other], l[:quantity]
              l[:per_unit][:landed_cost] = safe_divide l[:landed_cost], l[:quantity]

              l[:percentage] = initialize_charge_columns
              l[:percentage][:entered_value] = safe_divide(l[:entered_value], l[:landed_cost]) * BigDecimal.new("100")
              l[:percentage][:duty] = safe_divide(l[:duty], l[:landed_cost]) * BigDecimal.new("100")
              l[:percentage][:fee] = safe_divide(l[:fee], l[:landed_cost]) * BigDecimal.new("100")
              l[:percentage][:international_freight] = safe_divide(l[:international_freight], l[:landed_cost]) * BigDecimal.new("100")
              l[:percentage][:inland_freight] = safe_divide(l[:inland_freight], l[:landed_cost]) * BigDecimal.new("100")
              l[:percentage][:brokerage] = safe_divide(l[:brokerage], l[:landed_cost]) * BigDecimal.new("100")
              l[:percentage][:other] = safe_divide(l[:other], l[:landed_cost]) * BigDecimal.new("100")

              ed[:totals][:entered_value] += l[:entered_value]
              ed[:totals][:duty] += l[:duty]
              ed[:totals][:fee] += l[:fee]
              ed[:totals][:brokerage] += l[:brokerage]
              ed[:totals][:inland_freight] += l[:inland_freight]
              ed[:totals][:other] += l[:other]
              ed[:totals][:international_freight] += l[:international_freight]
              ed[:totals][:landed_cost] += l[:landed_cost]
            end
            ed[:number_of_invoice_lines] += line_count
          end
         
          ed[:percentage][:entered_value] = safe_divide(ed[:totals][:entered_value], ed[:totals][:landed_cost]) * BigDecimal.new("100")
          ed[:percentage][:duty] = safe_divide(ed[:totals][:duty], ed[:totals][:landed_cost]) * BigDecimal.new("100")
          ed[:percentage][:fee] = safe_divide(ed[:totals][:fee], ed[:totals][:landed_cost]) * BigDecimal.new("100")
          ed[:percentage][:international_freight] = safe_divide(ed[:totals][:international_freight], ed[:totals][:landed_cost]) * BigDecimal.new("100")
          ed[:percentage][:inland_freight] = safe_divide(ed[:totals][:inland_freight], ed[:totals][:landed_cost]) * BigDecimal.new("100")
          ed[:percentage][:brokerage] = safe_divide(ed[:totals][:brokerage], ed[:totals][:landed_cost]) * BigDecimal.new("100")
          ed[:percentage][:other] = safe_divide(ed[:totals][:other], ed[:totals][:landed_cost])  * BigDecimal.new("100")

          data[:totals][:entered_value] += ed[:totals][:entered_value]
          data[:totals][:duty] += ed[:totals][:duty]
          data[:totals][:fee] += ed[:totals][:fee]
          data[:totals][:international_freight] += ed[:totals][:international_freight]
          data[:totals][:inland_freight] += ed[:totals][:inland_freight]
          data[:totals][:brokerage] += ed[:totals][:brokerage]
          data[:totals][:other] += ed[:totals][:other]
          data[:totals][:landed_cost] += ed[:totals][:landed_cost]
        end

        data
      end

      def safe_divide dividend, divisor
        value = dividend / divisor if divisor && divisor.nonzero?
        (value && value.finite?) ? value : BigDecimal.new("0")
      end

      def initialize_charge_columns
        data = {}
        [:entered_value, :duty, :fee, :international_freight, :inland_freight, :brokerage, :other, :landed_cost].each do |x|
          data[x] = BigDecimal.new("0") unless data[x]
        end

        data
      end

      def calculate_fees_per_line line
        fee = BigDecimal.new "0"
        fee += line.hmf if line.hmf
        fee += line.mpf if line.mpf
        fee += line.cotton_fee if line.cotton_fee

        fee
      end

      def calculate_duty_per_line line
        total = BigDecimal.new "0"
        line.commercial_invoice_tariffs.each {|t| total += t.duty_amount if t.duty_amount}
        total
      end

      def calculate_entered_value_per_line line
        total = BigDecimal.new "0"
        line.commercial_invoice_tariffs.each {|t| total += t.entered_value if t.entered_value}
        total
      end

      def calculate_landed_cost l
        l[:entered_value] + l[:duty] + l[:fee] + l[:international_freight] + l[:inland_freight] + l[:brokerage]  + l[:other]
      end

      def calculate_broker_invoice_charge_proration total_units, entry, invoice_lines, charge_id, *charge_types
        total_amount = BigDecimal.new "0"
        entry.broker_invoices.each do |inv|
          inv.broker_invoice_lines.each do |line|
            if block_given?
              total_amount += line.charge_amount if yield(line) == true
            else
              total_amount += line.charge_amount if line.charge_amount && charge_types.include?(line.charge_type)
            end
          end
        end

        proration = safe_divide total_amount, total_units
        remainder = total_amount
        number_of_lines = invoice_lines.size
        x = 0
        invoice_lines.each_value do |line|
          x += 1

          if x == number_of_lines
            line[charge_id] = remainder
          else
            amount = (proration * line[:quantity]).round(2, BigDecimal::ROUND_HALF_UP)
            remainder -= amount
            line[charge_id] = amount
          end
        end

        proration
      end

      def calculate_freight_proration total_units, entry, invoice_lines, invoice_freight_mapping
        flattened_freight_mapping = invoice_freight_mapping.keys
        calculate_broker_invoice_charge_proration total_units, entry, invoice_lines, :international_freight do |line|
          (line.charge_type == "F") && line.charge_amount && !flattened_freight_mapping.include?(line.charge_description)
        end
      end

      def find_per_invoice_freight_charges entry, *invoice_numbers
        lines = {}
        invoice_numbers.each do |inv|
          matches = []
          entry.broker_invoices.each do |b|
            b.broker_invoice_lines.each do |l|
              matches << l.charge_amount if ("0600" == l.charge_code) && l.charge_description && l.charge_amount && l.charge_description.upcase.include?(inv)
            end
          end
          # Sum all the matching invoice values
          lines[inv] = (matches.length > 0) ? matches.reduce(:+) : BigDecimal.new("0")
        end
        

        lines
      end

  end
end; end