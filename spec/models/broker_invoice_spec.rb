require 'spec_helper'

describe BrokerInvoice do
  context 'currency' do
    it "should default currency to USD" do
      bi = BrokerInvoice.create!
      bi.currency.should == "USD"
    end
    it "should leave existing currency alone" do
      BrokerInvoice.create!(:currency=>"CAD").currency.should == "CAD"
    end
  end
  context 'security' do
    before :each do
      MasterSetup.get.update_attributes(:broker_invoice_enabled=>true)
      @importer = Factory(:company,:importer=>true)
      @importer_user = Factory(:user,:company_id=>@importer.id,:broker_invoice_view=>true)
      @entry = Factory(:entry,:importer_id=>@importer.id)
      @inv = Factory(:broker_invoice,:entry_id=>@entry.id)
    end
    context 'search secure' do
      before :each do
        entry_2 = Factory(:entry,:importer_id=>Factory(:company,:importer=>true).id)
        inv_2 = Factory(:broker_invoice,:entry_id=>entry_2.id)
      end
      it 'should restrict non master by entry importer id' do
        found = BrokerInvoice.search_secure(@importer_user,BrokerInvoice)
        found.should have(1).invoice
        found.first.should == @inv
      end
      it 'should allow all for master' do
        u = Factory(:user,:broker_invoice_view=>true)
        u.company.update_attributes(:master=>true)
        found = BrokerInvoice.search_secure(u,BrokerInvoice)
        found.should have(2).invoices
      end
      it 'should allow for linked company' do
        child = Factory(:company,:importer=>true)
        i3 = Factory(:broker_invoice,:entry=>Factory(:entry,:importer_id=>child.id))
        @importer.linked_companies << child
        BrokerInvoice.search_secure(@importer_user,BrokerInvoice).all.should == [@inv,i3]
      end
    end
    it 'should be visible for importer' do
      @inv.can_view?(@importer_user).should be_true 
    end
    it 'should not be visible for another importer' do
      u = Factory(:user,:company_id=>Factory(:company,:importer=>true).id,:broker_invoice_view=>true)
      @inv.can_view?(u).should be_false
    end
    it 'should be visible for parent importer' do
      parent = Factory(:company,:importer=>true)
      parent.linked_companies << @importer
      u = Factory(:user,:company_id=>parent.id,:broker_invoice_view=>true)
      @inv.can_view?(u).should be_true
    end
    it 'should not be visible without permission' do
      u = Factory(:user,:broker_invoice_view=>false)
      u.company.update_attributes(:master=>true)
      @inv.can_view?(u).should be_false
    end
    it 'should not be visible without company permission' do
      u = Factory(:user,:broker_invoice_view=>true)
      @inv.can_view?(u).should be_false
    end
    it 'should be visible with permission' do
      u = Factory(:user,:broker_invoice_view=>true)
      u.company.update_attributes(:master=>true)
      @inv.can_view?(u).should be_true
    end
    it "should be editable with permission and view permission" do
      @inv.stub(:can_view?).and_return(true)
      u = User.new
      u.stub(:edit_broker_invoices?).and_return true
      @inv.can_edit?(u).should be_true
    end
    it "should not be editable without view permission" do
      @inv.stub(:can_view?).and_return(false)
      u = User.new
      u.stub(:edit_broker_invoices?).and_return true
      @inv.can_edit?(u).should be_false
    end
    it "should not be editable without edit permission" do
      @inv.stub(:can_view?).and_return(true)
      u = User.new
      u.stub(:edit_broker_invoices?).and_return false
      @inv.can_edit?(u).should be_false
    end
    it "should not be editable if locked" do
      @inv.stub(:can_view?).and_return(true)
      u = User.new
      u.stub(:edit_broker_invoices?).and_return true
      @inv.locked = true
      @inv.can_edit?(u).should be_false
    end
  end
end
