describe SummaryStatementsHelper do
  before(:each) do
    @company = create(:company)
    @sum_stat= create(:summary_statement, customer: @company)
  end

  describe "render_summary_xls" do
    it "renders statement header" do
      ent = create(:entry, importer: @company)
      broker_inv = create(:broker_invoice, summary_statement: @sum_stat, entry: ent, invoice_total: 150)
      wb = helper.render_summary_xls @sum_stat
      sheet = wb.worksheets.first

      expect(sheet.row(0)).to eq ["Company:", @company.name]
      expect(sheet.row(1)).to eq ["Statement:", @sum_stat.statement_number]
      expect(sheet.row(2)).to eq ["Total:", broker_inv.invoice_total]

    end

    it "renders data for US invoices" do
      ent = create(:entry, importer: @company, import_country: create(:country, iso_code: 'US'),
                    entry_number: "1357911", release_date: Date.today - 1, monthly_statement_due_date: Date.today + 1)
      bi = create(:broker_invoice, summary_statement: @sum_stat, entry: ent, invoice_number: "987654321",
                    invoice_date: Date.today - 1, invoice_total: 150, bill_to_name: @company.name)

      wb = helper.render_summary_xls @sum_stat
      sheet = wb.worksheets.first

      expect(sheet.row(4)).to eq ["Invoice Number", "Invoice Date", "Amount", "Customer Name", "Entry Number", "Bill To Name", "Release Date", "PMS Month"]
      expect(sheet.row(5)).to eq [bi.invoice_number, bi.invoice_date, bi.invoice_total, @company.name, ent.entry_number, bi.bill_to_name,
                                  ent.release_date, ent.monthly_statement_due_date, "Web View"] # can't access link in last field
    end

    it "renders data for CA invoices" do
      ent = create(:entry, importer: @company, import_country: create(:country, iso_code: 'CA'),
                     entry_number: "246810", k84_month: 5, cadex_accept_date: Time.zone.parse("2015-12-02 13:50"))
      bi = create(:broker_invoice, summary_statement: @sum_stat, entry: ent, invoice_number: "123456789",
                   invoice_date: Date.today, invoice_total: 100, bill_to_name: @company.name)

      wb = helper.render_summary_xls @sum_stat
      sheet = wb.worksheets.first

      expect(sheet.row(4)).to eq ["Invoice Number", "Invoice Date", "Amount", "Customer Name", "Entry Number", "Bill To Name", "K84 Month", "Cadex Accept Date"]
      expect(sheet.row(5)).to eq [bi.invoice_number, bi.invoice_date, bi.invoice_total, @company.name, ent.entry_number, bi.bill_to_name,
                                  ent.k84_month, ent.cadex_accept_date, "Web View"] # can't access link in last field
    end
  end

end

