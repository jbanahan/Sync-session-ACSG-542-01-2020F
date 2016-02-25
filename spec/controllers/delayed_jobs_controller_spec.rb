require 'spec_helper'

describe DelayedJobsController do
  before :each do
    @u = Factory(:user, :admin => true, :sys_admin => true, :company => Factory(:company, :master=>true))
    sign_in_as @u
  end

  describe "GET 'download'" do  
    before(:each) { @dj = Delayed::Job.create! }

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

  describe :bulk_destroy do
    before :each do
      @dj_1 = Delayed::Job.create!
      @dj_1.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult"
      @dj_1.last_error = "Error!"
      dj_2 = Delayed::Job.create!
      dj_2.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:User"
      dj_2.last_error = "Error!"
      dj_3 = Delayed::Job.create!
      dj_3.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult"
      dj_3.last_error = "Error!"
      [@dj_1, dj_2, dj_3].each(&:save!)
    end

    it "rejects if user isn't sys admin" do
      @u.sys_admin = false
      @u.save!
      delete :bulk_destroy, :id => @dj_1.id
      expect(Delayed::Job.count).to eq 3
      flash[:errors].should have(1).message
      response.should redirect_to root_path
    end

    it "destroys jobs with same class as input job" do
      delete :bulk_destroy, :id => @dj_1.id
      expect(Delayed::Job.count).to eq 1
      expect(response).to redirect_to request.referrer
    end
  end

end
