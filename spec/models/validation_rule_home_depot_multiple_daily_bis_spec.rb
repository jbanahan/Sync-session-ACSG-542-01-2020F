describe ValidationRuleHomeDepotMultipleDailyBis do
  before(:each) do
    @rule = described_class.new

    @e = Factory(:entry)
  end

  describe "run_validation" do
    it "passes if there are no duplicate broker invoices on a day" do
      Timecop.freeze(Date.today) do
        bi1 = Factory(:broker_invoice, invoice_date: Date.today, invoice_number: "123456789/A", entry: @e)
        bi2 = Factory(:broker_invoice, invoice_date: Date.today - 1.day, invoice_number: "123456789/B", entry: @e)

        expect(@rule.run_validation(@e)).to be_falsey
      end
    end

    it "fails if multiple matching broker invoices come in one day" do
      Timecop.freeze(Date.today) do
        today_string = Date.today.strftime("%m/%d/%Y")

        bi1 = Factory(:broker_invoice, invoice_date: Date.today, invoice_number: "123456789/A", entry: @e)
        bi2 = Factory(:broker_invoice, invoice_date: Date.today, invoice_number: "123456789/B", entry: @e)

        expect(@rule.run_validation(@e)).to eql(["123456789/A, 123456789/B were all sent on #{today_string}"])
      end
    end

    it "handles multiple days" do
      Timecop.freeze(Date.today) do
        today_string = Date.today.strftime("%m/%d/%Y")
        yesterday_string = (Date.today - 1.day).strftime("%m/%d/%Y")

        bi1 = Factory(:broker_invoice, invoice_date: Date.today, invoice_number: "123456789/A", entry: @e)
        bi2 = Factory(:broker_invoice, invoice_date: Date.today, invoice_number: "123456789/B", entry: @e)
        bi3 = Factory(:broker_invoice, invoice_date: Date.today - 1.day, invoice_number: "123456799/A", entry: @e)
        bi4 = Factory(:broker_invoice, invoice_date: Date.today - 1.day, invoice_number: "123456799/B", entry: @e)

        expect(@rule.run_validation(@e)).to eql(["123456789/A, 123456789/B were all sent on #{today_string}", "123456799/A, 123456799/B were all sent on #{yesterday_string}"])
      end
    end
  end
end