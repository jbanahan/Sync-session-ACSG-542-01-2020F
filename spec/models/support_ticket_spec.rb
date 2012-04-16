require 'spec_helper'

describe SupportTicket do
  before :each do
    @st = SupportTicket.new
  end
  describe "open scope" do
    it "should return open tickets" do
      find = Factory(:support_ticket)
      dont_find = Factory(:support_ticket,:state=>"closed")
      r = SupportTicket.open
      r.should have(1).ticket
      r.first.should == find
    end
  end
  describe :can_view? do
    it "should allow view if user is support agent" do
      @st.can_view?(User.new(:support_agent=>true)).should be_true
    end
    it "should allow view if user is requestor" do
      u = Factory(:user)
      @st.requestor = u
      @st.can_view?(u).should be_true
    end
    it "should allow view if user is admin" do
      u = User.new
      u.admin = true
      @st.can_view?(u).should be_true
    end
    it "should allow view if user is sysadmin" do
      u = User.new
      u.sys_admin = true
      @st.can_view?(u).should be_true
    end
    it "should not allow view if not agent/requestor/admin/sysadmin" do
      @st.can_view?(User.new()).should be_false
    end
  end
  describe :can_edit? do
    before :each do
      @u = User.new
    end
    it "should allow if can_view?" do
      @st.should_receive(:can_view?).with(@u).and_return(true)
      @st.can_edit?(@u).should be_true
    end
    it "should not allow if not can_view?" do
      @st.should_receive(:can_view?).with(@u).and_return(false)
      @st.can_edit?(@u).should be_false
    end
  end
  context "notifications" do
    before :each do
      @dj_state = Delayed::Worker.delay_jobs
      Delayed::Worker.delay_jobs = false
      @requestor = Factory(:user)
      @agent = Factory(:user,:support_agent=>true)
      @st = Factory(:support_ticket,:requestor=>@requestor,:agent=>@agent,:email_notifications=>true)
      @mock_email = mock(:email)
    end
    after :each do
      Delayed::Worker.delay_jobs = @dj_state
    end
    it "should notify agent when requestor is_last_saved_by" do
      @mock_email.should_receive(:deliver)
      OpenMailer.should_receive(:send_support_ticket_to_agent).with(@st).and_return(@mock_email)
      @st.last_saved_by = @requestor
      @st.send_notification
    end
    it "should notify requestor when agent is last_saved_by" do
      @mock_email.should_receive(:deliver)
      OpenMailer.should_receive(:send_support_ticket_to_requestor).with(@st).and_return(@mock_email)
      @st.last_saved_by = @agent
      @st.send_notification
    end
    it "should not notify requestor when email_notifications is not true" do
      @st.email_notifications = false
      OpenMailer.should_not_receive(:send_support_ticket_to_requestor).with(@st)
      @st.last_saved_by = @agent
      @st.send_notification
    end
    it "should notify both when last_saved_by is not agent or requestor" do
      @mock_email.should_receive(:deliver).twice
      OpenMailer.should_receive(:send_support_ticket_to_agent).with(@st).and_return(@mock_email)
      OpenMailer.should_receive(:send_support_ticket_to_requestor).with(@st).and_return(@mock_email)
      @st.last_saved_by = Factory(:user)
      @st.send_notification
    end
    it "should call send_notification after save if last_saved_by is set" do
      @st.last_saved_by = @agent
      @st.should_receive(:send_notification)
      @st.save!
    end
    it "should delay send_notification after save if last_saved_by is set" do
      @st.last_saved_by = @agent
      @st.should_receive(:delay).and_return(@st)
      @st.should_receive(:send_notification)
      @st.save!
    end
  end
end
