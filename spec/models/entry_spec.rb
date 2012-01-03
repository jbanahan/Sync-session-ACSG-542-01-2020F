require 'spec_helper'

describe Entry do
  context 'security' do
    before :each do
      MasterSetup.get.update_attributes(:entry_enabled=>true)
      @importer = Factory(:company,:importer=>true)
      @entry = Factory(:entry,:importer_id=>@importer.id)
      @importer_user = Factory(:user,:company_id=>@importer.id)
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
  end
end
