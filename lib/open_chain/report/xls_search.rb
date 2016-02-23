module OpenChain
  module Report
    class XLSSearch
      # Run the report, passing the search_setup_id
      def self.run_report run_by, settings={}
        run(run_by, settings['search_setup_id'])
      end

      def self.run_and_email_report run_by, search_setup_id, mail_fields
        report = run(run_by, search_setup_id)
        OpenMailer.send_search_result_manually(mail_fields[:to], mail_fields[:subject], mail_fields[:body], report.path, run_by).deliver!
      rescue => e
        e.log_me
        run_by.messages.create!(:subject=>"Report FAILED: Search-results email",:body=>"<p>Your report failed to run due to a system error.</p>")
      ensure
        report.close! if report
      end

      def self.run run_by, ss_id
        search_setup = SearchSetup.find ss_id
        raise "You cannot run another user's report.  Your id is #{run_by.id}, this report is for user #{search_setup.user_id}" unless run_by == search_setup.user
        wb, result_count = XlsMaker.new(:include_links=>search_setup.include_links?,:no_time=>search_setup.no_time?).make_from_search_query_by_search_id_and_user_id(search_setup.id, run_by.id)
       
        if wb
          t = Tempfile.new(['search_result','.xls'])
          wb.write t.path
          t
        else
          nil
        end
      end

    end
  end
end
