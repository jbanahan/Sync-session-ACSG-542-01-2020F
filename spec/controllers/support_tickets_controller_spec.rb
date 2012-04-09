require 'spec_helper'

describe SupportTicketsController do
  describe 'index' do
    before :each do
      @requestor = Factory(:user)
      @agent = Factory(:user,:support_agent=>true)
      activate_authlogic
    end
    it 'should show requestor tickets' do
      UserSession.create! @requestor
      2.times {|i| Factory(:support_ticket,:requestor=>@requestor)}
      Factory(:support_ticket,:requestor=>Factory(:user)) #don't find this one
      get :index
      response.should be_success
      assigns(:tickets).should have(2).tickets
      assigns(:tickets).each {|t| t.requestor.should == @requestor}
    end
    it 'should show assigned tickets support agents' do
      UserSession.create! @agent
      2.times {|i| Factory(:support_ticket,:agent=>@agent)}
      get :index
      response.should be_success
      assigns(:tickets).should be_empty
      assigns(:assigned).should have(2).tickets
    end
    it 'should show unassigned tickets for support agents' do
      UserSession.create! @agent
      2.times {|i| Factory(:support_ticket,:agent=>nil)}
      get :index
      response.should be_success
      assigns(:tickets).should be_empty
      assigns(:unassigned).should have(2).tickets
    end
  end
end
