describe OpenChain::Report::AscenaCumulativeEntryReport do
  let(:parser) { described_class.new }
  let(:us) { Factory :country, iso_code: "US" }

  describe "run_schedulable" do
    it "emails report" do
      ascena = Factory(:company, system_code: "ASCENA")
      this_month = Factory :fiscal_month, company: ascena, month_number: 6, year: 2018, start_date: Date.new(2017,12,31), end_date: Date.new(2018,1,27)
      last_month = Factory :fiscal_month, company: ascena, month_number: 5, year: 2018, start_date: Date.new(2017,11,26), end_date: Date.new(2017,12,30)
      us
      
      expect_any_instance_of(described_class).to receive(:main_query).with(5, 2018).and_call_original
      expect_any_instance_of(described_class).to receive(:isf_query).with("2017-11-26", "2017-12-30").and_call_original

      Timecop.freeze(DateTime.new(2017,12,31,12,0)) do
        described_class.run_schedulable('email'=>'st-hubbins@hellhole.co.uk')
      end

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['st-hubbins@hellhole.co.uk']
      expect(mail.subject).to eq "Ascena Cumulative Entry Report for 2018-05"
      expect(mail.body.raw_source).to match(/Attached is the Ascena Cumulative Entry Report for 2018-05/)
      expect(mail.attachments.length).to eq 1
      att = mail.attachments["Ascena Cumulative Entry Report for 2018-05.xls"]
      expect(att).to_not be_nil
      Tempfile.open('temp') do |t|
        t.binmode
        t << att.read
        t.flush
        wb = XlsMaker.open_workbook t.path
        sheet1 = wb.worksheet(0)
        expect(sheet1.row(0)[0]).to eq "Total Entries"
        sheet2 = wb.worksheet(1)
        expect(sheet2.row(0)[0]).to eq "Count"
      end
    end
  end

  describe "main_query" do
    let(:ca) { Factory :country, iso_code: "CA" }
    let!(:e1) { Factory :entry, customer_number: "ASCE", import_country: us, entry_number: "12345", transport_mode_code: 40, gross_weight: 2, mpf: 3, total_duty: 4, entered_value: 17, fiscal_month: 1, fiscal_year: 2018 }
    let!(:e2) { Factory :entry, customer_number: "ASCE", import_country: us, entry_number: "12346", transport_mode_code: 41, gross_weight: 5, mpf: 6, total_duty: 7, entered_value: 18, fiscal_month: 1, fiscal_year: 2018 }
    let!(:e3) { Factory :entry, customer_number: "ASCE", import_country: us, entry_number: "12347", transport_mode_code: 10, gross_weight: 8, mpf: 9, total_duty: 10, entered_value: 19, fiscal_month: 1, fiscal_year: 2018 }
    let!(:e4) { Factory :entry, customer_number: "ASCE", import_country: us, entry_number: "12348", transport_mode_code: 11, gross_weight: 11, mpf: 12, total_duty: 13, entered_value: 20, fiscal_month: 1, fiscal_year: 2018 }
    let!(:e5) { Factory :entry, customer_number: "ASCE", import_country: us, entry_number: "12349", transport_mode_code: 99, gross_weight: 14, mpf: 15, total_duty: 16, entered_value: 21, fiscal_month: 1, fiscal_year: 2018 }
    let!(:ci1) { Factory :commercial_invoice, entry: e1 }
    let!(:ci2) { Factory :commercial_invoice, entry: e2 }
    let!(:cil1) { Factory :commercial_invoice_line, commercial_invoice: ci1 }
    let!(:cil2) { Factory :commercial_invoice_line, commercial_invoice: ci1 }
    let!(:cil3) { Factory :commercial_invoice_line, commercial_invoice: ci2 }
    
    it "produces expected results" do
      results = ActiveRecord::Base.connection.execute parser.main_query(1,2018)
      expect(results.fields).to eq ["Total Entries", "Air Entries", "Ocean Entries", "Invoice Line Count", "Invoice Count", "Air Weight", "Ocean Weight", "MPF", "Entered Value", "Total Duty"]
      expect(results.count).to eq 1
      r = results.first
      expect(r).to eq [5, 2, 2, 3, 2, 7, 19, 45, 95, 50]
    end

    it "skips non-US entries" do
      e5.update_attributes! import_country: ca
      results = ActiveRecord::Base.connection.execute parser.main_query(1,2018)
      expect(results.first[0]).to eq 4
    end

    it "skips non-Ascena entries" do
      e5.update_attributes! customer_number: "ACME"
      results = ActiveRecord::Base.connection.execute parser.main_query(1,2018)
      expect(results.first[0]).to eq 4
    end

    it "skips entries with wrong fiscal month" do
      e5.update_attributes! fiscal_month: 2
      results = ActiveRecord::Base.connection.execute parser.main_query(1,2018)
      expect(results.first[0]).to eq 4
    end

    it "skips entries with wrong fiscal year" do
      e5.update_attributes! fiscal_year: 2017
      results = ActiveRecord::Base.connection.execute parser.main_query(1,2018)
      expect(results.first[0]).to eq 4
    end
  end

  describe "isf_query" do
    let!(:sf) { Factory :security_filing, importer_account_code: "ASCE", first_sent_date: Date.new(2018,1,15) }
    let!(:sf2) { Factory :security_filing, importer_account_code: "ASCE", first_sent_date: Date.new(2018,1,25) }
    
    it "produces expected results" do
      results = ActiveRecord::Base.connection.execute parser.isf_query("2018-01-01","2018-01-31")
      expect(results.fields).to eq ["Count"]
      expect(results.count).to eq 1
      expect(results.first).to eq [2]
    end

    it "skips filings with wrong customer number" do
      sf.update_attributes! importer_account_code: "ACME"
      results = ActiveRecord::Base.connection.execute parser.isf_query("2018-01-01","2018-01-31")
      expect(results.first).to eq [1]
    end

    it "skips filings with first_sent_date outside of range" do
      sf.update_attributes! first_sent_date: Date.new(2018,2,1)
      results = ActiveRecord::Base.connection.execute parser.isf_query("2018-01-01","2018-01-31")
      expect(results.first).to eq [1]
    end
  end


end
