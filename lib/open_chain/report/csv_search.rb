module OpenChain
  module Report
    class CSVSearch
      def self.run_report run_by, settings={}
        search_setup = SearchSetup.find settings['search_setup_id']
        raise "You cannot run another user's report.  Your id is #{run_by.id}, this report is for user #{search_setup.user_id}" unless run_by == search_setup.user
        t = Tempfile.new(['search_result','.csv'])
        wb, result_count = CsvMaker.new(:include_links=>search_setup.include_links?).make_from_search_query(SearchQuery.new(search_setup, run_by)) 
        t << wb
        t.flush
        t
      end
    end
  end
end
