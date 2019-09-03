require 'open_chain/report/report_helper'
require 'prawn'
require 'prawn/table'

module OpenChain; module Report; class SgDutyDueReport
  include OpenChain::Report::ReportHelper
  include ActionView::Helpers::NumberHelper

  def self.permission? user
    user.view_entries? && user.company.master? && MasterSetup.get.custom_feature?("WWW VFI Track Reports")
  end

  def self.run_report run_by, settings={}
    company = get_company(settings['customer_number'])
    self.new.run(run_by, company)
  end

  def self.run_schedulable opts_hash={}
    opts_hash['customer_numbers'].each do |cust_num|
      company = get_company cust_num
      self.new.send_email(email: opts_hash['email'], company: company)
    end
  end

  def self.get_company cust_num
    Company.with_customs_management_number(cust_num).first
  end

  def run(run_by, company)
    pdf = generate_pdf(run_by, company)
    pdf_to_tempfile pdf, 'SgDutyDueReport-', file_name: file_name
  end

  def send_email(settings)
    pdf = generate_pdf(User.integration, settings[:company])
    pdf_to_tempfile pdf, 'SgDutyDueReport-', file_name: file_name do |t|
      subject = "Duty Due Report: #{settings[:company].name}"
      body = "<p>Report attached.<br>--This is an automated message, please do not reply.<br>This message was generated from VFI Track</p>".html_safe
      OpenMailer.send_simple_html(settings[:email], subject, body, t).deliver_now
    end
  end

  def file_name
    "Duty Due Report - #{Date.today.strftime('%Y-%m-%d')}.pdf"
  end

  def generate_pdf(user, company)
    Prawn::Font::AFM.hide_m17n_warning = true #suppress warning triggered by #indent
    d = Prawn::Document.new page_size: "LETTER", page_layout: :landscape, margin: [36, 20, 36, 20]
    d.font("Courier", :size => 10)
    d.repeat(:all, :dynamic => true) { d.text_box header(d.page_number, company.name), :at => [0, d.bounds.top] }
    d.bounding_box([-5, 510], :width => d.bounds.width) do
      content = [col_names]
      write_body content, create_digest(get_entries user, company)
      d.table(content, header: true, cell_style: { borders: []}, width: table_width, column_widths: column_widths) do |t|
        t.columns(5).style(align: :right)
        t.rows(0..-1).style(padding: [0,5,0,5])
      end
    end
    d
  end

  def write_body content, digest
    digest.each do |group|
      date_data = {duties: group[:date_total_duties_and_fees], statement_appr: group[:daily_statement_approved], 
                   statement_num: group[:daily_statement_number], debit: group[:est_debit_date] }
      group.keys.select{|k| k.is_a?(String)}.each do |sched_d|
        group[sched_d][:entries].each do |ent| 
          content << row(ent[:entry_number], ent[:entry_type], ent[:release_date], 
                         ent[:arrival_date], ent[:broker_reference], ent[:total_duties_and_fees], 
                         ent[:customer_references] || "")
        end
        content << sub_total(group[sched_d][:port_name], sched_d, group[sched_d][:port_total_duties_and_fees],
                             date_data[:statement_appr], date_data[:debit], date_data[:statement_num]) << space
      end
      content << forecast_total(date_data[:duties], date_data[:statement_appr], date_data[:debit]) << space << divider
    end
    content << space << footer
  end

  def get_entries user, company
    if user.view_entries? && company.can_view?(user)
      Entry.search_secure(user, Entry.select("entries.id, entry_number, arrival_date, daily_statement_approved_date, daily_statement_number, "\
                                             "broker_reference, duty_due_date, ports.name AS port_name, ports.schedule_d_code AS port_sched_d,"\
                                             "entry_type, customer_references, release_date, (total_duty + total_fees) AS total_duties_and_fees")
                                             .joins(:us_entry_port)
                                             .where("importer_id = ? ", company.id)
                                             .where("release_date IS NOT NULL")
                                             .where("duty_due_date >= ?", Time.zone.now.in_time_zone(user.time_zone).to_date)
                                             .where(monthly_statement_due_date: nil)
                                             .order("release_date"))                                      
      else []
    end
  end
  
  #returns array of hashes, each representing a group of entries that corresponds to a release_date,
  #except when it's Fri/Sat/Sun, which is treated as a single date
  def create_digest(entries) 
    digest = []
    previous_date = nil
    group_ptr = nil
    entries.each do |ent|
      current_date = ent[:release_date]
      if previous_date && (previous_date == current_date || (weekend?(previous_date) && weekend?(current_date)))
        # add to existing group
        port_ptr = group_ptr[ent[:port_sched_d]]
        port_ptr = group_ptr[ent[:port_sched_d]] = init_port_hsh(ent) unless port_ptr
      else
        # start a new group
        digest << group_ptr = init_group_hsh(ent)
        port_ptr = group_ptr[ent[:port_sched_d]]
      end
      port_ptr[:entries] << init_entry_hsh(ent)
      port_ptr[:port_total_duties_and_fees] += ent[:total_duties_and_fees]
      group_ptr[:date_total_duties_and_fees] += ent[:total_duties_and_fees]
      group_ptr[:daily_statement_number].add ent[:daily_statement_number]
      previous_date = current_date
    end
    digest
  end

  def weekend? date
    weekend = [0,5,6]
    weekend.include? date.wday
  end

  def init_group_hsh ent 
    {ent[:port_sched_d] => init_port_hsh(ent), 
     date_total_duties_and_fees: 0,
     daily_statement_approved: ent[:daily_statement_approved_date],
     daily_statement_number: Set.new([ent[:daily_statement_number]]),
     est_debit_date: ent[:duty_due_date]}
  end
  
  def init_port_hsh ent
    {port_total_duties_and_fees: 0, port_name: ent[:port_name], entries: []}
  end

  def init_entry_hsh ent
    {release_date: ent[:release_date], arrival_date: ent[:arrival_date], broker_reference: ent[:broker_reference], 
     entry_number: ent[:entry_number], entry_type: ent[:entry_type], customer_references: ent[:customer_references], 
     total_duties_and_fees: ent[:total_duties_and_fees]}
  end

  def header(page_num, cust_name)
    "#{Date.today.strftime("%m/%d/%Y")}                               ACH PAYMENT REPORT                      PAGE    #{page_num}\n"\
    "#{indent (59 - cust_name.length)}#{cust_name}\n\n"
  end

  def footer
    [{ content: "#{indent 5}INFORMATION PROVIDED BY VANDEGRIFT             --  FOR QUESTIONS CONTACT ANGELA CALGANO (ANGELAC@THESGCOMPANIES.COM)", colspan: 7}]
  end

  def col_names
    ["ENTRY NUMBER", "TY", "ENTRY DT", "IMPORT DT", "FILE NO.", "AMT DUE CUSTOMS", "REFERENCE"]
  end

  def row(entry_num, ty, entry_dt, import_dt, file, due, ref)
    [entry_num, ty, date(entry_dt), date(import_dt), file, number_to_currency(due), ref.split("\n ").join(", ")]
  end

  def indent num # see https://github.com/prawnpdf/prawn/issues/89
    "\xC2\xA0" * num
  end

  def sub_total(city, sched_d, due, daily, debit, statement)
    short_statement_number_str = statement.to_a.join(", ")
    full_statement_number_str = short_statement_number_str.presence ? "\nSTATEMENT: #{short_statement_number_str}" : ""
    [{ content: "#{indent 5}SUB-TOTAL FOR #{sched_d}-#{city.upcase}", colspan: 5 }, number_to_currency(due), "REGULAR DAILY: #{date(daily)}  EST. DEBIT DATE: #{date(debit)}#{full_statement_number_str}" ]
  end

  def forecast_total(due, daily, debit)
    [{ content: "#{indent 5}FORECASTED TOTAL FOR REGULAR IMPORTER STATEMENTS", colspan: 5 }, number_to_currency(due), "REGULAR DAILY: #{date(daily)}  EST. DEBIT DATE: #{date(debit)}"]
  end
 
  def date d
    d ? d.strftime("%m/%d/%Y") : "          "
  end

  def space
    [{content: ' ', colspan: 7}]
  end

  def divider
    [{content: '*' * 126, colspan: 7}]
  end

  def column_widths
    [width_chr(13), width_chr(2), width_chr(10), width_chr(10), width_chr(9), width_chr(12) + 12, width_chr(54)]
  end

  def table_width
    column_widths.inject(&:+)
  end

  def width_chr num_letters
    ((num_letters * 20).to_f / 3).ceil + 7
  end

end; end; end