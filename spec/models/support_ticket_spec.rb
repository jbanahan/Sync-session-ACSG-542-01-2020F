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
      expect(r.size).to eq(1)
      expect(r.first).to eq(find)
    end
  end
  describe "can_view?" do
    it "should allow view if user is support agent" do
      expect(@st.can_view?(User.new(:support_agent=>true))).to be_truthy
    end
    it "should allow view if user is requestor" do
      u = Factory(:user)
      @st.requestor = u
      expect(@st.can_view?(u)).to be_truthy
    end
    it "should allow view if user is admin" do
      u = User.new
      u.admin = true
      expect(@st.can_view?(u)).to be_truthy
    end
    it "should allow view if user is sysadmin" do
      u = User.new
      u.sys_admin = true
      expect(@st.can_view?(u)).to be_truthy
    end
    it "should not allow view if not agent/requestor/admin/sysadmin" do
      expect(@st.can_view?(User.new())).to be_falsey
    end
  end
  describe "can_edit?" do
    before :each do
      @u = User.new
    end
    it "should allow if can_view?" do
      expect(@st).to receive(:can_view?).with(@u).and_return(true)
      expect(@st.can_edit?(@u)).to be_truthy
    end
    it "should not allow if not can_view?" do
      expect(@st).to receive(:can_view?).with(@u).and_return(false)
      expect(@st.can_edit?(@u)).to be_falsey
    end
  end
  context "notifications", :disable_delayed_jobs do
    before :each do
      @requestor = Factory(:user)
      @agent = Factory(:user,:support_agent=>true)
      @st = Factory(:support_ticket,:requestor=>@requestor,:agent=>@agent,:email_notifications=>true)
      @mock_email = double(:email)
    end
    it "should notify agent when requestor is_last_saved_by" do
      expect(@mock_email).to receive(:deliver)
      expect(OpenMailer).to receive(:send_support_ticket_to_agent).with(@st).and_return(@mock_email)
      @st.last_saved_by = @requestor
      @st.send_notification
    end
    it "should notify requestor when agent is last_saved_by" do
      expect(@mock_email).to receive(:deliver)
      expect(OpenMailer).to receive(:send_support_ticket_to_requestor).with(@st).and_return(@mock_email)
      @st.last_saved_by = @agent
      @st.send_notification
    end
    it "should not notify requestor when email_notifications is not true" do
      @st.email_notifications = false
      expect(OpenMailer).not_to receive(:send_support_ticket_to_requestor).with(@st)
      @st.last_saved_by = @agent
      @st.send_notification
    end
    it "should notify both when last_saved_by is not agent or requestor" do
      expect(@mock_email).to receive(:deliver).twice
      expect(OpenMailer).to receive(:send_support_ticket_to_agent).with(@st).and_return(@mock_email)
      expect(OpenMailer).to receive(:send_support_ticket_to_requestor).with(@st).and_return(@mock_email)
      @st.last_saved_by = Factory(:user)
      @st.send_notification
    end
    it "should call send_notification after save if last_saved_by is set" do
      @st.last_saved_by = @agent
      expect(@st).to receive(:send_notification)
      @st.save!
    end
    it "should delay send_notification after save if last_saved_by is set" do
      @st.last_saved_by = @agent
      expect(@st).to receive(:delay).and_return(@st)
      expect(@st).to receive(:send_notification)
      @st.save!
    end
  end
end
