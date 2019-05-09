module OpenChain; module Report; class MonthlyYoyReport
  include OpenChain::Report::ReportHelper

  def self.run_schedulable opts_hash={}
    self.new.send_email(opts_hash)
  end

  def send_email(settings)
    wb = create_workbook settings
    workbook_to_tempfile wb, 'MonthlyYoyReport-' do |t|
      subject = "Monthly YOY Report"
      body = "<p>Report attached.<br>--This is an automated message, please do not reply.<br>This message was generated from VFI Track</p>".html_safe
      OpenMailer.send_simple_html(settings['email'], subject, body, t).deliver!
    end
  end

  def create_workbook settings
    wb = XlsMaker.create_workbook "YOY Report #{Date.today.strftime('%m-%Y')}"
    table_from_query wb.worksheet(0), query(get_range_field(settings))
    wb
  end

  # Pulls the range field from the settings, allowing only certain values so as to bypass potential SQL injection
  # issues.  Because of the way these queries are written (this is a dynamic field in the query, not a value for
  # a field), simply sanitizing the settings value is inadequate.
  def get_range_field settings
    range_field = settings['range_field']
    # Defaults to file logged date if bad.  This was the date field the report was originally written against.
    ['file_logged_date','invoice_date'].include?(range_field) ? range_field : "file_logged_date"
  end

  def query range_field
    <<-SQL
      SELECT CONCAT(year(#{range_field}),"-",LPAD(month(#{range_field}),2,"0")) AS 'Period',
        year(#{range_field}) AS 'Year', 
        month(#{range_field}) AS 'Month',
        import_country.iso_code AS 'Country',
        division_number AS 'Division Number',
        customer_number AS 'Customer Number',
        CASE entries.transport_mode_code WHEN '10' THEN 'Ocean' WHEN '11' THEN 'Ocean' WHEN '40' THEN 'Air' WHEN '41' THEN 'Air' ELSE 'Other' END AS 'Mode',
        COUNT(*) AS 'File Count'
      FROM entries
        INNER JOIN countries import_country ON entries.import_country_id = import_country.id 
        #{range_field == "invoice_date" ? "LEFT OUTER JOIN (SELECT entry_id, MIN(invoice_date) AS invoice_date FROM commercial_invoices GROUP by entry_id) AS ci ON entries.id = ci.entry_id " : ""}
      WHERE 
        #{range_field} > '#{(Time.zone.now.beginning_of_year - 2.years).to_s(:db)}' AND 
        #{range_field} < '#{Time.zone.now.beginning_of_month.to_s(:db)}' 
      GROUP BY period, country, division_number, customer_number, mode
    SQL
  end

end; end; end