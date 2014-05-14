require 'spec_helper'

describe DelayedJobsController do
  before :each do

    @u = Factory(:user, :admin => true, :sys_admin => true, :company => Factory(:company, :master=>true))
    sign_in_as @u
    @dj = Delayed::Job.create!(:priority => 1, :attempts => 1, :handler => 'handler', :run_at => 2.days.from_now)
  end

  describe "GET 'download'" do
    it "should be successful" do
      delete :destroy, :id => @dj.id
      response.should redirect_to request.referrer
    end

    it "should reject if user isn't sys admin" do
      @u.sys_admin = false
      @u.save!
      delete :destroy, :id => @dj.id
      response.should redirect_to root_path
      flash[:errors].should have(1).message
    end
  end

end
