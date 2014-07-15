require 'spec_helper'

describe Message do
  describe 'unread_message_count' do
    before :each do
      @u = Factory(:user)
    end
    it 'should return number if unread messages exist' do
      Factory(:message,:user=>@u,:viewed=>false) #not viewed should be counted
      Factory(:message,:user=>@u) #no viewed value should be counted
      Factory(:message,:user=>@u,:viewed=>true) #viewed should not be counted
      Message.unread_message_count(@u.id).should == 2
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      Message.should_receive(:purge_messages)
      Message.run_schedulable
    end
  end
end
