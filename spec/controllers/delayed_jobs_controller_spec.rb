describe DelayedJobsController do
  before :each do
    @u = FactoryBot(:user, :admin => true, :sys_admin => true, :company => FactoryBot(:company, :master=>true))
    sign_in_as @u
  end

  describe "run_now" do
    let(:now) { DateTime.new(2019, 3, 16, 12) }
    let(:yesterday) { DateTime.new(2019, 3, 15, 12) }
    let(:dj) { Delayed::Job.create!(priority: 10, run_at: yesterday) }

    it "sets run_at and priority" do
      now = DateTime.new(2019, 3, 16, 12)
      Timecop.freeze(now) { post :run_now, id: dj.id }
      dj.reload
      expect(dj.priority).to eq(-1000)
      expect(dj.run_at).to eq now
      expect(response).to redirect_to request.referrer
      expect(flash[:notices]).to eq ["Delayed Job #{dj.id} will run next."]
    end

    it "errors if job is locked" do
      dj.update_attributes! locked_at: Time.now
      Timecop.freeze(now) { post :run_now, id: dj.id }
      dj.reload
      expect(dj.priority).to eq 10
      expect(dj.run_at).to eq yesterday
      expect(flash[:errors]).to eq ["Delayed Job #{dj.id} can't be scheduled because it is locked."]
    end
  end

  describe "destroy" do
    before(:each) { @dj = Delayed::Job.create! }

    it "should be successful" do
      delete :destroy, :id => @dj.id
      expect(response).to redirect_to request.referrer
    end

    it "should reject if user isn't sys admin" do
      @u.sys_admin = false
      @u.save!
      delete :destroy, :id => @dj.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
  end

  describe "bulk_destroy" do
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
      expect(flash[:errors].size).to eq(1)
      expect(response).to redirect_to root_path
    end

    it "destroys jobs with same class as input job" do
      delete :bulk_destroy, :id => @dj_1.id
      expect(Delayed::Job.count).to eq 1
      expect(response).to redirect_to request.referrer
    end

    it "skips jobs that are locked" do
      dj_4 = Delayed::Job.create!
      dj_4.handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/ActiveRecord:ReportResult"
      dj_4.last_error = "Error!"
      dj_4.locked_at = DateTime.now
      dj_4.save!

      delete :bulk_destroy, :id => @dj_1.id
      expect(Delayed::Job.count).to eq 2
      expect(response).to redirect_to request.referrer
    end
  end

end
