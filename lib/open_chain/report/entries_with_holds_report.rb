require 'open_chain/report/builder_output_report_helper'

module OpenChain; module Report; class EntriesWithHoldsReport
  include OpenChain::Report::BuilderOutputReportHelper

  def self.permission? user
    MasterSetup.get.custom_feature?("Kewill Entries") && user.view_entries?
  end

  def self.run_report user, settings = {}
    self.new.run(user, settings)
  end

  def run user, settings = {}
    start_date = Date.parse(settings['start_date'])
    end_date = Date.parse(settings['end_date'])

    customer_numbers = settings['customer_numbers'].split(/[\s\n\r]+/)

    start_date_query = ActiveSupport::TimeZone[user.time_zone].parse start_date.to_s
    end_date_query = ActiveSupport::TimeZone[user.time_zone].parse end_date.to_s

    filename = "Entries With Holds #{start_date.to_s} - #{end_date}"
    dt_lambda = datetime_translation_lambda(user.time_zone, true)
    conversions = {"Release Date" => dt_lambda, "Arrival Date" => dt_lambda}
    generate_results_to_tempfile query(user, customer_numbers, start_date_query, end_date_query), "xlsx", "Entries With Holds", filename, data_conversions: conversions
  end


  def query user, customer_numbers, start_date, end_date
    cust_nos = customer_numbers.map {|c| "#{ActiveRecord::Base.sanitize c}"}.join ","
    #convert the start and end dates from the user's timezone into utc one
    start_date = sanitize_date_string(start_date, user.time_zone)
    end_date = sanitize_date_string(end_date, user.time_zone)

    query = <<-SQL
      SELECT DISTINCT entries.broker_reference 'Broker Reference', entries.entry_number 'Entry Number', entries.container_numbers 'Container Numbers', entries.master_bills_of_lading 'Master Bills', entries.house_bills_of_lading 'House Bills', entries.customer_references 'Customer References', entries.po_numbers 'PO Numbers', entries.release_date 'Release Date', entries.arrival_date 'Arrival Date'
      FROM entries
      WHERE entries.on_hold IS NOT NULL and entries.on_hold = true 
      AND #{Entry.search_where(user)} 
      AND entries.customer_number IN (#{cust_nos}) AND entries.arrival_date >= '#{start_date}' AND entries.arrival_date < '#{end_date}'
    SQL
  end
end; end; end