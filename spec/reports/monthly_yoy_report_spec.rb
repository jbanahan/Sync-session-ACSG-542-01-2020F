describe OpenChain::Report::MonthlyYoyReport do
  
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

  describe "run_schedulable" do
    it "sends email with attached xls" do
      Timecop.freeze(today) { described_class.run_schedulable({"email" => "test@vandegriftinc.com", "range_field" => "file_logged_date"}) }
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

    it "sends email with attached xls (invoice date)" do
      ci1 = Factory(:commercial_invoice, entry: e1, invoice_date: two_months_ago)

      Timecop.freeze(today) { described_class.run_schedulable({"email" => "test@vandegriftinc.com", "range_field" => "invoice_date"}) }
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

        # Should get less results since the query is based off invoice date and only one of the entries has an invoice.
        expect(sheet.count).to eq 2
        expect(sheet.row(0)).to eq ["Period", "Year", "Month", "Country", "Division Number", "Customer Number", "Mode", "File Count"]
      end
    end
  end

  describe "query" do
    it "produces expected data (for file_logged_date)" do
      res = nil
      Timecop.freeze(today) { res = ActiveRecord::Base.connection.execute(subject.query("file_logged_date")) }
      results = []
      res.each { |r| results << r }
      expect(results.count).to eq 5
      expect(results).to match_array [[two_months_ago.strftime("%Y-%m"), two_months_ago.year, two_months_ago.month, "CA", "1", "2", "Ocean", 1],
                                      [month_ago.strftime("%Y-%m"), month_ago.year, month_ago.month, "CA", "2", "2", "Ocean", 1],
                                      [month_ago.strftime("%Y-%m"), month_ago.year, month_ago.month, "CA", "1", "3", "Ocean", 1],
                                      [month_ago.strftime("%Y-%m"), month_ago.year, month_ago.month, "CA", "1", "2", "Air", 1],
                                      [month_ago.strftime("%Y-%m"), month_ago.year, month_ago.month, "US", "1", "2", "Ocean", 1]]
    end

    it "produces expected data (for invoice_date)" do
      ci1 = Factory(:commercial_invoice, entry: e1, invoice_date: two_months_ago)
      ci1b = Factory(:commercial_invoice, entry: e1, invoice_date: nil)
      ci2 = Factory(:commercial_invoice, entry: e2, invoice_date: two_months_ago)
      ci2b = Factory(:commercial_invoice, entry: e2, invoice_date: month_ago)
      ci3 = Factory(:commercial_invoice, entry: e3, invoice_date: month_ago)
      ci4 = Factory(:commercial_invoice, entry: e4, invoice_date: month_ago)

      res = nil
      Timecop.freeze(today) { res = ActiveRecord::Base.connection.execute(subject.query("invoice_date")) }
      results = []
      res.each { |r| results << r }
      expect(results.count).to eq 4
      expect(results).to match_array [[two_months_ago.strftime("%Y-%m"), two_months_ago.year, two_months_ago.month, "CA", "1", "2", "Ocean", 1],
                                      [two_months_ago.strftime("%Y-%m"), two_months_ago.year, two_months_ago.month, "CA", "2", "2", "Ocean", 1],
                                      [month_ago.strftime("%Y-%m"), month_ago.year, month_ago.month, "CA", "1", "3", "Ocean", 1],
                                      [month_ago.strftime("%Y-%m"), month_ago.year, month_ago.month, "CA", "1", "2", "Air", 1]]
    end

    it "skips entries with file_logged_date earlier than January two years ago" do
      # This should be December 31, 2013 based on our 'today' value of May 15, 2016.  January 1, 2014 is included, but
      # one day earlier is too far into the past.
      e1.update_attributes(file_logged_date: (today.at_beginning_of_month - 2.years).at_beginning_of_year - 1.day)
      results = nil
      Timecop.freeze(today) { results = ActiveRecord::Base.connection.execute(subject.query("file_logged_date")) }
      expect(results.count).to eq 4
    end

    it "skips entries with file_logged_date from the current month" do
      e1.update_attributes(file_logged_date: today.at_beginning_of_month)
      results = nil
      Timecop.freeze(today) { results = ActiveRecord::Base.connection.execute(subject.query("file_logged_date")) }
      expect(results.count).to eq 4
    end
  end

  describe "get_range_field" do
    it "cleans range field value" do
      expect(subject.get_range_field({"range_field"=>"file_logged_date"})).to eq "file_logged_date"
      expect(subject.get_range_field({"range_field"=>"invoice_date"})).to eq "invoice_date"
      expect(subject.get_range_field({"range_field"=>"INVALID"})).to eq "file_logged_date"
      expect(subject.get_range_field({})).to eq "file_logged_date"
    end
  end
end