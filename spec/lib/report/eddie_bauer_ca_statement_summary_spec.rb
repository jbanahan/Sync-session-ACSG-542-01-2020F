require 'open_chain/report/eddie_bauer_ca_statement_summary'

describe OpenChain::Report::EddieBauerCaStatementSummary do

  describe "permission?" do
    let!(:user) { FactoryBot(:user) }

    it "allows master users only" do
      expect_any_instance_of(Company).to receive(:master?).and_return true
      expect(described_class.permission? user).to be_truthy
    end

    it "rejects non-master companies" do
      expect_any_instance_of(Company).to receive(:master?).and_return false
      expect(described_class.permission? user).to be_falsey
    end
  end

  describe "run_report" do
    it "runs the report" do
      user =  FactoryBot(:user)
      expect_any_instance_of(OpenChain::Report::EddieBauerCaStatementSummary).to receive(:run).with(user, instance_of(HashWithIndifferentAccess))
      OpenChain::Report::EddieBauerCaStatementSummary.run_report user, {}
    end
  end

  describe "run_schedulable" do
    it "runs/emails the report" do
      now = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].local(2017, 3, 15)
      Timecop.freeze(now) do
        Tempfile.open(["file", ".csv"]) do |t|
          t.binmode
          t << "content"
          t.rewind
          expect_any_instance_of(described_class).to receive(:run).with(User.integration, {start_date: "2017-03-08", end_date: "2017-03-15"}).and_return t
          described_class.run_schedulable({'email' => 'tufnel@stonehenge.biz', 'after_x_days_ago' => 7, 'before_x_days_ago' => 0})
          m = ActionMailer::Base.deliveries.first
          expect(m.to).to eq ["tufnel@stonehenge.biz"]
          expect(m.subject).to eq "Eddie Bauer CA Statement Summary for 2017-03-08 to 2017-03-15"
          expect(m.attachments.size).to eq 1
        end
      end
    end
  end

  describe "run" do
    before :each do
      @entry = FactoryBot(:entry, entry_number: '123456789', customer_number: "EBCC", entry_filed_date: '2014-03-01')
      @commercial_invoice = FactoryBot(:commercial_invoice, entry: @entry, invoice_number: "A")
      @cil =  FactoryBot(:commercial_invoice_line, commercial_invoice: @commercial_invoice, po_number: "ABC-123", hmf: 1, prorated_mpf: 2, cotton_fee: 3, country_origin_code: "CN")
      @tariff_line = @cil.commercial_invoice_tariffs.create! duty_amount: 5, duty_rate: 0.5
      @tariff_line2 = @cil.commercial_invoice_tariffs.create! duty_amount: 10, duty_rate: 0.05
      @cil2 =  FactoryBot(:commercial_invoice_line, commercial_invoice: @commercial_invoice, po_number: "DEF-456", hmf: 4, prorated_mpf: 5, cotton_fee: 6, country_origin_code: "CA")
      @tariff_line3 = @cil2.commercial_invoice_tariffs.create! duty_amount: 20, duty_rate: 0.25
      @tariff_line4 = @cil2.commercial_invoice_tariffs.create! duty_amount: 25, duty_rate: 0.05

      @broker_invoice = FactoryBot(:broker_invoice, entry: @entry, invoice_date: '2014-03-01')
      @broker_invoice_line1 = FactoryBot(:broker_invoice_line, broker_invoice: @broker_invoice, charge_amount: 5)
      @broker_invoice_line2 = FactoryBot(:broker_invoice_line, broker_invoice: @broker_invoice, charge_amount: 15, charge_type: "D")

      allow_any_instance_of(MasterSetup).to receive(:request_host).and_return "localhost"
    end

    after :each do
      @t.close! if @t && !@t.closed?
    end

    it "outputs statement information for all entries w/ invoice dates between specified dates" do
      @t = described_class.new.run FactoryBot(:master_user, time_zone: "Eastern Time (US & Canada)"), start_date: '2014-02-28', end_date: '2014-03-02'
      sheet = Spreadsheet.open(@t.path).worksheet 0

      expect(sheet.row(0)).to eq ["Statement #", "ACH #", "Entry #", "PO", "Business", "Invoice", "Duty Rate", "Duty", "Taxes / Fees", "Fees", "ACH Date", "Statement Date", "Release Date", "Unique ID", "Country of Origin", "LINK"]
      expect(sheet.row(1)).to eq [nil, nil, @entry.entry_number, "ABC", "123", @commercial_invoice.invoice_number,
        50.0, 15.0, 6.0, 5.0, nil, nil, nil, "#{@entry.entry_number}/#{50.0}/#{@commercial_invoice.invoice_number}", "CN", Spreadsheet::Link.new(@entry.view_url, 'Web Link')]
      expect(sheet.row(2)).to eq [nil, nil, @entry.entry_number, "DEF", "456", @commercial_invoice.invoice_number,
        25.0, 45.0, 15.0, 0, nil, nil, nil, "#{@entry.entry_number}/#{25.0}/#{@commercial_invoice.invoice_number}", "CA", Spreadsheet::Link.new(@entry.view_url, 'Web Link')]
    end

    it "prevents users who do not have access to the entry from seeing them" do
      @t = described_class.new.run FactoryBot(:user, time_zone: "Eastern Time (US & Canada)"), start_date: '2014-02-28', end_date: '2014-03-02'
      sheet = Spreadsheet.open(@t.path).worksheet 0
      expect(sheet.rows.length).to eq 1
    end

    it "excludes invoices outside the start and end date range on an entry" do
      prior_invoice = FactoryBot(:broker_invoice_line, broker_invoice: FactoryBot(:broker_invoice, entry: @entry, invoice_date: '2014-02-01'), charge_amount: 5).broker_invoice
      post_invoice = FactoryBot(:broker_invoice_line, broker_invoice: FactoryBot(:broker_invoice, entry: @entry, invoice_date: '2014-05-01'), charge_amount: 5).broker_invoice

      @t = described_class.new.run FactoryBot(:master_user, time_zone: "Eastern Time (US & Canada)"), start_date: '2014-02-28', end_date: '2014-03-02'
      sheet = Spreadsheet.open(@t.path).worksheet 0

      sheet = Spreadsheet.open(@t.path).worksheet 0
      expect(sheet.row(1)[9]).to eq 5.0
      expect(sheet.row(2)[9]).to eq 0
    end

    it "excludes entries with invoices that zero each other out when there's no duty" do
      @broker_invoice_line2.update! charge_type: nil, charge_amount: 0
      other_invoice = FactoryBot(:broker_invoice_line, broker_invoice: FactoryBot(:broker_invoice, entry: @entry, invoice_date: '2014-03-01'), charge_amount: -5).broker_invoice

      @t = described_class.new.run FactoryBot(:master_user, time_zone: "Eastern Time (US & Canada)"), start_date: '2014-02-28', end_date: '2014-03-02'
      sheet = Spreadsheet.open(@t.path).worksheet 0
      expect(sheet.rows.length).to eq 1
    end

    it "includes entries with invoices that zero each other out when there is duty" do
      @broker_invoice_line2.update! charge_type: "D", charge_amount: 0
      other_invoice = FactoryBot(:broker_invoice_line, broker_invoice: FactoryBot(:broker_invoice, entry: @entry, invoice_date: '2014-03-01'), charge_amount: -5).broker_invoice

      @t = described_class.new.run FactoryBot(:master_user, time_zone: "Eastern Time (US & Canada)"), start_date: '2014-02-28', end_date: '2014-03-02'
      sheet = Spreadsheet.open(@t.path).worksheet 0
      expect(sheet.rows.length).to eq 3
    end
  end
end
