module OpenChain
  module Report
    class XLSSearch
      # Run the report, passing the search_setup_id
      def self.run_report run_by, settings={}
        run(run_by, settings['search_setup_id'])
      end

      def self.run_and_email_report run_by_id, search_setup_id, mail_fields
        run_by = User.where(id: run_by_id).first
        return unless run_by

        run(run_by, search_setup_id) do |report|
          OpenMailer.send_search_result_manually(mail_fields[:to], mail_fields[:subject], mail_fields[:body], report, run_by).deliver!
        end
        
      rescue => e
        e.log_me
        run_by.messages.create!(:subject=>"Report FAILED: Search-results email",:body=>"<p>Your report failed to run due to a system error.</p>")
      end

      def self.run run_by, ss_id
        search_setup = SearchSetup.where(id: ss_id).first
        return nil unless search_setup
        raise "You cannot run another user's report.  Your id is #{run_by.id}, this report is for user #{search_setup.user_id}" unless run_by == search_setup.user

        wb = nil
        User.run_with_user_settings(run_by) do 
          wb, result_count = XlsMaker.new(:include_links=>search_setup.include_links?,:no_time=>search_setup.no_time?).make_from_search_query(SearchQuery.new(search_setup, run_by))
        end
        
        if wb
          t = Tempfile.new(['search_result','.xls'])
          Attachment.add_original_filename_method(t, SearchSchedule.report_name(search_setup, "xls", include_timestamp: true))
          wb.write t.path
          if block_given? 
            begin
              yield t
            ensure
              t.close!
            end
          else
            return t
          end
        end
       
        nil
      end

    end
  end
end
