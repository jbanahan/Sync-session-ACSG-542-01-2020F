require 'open_chain/custom_handler/lumber_liquidators/lumber_cost_file_calculations_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberActualizedChargesReport
  include OpenChain::CustomHandler::LumberLiquidators::LumberCostFileCalculationsSupport
  include OpenChain::Report::ReportHelper

  def self.permission? user
    # Since this can be deployed on both www and LL systems, make sure we have permissions set so the report works on both
    permission = MasterSetup.get.custom_feature?("Lumber Charges Report") && user.view_broker_invoices? && user.view_entries?
    if permission
      if !user.company.master?
        # Must be partnered with LL importer if not master company
        permission = Company.where(importer: true, system_code: "LUMBER").first.try(:can_view?, user)
      end
    end

    permission
  end

  def self.run_schedulable settings = {}
    raise "Report must have an email_to attribute configured." unless Array.wrap(settings['email_to']).length > 0
    start_date, end_date =  start_end_dates("America/New_York")
    self.new.run User.integration, start_date, end_date, email_to: settings['email_to']
  end

  def self.start_end_dates time_zone
    # Calculate start/end dates using the run date as the previous workweek (Monday - Sunday)
    now = Time.zone.now.in_time_zone(time_zone)
    start_date = (now - 7.days)
    # Subtract days until we're at a Monday
    start_date -= 1.day while start_date.wday != 1
    # Basically, we're formatting these dates so the represent the Monday @ Midnight and the following Monday @ midnight, relying on the 
    # where clause being >= && <.  We don't want any results showing that are actually on the following Monday based on Eastern timezone
    [start_date.beginning_of_day, (start_date + 7.days).beginning_of_day]
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings['start_date'], settings['end_date']
  end

  def run user, start_date, end_date, email_to: nil
    values = []
    find_entries(user, start_date, end_date, user.time_zone).each do |entry|
      values << generate_entry_data(entry)
    end

    wb = write_entry_values "Charges #{start_date} - #{end_date}", values
    if email_to
      workbook_to_tempfile wb, "report", file_name: "Actualized Charges #{start_date} - #{end_date}.xls" do |file|
        OpenMailer.send_simple_html(email_to, "[VFI Track] Actualized Charges Report", "Attached is your Actualized Charges report for entries released after #{start_date} and prior to #{end_date}.", file).deliver_now
      end
    else
      workbook_to_tempfile wb, "report", file_name: "Actualized Charges #{start_date} - #{end_date}.xls"  
    end
  end

  def find_entries user, start_date, end_date, time_zone = "America/New_York"
    start_date = ActiveSupport::TimeZone[time_zone].parse start_date.to_s
    end_date = ActiveSupport::TimeZone[time_zone].parse end_date.to_s
    Entry.search_secure(user, Entry.where(customer_number: "LUMBER", source_system: Entry::KEWILL_SOURCE_SYSTEM).where("entries.release_date >= '#{start_date.to_s(:db)}' AND entries.release_date < '#{end_date.to_s(:db)}'").
      order("entries.release_date ASC"))
  end

  def generate_entry_data entry
    # First, collect all the invoice lines listed under each container...each one of those groupings
    # will represent a single line on the report.
    containers = {}

    # Use a blank container as a holder just in case ops keys a line without an actual container on it...this'll cause a business rule failure
    # but it shouldn't cause the report to fail.
    containers[""] = {container_number: "", container_size: "", container_description: "", lines: []}
    entry.containers.each do |container|
      containers[container.container_number] = {container_number: container.container_number, container_size: container.container_size, lines: []}
    end

    entry.commercial_invoices.each do |invoice|
      invoice.commercial_invoice_lines.each do |line|
        # It's possible if ops keyed the data wrong that container is nil, handle that as if 
        # no container was keyed
        container_number = line.container.try(:container_number).to_s
        containers[container_number][:lines] << line
      end
    end

    # Second, calculate the charge armounts associated with the brokerage invoices...
    total_entered_value = entry.entered_value
    charge_totals = calculate_charge_totals entry
    charge_buckets = charge_totals.deep_dup

    # Third, prorate those amounts against the entered value from the container lines
    entry_values = []
    containers.values.each do |container|
      next unless container[:lines].length > 0

      values = calculate_proration_for_lines(container[:lines], total_entered_value, charge_totals, charge_buckets)

      values[:ship_date] = entry.export_date
      values[:port_of_entry] = entry.us_entry_port.try(:name)
      values[:broker_reference] = entry.broker_reference
      values[:entry_number] = entry.entry_number
      values[:carrier_code] = entry.carrier_code
      values[:master_bill] = entry.master_bills_of_lading
      values[:vessel] = entry.vessel
      values[:eta_date] = entry.eta_date
      values[:origin] = entry.lading_port.try(:name)
      values[:container_number] = container[:container_number]
      values[:container_size] = container[:container_size]
      # Lumber appears to have a 1-1 relationship with Container / PO..I'm still going to account for multiple though
      values[:po_numbers] = container[:lines].map {|l| l.po_number }.compact.uniq.join "\n "
      values[:vendors] = container[:lines].map {|l| l.vendor_name }.compact.uniq.join "\n "
      values[:quantity] = container[:lines].map {|l| l.quantity.presence || 0 }.sum
      values[:gross_weight_kg] = container[:lines].map {|l| l.commercial_invoice_tariffs }.flatten.map {|t| t.gross_weight.presence || 0}.sum

      # Convert Gross Weight to LBS
      if values[:gross_weight_kg].nonzero?
        values[:gross_weight] = (values[:gross_weight_kg] * BigDecimal("2.20462")).round(2, BigDecimal::ROUND_HALF_UP)
      end

      entry_values << values
    end

    add_remaining_proration_amounts entry_values, charge_buckets

    entry_values
  end


  def write_entry_values name, all_entries
    wb, sheet = XlsMaker.create_workbook_and_sheet name, ["Ship Date", "", "Port of Entry", "", "", "", "Broker Reference", "Entry Number", "", "PO Number", "Vendor", "Container Number", "", "Container Size", "Carrier Code", "Master Bill", "", "Vessel", "ETA Date", "Quantity", "Gross Weight (KG)", "Gross Weight (LB)", "Ocean Freight", "", "Custom Clearance Fees", "Additional Charges", "CPM Fee", "ISF Fee", "CCC Charges", "Pier Pass / Clean Truck Fee", "", "MSC Charges", "Customs Duty", "", "", "Bill of Lading Origin", "Origin Port", "", "", "", "Countervailing Duty", "Anti Dumpting Duty", "Contract #"]
    counter = 0
    widths = []
    all_entries.each do |entry_data|
      entry_data.each do |values|
        row = []
        row[0] = values[:ship_date]
        row[2] = values[:port_of_entry]
        row[6] = values[:broker_reference]
        row[7] = values[:entry_number]
        row[9] = values[:po_numbers]
        row[10] = values[:vendors]
        row[11] = values[:container_number]
        row[13] = values[:container_size]
        row[14] = values[:carrier_code]
        row[15] = values[:master_bill]
        row[17] = values[:vessel]
        row[18] = values[:eta_date]
        row[19] = values[:quantity]
        row[20] = values[:gross_weight_kg]
        row[21] = values[:gross_weight]
        row[22] = values[:ocean_rate] 
        row[24] = values[:brokerage]
        row[25] = values[:courier]
        row[26] = values[:isc_management]
        row[27] = values[:isf]
        row[29] = ((values[:pier_pass] || BigDecimal("0")) + (values[:clean_truck] || BigDecimal("0")))
        row[31] = values[:acessorial]
        row[32] = ((values[:duty] || BigDecimal("0")) + (values[:hmf] || BigDecimal("0")) + (values[:mpf] || BigDecimal("0")))
        row[36] = values[:origin]
        row[40] = values[:cvd]
        row[41] = values[:add]

        XlsMaker.add_body_row sheet, (counter += 1), row, widths, true
      end
    end

    wb
  end

end; end; end; end