require 'spec_helper'

describe OpenChain::Report::MonthlyYoyReport do
  
  let(:report) { described_class.new }
  let(:co1) { Factory(:country, iso_code: "CA") }
  let(:co2) { Factory(:country, iso_code: "US") }
  let(:today) { Date.new(2016,5,15) }
  let(:month_ago) { today - 1.month }
  let(:two_months_ago) { month_ago - 1.month }
  let!(:e1) { Factory(:entry, file_logged_date: two_months_ago, division_number: '1', customer_number: '2', transport_mode_code: '10', import_country: co1) }
  let!(:e2) { Factory(:entry, file_logged_date: month_ago, division_number: '2', customer_number: '2', transport_mode_code: '10', import_country: co1) }
  let!(:e3) { Factory(:entry, file_logged_date: month_ago, division_number: '1', customer_number: '3', transport_mode_code: '10', import_country: co1) }
  let!(:e4) { Factory(:entry, file_logged_date: month_ago, division_number: '1', customer_number: '2', transport_mode_code: '40', import_country: co1) }
  # Ensures we are including the final day of the previous month.
  let!(:e5) { Factory(:entry, file_logged_date: Date.new(2016,4,30), division_number: '1', customer_number: '2', transport_mode_code: '10', import_country: co2) }

  describe "send_email" do
    it "sends email with attached xls" do
      Timecop.freeze(today) { report.send_email({"email" => "test@vandegriftinc.com"}) }
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq [ "test@vandegriftinc.com" ]
      expect(mail.subject).to eq "Monthly YOY Report"
      expect(mail.attachments.count).to eq 1

      Tempfile.open('attachment') do |t|
        t.binmode
        t << mail.attachments.first.read
        t.flush
        wb = Spreadsheet.open t.path
        sheet = wb.worksheet(0)
        
        expect(sheet.count).to eq 6
        expect(sheet.row(0)).to eq ["Period", "Year", "Month", "Country", "Division Number", "Customer Number", "Mode", "File Count"]
      end
    end
  end

  describe "query" do
    it "produces expected data" do
      res = nil
      Timecop.freeze(today) { res = ActiveRecord::Base.connection.execute(report.query) }
      results = []
      res.each { |r| results << r }
      expect(results.count).to eq 5
      expect(results).to match_array [[two_months_ago.strftime("%Y-%m"), two_months_ago.year, two_months_ago.month, "CA", "1", "2", "Ocean", 1],
                                      [month_ago.strftime("%Y-%m"), month_ago.year, month_ago.month, "CA", "2", "2", "Ocean", 1],
                                      [month_ago.strftime("%Y-%m"), month_ago.year, month_ago.month, "CA", "1", "3", "Ocean", 1],
                                      [month_ago.strftime("%Y-%m"), month_ago.year, month_ago.month, "CA", "1", "2", "Air", 1],
                                      [month_ago.strftime("%Y-%m"), month_ago.year, month_ago.month, "US", "1", "2", "Ocean", 1]]
    end

    it "skips entries with file_logged_date earlier than January two years ago" do
      # This should be December 31, 2013 based on our 'today' value of May 15, 2016.  January 1, 2014 is included, but
      # one day earlier is too far into the past.
      e1.update_attributes(file_logged_date: (today.at_beginning_of_month - 2.years).at_beginning_of_year - 1.day)
      results = nil
      Timecop.freeze(today) { results = ActiveRecord::Base.connection.execute(report.query) }
      expect(results.count).to eq 4
    end

    it "skips entries with file_logged_date from the current month" do
      e1.update_attributes(file_logged_date: today.at_beginning_of_month)
      results = nil
      Timecop.freeze(today) { results = ActiveRecord::Base.connection.execute(report.query) }
      expect(results.count).to eq 4
    end
  end
end