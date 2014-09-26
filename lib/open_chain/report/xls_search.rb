module OpenChain
  module Report
    class XLSSearch
      # Run the report, passing the search_setup_id
      def self.run_report run_by, settings={}
        search_setup = SearchSetup.find settings['search_setup_id']
        raise "You cannot run another user's report.  Your id is #{run_by.id}, this report is for user #{search_setup.user_id}" unless run_by == search_setup.user
        wb = XlsMaker.new(:include_links=>search_setup.include_links?,:no_time=>search_setup.no_time?).make_from_search_query_by_search_id_and_user_id(search_setup.id, run_by.id)
       
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
