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

  describe "email_to_user" do
    let(:user) { Factory(:user, email_new_messages: true) }

    it "sends emails to user who gets a system message" do
      OpenMailer.should_receive(:delay).and_return OpenMailer
      OpenMailer.should_receive(:send_message)

      user.messages.create! subject: "Subject", body: "Body"
    end

    it "does not send email to user that doesn't want them" do
      user.update_attributes! email_new_messages: false
      OpenMailer.should_not_receive(:delay)
      user.messages.create! subject: "Subject", body: "Body"
    end

    it "doesn't send email to disabled users" do
      user.disabled = true
      user.save!

      OpenMailer.should_not_receive(:delay)
      user.messages.create! subject: "Subject", body: "Body"
    end
  end
end
