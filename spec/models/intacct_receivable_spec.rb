require 'spec_helper'

describe IntacctReceivable do

  describe "create_receivable_type" do
    it "handles ALS sales invoices" do
      expect(IntacctReceivable.create_receivable_type 'als', false).to eq "ALS Sales Invoice"
    end

    it "handles ALS credit notes" do
      expect(IntacctReceivable.create_receivable_type 'als', true).to eq "ALS Credit Note"
    end

    it "handles VCU sales invoices" do
      expect(IntacctReceivable.create_receivable_type 'vcu', false).to eq "VFC Sales Invoice"
    end

    it "handles VCU credit notes" do
      expect(IntacctReceivable.create_receivable_type 'vcu', true).to eq "VFC Credit Note"
    end

    it "handles VFC sales invoices" do
      expect(IntacctReceivable.create_receivable_type 'vfc', false).to eq "VFI Sales Invoice"
    end

    it "handles VFC credit notes" do
      expect(IntacctReceivable.create_receivable_type 'vfc', true).to eq "VFI Credit Note"
    end

    it "handles LMD sales invoices" do
      expect(IntacctReceivable.create_receivable_type 'lmd', false).to eq "LMD Sales Invoice"
    end

    it "handles LMD credit notes" do
      expect(IntacctReceivable.create_receivable_type 'lmd', true).to eq "LMD Credit Note"
    end

    it "raises an error on an unexpected company" do
      expect {IntacctReceivable.create_receivable_type 'blah', true}.to raise_error "Unknown Intacct company received: blah."
    end
  end

  describe "suggested_fix" do
    it "recognizes Receivable invalid customer errors" do
      expect(IntacctReceivable.suggested_fix "Description 2: Invalid Customer").to eq "Create Customer account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Receivable Date Due customer errors" do
      expect(IntacctReceivable.suggested_fix "Description 2: Required field Date Due is missing").to eq "Create Customer account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Receivable retry errors" do
      expect(IntacctReceivable.suggested_fix "BL01001973 XL03000009").to eq "Temporary Upload Error. Click 'Clear This Error' link to try again."
    end

    it "recognizes Receivable invalid vendor errors" do
      expect(IntacctReceivable.suggested_fix "Description 2: Invalid Vendor 'Test' specified.").to eq "Create Vendor account Test in Intacct and/or ensure account has payment Terms set."
    end
  end

  describe "canada?" do
    it "recognizes ALS and VCU as canadian companies" do
      ['vcu', 'als'].each do |c|
        expect(IntacctReceivable.new(company: c)).to be_canada
      end
    end

    it "does not recognize lmd and vfc as canadian companies" do
      ['lmd', 'vfc'].each do |c|
        expect(IntacctReceivable.new(company: c)).not_to be_canada
      end
    end
  end
end