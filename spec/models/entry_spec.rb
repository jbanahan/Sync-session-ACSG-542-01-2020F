require 'spec_helper'

describe Entry do
  context 'security' do
    before :each do
      MasterSetup.get.update_attributes(:entry_enabled=>true)
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
