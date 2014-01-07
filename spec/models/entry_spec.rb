require 'spec_helper'

describe Entry do
  
  context :tracking_status do
    context :fenix do
      it "should default to created" do
        Factory(:entry,source_system:'Fenix').tracking_status.should == Entry::TRACKING_STATUS_CREATED
      end
      it "should use open for all non-V type entries with across_sent_date" do
        Factory(:entry,source_system:'Fenix',across_sent_date:Time.now).tracking_status.should == Entry::TRACKING_STATUS_OPEN
      end
      it "should use open for all V type entries" do
        Factory(:entry,source_system:'Fenix',entry_type:'V').tracking_status.should == Entry::TRACKING_STATUS_OPEN
      end
      it "should not override closed" do
        ent = Factory(:entry,source_system:'Fenix',tracking_status:Entry::TRACKING_STATUS_CLOSED) 
        ent.release_date = Time.now
        ent.save!
        ent.tracking_status.should == Entry::TRACKING_STATUS_CLOSED
      end
    end
    context :alliance do
      it "should use created for base entry" do
        Factory(:entry,source_system:'Alliance').tracking_status == Entry::TRACKING_STATUS_CREATED
      end
      it "should use open for entries that have been filed" do
        Factory(:entry,source_system:'Alliance',entry_filed_date:Time.now).tracking_status == Entry::TRACKING_STATUS_OPEN
      end
      it "should not override closed" do
        ent = Factory(:entry,source_system:'Alliance',tracking_status:Entry::TRACKING_STATUS_CLOSED)
        ent.entry_filed_date = Time.now
        ent.save!
        ent.tracking_status.should == Entry::TRACKING_STATUS_CLOSED
      end
    end
    context :other do
      it "should default to open" do
        Factory(:entry).tracking_status.should == Entry::TRACKING_STATUS_OPEN
      end
      it "should not override closed" do
        ent = Factory(:entry,tracking_status:Entry::TRACKING_STATUS_CLOSED)
        ent.entry_filed_date = Time.now
        ent.save!
        ent.tracking_status.should == Entry::TRACKING_STATUS_CLOSED
      end
    end
  end
  describe "link_broker_invoices" do
    before :each do
      @ent = Factory(:entry,:broker_reference=>'5555',:source_system=>'ABC')
    end
    it 'should match' do 
      bi = BrokerInvoice.create!(:broker_reference=>'5555',:invoice_number=>'notbrokref',:source_system=>'ABC')
      @ent.link_broker_invoices
      @ent.broker_invoices.first.should == bi
    end
    it "should not match if source system doesn't match" do
      bi = BrokerInvoice.create!(:broker_reference=>'5555',:invoice_number=>'notbrokref',:source_system=>'ZZ')
      @ent.link_broker_invoices
      @ent.broker_invoices.count.should == 0
    end
    it "should not match if broker_reference doesn't match" do
      bi = BrokerInvoice.create!(:broker_reference=>'XX',:invoice_number=>'notbrokref',:source_system=>'ABC')
      @ent.link_broker_invoices
      @ent.broker_invoices.count.should == 0
    end
  end
  describe 'ocean?' do
    it "should return false for nil transport mode" do
      Entry.new.should_not be_ocean
    end
    it "should return true for 10" do
      Entry.new(:transport_mode_code=>"10").should be_ocean
    end
    it "should return true for 11" do
      Entry.new(:transport_mode_code=>"11").should be_ocean
    end
    it "should return false for any other value" do
      Entry.new(:transport_mode_code=>"40").should_not be_ocean
    end
  end
  context 'security' do
    before :each do
      MasterSetup.get.update_attributes(:entry_enabled=>true)
      @importer = Factory(:company,:importer=>true)
      @entry = Factory(:entry,:importer_id=>@importer.id)
      @importer_user = Factory(:user,:company_id=>@importer.id)
      @importer_user.stub(:view_entries?).and_return true
    end
    describe :can_view_importer? do
      it "should allow same company" do
        Entry.can_view_importer?(@importer, @importer_user).should be_true
      end
      it "should not allow different company" do
        Entry.can_view_importer?(Factory(:company), @importer_user).should be_false
      end
      it "should allow master" do
        User.any_instance.stub(:view_entries?).and_return(true)
        Entry.can_view_importer?(@importer, Factory(:master_user)).should be_true
      end
      it "should allow linked" do
        c = Factory(:company)
        @importer.linked_companies << c
        Entry.can_view_importer?(c, @importer_user).should be_true
      end
    end
    context 'search secure' do
      before :each do
        @entry_2 = Factory(:entry,:importer_id=>Factory(:company,:importer=>true).id)
      end
      it 'should restrict non master' do
        found = Entry.search_secure(@importer_user,Entry).all
        found.should have(1).entry
        found.first.should == @entry
      end
      it "should allow linked company for non master" do
        importer2 = Factory(:company,:importer=>true)
        @importer.linked_companies << importer2
        e2 = Factory(:entry,:importer_id=>@importer.id)
        Entry.search_secure(@importer_user,Entry).all.should == [@entry,e2]
      end
      it 'should allow all for master' do
        u = Factory(:user,:entry_view=>true)
        u.company.update_attributes(:master=>true)
        found = Entry.search_secure(u,Entry).all
        found.should have(2).entries
      end
    end
    it 'should allow importer user with permission to view/edit/comment/attach' do
      @importer_user.update_attributes(:entry_view=>true,:entry_comment=>true,:entry_edit=>true,:entry_attach=>true)
      @entry.can_view?(@importer_user).should be_true
      @entry.can_edit?(@importer_user).should be_false #hard coded to false
      @entry.can_attach?(@importer_user).should be_true
      @entry.can_comment?(@importer_user).should be_true
    end
    it 'should allow importer from parent company to view/edit/comment/attach' do
      @parent_company = Factory(:company,:importer=>true)
      @parent_user = Factory(:user,:company=>@parent_company,:entry_view=>true,:entry_comment=>true,:entry_edit=>true,:entry_attach=>true)
      @parent_company.linked_companies << @importer
      @entry.can_view?(@parent_user).should be_true
      @entry.can_edit?(@parent_user).should be_false #hard coded to false
      @entry.can_attach?(@parent_user).should be_true
      @entry.can_comment?(@parent_user).should be_true
    end
    it 'should not allow a user from a different company with overall permission to view/edit/comment/attach' do
      u = Factory(:user,:entry_view=>true,:entry_comment=>true,:entry_edit=>true,:entry_attach=>true)
      u.company.update_attributes(:importer=>true)
      @entry.can_view?(u).should be_false
      @entry.can_edit?(u).should be_false
      @entry.can_attach?(u).should be_false
      @entry.can_comment?(u).should be_false
    end
    it 'should allow master user to view' do
      u = Factory(:user,:entry_view=>true)
      u.company.update_attributes(:master=>true)
      @entry.can_view?(u).should be_true
    end
    it 'should allow user to comment' do
      u = Factory(:user,:entry_comment=>true)
      u.company.update_attributes(:master=>true)
      u.stub(:view_entries?).and_return true
      Factory(:entry).can_comment?(u).should be_true
    end
    it 'should not allow user w/o permission to comment' do
      u = Factory(:user,:entry_comment=>false)
      u.company.update_attributes(:master=>true)
      Factory(:entry).can_comment?(u).should be_false
    end
    it 'should allow user to attach' do
      u = Factory(:user,:entry_attach=>true)
      u.company.update_attributes(:master=>true)
      u.stub(:view_entries?).and_return true
      Factory(:entry).can_attach?(u).should be_true
    end
    it 'should not allow user w/o permisstion to attach' do
      u = Factory(:user,:entry_attach=>false)
      u.company.update_attributes(:master=>true)
      Factory(:entry).can_attach?(u).should be_false
    end
  end

  context 'ports' do
    before :each do 
      @port = Factory(:port)
    end
    it 'should find matching lading port' do
      ent = Factory(:entry,:lading_port_code=>@port.schedule_k_code)
      ent.lading_port.should == @port
    end
    it 'should find matching unlading port' do
      Factory(:entry,:unlading_port_code=>@port.schedule_d_code).unlading_port.should == @port
    end
    it 'should find matching entry port' do
      Factory(:entry,:entry_port_code=>@port.schedule_d_code).entry_port.should == @port
    end
    it 'should find matching us exit port' do
      Factory(:entry,:us_exit_port_code=>@port.schedule_d_code).us_exit_port.should == @port
    end
  end

  context :update_k84_month do
    before :each do
      @entry = Factory(:entry)
    end

    it "should set k84 month" do
      @entry.update_attributes cadex_accept_date: Time.zone.parse("2013-01-01")
      @entry.k84_month.should eq 1
      @entry.k84_due_date.to_date.should == Date.new(2013,1,25)
    end

    it "should set k84 month to next month if cadex accept is 25th or later" do
      @entry.update_attributes cadex_accept_date: Time.zone.parse("2013-01-25")
      @entry.k84_month.should eq 2
      @entry.k84_due_date.to_date.should == Date.new(2013,2,25)
    end

    it "should set k84 month to 1 if cadex accept is after Dec 24th" do
      @entry.update_attributes cadex_accept_date: Time.zone.parse("2013-12-25")
      @entry.k84_due_date.to_date.should == Date.new(2014,1,25)
      @entry.k84_month.should eq 1
    end
  end
end
