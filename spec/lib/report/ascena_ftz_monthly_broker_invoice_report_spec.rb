describe OpenChain::Report::AscenaFtzMonthlyBrokerInvoiceReport do
  subject { described_class.new("ASCE") }

  let(:ascena) { with_customs_management_id(Factory(:company), "ASCE") }
  let(:ent) { Factory(:entry, entry_type: "06", po_numbers: "INV NUM\n INV NUM2", importer: ascena, first_entry_sent_date: Date.new(2017, 3, 15)) }
  let(:ci) { Factory(:commercial_invoice, entry: ent) }
  let(:cil) { Factory(:commercial_invoice_line, commercial_invoice: ci, po_number: nil)}

  let(:bi) { Factory(:broker_invoice, entry: ent, invoice_date: Date.new(2017, 3, 15), invoice_number: "INV NUM", invoice_total: 100) }
  let(:bil) { Factory(:broker_invoice_line, broker_invoice: bi, charge_description: "Foo Debit", charge_amount: 90) }
  let(:bil2) { Factory(:broker_invoice_line, broker_invoice: bi, charge_description: "Customs Entry", charge_amount: 10) }
  let(:bi2) { Factory(:broker_invoice, entry: ent, invoice_date: Date.new(2017, 3, 15), invoice_number: "INV NUM2", invoice_total: -25) }
  let(:bil3) { Factory(:broker_invoice_line, broker_invoice: bi2, charge_description: "Bar Credit", charge_amount: -25) }

  let(:raw_row_1) do
      ["", "", "77519", Date.new(2017, 3, 15), "", "INV NUM", 100, "USD", "", "Foo Debit", Date.new(2017, 3, 15), "USD1", "", "INV NUM", "",
       "S", 90, "U1", "Foo Debit", "", "", ""]
  end

  let(:raw_row_2) do
    ["", "", "77519", Date.new(2017, 3, 15), "", "INV NUM", 100, "USD", "", "Customs Entry", Date.new(2017, 3, 15), "USD1", "", "INV NUM", "",
     "S", 10, "U1", "Customs Entry", "", "", ""]
  end

  let(:raw_row_3) do
    ["", "", "77519", Date.new(2017, 3, 15), "", "INV NUM2", 25, "USD", "", "Bar Credit", Date.new(2017, 3, 15), "USD1", "", "INV NUM2", "",
     "H", 25, "U1", "Bar Credit", "", "", ""]
  end

  def wrap row
    described_class::Wrapper.new row
  end

  def wrap_all rows
    described_class::Wrapper.wrap_all rows
  end

  def unwrap_all rows
    described_class::Wrapper.unwrap_all rows
  end

  describe "query" do
    before { bil; bil2; bil3; cil }

    it "returns expected type 06 data" do
      # data for another importer
      ent2 = Factory(:entry, importer: Factory(:company), entry_type: "06", first_entry_sent_date: Date.new(2017, 3, 15))
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

    it "returns expected type 01 data" do
      ent.update! entry_type: "01"

      q = subject.query(ent.importer.id, '2017-03-01', '2017-03-31')
      res = ActiveRecord::Base.connection.execute q

      results = []
      res.each { |r| results << r }
      expect(results.count).to eq 3
    end

    it "doesn't return data for type 01 entries that have a PO" do
      ent.update! entry_type: "01"
      cil.update! po_number: "123"

      q = subject.query(ent.importer.id, '2017-03-01', '2017-03-31')
      res = ActiveRecord::Base.connection.execute q

      results = []
      res.each { |r| results << r }
      expect(results.count).to eq 0
    end

    it "doesn't return invoices outside the specified range" do
      q = subject.query(ent.importer.id, '2017-03-01', '2017-03-02')
      res = ActiveRecord::Base.connection.execute q
      expect(res.count).to eq 0
    end

    it "doesn't return entries without a first_entry_sent_date, with the exception of ISF" do
      ent.update! first_entry_sent_date: nil
      q = subject.query(ent.importer.id, '2017-03-01', '2017-03-31')
      res = ActiveRecord::Base.connection.execute q
      expect(res.count).to eq 0

      bil.update! charge_code: "0191"
      q = subject.query(ent.importer.id, '2017-03-01', '2017-03-31')
      res = ActiveRecord::Base.connection.execute q
      expect(res.count).to eq 1
    end

    it "doesn't return entries of types other than 01, 06" do
      ent.update! entry_type: "05"
      q = subject.query(ent.importer.id, '2017-03-01', '2017-03-31')
      res = ActiveRecord::Base.connection.execute q
      expect(res.count).to eq 0
    end

    it "doesn't return invoice lines with charge_type 'D'" do
      bil2.update! charge_type: 'D'
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
      rows = wrap_all [raw_row_1, raw_row_2, raw_row_3]
      wrapped = subject.arrange_rows(rows)
      unwrapped = unwrap_all wrapped
      expect(unwrapped).to eq [["H", "", "77519", Date.new(2017, 3, 15), "", "INV NUM", 100, "USD", "", "Customs Entry", Date.new(2017, 3, 15),
                                "USD1", "", "INV NUM", "", "S", 10, "U1", "Customs Entry", "", "", ""],
                               ["D", "", "77519", Date.new(2017, 3, 15), "", "INV NUM2", "", "USD", "", "Bar Credit", Date.new(2017, 3, 15),
                                "USD1", "", "INV NUM2", "", "H", 25, "U1", "Bar Credit", "", "", ""],
                               ["D", "", "77519", Date.new(2017, 3, 15), "", "INV NUM", "", "USD", "", "Foo Debit", Date.new(2017, 3, 15),
                                "USD1", "", "INV NUM", "", "S", 90, "U1", "Foo Debit", "", "", ""]]
    end
  end

  describe "compile_invoices" do
    it "chunks query results by invoice" do
      invoice1 = wrap_all([["", "", "", "", "", "INV NUM1", "", "", "", "Foo Debit"],
                           ["", "", "", "", "", "INV NUM1", "", "", "", "Bar Debit"],
                           ["", "", "", "", "", "INV NUM1", "", "", "", "Baz Debit"]])
      invoice2 = wrap_all([["", "", "", "", "", "INV NUM2", "", "", "", "Quux Debit"]])
      invoice3 = wrap_all([["", "", "", "", "", "INV NUM3", "", "", "", "Fribble Debit"]])
      expect(subject).to receive(:arrange_rows).with(invoice1).and_return [:invoice1]
      expect(subject).to receive(:arrange_rows).with(invoice2).and_return [:invoice2]
      expect(subject).to receive(:arrange_rows).with(invoice3).and_return [:invoice3]

      expect(subject.compile_invoices(invoice1 + invoice2 + invoice3)).to eq([:invoice1, :invoice2, :invoice3])
    end
  end

  describe 'run_schedulable' do
    before { bil; bil2; bil3 }

    it "sends email w/ correct data" do
      Timecop.freeze(DateTime.new(2017, 4, 2)) do
        described_class.run_schedulable('customer_number' => 'ASCE', 'email' => 'tufnel@stonehenge.biz',
                                        'cc' => ['st-hubbins@hellhole.co.uk', 'smalls@sharksandwich.net'])
      end
      expect(ActionMailer::Base.deliveries.size).to eq 1
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['tufnel@stonehenge.biz']
      expect(mail.cc).to eq ['st-hubbins@hellhole.co.uk', 'smalls@sharksandwich.net']
      expect(mail.subject).to eq "Ascena Monthly FTZ Broker Invoice Report - 03-2017"
      expect(mail.body.raw_source).to match(/Attached is the completed report named "Ascena Monthly FTZ Broker Invoice Report - 03-2017.xls"/)
      expect(mail.attachments.size).to eq 1
      att = mail.attachments['Ascena Monthly FTZ Broker Invoice Report - 03-2017.xlsx']
      expect(att).not_to be_nil
      Tempfile.open('att') do |t|
        t.binmode
        t << att.read
        t.flush
        reader = XlsxTestReader.new(t.path).raw_workbook_data
        sheet = reader["03-2017 Detail"]

        date = ActiveSupport::TimeZone["UTC"].local(2017, 3, 15)
        expect(sheet[0]).to eq(subject.column_names)
        expect(sheet[1]).to eq ["H", "", "77519", date, "", "INV NUM", 100.0, "USD", "", "Customs Entry", date, "USD1", "",
                                "INV NUM", "", "S", 10.0, "U1", "Customs Entry", "", "", ""]
        expect(sheet[2]).to eq ["D", "", "77519", date, "", "INV NUM", "", "USD", "", "Foo Debit", date, "USD1", "",
                                "INV NUM", "", "S", 90.0, "U1", "Foo Debit", "", "", ""]
        expect(sheet[3]).to eq ["H", "", "77519", date, "", "INV NUM2", 25.0, "USD", "", "Bar Credit", date, "USD1", "",
                                "INV NUM2", "", "H", 25.0, "U1", "Bar Credit", "", "", ""]

        sheet = reader["03-2017 Summary"]
        expect(sheet[0]).to eq ["Vendor Number", "Invoice Date", "Invoice Number", "Invoice Total", "IOR"]
        expect(sheet[1]).to eq ["77519", Date.new(2017, 4, 2), "ATS-FTZ042017", 75, "ATS"]

        sheet = reader["VFI - Internal Use Only"]
        expect(sheet[0]).to eq ["Broker Invoice Date", "Invoice Number", "Invoice Total Amount"]

        expect(sheet[1]).to eq [date, "INV NUM", 100]
        expect(sheet[2]).to eq [date, "INV NUM2", -25]
      end
    end
  end

  it "throws exception if ASCE not found" do
    ascena.system_identifiers.first.update! code: "FOO"
    expect {described_class.run_schedulable('customer_number' => 'ASCE', 'email' => 'tufnel@stonehenge.biz')}.to raise_error "Importer not found!"
  end

end
