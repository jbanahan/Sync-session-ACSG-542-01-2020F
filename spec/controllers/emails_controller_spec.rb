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
    before :each do
      @e1 = Factory(:email,:archived=>true)
      @e2 = Factory(:email)
      @e3 = Factory(:email)
    end

    it "should return error if user does not have permission to edit" do
      Email.any_instance.stub(:can_edit?).and_return false, true
      post :toggle_archive, {'email'=>{"0"=>{"id"=>@e1.id.to_s},"1"=>{"id"=>@e2.id.to_s}},'user_id'=>@u.id.to_s}
      JSON.parse(response.body).should == {"errors"=>["You do not have permission to edit these messages."]}
      [@e1,@e2,@e3].each {|e| e.reload}
      @e1.should be_archived
      @e2.should_not be_archived
      @e3.should_not be_archived
    end
    context :secure do
      before :each do
        Email.any_instance.stub(:can_edit?).and_return true
      end
      it "should toggle archive" do
        post :toggle_archive, {'email'=>{"0"=>{"id"=>@e1.id.to_s},"1"=>{"id"=>@e2.id.to_s}},'user_id'=>@u.id.to_s}
        JSON.parse(response.body).should == {"OK"=>"OK"}
        [@e1,@e2,@e3].each {|e| e.reload}
        @e1.should_not be_archived
        @e2.should be_archived
        @e3.should_not be_archived
      end
    end
  end
  describe "assign" do
    before :each do 
      @e1 = Factory(:email)
      @e2 = Factory(:email)
      @e3 = Factory(:email)
    end
    it "should return error if user does not have permission to edit" do
      Email.any_instance.stub(:can_edit?).and_return false, true
      Email.any_instance.stub(:can_view?).and_return true
      post :assign, {'email'=>{"0"=>{"id"=>@e1.id.to_s},"1"=>{"id"=>@e2.id.to_s}},'user_id'=>@u.id.to_s}
      JSON.parse(response.body).should == {"errors"=>["You do not have permission to edit these messages."]}
      [@e1,@e2,@e3].each do |e| 
        e.reload
        e.assigned_to.should be_nil
      end
    end
    it "should return error if target user does not have permission to view" do
      Email.any_instance.stub(:can_edit?).and_return true
      Email.any_instance.stub(:can_view?).and_return false
      post :assign, {'email'=>{"0"=>{"id"=>@e1.id.to_s},"1"=>{"id"=>@e2.id.to_s}},'user_id'=>@u.id.to_s}
      JSON.parse(response.body).should == {"errors"=>["Messages cannot be assigned because #{@u.full_name} does not have permission to view them."]}
      [@e1,@e2,@e3].each do |e| 
        e.reload
        e.assigned_to.should be_nil
      end
    end
    it "should make assignements and return success if user has permission" do
      Email.any_instance.stub(:can_edit?).and_return true
      Email.any_instance.stub(:can_view?).and_return true 
      post :assign, {'email'=>{"0"=>{"id"=>@e1.id.to_s},"1"=>{"id"=>@e2.id.to_s}},'user_id'=>@u.id.to_s}
      JSON.parse(response.body).should == {"OK"=>"OK"}
      [@e1,@e2,@e3].each {|e| e.reload}
      @e1.assigned_to.should == @u
      @e2.assigned_to.should == @u
      @e3.assigned_to.should be_nil
    end
  end
end
