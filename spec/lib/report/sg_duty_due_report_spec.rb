require 'spec_helper'
require 'open_chain/report/sg_duty_due_report'

describe OpenChain::Report::SgDutyDueReport do

  describe :get_entries do
    it "returns results of query" do
      co = Factory(:company, alliance_customer_number: 'sgold')
      duty_due = Date.today + 1

      port = Factory(:port, schedule_d_code: "1234", name: "Boston")

      Factory(:entry, importer: co, us_entry_port: port, arrival_date: '2016-03-01', 
              daily_statement_approved_date: '2016-03-02', daily_statement_number: '12345678AB', broker_reference: "12345", 
              customer_references: "123AB\n 456CD", release_date: "2016-03-02", total_duty: 60 ,total_fees: 40, entry_number: "22212345666", 
              entry_type: "01", duty_due_date: duty_due)

      Factory(:entry, importer: co, us_entry_port: port, arrival_date: '2016-03-01', 
              daily_statement_approved_date: '2016-03-02', daily_statement_number: '87654321CD', broker_reference: "54321", 
              customer_references: "321AB\n 654CD", release_date: "2016-03-01", total_duty: 30 ,total_fees: 20, entry_number: "22254321666", 
              entry_type: "01", duty_due_date: duty_due)

       u = Factory(:user, company: co)
       u.stub(:view_entries?).and_return true
       co.stub(:can_view?).with(u).and_return true
       parser = described_class.new
       results = parser.get_entries u, co
       expect(results.count).to eq 2
       expect(results[0][:arrival_date].to_date.to_s).to eq '2016-03-01'
       expect(results[0][:daily_statement_approved_date].to_date.to_s).to eq '2016-03-02'
       expect(results[0][:daily_statement_number]).to eq '87654321CD'
       expect(results[0][:broker_reference]).to eq "54321"
       expect(results[0][:customer_references]).to eq "321AB\n 654CD"
       expect(results[0][:release_date].to_date.to_s).to eq '2016-03-01'
       expect(results[0][:total_duties_and_fees]).to eq 50
       expect(results[0][:entry_number]).to eq "22254321666"
       expect(results[0][:entry_type]).to eq "01"
       expect(results[0][:duty_due_date]).to eq duty_due
       expect(results[0][:port_name]).to eq "Boston"
       expect(results[0][:port_sched_d]).to eq "1234"

       expect(results[1][:release_date].to_date.to_s).to eq "2016-03-02"
       expect(results[1][:total_duties_and_fees]).to eq 100
    end
  end

  describe :create_digest do
    it "returns digest for multiple dates, ports" do
      mar_1 = Date.parse('2016-03-01')
      mar_2 = Date.parse('2016-03-02')
      mar_4 = Date.parse('2016-03-04')
      mar_6 = Date.parse('2016-03-06')
      mar_7 = Date.parse('2016-03-07')
      mar_8 = Date.parse('2016-03-08')

      input = [{arrival_date: mar_1, daily_statement_approved_date: mar_2, daily_statement_number: '12345678AB',
                broker_reference: "12345", customer_references: "123AB\n 456CD", release_date: mar_1, total_duties_and_fees: 100,
                entry_number: "22212345666", entry_type: "01", duty_due_date: mar_7, port_name: "Boston", port_sched_d: "1234"}, 
               {arrival_date: mar_1, daily_statement_approved_date: mar_2, daily_statement_number: '87654321CD',
                broker_reference: "54321", customer_references: "321AB\n 654CD", release_date: mar_1, total_duties_and_fees: 50,
                entry_number: "22254321666", entry_type: "01", duty_due_date: mar_7, port_name: "Boston", port_sched_d: "1234"}, 
               {arrival_date: mar_4, daily_statement_approved_date: mar_7, daily_statement_number: '24681012CD',
                broker_reference: "24681", customer_references: "312AB", release_date: mar_4, total_duties_and_fees: 250,
                entry_number: "22224681666", entry_type: "02", duty_due_date: mar_7, port_name: "Boston", port_sched_d: "1234"},
               {arrival_date: mar_4, daily_statement_approved_date: mar_7, daily_statement_number: '24681012CD',
                broker_reference: "35791", customer_references: "213AB\n 465CD", release_date: mar_4, total_duties_and_fees: 200,
                entry_number: "22235791666", entry_type: "01", duty_due_date: mar_7, port_name: "New York", port_sched_d: "5678"}, 
               {arrival_date: mar_4, daily_statement_approved_date: mar_7, daily_statement_number: '24681012CD',
                broker_reference: "43215", customer_references: "122AB", release_date: mar_4, total_duties_and_fees: 350,
                entry_number: "22243215666", entry_type: "01", duty_due_date: mar_7, port_name: "New York", port_sched_d: "5678"}, 
               {arrival_date: mar_6, daily_statement_approved_date: mar_7, daily_statement_number: '24681012CD',
                broker_reference: "31245", customer_references: "123EF\n 456FA", release_date: mar_6, total_duties_and_fees: 400,
                entry_number: "22231245666", entry_type: "02", duty_due_date: mar_7, port_name: "New York", port_sched_d: "5678"}, 
               {arrival_date: mar_7, daily_statement_approved_date: mar_8, daily_statement_number: '87654321CD',
                broker_reference: "51342", customer_references: "456HD", release_date: mar_7, total_duties_and_fees: 130,
                entry_number: "22251342666", entry_type: "02", duty_due_date: mar_7, port_name: "Boston", port_sched_d: "1234"}]

      digest = [ {"1234"=>{:port_total_duties_and_fees=>150, 
                           :port_name=> "Boston",                                                                                  
                           :entries=>[{release_date: mar_1, arrival_date: mar_1,  #TUESDAY
                                       broker_reference: "12345", entry_number: "22212345666", entry_type: "01", 
                                       customer_references: "123AB\n 456CD", total_duties_and_fees: 100}, 
                                      {release_date: mar_1, arrival_date: mar_1, 
                                       broker_reference: "54321", entry_number: "22254321666", entry_type: "01", 
                                       customer_references: "321AB\n 654CD", total_duties_and_fees: 50}]},                             
                  :date_total_duties_and_fees=>150,
                  :daily_statement_approved => mar_2,
                  :daily_statement_number => Set.new(['12345678AB', '87654321CD']),
                  :est_debit_date => mar_7},
                 {"1234"=>{:port_total_duties_and_fees=>250,
                           :port_name=> "Boston",                                                                                 
                           :entries=>[{release_date: mar_4, arrival_date: mar_4, #FRIDAY
                                       broker_reference: "24681", entry_number: "22224681666", entry_type: "02", 
                                       customer_references: "312AB", total_duties_and_fees: 250}]}, 
                  "5678"=>{:port_total_duties_and_fees=>950,
                           :port_name=>"New York",                                                                                    
                           :entries=>[{release_date: mar_4, arrival_date: mar_4,  
                                       broker_reference: "35791", entry_number: "22235791666", entry_type: "01", 
                                       customer_references: "213AB\n 465CD", total_duties_and_fees: 200}, 
                                      {release_date: mar_4, arrival_date: mar_4, 
                                       broker_reference: "43215", entry_number: "22243215666", entry_type: "01", 
                                       customer_references: "122AB", total_duties_and_fees: 350},
                                      {release_date: mar_6, arrival_date: mar_6, #SUNDAY 
                                       broker_reference: "31245", entry_number: "22231245666", entry_type: "02", 
                                       customer_references: "123EF\n 456FA", total_duties_and_fees: 400}]}, 
                :date_total_duties_and_fees=>1200,
                :daily_statement_approved => mar_7,
                :daily_statement_number => Set.new(['24681012CD']),
                :est_debit_date => mar_7},
                {"1234"=>{:port_total_duties_and_fees=>130, 
                           :port_name=> "Boston",                                                                                  
                           :entries=>[{release_date: mar_7, arrival_date: mar_7, #MONDAY
                                       broker_reference: "51342", entry_number: "22251342666", entry_type: "02", 
                                       customer_references: "456HD", total_duties_and_fees: 130}]},                             
                  :date_total_duties_and_fees=>130,
                  :daily_statement_approved => mar_8,
                  :daily_statement_number => Set.new(['87654321CD']),
                  :est_debit_date => mar_7}]

      parser = described_class.new
      expect(parser.create_digest input).to eq digest
    end
  end

end

