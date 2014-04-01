require 'open_chain/report/eddie_bauer_ca_statement_summary'

describe OpenChain::Report::EddieBauerCaStatementSummary do

  describe "permission?" do
    it "allows master users only" do
      Company.any_instance.should_receive(:master?).and_return true
      expect(described_class.permission? Factory(:user)).to be_true
    end

    it "rejects non-master companies" do
      Company.any_instance.should_receive(:master?).and_return false
      expect(described_class.permission? Factory(:user)).to be_false
    end
  end

  describe "run_report" do
    it "runs the report" do
      user =  Factory(:user)
      OpenChain::Report::EddieBauerCaStatementSummary.any_instance.should_receive(:run).with(user, instance_of(HashWithIndifferentAccess))
      OpenChain::Report::EddieBauerCaStatementSummary.run_report user, {}
    end
  end

  describe "run" do
    before :each do
      @entry = Factory(:entry, entry_number: '123456789', customer_number: "EBCC", entry_filed_date: '2014-03-01')
      @commercial_invoice = Factory(:commercial_invoice, entry: @entry, invoice_number: "A")
      @cil =  Factory(:commercial_invoice_line, commercial_invoice: @commercial_invoice, po_number: "ABC-123", hmf: 1, prorated_mpf: 2, cotton_fee: 3)
      @tariff_line = @cil.commercial_invoice_tariffs.create! duty_amount: 5, duty_rate: 0.5
      @tariff_line2 = @cil.commercial_invoice_tariffs.create! duty_amount: 10, duty_rate: 0.05
      @cil2 =  Factory(:commercial_invoice_line, commercial_invoice: @commercial_invoice, po_number: "DEF-456", hmf: 4, prorated_mpf: 5, cotton_fee: 6)
      @tariff_line3 = @cil2.commercial_invoice_tariffs.create! duty_amount: 20, duty_rate: 0.25
      @tariff_line4 = @cil2.commercial_invoice_tariffs.create! duty_amount: 25, duty_rate: 0.05

      @broker_invoice = Factory(:broker_invoice, entry: @entry, invoice_date: '2014-03-01')
      @broker_invoice_line1 = Factory(:broker_invoice_line, broker_invoice: @broker_invoice, charge_amount: 5)
      @broker_invoice_line2 = Factory(:broker_invoice_line, broker_invoice: @broker_invoice, charge_amount: 15, charge_type: "D")

      MasterSetup.any_instance.stub(:request_host).and_return "localhost"
    end

    after :each do
      @t.close! if @t && !@t.closed?
    end

    it "outputs statement information for all entries w/ invoice dates between specified dates" do
      @t = described_class.new.run Factory(:master_user, time_zone: "Eastern Time (US & Canada)"), start_date: '2014-02-28', end_date: '2014-03-02'
      sheet = Spreadsheet.open(@t.path).worksheet 0

      expect(sheet.row(0)).to eq ["Statement #","ACH #","Entry #","PO","Business","Invoice","Duty Rate","Duty","Taxes / Fees","Fees","ACH Date","Statement Date","Release Date","Unique ID", "LINK"]
      expect(sheet.row(1)).to eq [nil, nil, @entry.entry_number, "ABC", "123", @commercial_invoice.invoice_number, 
        50.0, 15.0, 6.0, 5.0, nil, nil, nil, "#{@entry.entry_number}/#{50.0}/#{@commercial_invoice.invoice_number}", Spreadsheet::Link.new(@entry.view_url,'Web Link')]
      expect(sheet.row(2)).to eq [nil, nil, @entry.entry_number, "DEF", "456", @commercial_invoice.invoice_number, 
        25.0, 45.0, 15.0, nil, nil, nil, nil, "#{@entry.entry_number}/#{25.0}/#{@commercial_invoice.invoice_number}", Spreadsheet::Link.new(@entry.view_url,'Web Link')]
    end

    it "prevents users who do not have access to the entry from seeing them" do
      @t = described_class.new.run Factory(:user, time_zone: "Eastern Time (US & Canada)"), start_date: '2014-02-28', end_date: '2014-03-02'
      sheet = Spreadsheet.open(@t.path).worksheet 0
      expect(sheet.rows.length).to eq 1
    end

    it "excludes invoices outside the start and end date range on an entry" do
      prior_invoice = Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: @entry, invoice_date: '2014-02-01'), charge_amount: 5).broker_invoice
      post_invoice = Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: @entry, invoice_date: '2014-05-01'), charge_amount: 5).broker_invoice

      @t = described_class.new.run Factory(:master_user, time_zone: "Eastern Time (US & Canada)"), start_date: '2014-02-28', end_date: '2014-03-02'
      sheet = Spreadsheet.open(@t.path).worksheet 0
      
      sheet = Spreadsheet.open(@t.path).worksheet 0
      expect(sheet.row(1)[9]).to eq 5.0
      expect(sheet.row(2)[9]).to be_nil
    end

    it "excludes entries with invoices that zero each other out" do
      other_invoice = Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: @entry, invoice_date: '2014-03-01'), charge_amount: -5).broker_invoice

      @t = described_class.new.run Factory(:user, time_zone: "Eastern Time (US & Canada)"), start_date: '2014-02-28', end_date: '2014-03-02'
      sheet = Spreadsheet.open(@t.path).worksheet 0
      expect(sheet.rows.length).to eq 1
    end
  end
end