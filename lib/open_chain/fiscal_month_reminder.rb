module OpenChain; class FiscalMonthReminder
  THRESHOLD = 6

  def self.run_schedulable settings={}
    needs_update = companies_needing_update
    send_email(settings['email'], needs_update) if needs_update.count > 0
  end

  def self.fiscal_months_remaining company
    return nil if company.fiscal_reference.blank?
    FiscalMonth.where(company_id: company).where("start_date >= '#{Time.now}'").count
  end

  def self.companies_needing_update
    needs_update = []
    companies_with_fr = Company.where("fiscal_reference <> '' AND fiscal_reference IS NOT NULL")
    companies_with_fr.each { |co| needs_update << co if calendar_needs_update?(fiscal_months_remaining co) }
    needs_update
  end

  def self.calendar_needs_update? fm_remaining
    fm_remaining.nil? || fm_remaining > THRESHOLD ? false : true
  end

  private

  def self.send_email address, company_list
    formatted_list = company_list.map{|c| "#{c.name} " + (c.system_code.presence ? "(#{c.system_code})" : "")}.join("<br>")
    body = "There are fewer than #{THRESHOLD} months remaining on the fiscal calendars of the following companies:<br><br>#{formatted_list}".html_safe
    OpenMailer.send_simple_html(address, "Fiscal calendar(s) need update", body).deliver!
  end

end; end