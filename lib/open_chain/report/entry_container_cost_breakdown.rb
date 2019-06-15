require 'open_chain/report/report_helper'

module OpenChain; module Report; class EntryContainerCostBreakdown
  include OpenChain::Report::ReportHelper

  def self.permission? user
    user.view_entries?
  end

  def self.run_report run_by, settings={}
    self.new.run(run_by, settings)
  end

  def run run_by, settings
    start_date = ActiveSupport::TimeZone[run_by.time_zone].parse(settings['start_date'])
    end_date = ActiveSupport::TimeZone[run_by.time_zone].parse(settings['end_date'])

    timeframe = "#{start_date.strftime("%m-%d-%y")} - #{(end_date - 1.day).strftime("%m-%d-%y")}"
    title = "Containers #{timeframe}"

    column_widths = []
    workbook, sheet = XlsMaker.create_workbook_and_sheet timeframe, headers

    entries = find_entries run_by, settings['customer_number'], start_date, end_date
    row_number = 0
    entries.each do |id|
      entry = load_entry(id)
      next if entry.nil? || !entry.can_view?(run_by)

      freight_amounts = container_invoice_amounts entry, '0600'
      brokerage_amounts = container_invoice_amounts entry

      if entry.containers.length == 0
        sums = entry_sums entry
        # Since there's no containers, the total freight and brokerage amounts are under the :total key
        sums[:freight] = freight_amounts[:total]
        sums[:brokerage] = brokerage_amounts[:total]
        write_report_line sheet, (row_number+= 1), column_widths, entry, "", sums
      else
        entry.containers.each do |container|
          sums = container_sums container
          sums[:freight] = freight_amounts[container_number_key(container.container_number)]
          sums[:brokerage] = brokerage_amounts[container_number_key(container.container_number)]

          write_report_line sheet, (row_number+= 1), column_widths, entry, container.container_number, sums
        end
      end
    end
    workbook_to_tempfile workbook, "Report", file_name: "#{title}.xls"
  end

  def write_report_line sheet, row_num, column_widths, entry, container_number, sums
    XlsMaker.add_body_row sheet, row_num, [entry.master_bills_of_lading, container_number, entry.entry_number, sums[:freight], sums[:duty], sums[:hmf], sums[:mpf], sums[:value], sums[:brokerage], sums.values.compact.inject(&:+)], column_widths
  end

  def find_entries run_by, customer, start_date, end_date
    Entry.search_secure(run_by, Entry.all).where(customer_number: customer).where("release_date >= ? and release_date < ?", start_date, end_date).order(:release_date)
  end

  def load_entry id
    Entry.where(id: id).includes([:containers => [:commercial_invoice_lines => [:commercial_invoice_tariffs]], :commercial_invoices => [:commercial_invoice_lines => [:commercial_invoice_tariffs]], :broker_invoices => [:broker_invoice_lines]]).first
  end

  def headers 
    ["Bill Of Lading", "Container Number", "Entry Number", "Freight", "Duty", "HMF", "MPF", "Commercial Invoice Value", "Brokerage Fees", "Total"]
  end

  def container_invoice_amounts entry, charge_code = nil
    container_numbers = {}

    entry.containers.each do |c|
      next if c.container_number.blank?

      container_numbers[container_number_key(c.container_number)] = BigDecimal("0")
    end
    container_numbers[:prorate_amount] = BigDecimal("0")

    if charge_code
      entry.broker_invoices.each do |invoice|
        # 0600 is the charge code for freight paid direct
        lines = invoice.broker_invoice_lines.find_all {|l| l.charge_code == charge_code}

        lines.each do |line|
          # The charge line may or may not have the container # the freight amount is listed for on the charge description...if it does, record 
          # the amount directly against the container.  If it doesn't, add it to the prorate amount.
          c = container_number_key(line.charge_description)
          if container_numbers.has_key? c
            container_numbers[c] += line.charge_amount
          else
            container_numbers[:prorate_amount] += line.charge_amount
          end
        end
      end
    else
      # We don't do freight for most customers - for the time being, we're just going to assume that freight is not 
      # calculated as part of the invoice total.  We can revist (seeing code in landed_cost_data_generator for how to handle freight charges)
      # later if we need to run this report for customers we bill for freight
      entry.broker_invoices.each {|inv| container_numbers[:prorate_amount] += (inv.invoice_total.presence || 0) }
    end

    prorate container_numbers, container_numbers.delete(:prorate_amount)
  end

  def prorate container_numbers, prorate_amount
    # If there's nothing to prorate against (.ie no containers), then just send back the full proration amount against a total key
    if container_numbers.size == 0
      container_numbers[:total] = prorate_amount
    elsif prorate_amount.nonzero?
      proration = (prorate_amount / container_numbers.size).round(2, BigDecimal::ROUND_DOWN)

      container_numbers.keys.cycle do |container_number|
        if prorate_amount < proration
          container_numbers[container_number] += BigDecimal("0.01")
          prorate_amount -= BigDecimal("0.01")
        else
          container_numbers[container_number] += proration
          prorate_amount -= proration
        end

        break if prorate_amount <= 0
      end
    end

    container_numbers
  end

  def container_sums container
    sums = initializize_sums
    container.commercial_invoice_lines.each do |line|
      add_sums line, sums
    end

    sums
  end

  def container_number_key container
    # Strip all non-alpha/numeric chars and upcase the values
    container.upcase.gsub("[^0-9A-Z]", "")
  end

  def entry_sums entry
    sums = initializize_sums
    entry.commercial_invoices.each do |ci|
      ci.commercial_invoice_lines.each do |line|
        add_sums line, sums
      end
    end
    sums
  end

  def initializize_sums
    {duty: BigDecimal("0"), hmf: BigDecimal("0"), mpf: BigDecimal("0"), value: BigDecimal(0)}
  end

  def add_sums line, sums
    sums[:duty] += line.commercial_invoice_tariffs.map {|t| t.duty_amount.presence || 0}.inject(&:+)
    sums[:value] += (line.value.presence || 0)
    sums[:hmf] += (line.hmf.presence || 0)
    sums[:mpf] += (line.mpf.presence || 0)
  end
end; end; end;