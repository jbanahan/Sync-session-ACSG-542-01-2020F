require 'open_chain/report/report_helper'

module OpenChain; module Report; class DutySavingsReport
  include OpenChain::Report::ReportHelper

  def self.permission? user
    user.view_entries? && user.company.master?
  end

  def self.run_report run_by, settings={}
    self.new.run run_by, settings
  end
  
  #requires 'email', 'customer_numbers' array, and EITHER 'previous_n_days' OR 'previous_n_months'
  def self.run_schedulable settings={}
    start_date = calculate_start_date(settings['previous_n_days'], settings['previous_n_months'])
    end_date = calculate_end_date(settings['previous_n_days'], settings['previous_n_months'])
    self.new.send_email(settings['email'], start_date, end_date, settings['customer_numbers'])
  end

  def self.calculate_start_date previous_n_days, previous_n_months
    today = Time.now.in_time_zone("Eastern Time (US & Canada)").beginning_of_day
    if previous_n_days
      today - previous_n_days.days
    elsif previous_n_months
      today.beginning_of_month - previous_n_months.months
    end
  end

  def self.calculate_end_date previous_n_days, previous_n_months
    today = Time.now.in_time_zone("Eastern Time (US & Canada)").beginning_of_day
    if previous_n_days
      today
    elsif previous_n_months
      today.beginning_of_month
    end
  end
  
  def run run_by, settings
    start_date = sanitize_date_string settings['start_date'], run_by.time_zone
    end_date = sanitize_date_string settings['end_date'], run_by.time_zone
    wb = create_workbook(start_date, end_date, settings['customer_numbers'])
    workbook_to_tempfile wb, 'DutySavings-', file_name: "Duty Savings Report.xls"
  end
  
  def send_email email, start_date, end_date, customer_numbers
    wb = create_workbook(start_date, end_date, customer_numbers)
    workbook_to_tempfile wb, 'DutySavings-', file_name: "Duty Savings Report.xls" do |t|
      subject = "Duty Savings Report: #{start_date.strftime("%m-%d-%Y")} through #{(end_date - 1.minute).strftime("%m-%d-%Y")}"
      body = "<p>Report attached.<br>--This is an automated message, please do not reply.<br>This message was generated from VFI Track</p>".html_safe
      OpenMailer.send_simple_html(email, subject, body, t).deliver!
    end
  end
  
  def create_workbook start_date, end_date, customer_numbers
    wb, sheet = XlsMaker.create_workbook_and_sheet "Duty Savings Report"
    table_from_query sheet, query(start_date, end_date, customer_numbers)
    wb
  end

  def query(start_date, end_date, customer_numbers)
    <<-SQL
      SELECT 
        ent.broker_reference AS 'Broker Ref#',
        ent.arrival_date AS 'Arrival Date',
        ent.release_date AS 'Release Date',
        cil.vendor_name AS 'Vendor Name',
        cil.po_number AS 'PO Number',
        cil.value AS 'Invoice Line Value',
        MAX(cit.entered_value) AS 'Entered Value',
        cil.value - cit.entered_value AS 'Cost Savings',
        IF(ROUND(SUM((cil.value * cit.duty_rate) - cit.duty_amount),2)< 1,0,ROUND(SUM((cil.value * cit.duty_rate) - cit.duty_amount),2)) AS 'Duty Savings'
      FROM entries ent
        INNER JOIN commercial_invoices ci ON ci.entry_id = ent.id
        INNER JOIN commercial_invoice_lines cil ON cil.commercial_invoice_id = ci.id
        INNER JOIN commercial_invoice_tariffs cit ON cit.commercial_invoice_line_id = cil.id
      WHERE ent.customer_number IN (#{customer_numbers.map{|c| ActiveRecord::Base.sanitize c}.join(', ')})
        AND ent.release_date >= '#{start_date}' AND ent.release_date < '#{end_date}'
        AND (cil.contract_amount IS NULL OR cil.contract_amount = 0)
      GROUP BY cil.id
      ORDER BY ent.release_date
    SQL
  end

end; end; end
