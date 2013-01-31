require 'spec_helper'

describe EmailsController do
  before :each do 
    @u = Factory(:user)
    activate_authlogic
    UserSession.create! @u
  end
  describe "show" do
    before :each do
      @e = Factory(:email)
    end
    it 'should only show if you have permission to view' do
      Email.any_instance.stub(:can_view?).and_return false
      get :show, :id=>@e.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should get email" do
      Email.any_instance.stub(:can_view?).and_return true 
      get :show, :id=>@e.id
      response.should be_success
      assigns(:email).should == @e
    end
  end
  describe "toggle_archive" do
    it "should return error if user does not have permission to edit"
    context :secure do
      before :each do
        Email.any_instance.stub(:can_edit?).and_return true
        @email = Factory(:email)
      end
      it "should archive email" do
        post :toggle_archive, :id=>@email.id
        JSON.parse(response.body).should == {"OK"=>"OK"}
        @email.reload
        @email.should be_archived
      end
      it "should remove archive flag" do
        @email.update_attributes(:archived=>true)
        post :toggle_archive, :id=>@email.id
        JSON.parse(response.body).should == {"OK"=>"OK"}
        @email.reload
        @email.should_not be_archived
      end
    end
  end
  describe "assign" do
    before :each do 
      @e1 = Factory(:email)
      @e2 = Factory(:email)
      @e3 = Factory(:email)
    end
    it "should return error if user does not have permission to edit"
    it "should return error if target user does not have permission to view"
    it "should make assignements and return success if user has permission" do
      Email.any_instance.stub(:can_edit?).and_return true
      post :assign, {'email'=>{"0"=>{"id"=>@e1.id.to_s},"1"=>{"id"=>@e2.id.to_s}},'user_id'=>@u.id.to_s}
      JSON.parse(response.body).should == {"OK"=>"OK"}
      [@e1,@e2,@e3].each {|e| e.reload}
      @e1.assigned_to.should == @u
      @e2.assigned_to.should == @u
      @e3.assigned_to.should be_nil
    end
  end
end
