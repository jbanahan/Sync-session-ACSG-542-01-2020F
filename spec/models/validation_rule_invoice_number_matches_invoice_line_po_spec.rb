describe ValidationRuleInvoiceNumberMatchesInvoiceLinePO do
  describe "run_child_validation" do
    before do
      @invoice = Factory(:commercial_invoice, invoice_number: "12345678910")
      @rule = described_class.new
    end

    it 'passes if the first 8 digits of the commercial invoice line does match the first 8 digits of the invoice' do
      invoice_line = Factory(:commercial_invoice_line, commercial_invoice: @invoice, po_number: '12345678910')

      expect(@rule.run_child_validation(invoice_line)).to be_nil
    end

    it 'fails if the first 8 digits of the commercial invoice line does not match the first 8 digits of the invoice' do
      invoice_line = Factory(:commercial_invoice_line, commercial_invoice: @invoice, po_number: '23456789010')

      expect(@rule.run_child_validation(invoice_line)).to include("does not match invoice number 12345678910")
    end
  end
end