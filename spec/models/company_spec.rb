require 'spec_helper'

describe Company do
  context 'security' do
    before :each do
      MasterSetup.get.update_attributes(:entry_enabled=>true,:broker_invoice_enabled=>true)
    end
    it 'should not allow duplicate alliance_customer_number' do
      c1 = Factory(:company,:alliance_customer_number=>'123')
      c2 = Company.new(:name=>'abc',:alliance_customer_number => c1.alliance_customer_number)
      c2.save.should be_false
      c2.errors.full_messages.first.should == "Alliance customer number is already taken."
    end
    context 'entries' do
      it 'should not allow view if master setup is disabled' do
        MasterSetup.get.update_attributes(:entry_enabled=>false)
        c = Factory(:company,:importer=>true)
        c.view_entries?.should be_false
        c.comment_entries?.should be_false
        c.attach_entries?.should be_false
      end
      it 'should allow master view/comment/attach' do
        c = Factory(:company,:master=>true)
        c.view_entries?.should be_true
        c.comment_entries?.should be_true
        c.attach_entries?.should be_true
      end
      it 'should allow importer view/comment/attach' do
        c = Factory(:company,:importer=>true)
        c.view_entries?.should be_true
        c.comment_entries?.should be_true
        c.attach_entries?.should be_true
      end
      it 'should not allow other company view/comment/attach' do
        c = Factory(:company,:importer=>false,:master=>false)
        c.view_entries?.should be_false
        c.comment_entries?.should be_false
        c.attach_entries?.should be_false
      end
    end
    context 'broker invoices' do
      it 'should not allow view if master setup is disabled' do
        MasterSetup.get.update_attributes(:broker_invoice_enabled=>false)
        c = Factory(:company,:importer=>true)
        c.view_broker_invoices?.should be_false
      end
      it 'should allow master view' do
        c = Factory(:company,:master=>true)
        c.view_broker_invoices?.should be_true
      end
      it 'should allow importer view' do
        c = Factory(:company,:importer=>true)
        c.view_broker_invoices?.should be_true
      end
      it 'should not allow other company view' do
        c = Factory(:company,:importer=>false,:master=>false)
        c.view_broker_invoices?.should be_false
      end
    end
  end
end
