require 'open_chain/report/report_helper'

module OpenChain; module Report; class PvhContainerLogReport
  include OpenChain::Report::ReportHelper

  def self.permission? user
    user.company.master? && (Rails.env.development? || MasterSetup.get.system_code == 'www-vfitrack-net')
  end

  def self.run_report run_by, settings
    self.new.run settings
  end

  def self.run_schedulable settings
    raise "Scheduled instances of the PVH Container Report must include an email_to setting with an array of email addresses." unless settings['email_to'] && settings['email_to'].respond_to?(:each)
    temp = nil
    begin
      temp = self.new.run_report settings
      date = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now.strftime "%m/%d/%Y %I:%M %p"
      OpenMailer.send_simple_html(settings['email_to'], "[VFI Track] PVH Container Log", "Attached is the PVH Container Log Report for #{date}", [temp]).deliver!
    ensure
      temp.close! if temp && !temp.closed?
    end
  end

  def run_report settings
    wb = XlsMaker.new_workbook
    sheet = XlsMaker.create_sheet wb, "Container Log"
    
    table_from_query sheet, container_log_query(settings), conversions

    workbook_to_tempfile wb, "PVH Container Log-"
  end

  private 
    def container_log_query settings
      if !settings['start_date'].blank? || !settings['end_date'].blank?
        date_clause = ""
        if !settings['start_date'].blank?
          date_clause += "AND e.arrival_date >= '#{Time.zone.parse(settings['start_date']).utc.strftime("%Y-%m-%d")}'"
        end

        if !settings['end_date'].blank?
          date_clause += " AND e.arrival_date < '#{Time.zone.parse(settings['end_date']).utc.strftime("%Y-%m-%d")}'"
        end
      else 
        date_clause = "AND DATEDIFF(now(), e.arrival_date) <= 6"
      end
      q = <<QRY
SELECT e.broker_reference as 'Broker Reference', e.entry_number as 'Entry Number', e.carrier_code as 'Carrier Code', e.vessel as 'Vessel/Airline', e.export_country_codes as 'Country Export Codes',
 e.customer_references as 'Customer References', e.worksheet_date as 'Worksheet Date', e.store_names as 'Departments', c.quantity as 'Total Packages', c.container_number as 'Container Numbers', 
 e.eta_date as 'ETA Date', e.arrival_date as 'Arrival Date', pe.name as 'Port of Entry Name', e.docs_received_date as 'Docs Received Date', e.first_entry_sent_date as 'First Summary Sent', 
 e.first_release_date as 'First Release Date', e.available_date as 'Available Date', null as 'First DO Date', '' as 'Trucker', '' as 'Comments', e.id as 'Links'
FROM entries e
INNER JOIN containers c ON e.id = c.entry_id
LEFT OUTER JOIN ports pe on e.entry_port_code = pe.schedule_d_code
WHERE 
 e.entry_port_code NOT IN ('5201', '5203')
 AND e.customer_number = 'PVH'
 #{date_clause}
QRY
    end

    def conversions
      conversions = {}
      date_conversion = datetime_translation_lambda "Eastern Time (US & Canada)", true
      ["Worksheet Date", "Arrival Date", "First Summary Sent", "First Release Date", "Available Date"].each {|d| conversions[d] = date_conversion}
      conversions['Links'] = weblink_translation_lambda CoreModule::ENTRY
      conversions['Customer References'] = cust_ref_conversion
      conversions['Departments'] = csv_translation_lambda
      conversions
    end

    def cust_ref_conversion
      lambda { |result_set_row, raw_column_value| 
        # Add all customer references that are substrings of the customer reference
        # after dropping the first value from the cust ref.
        # .ie F236067 10/1/14 matches to 2236067
        # Strip off anything that looks like a date
        if raw_column_value.blank?
          nil
        else
          broker_ref = result_set_row[0].to_s.upcase
          cust_refs = []
          raw_column_value.split(/\n\s*/).each do |ref|
            first_letter = ref[0]
            ref = ref[1..-1]
            if ref =~ /^(.+)\s+\d{1,2}[\/-]\d{1,2}[\/-]\d{1,4}\s*$/
              ref = $1
            end
            cust_refs << (first_letter + ref).strip if broker_ref.include?(ref.upcase)
          end

          cust_refs.join(", ")
        end
      }
    end

end; end; end;