describe OpenChain::Report::AscenaWeeklyInvoiceReport do
  let(:report) { described_class.new }
  let(:date) { Date.new(2017,04,10) }
  let(:ent) { Factory(:entry, customer_number: "ASCE") }
  let(:bi) { Factory(:broker_invoice, entry: ent, broker_reference: 'brok ref', invoice_number: 'inv num', invoice_date: date) }
  let(:bil) { Factory(:broker_invoice_line, broker_invoice: bi, charge_code: '0002', charge_description: 'charge descr', charge_amount: 1) }
  let(:sr) { SyncRecord.create!(syncable: bi, sent_at: date, trading_partner: 'ASCE_BROKERAGE_BILLING') }
  let(:header) { ["Broker Reference", "Invoice Number", "Invoice Date", "Charge Description", "Charge Amount"] }

  def create_data
    bil; sr
  end

  describe "run_schedulable" do
    it "starts query from previous Tuesday, sends email with attachment" do
      create_data
      
      Timecop.freeze(date + 2.days) do
        expect_any_instance_of(described_class).to receive(:query).with("ASCE", DateTime.parse("2017-04-04 14:00:00"), DateTime.parse("2017-04-11 14:00:00")).and_call_original
        described_class.run_schedulable({'email' => ['test@vandegriftinc.com'], 'customer_number' => 'ASCE'})
      end

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq [ "test@vandegriftinc.com" ]
      expect(mail.subject).to eq "Ascena Weekly Invoice Report - 4/4/2017 to 4/11/2017"
      expect(mail.attachments.count).to eq 1

      Tempfile.open('attachment') do |t|
        t.binmode
        t << mail.attachments.first.read
        t.flush
        wb = Spreadsheet.open t.path
        sheet = wb.worksheet(0)
        
        expect(sheet.count).to eq 2
        expect(sheet.row(0)).to eq header
      end
    end
  end

  describe "query" do
    before { create_data }
    
    it "returns expected results" do
      results = ActiveRecord::Base.connection.execute report.query("ASCE", Date.new(2017,04,01), Date.new(2017,04,15))
      expect(results.fields).to eq header
      expect(results.count).to eq 1
      expect(results.first).to eq ['brok ref', 'inv num', date, 'charge descr', 1]
    end

    it "returns expected results with legacy sync code" do
      sr.update_attributes! trading_partner: "ASCE_BILLING"
      
      results = ActiveRecord::Base.connection.execute report.query("ASCE", Date.new(2017,04,01), Date.new(2017,04,15))
      expect(results.fields).to eq header
      expect(results.count).to eq 1
      expect(results.first).to eq ['brok ref', 'inv num', date, 'charge descr', 1]
    end

    it "excludes results with a different customer number" do
      results = ActiveRecord::Base.connection.execute report.query("MAUR", Date.new(2017,04,01), Date.new(2017,04,15))
      expect(results.count).to eq 0
    end

    it "excludes results without a broker invoice sync record" do
      sr.update_attributes(syncable_type: 'Entry')
      results = ActiveRecord::Base.connection.execute report.query("ASCE", Date.new(2017,04,01), Date.new(2017,04,15))
      expect(results.count).to eq 0
    end

    it "excludes results without an 'ASCE Billing' sync record" do
      sr.update_attributes(trading_partner: "ACME")
      results = ActiveRecord::Base.connection.execute report.query("ASCE", Date.new(2017,04,01), Date.new(2017,04,15))
      expect(results.count).to eq 0
    end

    it "excludes results with an invoice-line charge code of 0001" do
      bil.update_attributes(charge_code: '0001')
      results = ActiveRecord::Base.connection.execute report.query("ASCE", Date.new(2017,04,01), Date.new(2017,04,15))
      expect(results.count).to eq 0
    end

    it "excludes results outside of date range" do
      results = ActiveRecord::Base.connection.execute report.query("ASCE", Date.new(2017,04,01), Date.new(2017,04,05))
      expect(results.count).to eq 0
    end
  end
end
