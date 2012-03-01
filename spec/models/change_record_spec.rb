require 'spec_helper'

describe ChangeRecord do
  describe "messages" do
    it 'should return all messages' do
      cr = ChangeRecord.new
      cr.add_message "x"
      cr.add_message "y"
      cr.messages.to_a.should == ["x","y"]
    end
    it 'should return empty but not nil' do
      ChangeRecord.new.messages.should == []
    end
  end
  describe "add_message" do
    before :each do
      @cr = ChangeRecord.new
    end
    it "should build a new message" do
      msg = @cr.add_message "hello world"
      msg.message.should == "hello world"
      @cr.should_not be_failed
      @cr.change_record_messages.should have(1).message
      @cr.change_record_messages.first.should equal msg
    end
    it "should set failure flag" do
      msg = @cr.add_message "hello world", true
      @cr.should be_failed
    end
    it "should not turn of failure flag when false is passed" do
      @cr.failed = true
      @cr.add_message "hello world", false
      @cr.should be_failed
    end
  end
end
