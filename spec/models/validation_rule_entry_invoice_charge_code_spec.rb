describe ValidationRuleEntryInvoiceChargeCode do
    before :each do
      @entry = create(:entry)
      @inv_no_suffix = create(:broker_invoice, entry: @entry)
      create(:broker_invoice_line, broker_invoice: @inv_no_suffix, charge_code: '123', charge_amount: 5)
      create(:broker_invoice_line, broker_invoice: @inv_no_suffix, charge_code: '456', charge_amount: 10)

      @inv_suffix = create(:broker_invoice, entry: @entry, suffix: 'AB')
      create(:broker_invoice_line, broker_invoice: @inv_suffix, charge_code: '123', charge_amount: 5)
      create(:broker_invoice_line, broker_invoice: @inv_suffix, charge_code: '123', charge_amount: 10)
      create(:broker_invoice_line, broker_invoice: @inv_suffix, charge_code: '456', charge_amount: 15)

      create(:broker_invoice_line, charge_code: '999', charge_amount: 17) # unrelated entry
    end

  describe "run_validation" do

    it "passes if invoice lines with white-listed charge codes have a non-zero sum" do
      rule = ValidationRuleEntryInvoiceChargeCode.new(rule_attributes_json: {charge_codes: ['123', '456', '789']}.to_json)
      expect(rule.run_validation(@entry)).to be_nil
    end

    it "fails if invoice lines with black-listed charge codes have a non-zero sum" do
      rule = ValidationRuleEntryInvoiceChargeCode.new(rule_attributes_json: {blacklist_charge_codes: ['123', '456', '789']}.to_json)

      expect(rule.run_validation(@entry)).to eq "The following invalid charge codes were found: 123, 456"
    end

    it "passes if invoice lines without blacklisted charge codes have a non-zero sum" do
      rule = ValidationRuleEntryInvoiceChargeCode.new(rule_attributes_json: {blacklist_charge_codes: ['123', '456', '789']}.to_json)
      create(:broker_invoice_line, broker_invoice: @inv_suffix, charge_code: '123', charge_amount: -20)
      create(:broker_invoice_line, broker_invoice: @inv_suffix, charge_code: '456', charge_amount: -25)
      expect(rule.run_validation(@entry)).to be_nil
    end

    it "passes if suffix-filtered invoice lines with white-listed charge codes have a non-zero sum" do
      rule = ValidationRuleEntryInvoiceChargeCode.new(rule_attributes_json: {charge_codes: ['123'],
                                                                             filter: 'suffix'}.to_json)
      create(:broker_invoice_line, broker_invoice: @inv_suffix, charge_code: '456', charge_amount: -15)
      expect(rule.run_validation(@entry)).to be_nil
    end

    it "passes if non-suffix-filtered invoice lines with white-listed charge codes have a non-zero sum" do
      rule = ValidationRuleEntryInvoiceChargeCode.new(rule_attributes_json: {charge_codes: ['123'],
                                                                             filter: 'no_suffix'}.to_json)
      create(:broker_invoice_line, broker_invoice: @inv_no_suffix, charge_code: '456', charge_amount: -10)
      expect(rule.run_validation(@entry)).to be_nil
    end
  end

  describe "query" do
    before :each do
      @results = []
      @rule = ValidationRuleEntryInvoiceChargeCode.new(rule_attributes_json: {charge_codes: ['123', '456', '789']}.to_json)
    end

    it "sums amounts for each charge code of every invoice associated with an entry" do
      @rule.query(@entry.id).each { |row| @results << row }
      expect(@results).to eq [{'charge_code' => '123', 'amount' => 20}, {'charge_code' => '456', 'amount' => 25}]
    end

    it "sums amounts for each charge code of every suffixed invoice" do
      @rule.query(@entry.id, 'suffix').each { |row| @results << row }
      expect(@results).to eq [{'charge_code' => '123', 'amount' => 15}, {'charge_code' => '456', 'amount' => 15}]
    end

    it "sums amounts for each charge code of every non-suffixed invoice" do
      @rule.query(@entry.id, 'no_suffix').each { |row| @results << row }
      expect(@results).to eq [{'charge_code' => '123', 'amount' => 5}, {'charge_code' => '456', 'amount' => 10}]
    end
  end

  describe "check_list" do
    before :each do
      @rule = ValidationRuleEntryInvoiceChargeCode.new(rule_attributes_json: {charge_codes: ['123', '456', '789']}.to_json)
      @totals = [{'charge_code' => '123', 'amount' => 5},
                {'charge_code' => '777', 'amount' => 14},
                {'charge_code' => '888', 'amount' => 0},
                {'charge_code' => '999', 'amount' => 10}]
    end
    it "returns codes not appearing on white list when associated amount greater than 0" do
      expect(@rule.check_list(@totals, ['123', '888', '999'], :white)).to eq ['777']
    end

    it "returns codes appearing on black list when associated amount greater than 0" do
      expect(@rule.check_list(@totals, ['123', '888', '999'], :black)).to eq ['123', '999']
    end
  end

end
