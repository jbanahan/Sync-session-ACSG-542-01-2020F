require 'spec_helper'

describe CommercialInvoice do
  describe "can_view?" do
    before :each do
      MasterSetup.get.update_attributes(:entry_enabled=>true)
    end
    it "should allow view if user is from master and can view invoices" do
      u = Factory(:user,:company=>Factory(:company,:master=>true),:commercial_invoice_view=>true)
      CommercialInvoice.new.can_view?(u).should be_true
    end
    it "should allow view if user is from importer and can view invoices" do
      c = Factory(:company,:importer=>true)
      u = Factory(:user,:commercial_invoice_view=>true,:company=>c)
      CommercialInvoice.new(:importer=>c).can_view?(u).should be_true
    end
    it "should allow view if user is from vendor and can view invoices" do
      c = Factory(:company,:vendor=>true)
      u = Factory(:user,:commercial_invoice_view=>true,:company=>c)
      CommercialInvoice.new(:vendor=>c).can_view?(u).should be_true
    end
  end
end
