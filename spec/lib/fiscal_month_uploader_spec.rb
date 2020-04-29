describe OpenChain::FiscalMonthUploader do
  describe "process" do
    before do
      @u = Factory(:user)
      @imp = Factory(:company)
      @ent = Factory(:entry, importer: @imp, release_date: Date.new(2016, 1, 15))
      @row_0 = ['Fiscal Year', 'Fiscal Month', 'Actual Start Date', 'Actual End Date']
      @row_1 = ['2017', '1', '2016-01-01', '2016-01-31']
      @row_2 = ['2017', '2', '2016-02-01', '2016-02-29']

      @cf = double("Custom File")
      allow(@cf).to receive(:path).and_return "path/to/fm_upload.xls"
      allow(@cf).to receive(:id).and_return 1
      @handler = described_class.new @cf
    end

    it "creates new fiscal months from spreadsheet" do
      expect(@handler).to receive(:foreach).with(@cf, {skip_blank_lines:true}).and_yield(@row_0, 0).and_yield(@row_1, 1).and_yield(@row_2, 2)
      expect { @handler.process @u, company_id: @imp.id }.to change(FiscalMonth, :count).from(0).to(2)
      fm1, fm2 = FiscalMonth.all
      expect(fm1.year).to eq 2017
      expect(fm1.month_number).to eq 1
      expect(fm1.start_date).to eq Date.new(2016, 01, 01)
      expect(fm1.end_date).to eq Date.new(2016, 01, 31)

      expect(fm2.year).to eq 2017
      expect(fm2.month_number).to eq 2
      expect(fm2.start_date).to eq Date.new(2016, 02, 01)
      expect(fm2.end_date).to eq Date.new(2016, 02, 29)
    end

    it "updates existing fiscal months from spreadsheet" do
      row_1 = ['2017', '2', '2016-02-15', '2016-02-25']
      Factory(:fiscal_month, company: @imp, year: 2017, month_number: 1, start_date: Date.new(2016, 01, 01), end_date: Date.new(2016, 01, 31))
      Factory(:fiscal_month, company: @imp, year: 2017, month_number: 2, start_date: Date.new(2016, 02, 01), end_date: Date.new(2016, 02, 29))

      expect(@handler).to receive(:foreach).with(@cf, {skip_blank_lines:true}).and_yield(@row_0, 0).and_yield(row_1, 1)
      expect(FiscalMonth.count).to eq 2
      expect { @handler.process @u, company_id: @imp.id }.not_to change(FiscalMonth, :count)
      fm1, fm2 = FiscalMonth.all # fm1 unchanged, fm2 updated
      expect(fm1.year).to eq 2017
      expect(fm1.month_number).to eq 1
      expect(fm1.start_date).to eq Date.new(2016, 01, 01)
      expect(fm1.end_date).to eq Date.new(2016, 01, 31)

      expect(fm2.year).to eq 2017
      expect(fm2.month_number).to eq 2
      expect(fm2.start_date).to eq Date.new(2016, 02, 15)
      expect(fm2.end_date).to eq Date.new(2016, 02, 25)
    end

    it "creates user message for an invalid date" do
      row_1 = ['2017', '2', '2016-02-15', 'blah']
      expect(@handler).to receive(:foreach).with(@cf, {skip_blank_lines:true}).and_yield(@row_0, 0).and_yield(row_1, 1)
      @handler.process @u, company_id: @imp.id
      message = @u.messages.first
      expect(message.subject).to eq 'Fiscal-month uploader generated errors'
      expect(message.body).to eq 'Fiscal-month uploader generated errors on the following row(s): 2. Check the date format.'
    end

    it "raises exception for file-type other than csv, xls, xlsx" do
      allow(@cf).to receive(:path).and_return "path/to/fm_upload.txt"
      handler = described_class.new @cf
      expect { handler.process @u, company_id: @imp.id }.to raise_error ArgumentError, "Only XLS, XLSX, and CSV files are accepted."
    end
  end

end