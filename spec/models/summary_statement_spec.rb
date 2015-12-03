require 'spec_helper'
 
 describe SummaryStatement do
  before(:each) {@ss = Factory(:summary_statement)}
  
  describe "self.include?" do
    it "returns true only if a statement number exists in the table" do
      bi = Factory(:broker_invoice)
      @ss.broker_invoices << bi
      
      expect(described_class.include?(bi.id)).to be_true
      expect(described_class.include?(100)).to be_false
    end
  end

  describe :belongs_to_customer? do
    before :each do
      @co = Factory(:company)
      @ss.update_attributes(customer: @co)
      @co_linked = Factory(:company)
      @co.linked_companies << @co_linked
    end

    it "accepts invoices that belong to customer" do
      bi = Factory(:broker_invoice, entry: Factory(:entry, importer: @co))
      expect(@ss.belongs_to_customer?(bi.id)).to be_true
    end

    it "accepts invoices that belong to linked customer" do
      bi = Factory(:broker_invoice, entry: Factory(:entry, importer: @co_linked))
      expect(@ss.belongs_to_customer?(bi.id)).to be_true
    end

    it "rejects invoices that don't belong to either customer or its linked companies" do
      bi = Factory(:broker_invoice, entry: Factory(:entry, importer: Factory(:importer)))
      expect(@ss.belongs_to_customer?(bi.id)).to be_false
    end 

    it "rejects non-existent invoices" do
      expect(@ss.belongs_to_customer?(1000)).to be_false
    end
  end

  describe :can_view? do
    it "returns true if user has permission to view broker invoices" do
      u = Factory(:user)
      u.stub(:view_broker_invoices?).and_return true
      expect(@ss.can_view?(u)).to be_true
    end
  end

  describe :total do
    it "returns the sum of the invoice totals" do
      @ss.broker_invoices = [Factory(:broker_invoice, invoice_total: 10), Factory(:broker_invoice, invoice_total: 5)]
      @ss.save!
      expect(@ss.total).to eq 15
    end
  end

  describe :remove! do
    before(:each) { @ss.broker_invoices << Factory(:broker_invoice) }

    it "removes specified invoice from the statement" do
      @ss.remove! @ss.broker_invoices.first.id
      expect(@ss.broker_invoices.count).to eq 0
    end

    it "raises an error if the invoice doesn't belong to the statement assigned" do
      unassigned_bi_id = Factory(:broker_invoice, invoice_number: '123456789').id
      expect{@ss.remove! unassigned_bi_id}.to raise_error("Invoice 123456789 is not on this statement.")
      expect(@ss.broker_invoices.count).to eq 1
    end
  end

  describe :add! do

    it "adds invoice to a statement if its company matches the statement customer" do
      co = Factory(:company)
      @ss.update_attributes(customer: co)
      bi = Factory(:broker_invoice, entry: Factory(:entry, importer: co))
      @ss.add! bi.id

      expect(@ss.broker_invoices.count).to eq 1
    end

    it "adds invoice to a statement if its company matches a company linked to the statement customer" do
      co = Factory(:company)
      co_linked = Factory(:company)
      co.linked_companies << co_linked
      @ss.update_attributes(customer: co)
      bi = Factory(:broker_invoice, entry: Factory(:entry, importer: co_linked))
      @ss.add! bi.id

      expect(@ss.broker_invoices.count).to eq 1
    end

    it "raises an error if the invoice company is neither the summary statement customer nor a linked company" do
      bi = Factory(:broker_invoice, invoice_number: '123456789', entry: Factory(:entry, importer: Factory(:company)))
      
      expect{@ss.add! bi.id}.to raise_error("Invoice 123456789 does not belong to customer.")
      expect(@ss.broker_invoices.count).to eq 0
    end

    it "raises an error if the invoice is already assigned" do
      bi = Factory(:broker_invoice, invoice_number: '123456789')
      @ss.broker_invoices << bi
      ss_2 = Factory(:summary_statement)

      expect{ss_2.add! bi.id}.to raise_error("Invoice 123456789 is already assigned to a statement.")
      expect(@ss.broker_invoices.count).to eq 1
      expect(ss_2.broker_invoices.count).to eq 0
    end
  end

 end