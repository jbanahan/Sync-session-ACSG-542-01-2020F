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
end