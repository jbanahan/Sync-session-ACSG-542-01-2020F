describe OpenChain::InvoiceGeneratorSupport do
  let(:generator) do
    Class.new { include OpenChain::InvoiceGeneratorSupport }.new
  end

  let(:detail) do
    d = Tempfile.new("detail")
    d.binmode
    d << "Detail content"
    d.rewind
    d
  end

  describe "email invoice" do
    it "creates and emails Excel invoice along with optional file" do
      co = Factory(:company, name: "ACME")
      inv = Factory(:vfi_invoice, customer: co, invoice_date: Date.new(2018, 1, 1), invoice_number: "inv num", currency: "USD")
      Factory(:vfi_invoice_line, vfi_invoice: inv, line_number: 1, charge_description: "descr", charge_amount: 10, charge_code: "CODE", quantity: 2, unit: "EA", unit_price: 5)

      generator.email_invoice inv, "tufnel@stonehenge.biz", "generator email", "invoice", detail

      expect(detail.closed?).to eq true
      expect(ActionMailer::Base.deliveries.count).to eq 1
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["tufnel@stonehenge.biz"]
      expect(mail.subject).to eq "generator email"
      expect(mail.attachments.count).to eq 2
      expect(mail.attachments["invoice.xls"]).not_to be_nil
      invoice_att, detail_att = mail.attachments
      expect(detail_att.filename).to match(/detail/)

      Tempfile.open('temp') do |t|
        t.binmode
        t << invoice_att.read
        t.flush
        wb = XlsMaker.open_workbook t.path
        sheet = wb.worksheet(0)
        expect(sheet.row(0)[0]).to eq "Customer Name:"
        expect(sheet.row(0)[1]).to eq "ACME"
        expect(sheet.row(2)[0]).to eq "Invoice Date:"
        expect(sheet.row(2)[1]).to eq inv.invoice_date
        expect(sheet.row(4)[0]).to eq "Invoice Number:"
        expect(sheet.row(4)[1]).to eq "inv num"
        expect(sheet.row(6)[0]).to eq "Currency:"
        expect(sheet.row(6)[1]).to eq "USD"
        expect(sheet.row(8)[0]).to eq "Total Charges:"
        expect(sheet.row(8)[1]).to eq 10

        expect(sheet.row(10)).to eq ["Line Number", "Description", "Quantity", "Unit", "Unit Price", "Charges"]
        expect(sheet.row(11)).to eq [1, "descr", 2, "EA", 5, 10]
      end

    end
  end

end
