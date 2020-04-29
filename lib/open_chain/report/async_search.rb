# This class is pretty much just an adapter for a search to be run utilizing the ReportResult#run_report interface

module OpenChain; module Report; class AsyncSearch

  # Run the report, passing the search_setup_id
  def self.run_report run_by, settings={}, &block
    search_setup = SearchSetup.where(id: settings['search_setup_id'].to_i).first
    run(run_by, search_setup, settings, &block)
  end

  def self.run_and_email_report run_by_id, search_setup_id, mail_fields
    run_by = User.where(id: run_by_id).first
    search_setup = SearchSetup.where(id: search_setup_id).first
    return unless run_by && search_setup

    run(run_by, search_setup) do |tempfile|
      to = []
      to << mail_fields[:to] unless mail_fields[:to].blank?
      mailing_list = MailingList.where(id: mail_fields[:mailing_list]).first unless mail_fields[:mailing_list].nil?
      to << mailing_list unless mailing_list.nil?

      OpenMailer.send_search_result_manually(to, mail_fields[:subject], mail_fields[:body], tempfile, run_by).deliver_now
    end

  rescue => e
    e.log_me
    run_by.messages.create!(:subject=>"Report FAILED: #{search_setup.try(:name)}", :body=>"<p>Your report failed to run due to a system error: #{ERB::Util.html_escape(e.message)}</p>")
  end

  def self.run run_by, search_setup, settings={}
    return nil unless search_setup
    raise "You cannot run another user's report.  Your id is #{run_by.id}, this report is for user #{search_setup.user_id}" unless run_by == search_setup.user

    filename = SearchSchedule.report_name(search_setup, search_setup.download_format, include_timestamp: true)
    tempfile_name = Attachment.get_sanitized_filename filename
    tempfile_params = ["#{File.basename(tempfile_name, ".*")}_", File.extname(tempfile_name)]
    if block_given?
      Tempfile.open(tempfile_params) do |tempfile|
        write_search tempfile, filename, search_setup, run_by, settings
        yield tempfile
      end

      return nil
    else
      tempfile = Tempfile.open(tempfile_params)
      write_search tempfile, filename, search_setup, run_by, settings
      return tempfile
    end
  end

  def self.write_search tempfile, filename, search_setup, run_by, settings
    Attachment.add_original_filename_method(tempfile, filename)
    SearchWriter.write_search search_setup, tempfile, user: run_by, audit: settings['audit']
    tempfile.rewind
  end

end; end; end
