module OpenChain; module CustomHandler; module LumberLiquidators; module LumberCostFileCalculationsSupport

  def calculate_charge_totals entry
    Calculations.calculate_charge_totals entry
  end

  def calculate_proration_for_lines lines, total_entered_value, charge_totals, charge_buckets
    Calculations.calculate_proration_for_lines lines, total_entered_value, charge_totals, charge_buckets
  end
  
  def add_remaining_proration_amounts values, charge_buckets
    Calculations.add_remaining_proration_amounts values, charge_buckets
  end

  # This class used is pretty much exclusively to enforce an API for using this module, "restricting"
  # calls to the delegate methods defined above
  class Calculations
    def self.charge_xref
      {
        '0004' => :ocean_rate,
        '0007' => :brokerage,
        '0176' => :acessorial,
        '0050' => :acessorial,
        '0142' => :acessorial,
        '0235' => :isc_management,
        '0191' => :isf,
        '0915' => :isf,
        '0189' => :pier_pass,
        '0720' => :pier_pass,
        '0739' => :pier_pass,
        '0212' => :inland_freight,
        '0016' => :courier,
        '0031' => :oga,
        '0125' => :oga,
        '0026' => :oga,
        '0193' => :clean_truck,
        '0196' => :clean_truck
      }
    end

    def self.prorated_values 
      [:ocean_rate, :brokerage, :acessorial, :isc_management, :isf, :blp_handling, :blp, :pier_pass, :inland_freight, :courier, :oga, :clean_truck]
    end

    def self.calculate_charge_totals entry
      totals = Hash.new do |h, k|
        h[k] = BigDecimal("0")
      end

      entry.broker_invoices.each do |inv|
        calculate_charge_totals_per_invoice inv, totals
      end

      totals
    end

    def self.calculate_charge_totals_per_invoice invoice, totals = nil
      if totals.nil?
        totals = Hash.new do |h, k|
          h[k] = BigDecimal("0")
        end
      end

      xref = charge_xref
      invoice.broker_invoice_lines.each do |line|
        rate_type = xref[line.charge_code]
        if rate_type && line.charge_amount
          totals[rate_type] += line.charge_amount
        end
      end

      totals
    end

    def self.calculate_proration_for_lines lines, total_entered_value, charge_totals, charge_buckets
      lines = Array.wrap(lines)

      line_entered_value = lines.inject(BigDecimal("0")) {|sum, line| sum += line.total_entered_value }

      # Don't round this value, we'll round the end amount to 3 decimals
      proration_percentage = total_entered_value.try(:nonzero?) ? (line_entered_value / total_entered_value) : 0

      c = {}
      c[:entered_value] = (line_entered_value || BigDecimal("0"))
      c[:duty] = lines.map {|line| line.total_duty || BigDecimal("0") }.sum
      c[:add] = lines.map {|line| line.add_duty_amount || BigDecimal("0") }.sum
      c[:cvd] = lines.map {|line| line.cvd_duty_amount || BigDecimal("0") }.sum
      c[:hmf] = lines.map {|line| line.hmf || BigDecimal("0") }.sum
      c[:mpf] = lines.map {|line| line.prorated_mpf || BigDecimal("0") }.sum

      # Figure the "ideal" proration value, we'll then compare to what's technically left over from the actual charge buckets
      prorated_values.each do |k|
        next if charge_totals[k].nil?

        ideal_proration = (charge_totals[k] * proration_percentage).round(3, BigDecimal::ROUND_HALF_UP)

        # If we go negative, it means the proration amount is too big to alot the full localized amount (in general, this should basically just be a few pennies
        # that we'll short the final line on)
        value = nil
        if (charge_buckets[k] - ideal_proration) < 0
          value = charge_buckets[k]
        else
          value = ideal_proration
        end

        c[k] = value
        charge_buckets[k] -= value
      end

      c
    end

    def self.add_remaining_proration_amounts values, charge_buckets
      # For every proration cent left over in the buckets, spread out the value over all the line items tenth of a cent by tenth of a cent
      # (since they want the values down to 3 decimal places)
      # There's probably some formulaic way to do this rather than iteratively, but we're not going to be dealing w/ vast
      # numbers of lines, so this should work just fine.
      if values.length > 0
        cent = BigDecimal("0.001")

        charge_buckets.each_pair do |k, val|
          next unless val > 0
          previous_val = val
          begin
            values.each do |line|
              next unless line[:entered_value].try(:nonzero?)

              # Skip the line if the entered value on the line is zero...since a zero entered value means the line has
              # no value to input into the total proration, it should not receive any back from the leftover.
              line[k] += cent
              val -= cent
              break if val <= 0
            end

            raise "Detected infinite loop condition.  No modifications made to the charge bucket." if previous_val == val
          end while val > 0
        end
      end
    end
  end

end; end; end; end