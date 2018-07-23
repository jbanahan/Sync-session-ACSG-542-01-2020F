# This class is pretty much just an adapter for a search to be run utilizing the ReportResult#run_report interface

module OpenChain; module Report; class AsyncSearch

  # Run the report, passing the search_setup_id
  def self.run_report run_by, settings={}, &block
    search_setup = SearchSetup.where(id: settings['search_setup_id'].to_i).first
    run(run_by, search_setup, &block)
  end

  def self.run_and_email_report run_by_id, search_setup_id, mail_fields
    run_by = User.where(id: run_by_id).first
    search_setup = SearchSetup.where(id: search_setup_id).first
    return unless run_by && search_setup

    run(run_by, search_setup) do |tempfile|
      OpenMailer.send_search_result_manually(mail_fields[:to], mail_fields[:subject], mail_fields[:body], tempfile, run_by).deliver!
    end

  rescue => e
    e.log_me
    run_by.messages.create!(:subject=>"Report FAILED: #{search_setup.try(:name)}",:body=>"<p>Your report failed to run due to a system error: #{ERB::Util.html_escape(e.message)}</p>")
  end

  def self.run run_by, search_setup
    return nil unless search_setup
    raise "You cannot run another user's report.  Your id is #{run_by.id}, this report is for user #{search_setup.user_id}" unless run_by == search_setup.user

    filename = SearchSchedule.report_name(search_setup, search_setup.download_format, include_timestamp: true)
    if block_given?
      Tempfile.open([search_setup.name, ".#{search_setup.download_format}"]) do |tempfile|
        write_search tempfile, filename, search_setup, run_by  
        yield tempfile
      end

      return nil
    else
      tempfile = Tempfile.open([search_setup.name, ".#{search_setup.download_format}"])
      write_search tempfile, filename, search_setup, run_by
      return tempfile
    end
  end

  def self.write_search tempfile, filename, search_setup, run_by
    Attachment.add_original_filename_method(tempfile, filename)
    SearchWriter.write_search search_setup, tempfile, user: run_by
    tempfile.rewind
  end

end; end; end