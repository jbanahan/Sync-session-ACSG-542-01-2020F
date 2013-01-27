require 'spec_helper'

describe MailboxesController do
  before :each do
    @u = Factory(:user,:first_name=>'Joe',:last_name=>'Friday')
    activate_authlogic
    UserSession.create! @u
  end
  describe :index do
    it "should render successfully" do
      get :index
      response.should be_success
    end
  end
  describe :show do
    before :each do
      @m = Factory(:mailbox,:name=>'MNAME')
      @m.users << @u
    end
    it "should render error message if user cannot view mailbox" do
      Mailbox.any_instance.stub(:can_view?).and_return(false)
      get :show, :id=>@m.id
      response.should be_success
      JSON.parse(response.body).should == {"errors"=>["You do not have permission to view this mailbox."]}
    end
    it "should be json if permissions are good" do
      e = @m.emails.create!(:body_text=>"abc",:from=>'x',:subject=>'s',:assigned_to_id=>@u.id)
      Mailbox.any_instance.stub(:can_view?).and_return(true)
      get :show, :id=>@m.id
      r = JSON.parse(response.body)
      r['id'].should == @m.id
      r['name'].should == @m.name
      r['emails'].should have(1).email
      eh = r['emails'].first
      eh['subject'].should == e.subject
      eh['safe_html'].should be_nil #we don't want to pre-load the text
      eh['created_at'].should_not be_nil
      eh['from'].should == e.from
      eh['id'].should == e.id
      eh['assigned_to_id'].should == @u.id
      r['users'].should have(1).user_entry
      u = r['users'].first
      u['id'].should == @u.id
      u['full_name'].should == 'Joe Friday'
      u['allow_assign'].should be_true
    end
    it "should include users not assigned to mailbox if assigned to an email" do
      u2 = Factory(:user,:first_name=>'Z')
      e = @m.emails.create!(:assigned_to_id=>u2.id,:body_text=>"abc",:from=>'x',:subject=>'s')
      Mailbox.any_instance.stub(:can_view?).and_return(true)
      get :show, :id=>@m.id
      r = JSON.parse(response.body)
      r['users'].last['id'].should == u2.id
      r['users'].last['allow_assign'].should be_false
    end
  end
end
