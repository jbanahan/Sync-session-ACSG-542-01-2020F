describe OpenChain::CustomHandler::AnnInc::AnnFirstSaleValidationRule do
  let(:rule) { described_class.new }
  let(:imp) { Factory(:company, system_code: "ATAYLOR") }
  let(:ci) { Factory(:commercial_invoice, entry: Factory(:entry, importer: imp), invoice_number: "INV123") }
  let!(:cil) { Factory(:commercial_invoice_line, commercial_invoice: ci, line_number: 1, po_number: "PO123", part_number: "PART123", non_dutiable_amount: nil)}
  let(:cust_inv) { Invoice.create!(importer: imp, invoice_number: "INV123") }
  let!(:cust_il) { InvoiceLine.create!(invoice: cust_inv, po_number: "PO123", part_number: "PART123", line_number: 1, middleman_charge: nil, air_sea_discount: nil, trade_discount: nil, early_pay_discount: nil) }

  describe "run_validation" do
    it "returns error for commercial invoices without matching customer invoice" do
      cust_inv.update_attributes! invoice_number: "FOO"
      expect(rule).to_not receive(:run_tests)
      expect(rule.run_validation ci.entry).to eq "No matching customer invoice was found for commercial invoice INV123.\n"
    end

    it "returns error for commercial-invoice lines without matching customer-invoice lines" do
      allow(rule).to receive(:first_sale?).with(cil).and_return true
      cil.update_attributes! non_dutiable_amount: 1
      cust_il.update_attributes! air_sea_discount: 6, middleman_charge: 5, po_number: "FOO"
      line1 = "Errors found on commercial invoice INV123:\n"
      line2 = "On line 1, no matching customer invoice line found with PO number PO123 and part number PART123."
      expect(rule.run_validation ci.entry).to eq (line1 + line2)
    end

    it "returns errors" do
      allow(rule).to receive(:first_sale?).with(cil).and_return true
      cust_il.update_attributes! air_sea_discount: 6, middleman_charge: 5
      line1 = "Errors found on commercial invoice INV123:\n"
      line2 = "On line 1, First Sale amount of 5.0 is less than Other Discounts amount of 6.0, but First Sale flag is set to True.\n"
      line3 = "On line 1, First Sale flag is set, but no First Sale value was entered."
      expect(rule.run_validation ci.entry).to eq (line1 + line2 + line3)
    end
  end

  describe "run_tests" do
    it "runs tests and concatenates the results with two newlines" do
      expect(rule).to receive(:fs_flag_is_false).with(ci, cust_inv).and_return 'a'
      expect(rule).to receive(:fs_flag_is_true).with(ci, cust_inv).and_return 'b'
      expect(rule).to receive(:fs_value_set).with(ci).and_return 'c'
      expect(rule).to receive(:fs_not_applied).with(ci, cust_inv).and_return 'd'
      expect(rule).to receive(:fs_on_invoices_match).with(ci, cust_inv).and_return 'e'
      expect(rule).to receive(:fs_is_only_discount).with(ci).and_return 'f'
      expect(rule).to receive(:fs_applied_instead_of_ci_discount).with(ci, cust_inv).and_return 'g'
      expect(rule).to receive(:air_sea_eq_non_dutiable).with(ci, cust_inv).and_return 'h'
      expect(rule).to receive(:other_amount_eq_trade_discount).with(ci, cust_inv).and_return 'i'
      expect(rule).to receive(:early_pay_eq_misc_discount).with(ci, cust_inv).and_return 'j'
      expect(rule).to receive(:no_missing_discounts).with(ci, cust_inv).and_return 'k'
      expect(rule).to receive(:fs_applied_instead_of_cust_inv_discount).with(ci, cust_inv).and_return 'l'

      expect(rule.run_tests ci, cust_inv).to eq %Q(a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk\nl)
    end
  end

  describe "first_sale?" do
    it "returns False if contract_amount is missing" do
      cil.update_attributes! contract_amount: nil
      expect(rule.first_sale? cil).to eq false
    end

    it "returns False if contract_amount is 0" do
      cil.update_attributes! contract_amount: 0
      expect(rule.first_sale? cil).to eq false
    end

    it "returns True if contract amount is > 0" do
      cil.update_attributes! contract_amount: 1
      expect(rule.first_sale? cil).to eq true
    end

    it "returns True if contract amount is > 0" do
      cil.update_attributes! contract_amount: 1
      expect(rule.first_sale? cil).to eq true
    end
  end

  context "first sale flag" do
    describe "fs_flag_is_false" do
      before do
        allow(rule).to receive(:first_sale?).with(cil).and_return true
        cust_il.update_attributes! middleman_charge: 8, air_sea_discount: 9
      end

      it "returns message if first-sale and discount > middleman charges" do
        expect(rule.fs_flag_is_false ci, cust_inv).to eq "On line 1, First Sale amount of 8.0 is less than Other Discounts amount of 9.0, but First Sale flag is set to True."
      end

      it "returns nil when discounts are <= middleman charges" do
        cust_il.update_attributes! air_sea_discount: 7
        expect(rule.fs_flag_is_false ci, cust_inv).to be_nil
      end

      it "returns nil when not first-sale" do
        allow(rule).to receive(:first_sale?).with(cil).and_return false
        expect(rule.fs_flag_is_false ci, cust_inv).to be_nil
      end
    end

    describe "fs_flag_is_true" do
      before { cust_il.update_attributes! middleman_charge: 7, air_sea_discount: 6 }

      it "returns message when not first-sale and middleman-charge > discounts" do
        expect(rule.fs_flag_is_true ci, cust_inv).to eq "On line 1, First Sale amount of 7.0 is greater than Other Discounts amount of 6.0, but the First Sale flag is set to False."
      end

      it "returns nil when middleman charges are <= discounts" do
        cust_il.update_attributes! middleman_charge: 5
        expect(rule.fs_flag_is_true ci, cust_inv).to be_nil
      end

      it "returns nil when first-sale" do
        allow(rule).to receive(:first_sale?).with(cil).and_return true
        expect(rule.fs_flag_is_true ci, cust_inv).to be_nil
      end
    end
  end

  context "First sale discount" do
    describe "fs_value_set" do
      before { allow(rule).to receive(:first_sale?).with(cil).and_return true }

      it "returns message when first sale and no non-dutiable amount" do
        expect(rule.fs_value_set ci).to eq "On line 1, First Sale flag is set, but no First Sale value was entered."
      end

      it "returns nil when has non-dutiable amount" do
        cil.update_attributes! non_dutiable_amount: 3
        expect(rule.fs_value_set ci).to be_nil
      end

      it "returns nil when not first sale" do
        allow(rule).to receive(:first_sale?).with(cil).and_return false
        expect(rule.fs_value_set ci).to be_nil
      end
    end

    describe "fs_not_applied" do
      before do
        allow(rule).to receive(:first_sale?).with(cil).and_return true
        cil.update_attributes! non_dutiable_amount: 3
        cust_il.update_attributes! middleman_charge: 3, air_sea_discount: 4
      end

      it "returns message if first sale and non-dutiable exists and customer-invoice discounts > middleman charge" do
        expect(rule.fs_not_applied ci, cust_inv).to eq "On line 1, Other Discounts amount of 4.0 is greater than the First Sale amount of 3.0, but the First Sale discount was applied."
      end

      it "returns nil when not first sale" do
        allow(rule).to receive(:first_sale?).with(cil).and_return nil
        expect(rule.fs_not_applied ci, cust_inv).to be_nil
      end

      it "returns nil when non-dutiable is blank" do
        cil.update_attributes! non_dutiable_amount: nil
        expect(rule.fs_not_applied ci, cust_inv).to be_nil
      end

      it "returns nil when customer-invoice discounts <= middleman charges" do
        cust_il.update_attributes! middleman_charge: 5
        expect(rule.fs_not_applied ci, cust_inv).to be_nil
      end
    end

    describe "fs_on_invoices_match" do
      before do
        allow(rule).to receive(:first_sale?).with(cil).and_return true
        cil.update_attributes! non_dutiable_amount: 3
        cust_il.update_attributes! middleman_charge: 4
      end

      it "returns message if first sale and non-dutiable exists and is not equal to middleman charge" do
        expect(rule.fs_on_invoices_match ci, cust_inv).to eq "On line 1, First Sale amount of 4.0 should equal the Non-Dutiable amount of the commercial invoice, 3.0."
      end

      it "returns nil when not first sale" do
        allow(rule).to receive(:first_sale?).with(cil).and_return false
        expect(rule.fs_on_invoices_match ci, cust_inv).to be_nil
      end

      it "returns nil when there's no non-dutiable amount" do
        cil.update_attributes! non_dutiable_amount: nil
        expect(rule.fs_on_invoices_match ci, cust_inv).to be_nil
      end

      it "returns nil when non-dutiable equals middleman charge" do
        cil.update_attributes! non_dutiable_amount: 4
        expect(rule.fs_on_invoices_match ci, cust_inv).to be_nil
      end
    end

    describe "fs_is_only_discount" do
      before do
        allow(rule).to receive(:first_sale?).with(cil).and_return true
        cil.update_attributes! non_dutiable_amount: 3, miscellaneous_discount: 1, other_amount: -2
      end

      it "returns message if first sale and non-dutiable exists and sum of miscellaneous discount and other amount > 0" do
        expect(rule.fs_is_only_discount ci).to eq "On line 1, with First Sale Flag set to True only a Non-Dutiable amount greater than 0 is allowed. Other Discounts for the commercial invoice are 3.0."
      end

      it "returns nil when not first sale" do
        allow(rule).to receive(:first_sale?).with(cil).and_return false
        expect(rule.fs_is_only_discount ci).to be_nil
      end

      it "returns nil when non-dutiable doesn't exist" do
        cil.update_attributes! non_dutiable_amount: nil
        expect(rule.fs_is_only_discount ci).to be_nil
      end

      it "returns nil when there's no miscellaneous discount or other adjustment" do
        cil.update_attributes! miscellaneous_discount: nil, other_amount: nil
        expect(rule.fs_is_only_discount ci).to be_nil
      end
    end
  end

  context "other discounts" do
    before { allow(rule).to receive(:first_sale?).with(cil).and_return false }

    describe "fs_applied_instead_of_ci_discount" do
      before do
        cil.update_attributes! non_dutiable_amount: 3
        cust_il.update_attributes! air_sea_discount: 3, middleman_charge: 4
      end

      it "returns message if not first sale and commercial-invoice discounts exist and customer-invoice discounts are < middleman charge" do
        expect(rule.fs_applied_instead_of_ci_discount ci, cust_inv).to eq "On line 1, Other Discounts amount of 3.0 is less than First Sale Discount of 4.0, but was applied anyway."
      end

      it "returns nil if first sale" do
        allow(rule).to receive(:first_sale?).with(cil).and_return true
        expect(rule.fs_applied_instead_of_ci_discount ci, cust_inv).to be_nil
      end

      it "returns nil if there's no ci discount" do
        cil.update_attributes! non_dutiable_amount: nil
        expect(rule.fs_applied_instead_of_ci_discount ci, cust_inv).to be_nil
      end

      it "returns nil if customer-invoice discounts >= middleman charges" do
        cust_il.update_attributes! air_sea_discount: 4,  middleman_charge: 3
        expect(rule.fs_applied_instead_of_ci_discount ci, cust_inv).to be_nil
      end
    end

    describe "air_sea_eq_non_dutiable" do
      before do
        cil.update_attributes! other_amount: -2, non_dutiable_amount: 3
        cust_il.update_attributes! air_sea_discount: 4
      end

      it "returns message if not first sale and commercial-invoice discount exists and non-dutiable amount not equal to air/sea discount" do
        expect(rule.air_sea_eq_non_dutiable ci, cust_inv).to eq "On line 1, Air/Sea Discount amount of 4.0 should equal the Non-Dutiable Amount of the commercial invoice, 3.0, when First Sale flag is set to False."
      end

      it "returns nil if first sale" do
        allow(rule).to receive(:first_sale?).with(cil).and_return true
        expect(rule.air_sea_eq_non_dutiable ci, cust_inv).to be_nil
      end

      it "returns nil if no commercial-invoice discount " do
        cil.update_attributes! other_amount: nil, non_dutiable_amount: 0
        expect(rule.air_sea_eq_non_dutiable ci, cust_inv).to be_nil
      end

      it "returns nil if non-dutiable amount not equal to air/sea discount" do
        cust_il.update_attributes! air_sea_discount: 3
        expect(rule.air_sea_eq_non_dutiable ci, cust_inv).to be_nil
      end
    end

    describe "other_amount_eq_trade_discount" do
      before do
        cil.update_attributes! non_dutiable_amount: 3, other_amount: -4
        cust_il.update_attributes! trade_discount: 5
      end

      it "returns message if not first sale and commercial-invoice discount exists and other adjustment not equal to trade discount " do
        cil.update_attributes! other_amount: -4
        expect(rule.other_amount_eq_trade_discount ci, cust_inv).to eq "On line 1, Trade Discount amount of 5.0 should equal the Other Adjustments Amount of the commercial invoice, 4.0, when First Sale flag is set to False."
      end

      it "returns nil if first sale" do
        allow(rule).to receive(:first_sale?).with(cil).and_return true
        expect(rule.other_amount_eq_trade_discount ci, cust_inv).to be_nil
      end

      it "returns nil if there's no commercial-invoice discount" do
        cil.update_attributes! non_dutiable_amount: nil, other_amount: nil
        expect(rule.other_amount_eq_trade_discount ci, cust_inv).to be_nil
      end

      it "returns nil if other adjustment equals trade discount" do
        cust_il.update_attributes! trade_discount: 4
        expect(rule.other_amount_eq_trade_discount ci, cust_inv).to be_nil
      end
    end

    describe "early_pay_eq_misc_discount" do
      before do
        cil.update_attributes! non_dutiable_amount: 3, miscellaneous_discount: 4
        cust_il.update_attributes! early_pay_discount: 5
      end

      it "returns message if not first sale and commercial-invoice discount exists and miscellaneous discount not equal to early-payment discount" do
        expect(rule.early_pay_eq_misc_discount ci, cust_inv).to eq "On line 1, Early Payment Discount amount of 5.0 should match the Miscellaneous Discount of the commercial invoice, 4.0, when the First Sale is set to False."
      end

      it "returns nil if first sale" do
        allow(rule).to receive(:first_sale?).with(cil).and_return true
        expect(rule.early_pay_eq_misc_discount ci, cust_inv).to be_nil
      end

      it "returns nil if there's no ci discount" do
        cil.update_attributes! non_dutiable_amount: nil, miscellaneous_discount: nil
        expect(rule.early_pay_eq_misc_discount ci, cust_inv).to be_nil
      end

      it "returns nil if miscellaneous discount equal to early-pay discount" do
        cil.update_attributes! miscellaneous_discount: 5
        expect(rule.early_pay_eq_misc_discount ci, cust_inv).to be_nil
      end
    end

    describe "no_missing_discounts" do
      before { cust_il.update_attributes! air_sea_discount: 1, trade_discount: 2, early_pay_discount: 3 }

      it "returns message if not first sale, no commercial-invoice discounts, but customer-invoice-discounts exist" do
        expect(rule.no_missing_discounts ci, cust_inv).to eq "Line 1 is missing the following discounts: Air/Sea Discount (1.0), Trade Discount (2.0), Early Payment Discount (3.0)"
      end

      it "returns nil if first sale" do
        allow(rule).to receive(:first_sale?).with(cil).and_return true
        expect(rule.no_missing_discounts ci, cust_inv).to be_nil
      end

      it "returns nil if there's a commercial-invoice discount" do
        cil.update_attributes! non_dutiable_amount: 3
        expect(rule.no_missing_discounts ci, cust_inv).to be_nil
      end

      it "returns nil if there are no customer-invoice discounts" do
        cust_il.update_attributes! air_sea_discount: 0, early_pay_discount: 0, trade_discount: 0
        expect(rule.no_missing_discounts ci, cust_inv).to be_nil
      end
    end

    describe "fs_applied_instead_of_cust_inv_discount" do
      before { cust_il.update_attributes! middleman_charge: 4, air_sea_discount: 3 }

      it "returns message if not first sale and middleman charge greater than customer-invoice discount" do
        expect(rule.fs_applied_instead_of_cust_inv_discount ci, cust_inv).to eq "On line 1, First Sale Discount amount of 4.0 should have been applied to invoice but was not. Other Discounts were applied instead."
      end

      it "returns nil if first sale" do
        allow(rule).to receive(:first_sale?).with(cil).and_return true
        expect(rule.fs_applied_instead_of_cust_inv_discount ci, cust_inv).to be_nil
      end

      it "returns nil if no middleman charges" do
        cust_il.update_attributes! middleman_charge: nil, air_sea_discount: 0
        expect(rule.fs_applied_instead_of_cust_inv_discount ci, cust_inv).to be_nil
      end

      it "returns nil if middleman charge <= customer-invoice discount" do
        cust_il.update_attributes! middleman_charge: 2
        expect(rule.fs_applied_instead_of_cust_inv_discount ci, cust_inv).to be_nil
      end
    end
  end

end


