require 'spec_helper'

describe MessagesController do

  before(:each) do
    @base_user = Factory(:user)
    @sys_admin_user = Factory(:user)
    @sys_admin_user.sys_admin = true
    @sys_admin_user.save!
    activate_authlogic
  end

  describe 'create' do
    it 'should work for sys_admins' do
      UserSession.create! @sys_admin_user
      put :create, {:message=>{:subject=>'test subject',:body=>'test body',:user_id=>@base_user.id.to_s}}
      response.should redirect_to('/messages')
      flash[:notices].should include "Your message has been sent."
      flash[:errors].should be_blank
      @base_user.reload
      @base_user.messages.should have(1).item
      msg = @base_user.messages.first
      msg.subject.should == 'test subject'
      msg.body.should == 'test body'
    end
    it 'should sanitize html' do
      UserSession.create! @sys_admin_user
      put :create, {:message=>{:subject=>'test <em>subject</em>',:body=>'<a href=\'http://www.google.com\'>test body</a>',:user_id=>@base_user.id.to_s}}
      msg = @base_user.messages.first
      msg.subject.should == 'test subject'
      msg.body.should == 'test body'
    end
    it 'should not allow basic users' do
      UserSession.create! @base_user
      put :create, {:subject=>'test subject',:body=>'test body',:user_id=>@base_user.id.to_s}
      response.should be_redirect
      flash[:notices].should be_blank
      flash[:errors].should_not be_blank
    end
    it 'should not allow normal admins' do
      u = Factory(:user)
      u.admin = true
      u.save!
      UserSession.create! u
      put :create, {:subject=>'test subject',:body=>'test body',:user_id=>@base_user.id.to_s}
      response.should be_redirect
      flash[:notices].should be_blank
      flash[:errors].should_not be_blank
    end
  end

  describe 'new' do
    it 'should allow sys_admins' do
      UserSession.create! @sys_admin_user
      get :new
      response.should be_success
    end
    it 'should not allow basic users' do
      UserSession.create! @base_user
      get :new
      response.should be_redirect
    end
    it 'should not allow normal admins' do
      u = Factory(:user)
      u.admin = true
      u.save!
      UserSession.create! u
      get :new
      response.should be_redirect
    end
  end

end
