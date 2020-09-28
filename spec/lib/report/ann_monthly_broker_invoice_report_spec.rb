describe OpenChain::Report::AnnMonthlyBrokerInvoiceReport do
  subject { described_class.new }

  let(:ent) { Factory(:entry, po_numbers: "INV NUM\n INV NUM2", importer: Factory(:company, system_code: "ATAYLOR"), first_entry_sent_date: Date.new(2017, 3, 15)) }
  let(:inv) { Factory(:broker_invoice, entry: ent, invoice_date: Date.new(2017, 3, 15), invoice_number: "INV NUM", invoice_total: 100) }
  let(:line) { Factory(:broker_invoice_line, broker_invoice: inv, charge_description: "Foo Debit", charge_amount: 90) }
  let(:line2) { Factory(:broker_invoice_line, broker_invoice: inv, charge_description: "Customs Entry", charge_amount: 10) }
  let(:inv2) { Factory(:broker_invoice, entry: ent, invoice_date: Date.new(2017, 3, 15), invoice_number: "INV NUM2", invoice_total: -25) }
  let(:line3) { Factory(:broker_invoice_line, broker_invoice: inv2, charge_description: "Bar Credit", charge_amount: -25) }

  let(:raw_row_1) do
    ["", "1100", "1003709", Date.new(2017, 3, 15), "", "INV NUM", 100, "USD", "", "Foo Debit", Date.new(2017, 3, 15), "USD1",
     "INV NUM\n INV NUM2", "INV NUM", "200190", "S", 90, "U1", "Foo Debit", "", "309401", ""]
  end
  let(:raw_row_2) do
    ["", "1100", "1003709", Date.new(2017, 3, 15), "", "INV NUM", 100, "USD", "", "Customs Entry", Date.new(2017, 3, 15), "USD1",
     "INV NUM\n INV NUM2", "INV NUM", "200190", "S", 10, "U1", "Customs Entry", "", "309401", ""]
  end
  let(:raw_row_3) do
    ["", "1100", "1003709", Date.new(2017, 3, 15), "", "INV NUM2", 25, "USD", "", "Bar Credit", Date.new(2017, 3, 15), "USD1",
    "INV NUM\n INV NUM2", "INV NUM2", "200190", "H", 25, "U1", "Bar Credit", "", "309401", ""]
  end

  describe "query" do
    before { line; line2; line3 }

    it "returns expected data" do
      # data for another importer
      ent2 = Factory(:entry)
      inv3 = Factory(:broker_invoice, entry: ent2, invoice_date: Date.new(2017, 3, 15), invoice_total: 50)
      Factory(:broker_invoice_line, broker_invoice: inv3, charge_description: "Customs Entry", charge_amount: 50)

      q = subject.query(ent.importer.id, '2017-03-01', '2017-03-31')
      res = ActiveRecord::Base.connection.execute q
      expect(res.fields).to eq ["ID Column", "Company Code", "Vendor Number", "Invoice Date in Document", "Posting Date in Document",
                                "Invoice Number", "Invoice Total Amount", "Currency Key", "Tax Amount", "Item Text (Description)", "Baseline Date",
                                "Partner Bank Type", "Assignment Number", "Invoice Number", "General Ledger Account", "Debit/Credit Indicator",
                                "Amount in Document Currency", "Sales Tax Code", "Item Text", "Cost Center", "Profit Center", "BLANK FIELD"]
      results = []
      res.each { |r| results << r }
      expect(results.count).to eq 3
      first, second, third = results
      expect(first).to eq raw_row_1
      expect(second).to eq raw_row_2
      expect(third).to eq raw_row_3
    end

    it "doesn't return invoices outside the specified range" do
      q = subject.query(ent.importer.id, '2017-03-01', '2017-03-02')
      res = ActiveRecord::Base.connection.execute q
      expect(res.count).to eq 0
    end

    it "doesn't return entries without a first_entry_sent_date" do
      ent.update! first_entry_sent_date: nil
      q = subject.query(ent.importer.id, '2017-03-01', '2017-03-31')
      res = ActiveRecord::Base.connection.execute q
      expect(res.count).to eq 0
    end

    it "doesn't return invoice lines with charge_type 'D'" do
      line2.update! charge_type: 'D'
      q = subject.query(ent.importer.id, '2017-03-01', '2017-03-31')
      res = ActiveRecord::Base.connection.execute q
      results = []
      res.each { |r| results << r }
      first, second = results
      expect(first).to eq raw_row_1
      expect(second).to eq raw_row_3
    end
  end

  describe "arrange_rows" do
    it "turns raw data into header/detail rows" do
      # Unrealistic invoice-number data. The point is the insertion of the header/detail indicator and the sorting by description with 'Customs Entry' at the top
      expect(subject.arrange_rows([raw_row_1, raw_row_2, raw_row_3])).to eq [
        ["H", "1100", "1003709", Date.new(2017, 3, 15), "", "INV NUM", 100, "USD", "", "Customs Entry", Date.new(2017, 3, 15), "USD1",
          "INV NUM\n INV NUM2", "INV NUM", "200190", "S", 10, "U1", "Customs Entry", "", "309401", ""],
        ["D", "1100", "1003709", Date.new(2017, 3, 15), "", "INV NUM2", "", "USD", "", "Bar Credit", Date.new(2017, 3, 15), "USD1",
          "INV NUM\n INV NUM2", "INV NUM2", "200190", "H", 25, "U1", "Bar Credit", "", "309401", ""],
        ["D", "1100", "1003709", Date.new(2017, 3, 15), "", "INV NUM", "", "USD", "", "Foo Debit", Date.new(2017, 3, 15), "USD1",
          "INV NUM\n INV NUM2", "INV NUM", "200190", "S", 90, "U1", "Foo Debit", "", "309401", ""]]
    end
  end

  describe "compile_invoices" do
    it "chunks query results by invoice" do
      invoice1_raw = [["", "", "", "", "", "INV NUM1", "", "", "", "Foo Debit"],
                      ["", "", "", "", "", "INV NUM1", "", "", "", "Bar Debit"],
                      ["", "", "", "", "", "INV NUM1", "", "", "", "Baz Debit"]]
      invoice2_raw = [["", "", "", "", "", "INV NUM2", "", "", "", "Quux Debit"]]
      invoice3_raw = [["", "", "", "", "", "INV NUM3", "", "", "", "Fribble Debit"]]
      expect(subject).to receive(:arrange_rows).with(invoice1_raw).and_return [:invoice1]
      expect(subject).to receive(:arrange_rows).with(invoice2_raw).and_return [:invoice2]
      expect(subject).to receive(:arrange_rows).with(invoice3_raw).and_return [:invoice3]

      expect(subject.compile_invoices(invoice1_raw + invoice2_raw + invoice3_raw)).to eq([:invoice1, :invoice2, :invoice3])
    end
  end

  describe 'run_schedulable' do
    before { line; line2; line3 }

    it "sends email w/ correct data" do
      Timecop.freeze(DateTime.new(2017, 4, 2)) do
        described_class.run_schedulable('email' => 'tufnel@stonehenge.biz', 'cc' => ['st-hubbins@hellhole.co.uk', 'smalls@sharksandwich.net'])
      end
      expect(ActionMailer::Base.deliveries.size).to eq 1
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['tufnel@stonehenge.biz']
      expect(mail.cc).to eq ['st-hubbins@hellhole.co.uk', 'smalls@sharksandwich.net']
      expect(mail.subject).to eq "Ann Inc. Monthly Broker Invoice Report – 03-2017"
      expect(mail.body.raw_source).to match(/Attached is the completed report named "Ann Inc. Monthly Broker Invoice Report – 03-2017.xls"/)
      expect(mail.attachments.size).to eq 1
      att = mail.attachments['Ann Inc. Monthly Broker Invoice Report – 03-2017.xls']
      expect(att).not_to be_nil
      Tempfile.open('att') do |t|
        t.binmode
        t << att.read
        t.flush
        wb = XlsMaker.open_workbook t.path
        sheet = wb.worksheet(0)
        expect(sheet.row(0)).to eq(described_class::HEADER)
        expect(sheet.row(1)).to eq ["H", "1100", "1003709", "03-15-17", nil, "INV NUM", "100.0", "USD", nil, "Customs Entry", "03-15-17",
          "USD1", "INV NUM", "INV NUM", "200190", "S", "10.0", "U1", "Customs Entry", nil, "309401", nil]
        expect(sheet.row(2)).to eq ["D", "1100", "1003709", "03-15-17", nil, "INV NUM", nil, "USD", nil, "Foo Debit", "03-15-17",
          "USD1", "INV NUM", "INV NUM", "200190", "S", "90.0", "U1", "Foo Debit", nil, "309401", nil]
        expect(sheet.row(3)).to eq ["H", "1100", "1003709", "03-15-17", nil, "INV NUM2", "25.0", "USD", nil, "Bar Credit", "03-15-17",
          "USD1", "INV NUM", "INV NUM2", "200190", "H", "25.0", "U1", "Bar Credit", nil, "309401", nil]
      end
    end
  end

  it "throws exception if ATAYLOR not found" do
    imp = ent.importer
    imp.system_code = "FOO"; imp.save!
    expect {described_class.run_schedulable('email' => 'tufnel@stonehenge.biz')}.to raise_error "Importer not found!"
  end

end
