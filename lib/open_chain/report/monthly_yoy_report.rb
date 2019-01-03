module OpenChain; module Report; class MonthlyYoyReport
  include OpenChain::Report::ReportHelper

  def self.run_schedulable opts_hash={}
    self.new.send_email('email' => opts_hash['email'])
  end

  def send_email(settings)
    wb = create_workbook
    workbook_to_tempfile wb, 'MonthlyYoyReport-' do |t|
      subject = "Monthly YOY Report"
      body = "<p>Report attached.<br>--This is an automated message, please do not reply.<br>This message was generated from VFI Track</p>".html_safe
      OpenMailer.send_simple_html(settings['email'], subject, body, t).deliver!
    end
  end

  def create_workbook
    wb = XlsMaker.create_workbook "YOY Report #{Date.today.strftime('%m-%Y')}"
    table_from_query wb.worksheet(0), query
    wb
  end

  def query
    <<-SQL
      SELECT CONCAT(year(file_logged_date),"-",LPAD(month(file_logged_date),2,"0")) AS 'Period',
        year(file_logged_date) AS Year, 
        month(file_logged_date) AS Month,
        import_country.iso_code AS 'Country',
        division_number AS 'Division Number',
        customer_number AS 'Customer Number',
        CASE entries.transport_mode_code WHEN '10' THEN 'Ocean' WHEN '11' THEN 'Ocean' WHEN '40' THEN 'Air' WHEN '41' THEN 'Air' ELSE 'Other' END AS 'Mode',
        COUNT(*) AS 'File Count'
      FROM entries
        INNER JOIN countries import_country ON entries.import_country_id = import_country.id
      WHERE 
        entries.file_logged_date > '#{(Time.zone.now.beginning_of_year - 2.years).to_s(:db)}' AND 
        file_logged_date < '#{Time.zone.now.beginning_of_month.to_s(:db)}' 
      GROUP BY period, country, division_number, customer_number, mode
    SQL
  end

end; end; end