require 'open_chain/report/builder_output_report_helper'
require 'open_chain/polling_job'

module OpenChain; module Report; class InboundFileReport
  include OpenChain::Report::BuilderOutputReportHelper
  extend OpenChain::PollingJob

  def self.run_schedulable settings = {}
    # By using the schedulable job's id, it isolates every single instance of this class as having
    # their own tracking for run times.
    job_name = settings["job_name"].presence || "SchedulableJob-#{SchedulableJob.current&.id.to_i}"
    poll(job_name: job_name) do |last_run, current_run|
      self.new.run(last_run, current_run, settings)
    end
  end

  def data_conversions builder, time_zone
    { "Web View" => weblink_translation_lambda(builder, InboundFile), "Parser" => demodulize_conversion(), "Start Time" => datetime_translation_lambda(time_zone), "End Time" => datetime_translation_lambda(time_zone)}
  end

  def run start_date, end_date, settings
    params = job_params(settings.with_indifferent_access, start_date, end_date)
    report_query = query(params[:start_time], params[:end_time], params[:company_ids], params[:statuses], params[:parser_names])

    generate_results_to_tempfile(report_query, params[:output_format], "VFI Track Files", "VFI Track Files #{params[:end_time].strftime "%Y-%m-%d-%H-%M"}", data_conversions: data_conversions(builder(params[:output_format]), params[:time_zone])) do |tempfile|
      OpenMailer.send_simple_html(params[:email_to], "VFI Track Files Report", "Your VFI Track Files report for #{start_date.strftime "%Y-%m-%d %H:%M"} - #{end_date.strftime "%Y-%m-%d %H:%M"} is attached.", [tempfile]).deliver_now
    end
  end

  def query start_date, end_date, company_ids, parser_statuses, parser_names
    query = "SELECT f.id as 'Web View', f.parser_name as 'Parser', f.file_name as 'File Name', c.name as 'Company Name', f.process_start_date as 'Start Time', f.process_end_date as 'End Time', f.process_status as 'Status'" +
            " FROM inbound_files f" +
            " LEFT OUTER JOIN companies c ON c.id = f.company_id " + 
            " WHERE f.process_end_date > '#{start_date.to_s(:db)}' AND f.process_end_date < '#{end_date.to_s(:db)}'"
            

    if parser_statuses.present?
      query += " AND f.process_status IN (" + sanitize_string_in_list(parser_statuses) + ")"
    end

    if company_ids.present?
      query += " AND f.company_id IN (" + company_ids.join(", ") + ")"
    end

    if parser_names.present?
      query += " AND f.parser_name IN (" + sanitize_string_in_list(parser_names) + ")"
    end

    query += " ORDER BY c.name, f.process_start_date"
  end

  def demodulize_conversion
    lambda do |result_set_row, raw_column_value|
      raw_column_value.to_s.demodulize
    end
  end

  def job_params settings, last_run, current_run
    time_zone = settings["time_zone"].presence || "America/New_York"

    {time_zone: time_zone, start_time: last_run.in_time_zone(time_zone), end_time: current_run.in_time_zone, 
      email_to: email_to(settings), company_ids: company_ids(settings), parser_names: settings["parsers"], statuses: file_statuses(settings), 
      output_format: output_format(settings)
    }
  end

  def email_to settings
    emails = []
    emails.push(*settings["email_to"]) unless settings["email_to"].blank?
    emails.push(*MailingList.where(system_code: settings["mailing_list"])) unless settings["mailing_list"].blank?

    emails
  end

  def company_ids settings
    return [] unless settings["company_system_codes"].present?

    Company.where(system_code: settings["company_system_codes"]).pluck :id
  end

  def file_statuses settings
    return [InboundFile::PROCESS_STATUS_REJECT, InboundFile::PROCESS_STATUS_ERROR] unless settings["statuses"].present?

    settings["statuses"]
  end

  def output_format settings
    settings["output_format"].presence || "xlsx"
  end

  

end; end; end
