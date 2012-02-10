module OpenChain
  module Report
    class XLSSearch
      # Run the report, passing the search_setup_id
      def self.run_report run_by, settings={}
        search_setup = SearchSetup.find settings['search_setup_id']
        raise "You cannot run another user's report.  Your id is #{run_by.id}, this report is for user #{search_setup.user_id}" unless run_by == search_setup.user
        t = Tempfile.new(['search_result','.xls'])
        XlsMaker.new.make_from_search(search_setup,search_setup.search).write t.path 
        t
      end
    end
  end
end
